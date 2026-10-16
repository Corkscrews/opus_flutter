#!/usr/bin/env python3
"""Vendors the pinned upstream libopus release into opus_dart/native.

Reads opus_dart/native/libopus.json, obtains the release archive (downloaded
from the pinned URL unless --archive is given), checks its SHA-256, and
rebuilds the vendored tree:

  vendor/opus/     allowlisted sources and their transitive quoted includes
  config/config.h  generated from the pinned version
  sources.json     compile groups and include directories for the build hook
  checksums.sha256 SHA-256 of every tracked file, relative to native/

Usage:
  scripts/vendor_libopus.py                  fetch, verify, vendor, check
  scripts/vendor_libopus.py --archive PATH   vendor from a local archive
  scripts/vendor_libopus.py --check          verify the tree offline (CI)
  scripts/vendor_libopus.py --latest         print the newest stable release
  scripts/vendor_libopus.py --update 1.6.1   pin a release, then vendor it

Standard library only, so it runs on any CI image with python3.
"""

import argparse
import hashlib
import json
import posixpath
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

NATIVE = Path(__file__).resolve().parent.parent / "opus_dart" / "native"
MANIFEST = NATIVE / "libopus.json"
VENDOR = NATIVE / "vendor" / "opus"
CONFIG_DIR = NATIVE / "config"
SHIM_DIR = NATIVE / "shim"
SOURCES_JSON = NATIVE / "sources.json"
CHECKSUMS = NATIVE / "checksums.sha256"

# Xiph's release directory and the checksums it publishes for it. --update
# takes the expected digest from here, never from the downloaded archive.
SUMS_URL = "https://downloads.xiph.org/releases/opus/SHA256SUMS.txt"
RELEASE_URL = "https://downloads.xiph.org/releases/opus/opus-%s.tar.gz"

# Compile groups, named after the upstream makefile variables they come from.
# This is the float, generic-C baseline: no fixed-point, no x86/ARM RTCD, no
# DNN/DRED/OSCE. Optimized groups are added deliberately, not by default.
GROUPS = [
    ("opus", "opus_sources.mk", "OPUS_SOURCES"),
    ("opus_float", "opus_sources.mk", "OPUS_SOURCES_FLOAT"),
    ("celt", "celt_sources.mk", "CELT_SOURCES"),
    ("silk", "silk_sources.mk", "SILK_SOURCES"),
    ("silk_float", "silk_sources.mk", "SILK_SOURCES_FLOAT"),
]

# Authored in this repository rather than taken from upstream.
SHIM_SOURCES = ["shim/opus_codec_shim.c"]

# Quoted includes resolve like the upstream CMake target: the including file's
# own directory first, then these release-relative directories.
UPSTREAM_INCLUDE_DIRS = ["", "include", "celt", "silk", "silk/float", "dnn"]

# Include directories the compiler needs, relative to native/. Only the ones
# that exist in the vendored tree are written to sources.json.
INCLUDE_CANDIDATES = ["config"] + [
    "vendor/opus" + ("/" + d if d else "") for d in UPSTREAM_INCLUDE_DIRS
]

# Licence notices copied next to the sources.
NOTICES = ["COPYING", "AUTHORS"]

# Quoted includes that are allowed to stay unresolved, each with the reason.
# They sit under preprocessor branches the baseline never enables, so the
# include is never compiled. Anything else unresolved fails the vendoring.
OPTIONAL_INCLUDES = {
    "custom_support.h": "celt/os_support.h: CUSTOM_SUPPORT, undefined",
    "dsplib.h": "celt/ecintrin.h: ENABLE_TI_DSPLIB, undefined",
    "fixed_bfin.h": "celt/arch.h: BFIN_ASM, undefined",
    "fixed_c5x.h": "celt/arch.h: TI_C5X_ASM, undefined",
    "fixed_c6x.h": "celt/arch.h: TI_C6X_ASM, undefined",
    "main_FIX.h": "silk/*.c: FIXED_POINT branch, baseline is float (main_FLP.h)",
    "xtensa/SigProc_FIX_lx7.h": "silk/SigProc_FIX.h: OPUS_XTENSA_LX7, undefined",
    "xtensa/macros_lx7.h": "silk/macros.h: OPUS_XTENSA_LX7, undefined",
}

