Pod::Spec.new do |s|
  s.name              = 'HockeySDK-Source'
  s.version           = '3.8.5'

  s.summary           = 'Collect live crash reports, get feedback from your users, distribute your betas, and analyze your test coverage with HockeyApp.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = "http://hockeyapp.net/help/sdk/ios/#{s.version}/"

  s.license           = 'MIT'
  s.author            = { 'Microsoft' => 'support@hockeyapp.net' }
  s.source            = { :git => 'https://github.com/bitstadium/HockeySDK-iOS.git', :tag => s.version.to_s }

  s.platform          = :ios, '7.0'
  s.ios.deployment_target = '6.0'
  s.source_files      = 'Classes'
  s.requires_arc      = true
  
  s.frameworks              = 'AssetsLibrary', 'CoreText', 'CoreGraphics', 'MobileCoreServices', 'QuartzCore', 'QuickLook', 'Security', 'SystemConfiguration', 'UIKit'
  s.libraries = 'c++'
  s.ios.vendored_frameworks = 'Vendor/CrashReporter.framework'
  s.xcconfig                = {'GCC_PREPROCESSOR_DEFINITIONS' => %{$(inherited) BITHOCKEY_VERSION="@\\"#{s.version}\\"" BITHOCKEY_C_VERSION="\\"#{s.version}\\"" BITHOCKEY_BUILD="@\\"57\\"" BITHOCKEY_C_BUILD="\\"57\\""} }
  s.resource_bundle         = { 'HockeySDKResources' => ['Resources/*.png', 'Resources/*.lproj'] }
  s.preserve_paths          = 'Resources', 'Support'
  s.private_header_files  = 'Classes/*Private.h'

end