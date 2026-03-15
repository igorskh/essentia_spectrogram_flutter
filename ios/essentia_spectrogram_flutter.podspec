#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint essentia_spectrogram_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'essentia_spectrogram_flutter'
  s.version          = '0.0.1'
  s.summary          = 'An iOS plugin for computing spectrograms using the Essentia library.'
  s.description      = <<-DESC
An iOS plugin for computing spectrograms using the Essentia library.
                       DESC
  s.homepage         = 'https://github.com/igorskh/essentia_spectrogram_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'igor.kim.dev@pm.me' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.public_header_files = 'Classes/EssentiaBridge.h'

  s.frameworks = 'Accelerate'
  s.vendored_frameworks = 'Frameworks/Essentia.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) $(PODS_TARGET_SRCROOT)/Headers/eigen $(PODS_TARGET_SRCROOT)/Headers/essentia'
  }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'essentia_spectrogram_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
