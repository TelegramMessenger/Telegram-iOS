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
