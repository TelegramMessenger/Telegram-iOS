Pod::Spec.new do |s|
  s.name              = 'HockeySDK-Source'
  s.version           = '3.7.0'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and analyze your test coverage with HockeyApp.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = 'http://hockeyapp.net/help/sdk/ios/3.7.0/'

  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = { 'Andreas Linde' => 'mail@andreaslinde.de', 'Thomas Dohmke' => "thomas@dohmke.de" }
  s.source            = { :git => 'https://github.com/bitstadium/HockeySDK-iOS.git', :tag => s.version.to_s }

  s.platform          = :ios, '6.0'
  s.requires_arc      = true
    
  s.prepare_command       = 'cp -f Classes/HockeySDKFeatureConfig_CP.h Classes/HockeySDKFeatureConfig.h' #Changes default of all features enabled to disabled
  s.resource_bundle       = { 'HockeySDKResources' => ['Resources/*.lproj'] }
  s.preserve_path         = 'README.md'
  s.private_header_files  = 'Classes/*Private.h'
  s.xcconfig              = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) BITHOCKEY_VERSION="@\\"#{s.version}\\"" BITHOCKEY_C_VERSION="\\"#{s.version}\\"" BITHOCKEY_BUILD="@\\"40\\"" BITHOCKEY_C_BUILD="\\"40\\""} }
  
  s.default_subspec = 'AllFeatures'

  s.subspec 'SharedRequirements' do |ss|
    ss.source_files  = 'Classes/HockeySDK*.{h,m}', 'Classes/BITHockeyManager*.{h,m}', 'Classes/BITHockeyAppClient.{h,m}', 'Classes/BITHTTPOperation.{h,m}', 'Classes/BITHockeyHelper.{h,m}', 'Classes/BITKeychain*.{h,m}', 'Classes/BITHockeyBaseManager*.{h,m}'
  end
  
  s.subspec 'UserInterface' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.frameworks = 'UIKit'
    ss.source_files = 'Classes/BITHockeyBaseViewController.{h,m}'
  end

  s.subspec 'Extendable' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.source_files = 'Classes/BITHockeyAttachment.{h,m}'
  end

  s.subspec 'CrashReporter' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.dependency 'HockeySDK-Source/Extendable'
    ss.vendored_frameworks = 'Vendor/CrashReporter.framework'
    ss.frameworks = 'SystemConfiguration'
    ss.libraries = 'c++'
    ss.source_files = 'Classes/BITCrash*.{h,m,mm}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_CRASH_REPORTER=1} }
  end
  
  s.subspec 'UserFeedback' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.dependency 'HockeySDK-Source/Extendable'
    ss.dependency 'HockeySDK-Source/UserInterface'
    ss.frameworks = 'AssetsLibrary', 'MobileCoreServices', 'QuickLook', 'CoreText'
    ss.source_files = 'Classes/BITFeedback*.{h,m}', 'Classes/BIT*ImageAnnotation.{h,m}', 'Classes/BITImageAnnotationViewController.{h,m}', 'Classes/BITAttributedLabel.{h,m}', 'Classes/BITActivityIndicatorButton.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_FEEDBACK=1} }
  end
  
  s.subspec 'StoreUpdates' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.source_files = 'Classes/BITStoreUpdate*.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_STORE_UPDATES=1} }
  end
  
  s.subspec 'Authenticator' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.dependency 'HockeySDK-Source/UserInterface'
    ss.source_files = 'Classes/BITAuthentica*.{h,m}'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_AUTHENTICATOR=1} }
  end
  
  s.subspec 'AdHocUpdates' do |ss|
    ss.dependency 'HockeySDK-Source/SharedRequirements'
    ss.dependency 'HockeySDK-Source/UserInterface'
    ss.source_files = 'Classes/BITUpdate*.{h,m}', 'Classes/BITAppVersionMetaInfo.{h,m}', 'Classes/BITStoreButton.{h,m}', 'Classes/BITAppStoreHeader.{h,m}', 'Classes/BITWebTableViewCell.{h,m}'
    ss.frameworks = 'CoreGraphics', 'QuartzCore', 'Security'
    ss.xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) HOCKEYSDK_FEATURE_UPDATES=1} }
  end
  
  s.subspec 'AllFeatures' do |ss|
    ss.dependency 'HockeySDK-Source/CrashReporter'
    ss.dependency 'HockeySDK-Source/UserFeedback'
    ss.dependency 'HockeySDK-Source/StoreUpdates'
    ss.dependency 'HockeySDK-Source/Authenticator'
    ss.dependency 'HockeySDK-Source/AdHocUpdates'
  end

end