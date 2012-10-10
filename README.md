## Introduction

HockeySDK-iOS implements support for using HockeyApp in your iOS applications.

The following features are currently supported:

1. **Update apps:** The app will check with HockeyApp if a new version is available. If yes, it will show an alert view to the user and let him see the release notes, the version history and start the installation process right away. 

2. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

The main SDK class is `BITHockeyManager`. It initializes all modules and provides access to them, so they can be further adjusted if required. Additionally all modules provide their own protocols.

## Prerequisites

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.
2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 4.
3. The SDK supports iOS 4.0 or newer.


## Installation & Setup

- [Installation & Setup](http://support.hockeyapp.net/kb/client-integration/hockeyapp-for-ios-hockeysdk) (Recommended)
- [Integrate as a Subproject ](http://support.hockeyapp.net/kb/client-integration/integrate-hockeyapp-on-ios-as-a-subproject-advanced-usage) (Using Git submodule and Xcode sub-project)
- [Migration from HockeyKit & QuincyKit](http://support.hockeyapp.net/kb/how-tos/how-to-migration-from-hockeykit-quincykit)
- [Mac Desktop Uploader](http://support.hockeyapp.net/kb/how-tos/how-to-upload-to-hockeyapp-on-a-mac)


## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTos.

1. Download the latest [HockeySDK-iOS documentation](https://github.com/bitstadium/HockeySDK-iOS/downloads).

2. Unzip the file. A new folder `HockeySDK-iOS-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSet`


## Changelog

### Version 2.5.4

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

### Version 2.5.3

- General:

    - [BUGFIX] Fix checking validity of live identifier not working correctly

### Version 2.5.2

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


### Version 2.5.1

- General:

	- [BUGFIX] Typo in delegate `shouldUseLiveIdentifier` of `BITHockeyManagerDelegate`
	- [BUGFIX] Default updateManager delegate wasn't set

- Crash Reporting:

	- [BUGFIX] Crash when developer sends the notification `BITHockeyNetworkDidBecomeReachableNotification`


### Version 2.5.0

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