INCLUDE_PATTERN = re.compile(rb'^[ \t]*#[ \t]*include[ \t]*"([^"]+)"', re.M)


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_group(release, makefile, variable):
    lines = (release / makefile).read_text(encoding="utf-8").splitlines()
    pattern = re.compile(r"^%s\s*=" % re.escape(variable))
    start = next((i for i, line in enumerate(lines) if pattern.match(line)), None)
    if start is None:
        raise SystemExit("%s: %s not found" % (makefile, variable))
    files = []
    for line in lines[start + 1 :]:
        entry = line.strip().rstrip("\\").strip()
        if not entry:
            break
        files.append(entry)
    return files


def resolve_include(release, including, name):
    candidates = [posixpath.join(posixpath.dirname(including), name)]
    candidates += [posixpath.join(d, name) for d in UPSTREAM_INCLUDE_DIRS]
    for candidate in candidates:
        candidate = posixpath.normpath(candidate)
        if candidate.startswith(".."):
            continue
        if (release / candidate).is_file():
            return candidate
    return None


def closure(release, seeds):
    wanted = set()
    unresolved = []
    pending = list(seeds)
    while pending:
        rel = pending.pop()
        if rel in wanted:
            continue
        wanted.add(rel)
        for raw in INCLUDE_PATTERN.findall((release / rel).read_bytes()):
            name = raw.decode("utf-8")
            if name == "config.h":
                continue  # supplied by native/config, generated below
            found = resolve_include(release, rel, name)
            if found is None:
                if name not in OPTIONAL_INCLUDES:
                    unresolved.append('#include "%s" in %s' % (name, rel))
                continue
            pending.append(found)
    if unresolved:
        raise SystemExit("unresolved includes, audit and add to OPTIONAL_INCLUDES:\n  "
                         + "\n  ".join(sorted(set(unresolved))))
    return sorted(wanted)


def extract(archive, destination):
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            parts = Path(member.name).parts
            if (
                member.name.startswith("/")
                or ".." in parts
                or member.issym()
                or member.islnk()
            ):
                raise SystemExit("refusing archive member %s" % member.name)
        if hasattr(tarfile, "data_filter"):
            tar.extractall(destination, filter="data")
        else:
            tar.extractall(destination)


def config_text(version):
    return (
        "/* Generated by scripts/vendor_libopus.py from libopus.json. "
        "Do not edit. */\n"
        '#define PACKAGE_VERSION "%s"\n' % version
    )


def tracked_files():
    found = []
    for base in [VENDOR, CONFIG_DIR, SHIM_DIR]:
        found += [p for p in base.rglob("*") if p.is_file()]
    return sorted(
        p.relative_to(NATIVE).as_posix()
        for p in found
        if not p.name.startswith(".")
    )


def write_outputs(version, groups, include_dirs):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    (CONFIG_DIR / "config.h").write_text(config_text(version), encoding="utf-8")

    sources = {"include_dirs": include_dirs, "groups": {}}
    for name, files in groups:
        sources["groups"][name] = ["native/vendor/opus/" + f for f in files]
    sources["groups"]["shim"] = ["native/" + f for f in SHIM_SOURCES]
    SOURCES_JSON.write_text(json.dumps(sources, indent=2) + "\n", encoding="utf-8")

    lines = [
        "%s  %s" % (sha256_of(NATIVE / rel), rel) for rel in tracked_files()
    ]
    CHECKSUMS.write_text("\n".join(lines) + "\n", encoding="utf-8")


