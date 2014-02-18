## Version 3.5.4

- [BUGFIX] Fix a possible crash before sending the crash report when the selector could not be found
- [BUGFIX] Fix a memory leak in keychain handling
<br /><br/>

## Version 3.5.3

- [NEW] Crash Reports now provide the selector name e.g. for crashes in `objc_MsgSend`
- [NEW] Add setter for global `userID`, `userName`, `userEmail`. Can be used instead of the delegates.
- [UPDATE] On device symbolication is now optional, disabled by default
- [BUGFIX] Fix for automatic authentication not always working correctly
- [BUGFIX] `BITFeedbackComposeViewControllerDelegate` now also works for compose view controller used by the feedback list view
- [BUGFIX] Fix typos in documentation
<br /><br/>

## Version 3.5.2

- [UPDATE] Make sure a log message appears in the console if the SDK is not setup on the main thread
- [BUGFIX] Fix usage time always being send as `0` instead of sending the actual usage time
- [BUGFIX] Fix "Install" button in the mandatory update alert not working and forcing users to use the "show" button and then install from the update view instead
- [BUGFIX] Fix possible unused function warnings
- [BUGFIX] Fix two warnings when `-Wshorten-64-to-32` is set.
- [BUGFIX] Fix typos in documentation
<br /><br/>

## Version 3.5.1

- General

  - [NEW] Add new initialize to make the configuration easier: `[BITHockeyManager configureWithIdentifier:]`
  - [NEW] Add `[BITHockeyManager testIdentifier]` to check if the SDK reaches the server. The result is shown on the HockeyApp website on success.
  - [UPDATE] `delegate` can now also be defined using the property directly (instead of using the configureWith methods)
  - [UPDATE] Use system provided Base64 encoding implementation
  - [UPDATE] Improved logic to choose the right `UIWindow` instance for dialogs
  - [BUGFIX] Fix compile issues when excluding all modules but crash reporting
  - [BUGFIX] Fix warning on implicit conversion from `CGImageAlphaInfo` to `CGBitmapInfo`
  - [BUGFIX] Fix warnings for implicit conversions of `UITextAlignment` and `UILineBreakMode`
  - [BUGFIX] Various additional smaller bug fixes
	<br /><br/>

- Crash Reporting

  - [NEW] Integrated PLCrashReporter 1.2 RC 2
  - [NEW] Add `generateTestCrash` method to more quickly test the crash reporting (automatically disabled in App Store environment!)
  - [NEW] Add PLCR header files to the public headers in the framework
  - [NEW] Add the option to define callbacks that will be executed prior to program termination after a crash has occurred. Callback code has to be async-safe!
  - [UPDATE] Change the default of `showAlwaysButton` property to `YES`
  - [BUGFIX] Always format date and timestamps in crash report in `en_US_POSIX` locale.
	<br /><br/>
  
- Feedback

  - [UPDATE] Use only one activity view controller per UIActivity
  - [BUGFIX] Fix delete button appearance in feedback list view on iOS 7 when swiping a feedback message
  - [BUGFIX] Comply to -[UIActivity activityDidFinish:] requirements
  - [BUGFIX] Use non-deprecated delegate method for `BITFeedbackActivity`
	<br /><br/>

- Ad-Hoc/Enterprise Authentication

  - [NEW] Automatic authorization when app was installed over the air. This still requires to call `[BITAuthenticator authenticateInstallation];` after calling `startManager`!
  - [UPDATE] Set the tintColor in the auth view and modal views navigation controller on iOS 7
  - [UPDATE] Show an alert if the authentication token could not be stored into the keychain
  - [UPDATE] Use UTF8 encoding for auth data
  - [UPDATE] Replace email placeholder texts
  - [BUGFIX] Make sure the authentication window is always correctly dismissed
  - [BUGFIX] Fixed memory issues
	<br /><br/>

- Ad-Hoc/Enterprise Updates

  - [NEW] Provide alert option to show mandatory update details
  - [NEW] Add button to expired page (and alert) that lets the user check for a new version (can be disabled using `disableUpdateCheckOptionWhenExpired`)
  - [UPDATE] Usage metrics are now stored in an independent file instead of using `NSUserDefaults`
	<br /><br/>
	

## Version 3.5.0

