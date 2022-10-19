#
# Be sure to run `pod lib lint CrowdinSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
  spec.name             = 'CrowdinSDK'
  spec.version          = '1.4.1'
  spec.summary          = 'Crowdin iOS SDK delivers all new translations from Crowdin project to the application immediately'
  
  spec.description      = <<-DESC
  
  Crowdin iOS SDK delivers all new translations from Crowdin project to the application immediately. So there is no need to update this application via App Store to get the new version with the localization.

  The SDK provides:

  Over-The-Air Content Delivery – the localized files can be sent to the application from the project whenever needed
  Real-time Preview – all the translations that are done via Editor can be shown in the application in real-time
  Screenshots – all screenshots made in the application may be automatically sent to your Crowdin project with tagged source strings
  
  DESC
  
  spec.homepage         = 'https://github.com/crowdin/mobile-sdk-ios'
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'Crowdin' => 'support@crowdin.com' }
  spec.source           = { :git => 'https://github.com/crowdin/mobile-sdk-ios.git', :tag => spec.version.to_s }
  spec.social_media_url    = 'https://twitter.com/crowdin'
  
  spec.ios.deployment_target = '9.0'
  spec.tvos.deployment_target = '9.0'
  
  spec.frameworks = 'UIKit'
  spec.static_framework = false
  spec.swift_version = '4.2'
  spec.default_subspecs = 'Core', 'CrowdinProvider'
  
  spec.subspec 'Core' do |core|
    core.source_files = 'Sources/CrowdinSDK/CrowdinSDK/**/*'
  end
  

  spec.test_spec 'Core_Tests' do |test_spec|
    test_spec.source_files = 'Sources/Tests/Core/*.swift'
  end
  
  spec.subspec 'CrowdinProvider' do |provider|
    provider.name = 'CrowdinProvider'
    provider.source_files = 'Sources/CrowdinSDK/Providers/Crowdin/**/*.swift'
    provider.dependency 'CrowdinSDK/Core'
    provider.dependency 'CrowdinSDK/CrowdinAPI'
  end
  
  spec.test_spec 'CrowdinProvider_Tests' do |test_spec|
    test_spec.source_files = 'Sources/Tests/CrowdinProvider/*.swift'
    test_spec.resources = 'Resources/Tests/SupportedLanguages.json'
  end
  
  spec.subspec 'CrowdinAPI' do |subspec|
    subspec.name = 'CrowdinAPI'
    subspec.source_files = 'Sources/CrowdinSDK/CrowdinAPI/**/*.swift'
    subspec.dependency 'CrowdinSDK/Core'
    subspec.dependency 'BaseAPI', '~> 0.2.0'
  end
  
  spec.test_spec 'CrowdinAPI_Tests' do |test_spec|
    test_spec.source_files = 'Sources/Tests/CrowdinAPI/*.swift'
  end
  
  spec.subspec 'Screenshots' do |feature|
    feature.name = 'Screenshots'
    feature.ios.source_files = 'Sources/CrowdinSDK/Features/ScreenshotFeature/**/*.swift'
    feature.dependency 'CrowdinSDK/Core'
    feature.dependency 'CrowdinSDK/CrowdinProvider'
    feature.dependency 'CrowdinSDK/CrowdinAPI'
    feature.dependency 'CrowdinSDK/LoginFeature'
  end
  
  spec.subspec 'RealtimeUpdate' do |feature|
    feature.name = 'RealtimeUpdate'
    feature.ios.source_files = 'Sources/CrowdinSDK/Features/RealtimeUpdateFeature/**/*.swift'
    feature.dependency 'CrowdinSDK/Core'
    feature.dependency 'CrowdinSDK/CrowdinProvider'
    feature.dependency 'CrowdinSDK/CrowdinAPI'
    feature.dependency 'CrowdinSDK/LoginFeature'
    
    feature.dependency 'Starscream', '~> 4.0.4'
  end
  
  spec.subspec 'RefreshLocalization' do |feature|
    feature.name = 'RefreshLocalization'
    feature.source_files = 'Sources/CrowdinSDK/Features/RefreshLocalizationFeature/**/*.swift'
    feature.dependency 'CrowdinSDK/Core'
    feature.dependency 'CrowdinSDK/CrowdinProvider'
    feature.dependency 'CrowdinSDK/CrowdinAPI'
  end
  
  spec.subspec 'LoginFeature' do |feature|
    feature.name = 'LoginFeature'
    feature.ios.source_files = 'Sources/CrowdinSDK/Features/LoginFeature/**/*.swift'
    feature.dependency 'CrowdinSDK/Core'
    feature.dependency 'CrowdinSDK/CrowdinProvider'
    feature.dependency 'CrowdinSDK/CrowdinAPI'
    feature.dependency 'BaseAPI', '~> 0.2.0'
  end
  
  spec.subspec 'IntervalUpdate' do |feature|
    feature.name = 'IntervalUpdate'
    feature.ios.source_files = 'Sources/CrowdinSDK/Features/IntervalUpdateFeature/**/*.swift'
    feature.dependency 'CrowdinSDK/Core'
    feature.dependency 'CrowdinSDK/CrowdinProvider'
    feature.dependency 'CrowdinSDK/CrowdinAPI'
  end
  
  spec.subspec 'Settings' do |settings|
    settings.name = 'Settings'
    settings.ios.source_files = 'Sources/CrowdinSDK/Settings/**/*.swift'
    settings.ios.resources = 'Sources/CrowdinSDK/Resources/Settings/*.{storyboard,xib,xcassets}'
    settings.dependency 'CrowdinSDK/Screenshots'
    settings.dependency 'CrowdinSDK/RealtimeUpdate'
    settings.dependency 'CrowdinSDK/RefreshLocalization'
    settings.dependency 'CrowdinSDK/IntervalUpdate'
    settings.dependency 'CrowdinSDK/Core'
    settings.dependency 'CrowdinSDK/CrowdinProvider'
    settings.dependency 'CrowdinSDK/CrowdinAPI'
    settings.dependency 'CrowdinSDK/LoginFeature'
  end

end
