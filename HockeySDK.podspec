Pod::Spec.new do |s|
  s.name              = 'HockeySDK'
  s.version           = '3.7.2'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and analyze your test coverage with HockeyApp.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = 'http://hockeyapp.net/help/sdk/ios/3.7.2/'

  s.license           = { :type => 'MIT', :file => 'HockeySDK-iOS/LICENSE' }
  s.author            = { 'Andreas Linde' => 'mail@andreaslinde.de', 'Thomas Dohmke' => "thomas@dohmke.de" }

  s.platform          = :ios, '6.0'
  s.requires_arc      = true
  
  s.preserve_path = 'HockeySDK-iOS/README.md'

  s.source = { :http => "https://github.com/bitstadium/HockeySDK-iOS/releases/download/#{s.version}/HockeySDK-iOS-#{s.version}.zip" }

  s.frameworks = 'SystemConfiguration', 'Security', 'Foundation'
  s.libraries = 'c++'

  s.default_subspec   = 'AllFeaturesLib'
  
  s.subspec 'CrashOnlyLib' do |ss|
    ss.frameworks = 'UIKit'
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDK.framework/Versions/A/Resources/HockeySDKResources.bundle/*.lproj'] }
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKCrashOnly/HockeySDK.framework'
  end

  s.subspec 'CrashOnlyExtensionsLib' do |ss|
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDKCrashOnlyExtension/HockeySDK.framework'
  end

  s.subspec 'AllFeaturesLib' do |ss|
    ss.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDK.framework/Versions/A/Resources/HockeySDKResources.bundle/*.png', 'HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDK.framework/Versions/A/Resources/HockeySDKResources.bundle/*.lproj'] }

    ss.frameworks = 'UIKit', 'CoreGraphics', 'QuartzCore', 'AssetsLibrary', 'MobileCoreServices', 'QuickLook', 'CoreText'
    ss.vendored_frameworks = 'HockeySDK-iOS/HockeySDK.embeddedframework/HockeySDK.framework'
  end

end