- General

  - [NEW] Added support for iOS 7
  - [NEW] Added support for arm64 architecture
  - [NEW] Added `BITStoreUpdateManager` for alerting the user of available App Store updates (disabled by default)
  - [NEW] Added `BITAuthenticator` class for authorizing installations (Ad-Hoc/Enterprise builds only!)
  - [NEW] Added support for apps starting in the background
  - [NEW] Added possibility to build custom frameworks including/excluding specific modules from the static library (see `HockeySDKFeatureConfig.h`)
  - [NEW] Added public access to the anonymous UUID that the SDK generates per app installation
  - [NEW] Added possibility to overwrite SDK specific localization strings in the apps localization files
  - [UPDATE] Updated localizations provided by [Wordcrafts.de](http://wordcrafts.de):
	Chinese, Dutch, English, French, German, Hungarian, Italian, Japanese, Portuguese, Brazilian-Portuguese, Romanian, Russian, Spanish
  - [UPDATE] User related data is now stored in the keychain instead of property files
  - [UPDATE] SDK documentation improvements
  - [BUGFIX] Fixed multiple compiler warnings
  - [BUGFIX] Various UI updates and fixes
  <br /><br/>

- Crash Reporting

  - [NEW] Integrated PLCrashReporter 1.2 beta 3
  - [NEW] Added optional support for Mach exceptions
  - [NEW] Added support for arm64
  - [UPDATE] PLCrashReporter build with `BIT` namespace to avoid collisions
  - [UPDATE] Crash reporting is automatically disabled when the app is invoked with the debugger!
  - [UPDATE] Automatically add the users UDID or email to crash reports in Ad-Hoc/Enterprise builds if they are provided by BITAuthenticator
	<br /><br/>

- Feedback

  - [NEW] New protocol to inform about incoming feedback messages, see `BITFeedbackManagerDelegate`
  - [UPDATE] Added method in `BITFeedbackComposeViewControllerDelegate` to let the app know if the user submitted a new message or cancelled it
	<br /><br/>

- App Store Updates

  - [NEW] Inform user when a new version is available in the App Store (optional, disabled by default)
	<br /><br/>


- Ad-Hoc/Enterprise Authentication

  - [NEW] `BITAuthenticator` identifies app installations, automatically disabled in App Store environments
  - [NEW] `BITAuthenticator` can identify the user through:
    - The email address of their HockeyApp account
    - Login with their HockeyApp account (does not work with Facebook accounts!)
    - Installation of the HockeyApp web-clip to provide the UDID (requires the app to handle URL callbacks)
    - Web based login with their HockeyApp account
  - [NEW] `BITAuthenticator` can require the authorization:
    - Never
    - On first app version launch
    - Whenever the app comes into foreground (requires the device to have a working internet connection)
  - [NEW] Option to customize the authentication flow
  - [NEW] Possibility to use an existing URL scheme
	<br /><br/>

- Ad-Hoc/Enterprise Updates

  - [UPDATE] Removed delegate for getting the UDID, please migrate to the new `BITAuthenticator`
  - [NEW] In-app updates are now only offered if the device matches the minimum OS version requirement
	<br /><br/>

---

## Version 3.5.0 RC 3

- General

  - [NEW] Added public access to the anonymous UUID that the SDK generates per app installation
  - [NEW] Added possibility to overwrite SDK specific localization strings in the apps localization files
  - [UPDATE] Podspec updates
  - [BUGFIX] Fixed memory leaks
  - [BUGFIX] Various minor bugfixes
  <br /><br/>

- Crash Reporting

  - [UPDATE] Integrated PLCrashReporter 1.2 beta 3
  - [BUGFIX] Fixed crash if minimum OS version isn't provided
  - [BUGFIX] Update private C function to use BIT namespace
  <br /><br/>
  
- Feedback

  - [BUGFIX] Fixed some layout issues in the user info screen
  <br /><br/>

- Ad-Hoc/Enterprise Updates

  - [BUGFIX] Fixed update view controller not showing updated content after using the check button
  - [BUGFIX] Fixed usage value being reset on every app cold start
  <br /><br/>

- Ad-Hoc/Enterprise Authentication

  - [NEW] Added web based user authentication
  - [UPDATE] IMPORTANT: You need to call `[[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];` yourself after startup when the authentication and/or verification should be performed and when it is safe to present a modal view controller!
  - [UPDATE] Removed `automaticMode`. You now need to call `authenticateInstallation` when it is safe to do so or handle the complete process yourself.
  <br /><br/>

## Version 3.5.0 RC 2

- General

  - [BUGFIX] Remove assertions from release build
	<br /><br/>
	
- Ad-Hoc/Enterprise Updates

  - [BUGFIX] Add new iOS 7 icon sizes detection and adjust corner radius
	<br /><br/>

## Version 3.5.0 RC 1

- General

  - [UPDATE] Documentation improvements nearly everywhere
	<br /><br/>

- Crash Reporting

  - [UPDATE] Integrated PLCrashReporter 1.2 beta 2
  - [UPDATE] 64 bit crash reports now contain the correct architecture string
  - [UPDATE] Automatically add the users UDID or email to crash reports in Ad-Hoc/Enterprise builds if they are provided by BITAuthenticator
  - [BUGFIX] Fixed userName, userEmail and userID not being added to crash reports
	<br /><br/>

- App Store Updates

  - [UPDATE] Changed default update check interval to weekly
	<br /><br/>

- Ad-Hoc/Enterprise Authentication

  - [NEW] Redesigned API for easier usage and more flexibility (please check the documentation!)
  - [NEW] Added option to customize the authentication flow
  - [NEW] Added option to provide a custom parentViewController for presenting the UI
  - [NEW] Added possibility to use an existing URL scheme
  - [BUGFIX] Fixed authentication UI appearing after updating apps without changing the authentication settings
	<br /><br/>

- Ad-Hoc/Enterprise Updates

  - [UPDATE] Don't add icon gloss to icons when running on iOS 7
  - [BUGFIX] Fixed a few iOS 7 related UI problems in the update view
	<br /><br/>


## Version 3.5.0 Beta 3

- Feedback

  - [BUGFIX] Fix a layout issue with the compose feedback UI on the iPad with iOS 7 in landscape orientation
	<br /><br/>

- Ad-Hoc/Enterprise Authentication

  - [BUGFIX] Fix a possible crash in iOS 5
	<br /><br/>


## Version 3.5.0 Beta 2

- General

  - [NEW] Added support for apps starting in the background
  - [UPDATE] Added updated CocoaSpec
  - [BUGFIX] Various documentation improvements
	<br /><br/>

- Ad-Hoc/Enterprise Authentication

  - [BUGFIX] Fix duplicate count of installations
	<br /><br/>

- Ad-Hoc/Enterprise Updates

  - [BUGFIX] Update view not showing any versions
  - [BUGFIX] Fix a crash presenting the update view on iOS 5 and iOS 6
	<br /><br/>


## Version 3.5.0 Beta 1

- General

  - [NEW] Added support for iOS 7
  - [NEW] Added experimental support for arm64 architecture
  - [NEW] Added `BITStoreUpdateManager` for alerting the user of available App Store updates (disabled by default)
  - [NEW] Added `BITAuthenticator` class for authorizing installations (Ad-Hoc/Enterprise builds only!)
  - [NEW] Added possibility to build custom frameworks including/excluding specific modules from the static library (see `HockeySDKFeatureConfig.h`)
  - [UPDATE] User related data is now stored in the keychain instead of property files
  - [UPDATE] SDK documentation improvements
  - [BUGFIX] Fixed multiple compiler warnings
  - [BUGFIX] Fixed a few UI glitches, e.g. adjusting status bar style
	<br /><br/>

- Crash Reporting

  - [NEW] Integrated PLCrashReporter 1.2 beta 1
  - [NEW] Added optional support for Mach exceptions
  - [NEW] Experimental support for arm64 (will be tested and improved once devices are available)
  - [UPDATE] PLCrashReporter build with `BIT` namespace to avoid collisions
  - [UPDATE] Crash reporting is automatically disabled when the app is invoked with the debugger!
	<br /><br/>

- Feedback

  - [NEW] New protocol to inform about incoming feedback messages, see `BITFeedbackManagerDelegate`
  - [UPDATE] Added method in `BITFeedbackComposeViewControllerDelegate` to let the app know if the user submitted a new message or cancelled it
	<br /><br/>

- App Store Updates

  - [NEW] Inform user when a new version is available in the App Store (optional, disabled by default)
	<br /><br/>

- Ad-Hoc/Enterprise Updates and Authentication

  - [UPDATE] Removed delegate for getting the UDID, please migrate to the new `BITAuthenticator`
  - [NEW] In-app updates are now only offered if the device matches the minimum OS version requirement
  - [NEW] `BITAuthenticator` identifies app installations, automatically disabled in App Store environments
  - [NEW] `BITAuthenticator` can identify the user through:
    - The email address of his/her HockeyApp account
    - Login with his/her HockeyApp account (does not work with Facebook accounts!)
    - Installation of the HockeyApp web-clip to provide the UDID (requires the app to handle URL callbacks)
  - [NEW] `BITAuthenticator` can require the authorization:
    - Never
    - Optionally, i.e. the user can skip the dialog
    - On first app version launch
    - Whenever the app comes into foreground (requires the device to have a working internet connection)
	<br /><br/>


## Version 3.0.0

- General

	- [NEW] Added new Feedback module
	- [NEW] Minimum iOS Deployment version is now iOS 5.0
	- [NEW] Migrated to use ARC
	- [NEW] Added localizations provided by [Wordcrafts.de](http://wordcrafts.de):
	Chinese, English, French, German, Italian, Japanese, Portuguese, Brazilian-Portuguese, Russian, Spanish
	- [NEW] Added Romanian, Hungarian localization
	- [UPDATE] Updated integration and migration documentation
      - [Installation & Setup](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Installation-Setup.html) (Recommended)
      - [Installation & Setup Advanced](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Installation-Setup-Advanced.html) (Using Git submodule and Xcode sub-project)
      - [Migration from previous SDK Versions](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Migration-Kits.html)
	- [UPDATE] Using embedded.framework for binary distribution containing everything needed in one package
	- [UPDATE] Improved Xcode project setup to only use one static library
	- [UPDATE] Providing build settings as `HockeySDK.xcconfig` file for easier setup
	- [UPDATE] Remove `-ObjC` from `Other Linker Flags`, since the SDK doesn't need it anymore
	- [UPDATE] Improved documentation
	- [UPDATE] Excluded binary UUID check from simulator builds, so unit test targets will work. But functionality based on binary UUID cannot be tested in the simulator, e.g. update without changing build version.
	- [BUGFIX] Fixed some new compiler warnings
	- [BUGFIX] Fixed some missing new lines at EOF
	- [BUGFIX] Make sure sure JSON serialization doesn't crash if the string is nil
	- [BUGFIX] Various additional minor fixes
	<br /><br/>

- Crash Reporting

	- [NEW] Added anonymous device ID to crash reports
	- [UPDATE] The following delegates in `BITCrashManagerDelegate` moved to `BITHockeyManagerDelegate`:
	- `- (NSString *)userNameForCrashManager:(BITCrashManager *)crashManager;` is now `- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
	- `- (NSString *)userEmailForCrashManager:(BITCrashManager *)crashManager;` is now `- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
	- [BUGFIX] Moved calculation of time interval between startup and crash further up in the code, so delegates can use this information e.g. to add it into a log file
	- [BUGFIX] If a crash was detected but could not be read (if handling crashes on startup is implemented), the delegate is still called
	- [BUGFIX] Timestamp in crash report is now always UTC in en_US locale
	- [BUGFIX] Make sure crash reports incident identifier and key don't have special [] chars and some value
	<br /><br/>

- Feedback

	- [NEW] User feedback interface for direct communication with your users
	- [NEW] iOS 6 UIActivity component for integrating feedback
	- [NEW] When first opening the feedback list view, user details and show compose screen are automatically shown
	<br /><br/>

- Updating

	- [NEW] Support for In-App updates without changing `CFBundleVersion`
	- [UPDATE] Update UI modified to be more iOS 6 alike
	- [UPDATE] Update UI shows the company name next to the app name if defined in the backend
	- [UPDATE] Updated integration and migration documentation: [Installation & Setup](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Installation-Setup.html) (Recommended), [Installation & Setup Advanced](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Installation-Setup-Advanced.html) (Using Git submodule and Xcode sub-project), [Migration from previous SDK Versions](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Guide-Migration-Kits.html)
      		
	- [BUGFIX] Fixed a problem showing the update UI animated if there TTNavigator class is present even though not being used

---

### Version 3.0.0 RC 1

- General:

    - [NEW] Added localizations provided by [Wordcrafts.de](http://wordcrafts.de):
      Chinese, English, French, German, Italian, Japanese, Portuguese, Brazilian-Portuguese, Russian, Spanish
    - [NEW] Added Romanian localization
    - [UPDATE] Documentation improvements
    - [UPDATE] Exclude binary UUID check from simulator builds, so unit test targets will work. But functionality based on binary UUID cannot be tested in the simulator, e.g. update without changing build version.
    - [BUGFIX] Cocoapods bugfix for preprocessor definitions
    - [BUGFIX] Various additional minor fixes

- Feedback:

    - [UPDATE] Only push user details screen automatically onto the list view once
    - [BUGFIX] Show proper missing user name or email instead of showing `(null)` in a button
    - [BUGFIX] Various fixes to changing the `requireUserEmail` and `requireUserName` values

    
### Version 3.0.0b5

- General:

    - [NEW] Remove `-ObjC` from `Other Linker Flags`, since the SDK doesn't need it
    - [NEW] Update localizations (german, croatian)
    - [BUGFIX] Fix some new compiler warnings
    - [BUGFIX] Fix some missing new lines at EOF
    - [BUGFIX] Make sure sure JSON serialization doesn't crash if the string is nil

- Crash Reporting:

    - [NEW] Add anonymous device ID to crash reports
    - [BUGFIX] Move calculation of time interval between startup and crash further up in the code, so delegates can use this information e.g. to add it into a log file
    - [BUGFIX] Call delegate also if a crash was detected but could not be read (if handling crashes on startup is implemented)
    - [BUGFIX] Format timestamp in crash report to be always UTC in en_US locale
    - [BUGFIX] Make sure crash reports incident identifier and key don't have special [] chars and some value

- Feedback:

    - [NEW] Ask user details and show compose screen automatically on first opening feedback list view
    - [BUGFIX] Fix some users own messages re-appearing after deleting them
    - [BUGFIX] Problems displaying feedback list view in a navigation hierarchy

- Updating:

    - [BUGFIX] Fix a problem showing the update UI animated if there TTNavigator class is present even though not being used
    
### Version 3.0.0b4

- Crash Reporting:

    - [BUGFIX] Fix a crash if `username`, `useremail` or `userid` delegate method returns `nil` and trying to send a crash report

- Feedback:

    - [BUGFIX] Fix user data UI not always being presented as a form sheet on the iPad
    
- Updating:

    - [BUGFIX] Fix a problem showing the update UI animated if there TTNavigator class is present even though not being used
    
### Version 3.0.0b3

- General:

    - [BUGFIX] Exchange some more prefixes of TTTAttributedLabel class that have been missed out
    - [BUGFIX] Fix some new compiler warnings

- Crash Reporting:

    - [BUGFIX] Format timestamp in crash report to be always UTC in en_US locale

### Version 3.0.0b2

- General:

    - [BUGFIX] Add missing header files to the binary distribution
    - [BUGFIX] Add missing new lines of two header files
    
### Version 3.0.0b1

- General:

    - [NEW] Feedback component
    - [NEW] Minimum iOS Deployment version is now iOS 5.0
    - [NEW] Migrated to use ARC
    - [UPDATE] Improved Xcode project setup to only use one static library
    - [UPDATE] Providing build settings as `HockeySDK.xcconfig` file for easier setup
    - [UPDATE] Using embedded.framework for binary distribution containing everything needed in one package
    
- Feedback:

    - [NEW] User feedback interface for direct communication with your users
    - [NEW] iOS 6 UIActivity component for integrating feedback

- Updating:

    - [NEW] Support for In-App updates without changing `CFBundleVersion`
    - [UPDATE] Update UI modified to be more iOS 6 alike
    - [UPDATE] Update UI shows the company name next to the app name if defined in the backend


## Version 2.5.5

- General:

    - [BUGFIX] Fix some new compiler warnings

- Crash Reporting:

    - [NEW] Add anonymous device ID to crash reports
    - [BUGFIX] Move calculation of time interval between startup and crash further up in the code, so delegates can use this information e.g. to add it into a log file
    - [BUGFIX] Call delegate also if a crash was detected but could not be read (if handling crashes on startup is implemented)
    - [BUGFIX] Format timestamp in crash report to be always UTC in en_US locale
    - [BUGFIX] Make sure crash reports incident identifier and key don't have special [] chars and some value

- Updating:

    - [BUGFIX] Fix a problem showing the update UI animated if there TTNavigator class is present even though not being used

## Version 2.5.4

- General:

    - Declared as final release, since everything in 2.5.4b3 is working as expected

### Version 2.5.4b3

- General:

    - [NEW] Atlassian JMC support disabled (Use subproject integration if you want it)

### Version 2.5.4b2

- Crash Reporting:

    - [UPDATE] Migrate pre v2.5 auto send user setting
    - [BUGFIX] The alert option 'Auto Send' did not persist correctly

- Updating:

    - [BUGFIX] Authorization option did not persist correctly and caused authorization to re-appear on every cold app start

### Version 2.5.4b1

- General:

    - [NEW] JMC support is removed from binary distribution, requires the compiler preprocessor definition `JIRA_MOBILE_CONNECT_SUPPORT_ENABLED=1` to be linked. Enabled when using the subproject
    - [BUGFIX] Fix compiler warnings when using Cocoapods

- Updating:

    - [BUGFIX] `expiryDate` property not working correctly

## Version 2.5.3

- General:

    - [BUGFIX] Fix checking validity of live identifier not working correctly

## Version 2.5.2

- General:

    - Declared as final release, since everything in 2.5.2b2 is working as expected

### Version 2.5.2b2

- General:

    - [NEW] Added support for armv7s architecture

- Updating:

    - [BUGFIX] Fix update checks not done when the app becomes active again


### Version 2.5.2b1

- General:

    - [NEW] Replace categories with C functions, so the `Other Linker Flag` `-ObjC` and `-all_load` won't not be needed for integration
	- [BUGFIX] Some code style fixes and missing new lines in headers at EOF

- Crash Reporting:

    - [NEW] PLCrashReporter framework now linked into the HockeySDK framework, so that won't be needed to be added separately any more
    - [NEW] Add some error handler detection to optionally notify the developer of multiple handlers that could cause crashes not to be reported to HockeyApp
    - [NEW] Show an error in the console if an older version of PLCrashReporter is linked
    - [NEW] Make sure the app doesn't crash if the developer forgot to delete the old PLCrashReporter version and the framework search path is still pointing to it

- Updating:

    - [BUGFIX] Fix disabling usage tracking and expiry check not working if `checkForUpdateOnLaunch` is set to NO
    - [BUGFIX] `disableUpdateManager` wasn't working correctly
    - [BUGFIX] If the server doesn't return any app versions, don't handle this as an error, but show a warning in the console when `debugLogging` is enabled

## Version 2.5.1

- General:

	- [BUGFIX] Typo in delegate `shouldUseLiveIdentifier` of `BITHockeyManagerDelegate`
	- [BUGFIX] Default updateManager delegate wasn't set

- Crash Reporting:

	- [BUGFIX] Crash when developer sends the notification `BITHockeyNetworkDidBecomeReachableNotification`


## Version 2.5

- General:

	- [NEW] Unified SDK for accessing HockeyApp on iOS

		- Requires iOS 4.0 or newer

		- Replaces the previous separate SDKs for iOS: HockeyKit and QuincyKit.
		
		  The previous SDKs are still available and are still working. But future
		  HockeyApp features will only be integrated in this new unified SDK.

		- Integration either as framework or Xcode subproject using the sourcecode
		
		  Check out [Installation & Setup](Guide-Installation-Setup)

	- [NEW] Cleaned up public interfaces and internal processing all across the SDK

	- [NEW] [AppleDoc](http://gentlebytes.com/appledoc/) based documentation and HowTos
	
		This allows the documentation to be generated into HTML or DocSet.

- Crash Reporting:

	- [NEW] Workflow to handle crashes that happen on startup.
	
		Check out [How to handle crashes on startup](HowTo-Handle-Crashes-On-Startup) for more details.

	- [NEW] Symbolicate iOS calls async-safe on the device

	- [NEW] Single property/option to deactivate, require user to agree submitting and autosubmit
		
		E.g. implement a settings screen with the three options and set
		`[BITCrashManager crashManagerStatus]` to the desired user value.

	- [UPDATED] Updated [PLCrashReporter](https://code.google.com/p/plcrashreporter/) with updates and bugfixes (source available on [GitHub](https://github.com/bitstadium/PLCrashReporter))

	- [REMOVED] Feedback for Crash Groups Status
		
		Please keep using QuincyKit for now if you want this feature. This feature needs to be
		redesigned on SDK and server side to be more efficient and easier to use.

- Updating:

	- [NEW] Expire beta versions with a given date

	- [REMOVED] Settings screen

		If you want users to be able not to send analytics data, implement the
		`[BITUpdateManagerDelegate updateManagerShouldSendUsageData:]` delegate and return
		the value depending on what the user defines in your settings UI.
