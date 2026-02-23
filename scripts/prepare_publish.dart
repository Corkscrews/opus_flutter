/// Rewrites path dependencies in a package's pubspec.yaml to version constraints.
///
/// Usage: dart run scripts/prepare_publish.dart <package_dir>
///
/// For each dependency using `path:`, this script reads the target package's
/// version from its pubspec.yaml and replaces the path reference with a caret
/// version constraint (e.g. `^3.0.0`).
library;

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/prepare_publish.dart <package_dir>');
    exit(1);
  }

  final packageDir = args[0];
  final pubspecFile = File('$packageDir/pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('Error: $packageDir/pubspec.yaml not found');
    exit(1);
  }

  final lines = pubspecFile.readAsLinesSync();
  final result = <String>[];
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (i + 1 < lines.length) {
      final nextLine = lines[i + 1];
      final pathMatch = RegExp(r'^\s+path:\s+(.+)$').firstMatch(nextLine);

      if (pathMatch != null && RegExp(r'^\s+\S+:\s*$').hasMatch(line)) {
        final relativePath = pathMatch.group(1)!.trim();
        final targetPubspec =
            File('$packageDir/$relativePath/pubspec.yaml');

        if (targetPubspec.existsSync()) {
          final targetContent = targetPubspec.readAsStringSync();
          final versionMatch =
              RegExp(r'^version:\s+(.+)$', multiLine: true)
                  .firstMatch(targetContent);

          if (versionMatch != null) {
            final version = versionMatch.group(1)!.trim();
            final depName = line.trimRight().replaceAll(':', '').trim();
            final indent = line.substring(0, line.indexOf(depName));

            result.add('$indent$depName: ^$version');
            stdout.writeln('  $depName: path -> ^$version');
            i += 2;
            continue;
          }
        }
      }
    }

    result.add(line);
    i++;
  }

  pubspecFile.writeAsStringSync('${result.join('\n')}\n');
  stdout.writeln('Updated $packageDir/pubspec.yaml');
}
