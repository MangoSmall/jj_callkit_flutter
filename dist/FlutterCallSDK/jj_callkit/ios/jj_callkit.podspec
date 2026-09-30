Pod::Spec.new do |s|
  s.name             = 'jj_callkit'
  s.version          = '0.1.3'
  s.summary          = 'JJCallKit Flutter plugin'
  s.description      = <<-DESC
Flutter plugin that wraps the JJ iOS and Android VoIP SDKs behind one Dart API.
                       DESC
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'JJ' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.4'
  s.swift_version = '5.0'
  s.static_framework = true
  s.vendored_frameworks = 'Frameworks/JJCallKit.xcframework'
  s.frameworks = 'CoreAudio', 'AudioToolbox', 'AVFoundation', 'CallKit'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-framework JJCallKit',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'PJ_IS_LITTLE_ENDIAN=1 PJ_IS_BIG_ENDIAN=0',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