def vendor(manifest, archive):
    version = manifest["version"]
    actual = sha256_of(archive)
    expected = manifest["archive"]["sha256"]
    if actual != expected:
        raise SystemExit(
            "archive sha256 %s does not match the pinned %s" % (actual, expected)
        )

    with tempfile.TemporaryDirectory() as tmp:
        extract(archive, tmp)
        release = Path(tmp) / ("opus-%s" % version)
        if not release.is_dir():
            raise SystemExit("archive does not contain opus-%s/" % version)

        groups = []
        seeds = []
        for name, makefile, variable in GROUPS:
            files = read_group(release, makefile, variable)
            groups.append((name, files))
            seeds.extend(files)

        files = closure(release, seeds)
        if VENDOR.exists():
            shutil.rmtree(VENDOR)
        for rel in files:
            target = VENDOR / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(release / rel, target)
        for notice in NOTICES:
            shutil.copyfile(release / notice, VENDOR / notice)

    # config/ is generated by write_outputs, so create it before listing dirs.
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    include_dirs = [
        "native/" + d
        for d in INCLUDE_CANDIDATES
        if (NATIVE / d).is_dir()
    ]
    write_outputs(version, groups, include_dirs)
    print("vendored libopus %s: %d sources and headers" % (version, len(files)))


def check():
    errors = []
    recorded = {}
    for line in CHECKSUMS.read_text(encoding="utf-8").splitlines():
        digest, rel = line.split("  ", 1)
        recorded[rel] = digest
        target = NATIVE / rel
        if not target.is_file():
            errors.append("missing: %s" % rel)
        elif sha256_of(target) != digest:
            errors.append("digest mismatch: %s" % rel)

    for rel in tracked_files():
        if rel not in recorded:
            errors.append("not listed in checksums.sha256: %s" % rel)

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if (CONFIG_DIR / "config.h").read_text(encoding="utf-8") != config_text(
        manifest["version"]
    ):
        errors.append("config/config.h is out of date for libopus %s" % manifest["version"])

    sources = json.loads(SOURCES_JSON.read_text(encoding="utf-8"))
    for group, paths in sources["groups"].items():
        for path in paths:
            if path[len("native/") :] not in recorded:
                errors.append("group %s lists untracked file %s" % (group, path))
    for directory in sources["include_dirs"]:
        if not (NATIVE.parent / directory).is_dir():
            errors.append("include directory missing: %s" % directory)
    # Every upstream source includes config.h unconditionally.
    if "native/config" not in sources["include_dirs"]:
        errors.append("native/config is not on the include path")

    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print("libopus vendor check failed: %d problem(s)" % len(errors), file=sys.stderr)
        return 1
    print("libopus vendor check passed: %d tracked files" % len(recorded))
    return 0


def published_releases():
    """Stable releases and their SHA-256, from Xiph's own checksum list.

    The strict version pattern excludes alpha/beta/rc archives.
    """
    with urllib.request.urlopen(SUMS_URL, timeout=60) as response:
        text = response.read().decode("utf-8")
    releases = {}
    for match in re.finditer(r"^([0-9a-f]{64})\s+opus-(\d+(?:\.\d+)+)\.tar\.gz$", text, re.M):
        releases[match.group(2)] = match.group(1)
    return releases


def version_key(version):
    return tuple(int(part) for part in version.split("."))


def pin(version):
    """Points libopus.json at a published release, with Xiph's digest."""
    releases = published_releases()
    if version not in releases:
        raise SystemExit("libopus %s is not in %s" % (version, SUMS_URL))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["version"] = version
    manifest["archive"] = {"url": RELEASE_URL % version, "sha256": releases[version]}
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--archive", help="vendor from this archive instead of downloading")
    parser.add_argument("--check", action="store_true", help="verify without network access")
    parser.add_argument("--latest", action="store_true", help="print the newest stable release")
    parser.add_argument("--update", metavar="VERSION", help="pin VERSION, then vendor it")
    args = parser.parse_args()

    if args.check:
        return check()
    if args.latest:
        print(max(published_releases(), key=version_key))
        return 0
    if args.update:
        pin(args.update)

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.archive:
        vendor(manifest, Path(args.archive))
    else:
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "libopus.tar.gz"
            print("downloading %s" % manifest["archive"]["url"])
            urllib.request.urlretrieve(manifest["archive"]["url"], archive)
            vendor(manifest, archive)
    return check()


if __name__ == "__main__":
    sys.exit(main())
