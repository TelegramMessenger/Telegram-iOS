Pod::Spec.new do |s|
  s.name     = 'HockeySDK'
  s.version  = '2.3.0'
  s.license  = 'MIT'
  s.platform = :ios
  s.summary  = 'Distribute beta apps and collect crash reports with HockeyApp.'
  s.homepage = 'http://hockeyapp.net/'
  s.author   = { 'Andreas Linde' => 'mail@andreaslinde.de', 'Thomas Dohmke' => "thomas@dohmke.de" }
  s.source   = { :git => 'https://github.com/bitstadium/HockeySDK-iOS', :tag => '2.3.0' }

  s.description = 'HockeyApp is a server to distribute beta apps and collect crash reports. '          \
                  'It improves the testing process dramatically and can be used for both beta '        \
                  'and App Store builds. Only beta builds will notify users about a new version  '     \
                  'NOTE: You will need to add a dependency on JSONKit or SBJson yourself. If you '     \
                  'want the framework to try again when a network is available, add a dependency '     \
                  'on Reachability and send a notification with the name `NetworkDidBecomeReachable` ' \
                  'yourself when the network becomse reachable.'

  s.source_files = 'Classes'
  s.resources    = 'Resources/HockeySDKResources.bundle'
  s.frameworks   = 'QuartzCore', 'SystemConfiguration', 'CrashReporter'
  s.xcconfig     = { 'FRAMEWORK_SEARCH_PATHS' => '"$(BUILT_PRODUCTS_DIR)/Pods/Frameworks"' }

  def s.post_install(target_installer)
    # Add a copy build phase and make it copy the CrashReporter.framework to the shared BUILT_PRODUCTS_DIR,
    # so that both the Pods project and the user's project will pick it up.
    phase = target_installer.target.buildPhases.add(Xcodeproj::Project::PBXCopyFilesBuildPhase, 'dstPath' => 'Pods/Frameworks')
    file = target_installer.project.main_group.files.new('path' => 'HockeySDK/Vendor/CrashReporter.framework')
    phase.files << file.buildFiles.new
    phases = target_installer.target.attributes['buildPhases']
    phases.delete(phase.uuid)
    phases.insert(1, phase.uuid)
  end  
end