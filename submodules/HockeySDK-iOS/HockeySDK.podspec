Pod::Spec.new do |s|
  s.name              = 'HockeySDK'
  s.version           = '5.1.2'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and analyze your test coverage with HockeyApp.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = "http://hockeyapp.net/help/sdk/ios/#{s.version}/"

  s.license           = { :type => 'MIT', :file => 'HockeySDK-iOS/LICENSE' }
  s.author            = { 'Microsoft' => 'support@hockeyapp.net' }

  s.platform          = :ios, '8.0'
  s.requires_arc      = true
  
  s.preserve_path = 'HockeySDK-iOS/README.md'

  s.source = { :http => "https://github.com/bitstadium/HockeySDK-iOS/releases/download/#{s.version}/HockeySDK-iOS-#{s.version}.zip" }

  s.frameworks = 'Foundation', 'Security', 'SystemConfiguration'
  s.libraries = 'c++'

  s.default_subspec   = 'DefaultLib'
  
  s.subspec 'CrashOnlyLib' do |ss|
    ss.frameworks = 'UIKit'
    ss.libraries = 'z'
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.lproj'] }
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKCrashOnly/HockeySDK.framework'
  end

  s.subspec 'CrashOnlyExtensionsLib' do |ss|
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKCrashOnlyExtension/HockeySDK.framework'
  end

  s.subspec 'DefaultLib' do |ss|
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.png', 'HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.lproj'] }

    ss.frameworks = 'CoreGraphics', 'CoreText', 'CoreTelephony', 'MobileCoreServices', 'QuartzCore', 'QuickLook', 'UIKit'
    ss.libraries = 'z'
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDK.framework'
  end

  s.subspec 'AllFeaturesLib' do |ss|
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDKAllFeatures/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.png', 'HockeySDK-iOS/HockeySDKAllFeatures/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.lproj'] }

    ss.frameworks = 'CoreGraphics', 'CoreText', 'CoreTelephony', 'MobileCoreServices', 'Photos', 'QuartzCore', 'QuickLook', 'UIKit'
    ss.libraries = 'z'
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKAllFeatures/HockeySDK.embeddedframework/HockeySDK.framework'
  end

  s.subspec 'FeedbackOnlyLib' do |ss|
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDKFeedbackOnly/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.png', 'HockeySDK-iOS/HockeySDKFeedbackOnly/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.lproj'] }

    ss.frameworks = 'CoreGraphics', 'CoreText', 'CoreTelephony', 'MobileCoreServices', 'Photos', 'QuartzCore', 'QuickLook', 'UIKit'
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKFeedbackOnly/HockeySDK.embeddedframework/HockeySDK.framework'
  end

end
