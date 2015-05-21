Pod::Spec.new do |s|
  s.name              = 'HockeySDK'
  s.version           = '3.6.4'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and analyze your test coverage with HockeyApp.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = 'http://hockeyapp.net/help/sdk/ios/3.6.4/'

  s.license           = 'MIT'
  s.author            = { 'Andreas Linde' => 'mail@andreaslinde.de', 'Thomas Dohmke' => "thomas@dohmke.de" }
  s.source            = { :git => 'https://github.com/bitstadium/HockeySDK-iOS.git', :tag => s.version.to_s }

  s.platform          = :ios, '6.0'
  s.requires_arc      = true
  
  s.default_subspec = 'CompiledLib'
  
  s.subspec 'SharedRequirements' do |ss|
    ss.source_files = 'Classes/HockeySDK*.{h,m}', 'Classes/BITHockeyManager*.{h,m}', 'Classes/BITHockeyAppClient.{h,m}', 'Classes/BITHTTPOperation.{h,m}', 'Classes/BITHockeyHelper.{h,m}', 'Classes/BITKeychain*.{h,m}', 'Classes/BITHockeyBaseManager*.{h,m}'
    ss.frameworks = 'CoreGraphics', 'QuartzCore', 'Security', 'UIKit'
    ss.resource_bundle         = { 'HockeySDKResources' => ['Resources/*.png', 'Resources/*.lproj'] }
    ss.preserve_paths          = 'Resources', 'Support'
    ss.private_header_files  = 'Classes/*Private.h'
    ss.xcconfig                = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) BITHOCKEY_VERSION="@\\"#{s.version}\\"" BITHOCKEY_C_VERSION="\\"#{s.version}\\"" BITHOCKEY_BUILD="@\\"38\\"" BITHOCKEY_C_BUILD="\\"38\\""} }
  end
  
  s.subspec 'CrashReporter' do |ss|
    ss.dependency 'HockeySDK/SharedRequirements'
    ss.ios.vendored_frameworks = 'Vendor/CrashReporter.framework'
    ss.frameworks = 'SystemConfiguration'
    ss.source_files = 'Classes/BITCrash*.{h,m}', 'Classes/BITHockeyAttachment.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_CRASH_REPORTER=1} }
  end
  
  s.subspec 'UserFeedback' do |ss|
    ss.dependency 'HockeySDK/SharedRequirements'
    ss.frameworks = 'AssetsLibrary', 'MobileCoreServices', 'QuickLook', 'CoreText'
    ss.source_files = 'Classes/BITFeedback*.{h,m}', 'Classes/BIT*ImageAnnotation.{h,m}', 'Classes/BITImageAnnotationViewController.{h,m}', 'Classes/BITHockeyAttachment.{h,m}', 'Classes/BITHockeyBaseViewController.{h,m}', 'Classes/BITAttributedLabel.{h,m}', 'Classes/BITActivityIndicatorButton.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_FEEDBACK=1} }
  end
  
  s.subspec 'StoreUpdates' do |ss|
    ss.dependency 'HockeySDK/SharedRequirements'
    ss.source_files = 'Classes/BITStoreUpdate*.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_STORE_UPDATES=1} }
  end
  
  s.subspec 'Authenticator' do |ss|
    ss.dependency 'HockeySDK/SharedRequirements'
    ss.source_files = 'Classes/BITAuthentica*.{h,m}', 'Classes/BITHockeyBaseViewController.{h,m}' 
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_AUTHENTICATOR=1} }
  end
  
  s.subspec 'AdHocUpdates' do |ss|
    ss.dependency 'HockeySDK/SharedRequirements'
    ss.source_files = 'Classes/BITUpdate*.{h,m}', 'Classes/BITAppVersionMetaInfo.{h,m}', 'Classes/BITHockeyBaseViewController.{h,m}', 'Classes/BITStoreButton.{h,m}', 'Classes/BITAppStoreHeader.{h,m}', 'Classes/BITWebTableViewCell.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_UPDATES=1} }
  end
  
  s.subspec 'CompiledLib' do |ss|
    ss.dependency 'HockeySDK/CrashReporter'
    ss.dependency 'HockeySDK/UserFeedback'
    ss.dependency 'HockeySDK/StoreUpdates'
    ss.dependency 'HockeySDK/Authenticator'
    ss.dependency 'HockeySDK/AdHocUpdates'
  end

end
