#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint opus_codec_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'opus_codec_macos'
  s.version          = '3.0.5'
  s.summary          = 'libopus wrappers for flutter on macOS.'
  s.description      = <<-DESC
  libopus wrappers for flutter on macOS.
                       DESC
  s.homepage         = 'https://github.com/Corkscrews/opus_codec'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Corkscrews' => '' }
  s.source           = { :path => '.' }
  s.source_files = 'opus_codec_macos/Sources/opus_codec_macos/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.vendored_frameworks = 'opus.xcframework'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
