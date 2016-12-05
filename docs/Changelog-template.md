## 4.1.3

- [NEW] Added `forceNewFeedbackThreadForFeedbackManager:`-callback to `BITFeedbackManagerDelegate` to force a new feedback thread for each new feedback.
- [NEW] Norwegian (Bokmal) localization
- [NEW] Persian (Farsi) localization
- [BUGFIX] Fix analyzer warning in `BITChannelManagerTests`
- [BUGFIX] Add check for nil in `BITChannel`.

## 4.1.2

- [NEW] New `shouldDisplayUpdateAlertForUpdateManager`-API [#339](https://github.com/bitstadium/HockeySDK-iOS/pull/339) to make the moment of appearance for custom update UI even more customizable. 
- [IMPROVEMENT] Fix static analyzer warnings. [#351](https://github.com/bitstadium/HockeySDK-iOS/pull/351)
- [IMPROVEMENT] Internal structure of embedded frameworks changed [#352](https://github.com/bitstadium/HockeySDK-iOS/pull/352)
- [IMPROVEMENT] Upgrade to PLCrashReporter 1.3
- [BUGFIX] Enable bitcode in all configurations [#344](https://github.com/bitstadium/HockeySDK-iOS/pull/344)
- [BUGFIX] Fixed anonymisation of binary paths when running in the simulator [#347](https://github.com/bitstadium/HockeySDK-iOS/pull/347)
- - [BUGFIX] Rename configurations to not break Carthage integration [#353](https://github.com/bitstadium/HockeySDK-iOS/pull/353)

## 4.1.1

**Attention** Due to changes in iOS 10, it is now necessary to include the `NSPhotoLibraryUsageDescription` in your app's Info.plist file if you want to use HockeySDK's Feedback feature. Since using the feature without the plist key present could lead to an App Store rejection, our default CocoaPods configuration does not include the Feedback feature anymore.
If you want to continue to use it, use this in your `Podfile`:

```ruby
pod "HockeySDK", :subspecs => ['AllFeaturesLib']
```

Additionally, we now also provide a new flavor in our binary distribution. To use all features, including Feedback, use `HockeySDK.embeddedframework` from the `HockeySDKAllFeatures` folder.

- [NEW] The property `userDescription` on `BITCrashMetaData` had to be renamed to `userProvidedeDescription` to provide a name clash with Apple Private API
- [IMPROVEMENT] Warn if the Feedback feature is being used without `NSPhotoLibraryUsageDescription` being present
- [IMPROVEMENT] Updated Chinese translations
- [IMPROVEMENT] Set web view baseURL to `about:blank` to improve security
- [BUGFIX] Fix an issue in the telemetry channel that could be triggered in multi-threaded environments
- [BUGFIX] Fix several small layout issues by updating to a newer version of TTTAttributedLabel
- [BUGFIX] Fix app icons with unusual filenames not showing in the in-app update prompt

## 4.1.0

- Includes improvements from 4.0.2 release of the SDK.
- [NEW] Additional API to track an event with properties and measurements.

## 4.1.0-beta.2

- [BUGFIX] Fixes an issue where the whole app's Application Support directory was accidentally excluded from backups.
This SDK release explicitly includes the Application Support directory into backups. If you want to opt-out of this fix and keep the Application Directory's backup flag untouched, add the following line above the SDK setup code:

  - Objective-C:
        ```objectivec
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"BITExcludeApplicationSupportFromBackup"];
        ```

  - Swift:
        ```swift
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "BITExcludeApplicationSupportFromBackup")
        ```

- [NEW] Add more fine-grained log levels
- [NEW] Add ability to connect existing logging framework
- [BUGFIX] Make CrashManager property `serverURL` individual setable
- [BUGFIX] Properly dispatch `dismissViewController` call to main queue
- [BUGFIX] Fixes an issue that prevented preparedItemsForFeedbackManager: delegate method from working

## Version 4.1.0-beta.1

- [IMPROVEMENT] Prevent User Metrics from being sent if `BITMetricsManager` has been disabled.

## Version 4.1.0-alpha.2

- [BUGFIX] Fix different bugs in the events sending pipeline

## Version 4.1.0-alpha.1

- [NEW] Add ability to track custom events
- [IMPROVEMENT] Events are always persisted, even if the app crashes
- [IMPROVEMENT] Allow disabling `BITMetricsManager` at any time
- [BUGFIX] Server URL is now properly customizable
- [BUGFIX] Fix memory leak in networking code
- [IMPROVEMENT] Optimize tests and always build test target
- [IMPROVEMENT] Reuse `NSURLSession` object
- [IMPROVEMENT] Under the hood improvements and cleanup

## Version 4.0.2

- [BUGFIX] Add Bitcode marker back to simulator slices. This is necessary because otherwise `lipo` apparently strips the Bitcode sections from the merged library completely. As a side effect, this unfortunately breaks compatibility with Xcode 6. [#310](https://github.com/bitstadium/HockeySDK-iOS/pull/310)
- [IMPROVEMENT] Improve error detection and logging during crash processing in case the app is sent to the background while crash processing hasn't finished.[#311](https://github.com/bitstadium/HockeySDK-iOS/pull/311)

## Version 4.0.1

- [BUGFIX] Fixes an issue where the whole app's Application Support directory was accidentally excluded from backups.
This SDK release explicitly includes the Application Support directory into backups. If you want to opt-out of this fix and keep the Application Directory's backup flag untouched, add the following line above the SDK setup code:

  - Objective-C:
        ```objectivec
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kBITExcludeApplicationSupportFromBackup"];
        ```

  - Swift:
        ```swift
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "kBITExcludeApplicationSupportFromBackup")
        ```

- [BUGFIX] Fixes an issue that prevented preparedItemsForFeedbackManager: delegate method from working

## Version 4.0.0

- [NEW] Added official Carthage support
- [NEW] Added `preparedItemsForFeedbackManager:` method in `BITFeedbackManagerDelegate` to allow to provide items with every possible method of showing the feedback compose dialog.
- [UPDATE] Our CrashOnly binary now includes User Metrics which enables crash free users statistics
- [UPDATE] Deprecate `feedbackComposerPreparedItems` property in favor of the new delegate method.
- [IMPROVEMENT] Prefix GZIP category on NSData to prevent symbol collisions
- [BUGFIX] Add minor UI bug when adding arrow annotation to feedback image

## Version 4.0.0-beta.1

- [NEW] User Metrics including users and sessions data is now in public beta

## Version 4.0.0-alpha.2

- [UPDATE] Include changes from HockeySDK 3.8.6

## Version 4.0.0-alpha.1

- [NEW] Added `BITMetricsManager` to track users and sessions
- [UPDATE] Remove previously deprecated UpdateManagerDelegate method `-viewControllerForUpdateManager:`
- [UPDATE] Remove previously deprecated CrashManagerDelegate methods `-userNameForCrashManager:` and `-userEmailForCrashManager:`
- [UPDATE] Remove previously deprecated property `appStoreEnvironment`
- [UPDATE] Remove previously deprecated misspelled `timeintervalCrashInLastSessionOccured` property
- [UPDATE] Remove previously deprecated misspelled `BITFeedbackListViewCellPresentatationStyle` enum

## Version 3.8.6

- [UPDATE] Some minor refactorings
- [BUGFIX] Fix crash in `BITCrashReportTextFormatter` in cases where processPath is unexpectedly nil
- [BUGFIX] Fix bug where feedback image could only be added once
- [BUGFIX] Fix URL encoding bug in BITUpdateManager
- [BUGFIX] Include username, email, etc. in `appNotTerminatingCleanly` reports
- [BUGFIX] Fix NSURLSession memory leak in Swift apps
- [BUGFIX] Fix issue preventing attachment from being included when sending non-clean termination report
- [IMPROVEMENT] Anonymize binary path in crash report
- [IMPROVEMENT] Support escaping of additional characters (URL encoding)
- [IMPROVEMENT] Support Bundle Identifiers which contain whitespaces

## Version 3.8.5

- [UPDATE] Some minor improvements to our documentation
- [BUGFIX] Fix a crash where `appStoreReceiptURL` was accidentally accessed on iOS 6
- [BUGFIX] Fix a warning when implementing `BITHockeyManagerDelegate`

## Version 3.8.4

- [BUGFIX] Fix a missing header in the `HockeySDK.h` umbrella
- [BUGFIX] Fix several type comparison warnings

## Version 3.8.3

- [NEW] Adds new `appEnvironment` property to indicate the environment the app is running in. This replaces the old `isAppStoreEnvironment` which is now deprecated. We can now differentiate between apps installed via TestFlight or the AppStore
- [NEW] Distributed zip file now also contains our documentation
- [UPDATE] Prevent issues with duplicate symbols from PLCrashReporter
- [UPDATE] Remove several typos in our documentation and improve instructions for use in extensions
- [UPDATE] Add additional nil-checks before calling blocks
- [UPDATE] Minor code readability improvements
- [BUGFIX] `BITFeedbackManager`: Fix Feedback Annotations not working on iPhones running iOS 9
- [BUGFIX] Switch back to using UIAlertView to prevent several issues. We will add a more robust solution which uses UIAlertController in a future update.
- [BUGFIX] Fix several small issues in our CrashOnly builds
- [BUGFIX] Minor fixes for memory leaks
- [BUGFIX] Fix crashes because completion blocks were not properly dispatched on the main thread

## Version 3.8.2

- [UPDATE] Added support for Xcode 6.x 
- [UPDATE] Requires iOS 7 or later as base SDK, deployment target iOS 6 or later
- [UPDATE] Updated PLCrashReporter build to exclude Bitcode in Simulator slices

## Version 3.8.1

- [UPDATE] Updated PLCrashReporter build using Xcode 7 (7A220)

## Version 3.8

- [NEW] Added Bitcode support
- [UPDATE] Requires Xcode 7 or later
- [UPDATE] Requires iOS 9 or later as base SDK, deployment target iOS 6 or later
- [UPDATE] Updated PLCrashReporter build using Xcode 7
- [UPDATE] Use `UIAlertController` when available
- [UPDATE] Added full support for `NSURLSession`
- [UPDATE] Removed statusbar adjustment code (which isn't needed any longer)
- [UPDATE] Removed kBITTextLabel... defines and use NSText.. instead
- [UPDATE] Removed a few `#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1` since iOS 7 or later is now required as base SDK
- [BUGFIX] `BITFeedbackManager`: Fixed feedback compose view rotation issue
- [BUGFIX] `BITFeedbackManager`: Fixed `Add Image` button not always presented centered
- [BUGFIX] Additional minor fixes

## Version 3.8-RC.1

- [UPDATE] Added full support for `NSURLSession`
- [BUGFIX] `BITFeedbackManager`: Fixed feedback compose view rotation issue
- [BUGFIX] `BITFeedbackManager`: Fixed `Add Image` button not always presented centered
- [BUGFIX] Additional minor fixes

## Version 3.8-Beta.1

- [NEW] Added Bitcode support
- [UPDATE] Requires Xcode 7 or later
- [UPDATE] Requires iOS 7 or later as base SDK
- [UPDATE] Silenced deprecation warnings for `NSURLConnection` calls, these will be refactored in a future update
- [UPDATE] Removed statusbar adjustment code (which isn't needed any longer)
- [UPDATE] Removed kBITTextLabel... defines and use NSText.. instead
- [UPDATE] Removed a few `#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1` since iOS 7 or later is now required as base SDK
- [UPDATE] Use `UIAlertController` when available

## Version 3.7.3

- [BUGFIX] `BITCrashManager`: Updated PLCrashReporter build created with Xcode 6.4 to solve a duplicate symbol error some users are experiencing
- [BUGFIX] `BITUpdateManager`: Fixed updating an app not triggering a crash report if `enableAppNotTerminatingCleanlyDetection` is enabled
- [BUGFIX] Additional minor fixes

## Version 3.7.2

- [BUGFIX] `BITCrashManager`: Added workaround for a bug observed in iOS 9 beta's dyld triggering an infinite loop on startup
- [BUGFIX] `BITFeedbackManager`: Fixed a crash in the feedback UI that can occur when rotating the device while data is being loaded
- [BUGFIX] Fixed `Info.plist` entries in `HockeySDKResources.bundle` which cause Xcode 7 to show an error when uploading an app to iTunes Connect
- [BUGFIX] Additional minor fixes

## Version 3.7.1

- [BUGFIX] `CocoaPods`: Fixes the default podspec with binary distribution
- [BUGFIX] `CocoaPods`: Changes `HockeySDK-Source` to use non configurable approach, since we couldn't make it work reliably in all scenarios

## Version 3.7.0

- [NEW] Simplified installation process. If support for modules is enabled in the target project (default for most projects), it’s no longer necessary to add the frameworks manually
- [NEW] `CocoaPods`: Default pod uses binary distribution and offers crash only build as a subspec
- [NEW] `CocoaPods`: New `HockeySDK-Source` pod integrates via source code and offers feature set customization via subspecs. Note: We do not support building with Xcode 7 yet!
- [NEW] `BITCrashManager`: Added support for unhandled C++ exceptions (requires to link `libc++`)
- [NEW] `BITCrashManager`: Sending crash reports via `NSURLSession` whenever possible
- [NEW] `BITCrashManager`: Added process ID to `BITCrashDetails`
- [NEW] `BITCrashManager`: Added `CFBundleShortVersionString` value to crash reports
- [NEW] `BITFeedbackManager`: "Add Image" button in feedback compose view can now be hidden using `feedbackComposeHideImageAttachmentButton` property
- [NEW] `BITFeedbackManagerDelegate`: Added `allowAutomaticFetchingForNewFeedbackForManager:` to define if the SDK should fetch new messages on app startup and when the app is coming into foreground. 
- [NEW] Added disableInstallTracking property to disable installation tracking (AppStore only).
- [UPDATE] Restructured installation documentation
- [BUGFIX] `BITCrashManager`: Fixed offline issue showing crash alert over and over again with unsent crash reports
- [BUGFIX] `BITFeedbackManager`: Improved screenshot handling on slow devices
- [BUGFIX] `BITStoreUpdateManager`: Delegate property wasn't propagated correctly
- [BUGFIX] Fixed various compiler warnings & other improvements

## Version 3.6.4

- [BUGFIX] Fixed a build issue

## Version 3.6.3

- [NEW] `BITCrashManager`: Added launch time to crash reports
- [NEW] `BITFeedbackManager`: Added support for setting tintColor for feedback list buttons
- [NEW] `BITFeedbackManager`: Added `feedbackComposerPreparedItems` to prefill feedback compose UI message with given items
- [NEW] `BITUpdateManagerDelegate`: Added `willStartDownloadAndUpdate` to be notified before beta update starts
- [UPDATE] Improved CocoaPods support to allow building as a native iOS 8 framework
- [UPDATE] Keychain is now accessed with `kSecAttrAccessibleAlwaysThisDeviceOnly` to support apps that are running in the background and the device is still locked
- [UPDATE] Reduced file size of images in `HockeySDKResources.bundle` by 63%
- [UPDATE] `BITCrashManager`: `timeintervalCrashInLastSessionOccured` property is deprecated due to typo, use `timeIntervalCrashInLastSessionOccurred` instead
- [UPDATE] `BITFeedbackManager`: `BITFeedbackListViewCellPresentatationStyle` is deprecated due to a typo, use `BITFeedbackListViewCellPresentationStyle` instead
- [UPDATE] `BITAuthenticator`: Use NSLog instead of an UIAlertView in case of keychain issues
- [BUGFIX] `BITCrashManager`: Fixed issue with `appNotTerminatingCleanlyDetection` for some scenarios
- [BUGFIX] `BITFeedbackManager`: Fixed a crash when deleting feedback attachments
- [BUGFIX] `BITFeedbackManager`: Fixed a crash related to viewing attachments
- [BUGFIX] `BITFeedbackManager`: Fixed landscape screenshot issues in iOS 8
- [BUGFIX] `BITFeedbackManager`: Fixed various issues in feedback compose UI
- [BUGFIX] `BITFeedbackManager`: Fixed loading issues for attachments in feedback UI
- [BUGFIX] `BITFeedbackManager`: Fixed statusbar issues and the image attachment picker with apps not showing a status bar
- [BUGFIX] Removed a header file from the crash only build that is not needed
- [BUGFIX] Fixed various typos in documentation, properties
- [BUGFIX] Fixed various compiler warnings
- [BUGFIX] Various additional fixes

## Version 3.6.2

- [UPDATE] Store anonymous UUID asynchronously into the keychain to work around rare keychain blocking behavior
- [UPDATE] `BITCrashManager`: Improved detecting app specific binary images in crash report for improved crash grouping on the server
- [UPDATE] `BITUpdateManager`: Added new `updateManagerWillExitApp` delegate method
- [UPDATE] `BITUpdateManager`: Don't save any file when app was installed from App Store
- [BUGFIX] `BITCrashManager`: Fixed issues with sending crash reports for apps with xml tags in the app name
- [BUGFIX] `BITFeedbackManager`: Fixed screenshot trigger issue not always fetching the last taken image
- [BUGFIX] `BITFeedbackManager`: Fixed compose view issue with predefined text
- [BUGFIX] Fixed a warning when integrating the binary framework for only crash reporting
- [BUGFIX] Fixed compiler warnings
- [BUGFIX] Various additional fixes

## Version 3.6.1

- [BUGFIX] Fixed feedback compose view to correctly show the text in landscape on iOS 8

## Version 3.6

- [NEW] `BITCrashManager`: Added support for iOS 8 Extensions
- [NEW] `BITCrashManager`: Option to add a custom UI flow before sending a crash report, e.g. to ask users for more details (see `setAlertViewHandler:`)
- [NEW] `BITCrashManager`: Provide details on a crash report (see `lastSessionCrashDetails` and `BITCrashDetails`)
- [NEW] `BITCrashManager`: Experimental support for detecting app kills triggered by iOS while the app is in foreground (see `enableAppNotTerminatingCleanlyDetection`)
- [NEW] `BITCrashManager`: Added `didReceiveMemoryWarningInLastSession` which indicates if the last app session did get a memory warning by iOS
- [NEW] `BITFeedbackManager`: Attach and annotate images and screenshots
- [NEW] `BITFeedbackManager`: Attach any binary data to compose message view (see `showFeedbackComposeViewWithPreparedItems:`)
- [NEW] `BITFeedbackManager`: Show a compose message with a screenshot image attached using predefined triggers (see `feedbackObservationMode`) or your own custom triggers (see `showFeedbackComposeViewWithGeneratedScreenshot`)
- [NEW] Minimum iOS Deployment version is now iOS 6.0
- [NEW] Requires to link additional frameworks: `AssetLibrary`, `MobileCoreServices`, `QuickLook`
- [UPDATE] `BITCrashManager`: Updated `setCrashCallbacks` handling now using `BITCrashManagerCallbacks` instead of `PLCrashReporterCallbacks` (which is no longer public)
- [UPDATE] `BITCrashManager`: Crash reports are now sent individually if there are multiple pending
- [UPDATE] `BITUpdateManager`: Improved algorithm for fetching an optimal sized app icon for the Update View
- [UPDATE] `BITUpdateManager`: Properly consider paragraphs in release notes when presenting them in the Update view
- [UPDATE] Property `delegate` in all components is now private. Set the delegate on `BITHockeyManager` only!
- [UPDATE] Removed support for Atlassian JMC
- [BUGFIX] Various additional fixes
<br /><br/>

## Version 3.6.0 Beta 2

- [NEW] `BITFeedbackManager`: Screenshot feature is now part of the public API
- [UPDATE] `BITFeedbackManager`: Various improvements for the screenshot feature
- [UPDATE] `BITFeedbackManager`: Added `BITHockeyAttachment` for more customizable attachments to feedback (`content-type`, `filename`)
- [UPDATE] `BITUpdateManager`: Improved algorithm for fetching an optimal sized app icon for the Update View
- [UPDATE] `BITUpdateManager`: Properly consider paragraphs in releases notes when presenting them in the Update View
- [UPDATE] `BITCrashManager`: Updated PLCrashReporter to version 1.2
- [UPDATE] `BITCrashManager`: Added `osVersion` and `osBuild` properties to `BITCrashDetails`
- [BUGFIX] `BITCrashManager`: Use correct filename for crash report attachments
- [UPDATE] Property `delegate` in all components is now private. Set the delegate on `BITHockeyManager` only!
- [BUGFIX] Various additional fixes
<br /><br/>

## Version 3.6.0 Beta 1

- [NEW] Minimum iOS Deployment version is now iOS 6.0
- [NEW] Requires to link additional frameworks: `AssetLibrary`, `MobileCoreServices`, `QuickLook`
- [NEW] `BITFeedbackManager`: Attach and annotate images and screenshots
- [NEW] `BITFeedbackManager`: Attach any binary data to compose message view (see `showFeedbackComposeViewWithPreparedItems:`)
- [NEW] `BITFeedbackManager`: Show a compose message with a screenshot image attached using predefined triggers (see `feedbackObservationMode`) or your own custom triggers (see `showFeedbackComposeViewWithGeneratedScreenshot`)
- [NEW] `BITCrashManager`: Option to add a custom UI flow before sending a crash report, e.g. to ask users for more details (see `setAlertViewHandler:`)
- [NEW] `BITCrashManager`: Provide details on a crash report (see `lastSessionCrashDetails`)
- [NEW] `BITCrashManager`: Experimental support for detecting app kills triggered by iOS while the app is in foreground (see `enableAppNotTerminatingCleanlyDetection`)
- [NEW] `BITCrashManager`: Added `didReceiveMemoryWarningInLastSession` which indicates if the last app session did get a memory warning by iOS
- [UPDATE] `BITCrashManager`: Updated `setCrashCallbacks` handling now using `BITCrashManagerCallbacks` instead of `PLCrashReporterCallbacks` (which is no longer public)
- [UPDATE] `BITCrashManager`: Crash reports are now send individually if there are multiple pending
- [UPDATE] Removed support for Atlassian JMC
- [BUGFIX] Fixed an incorrect submission warning about referencing non-public selector `attachmentData`
<br /><br/>

## Version 3.5.7

- [UPDATE] Easy Swift integration for binary distribution (No Objective-C bridging header required)
- [UPDATE] `BITAuthenticator`: Improved keychain handling
- [UPDATE] `BITUpdateManager`: Improved iOS 8 In-App-Update process handling
- [BUGFIX] `BITUpdateManager`: Fixed layout issue for resizable iOS layout
- [BUGFIX] Fixed an iTunes Connect warning for `attachmentData` property
<br /><br/>

## Version 3.5.6

- [UPDATE] `BITCrashManager`: Updated PLCrashReporter to version 1.2
- [UPDATE] `BITUpdateManager`: Improved algorithm to find the optimal app icon
- [BUGFIX] `BITAuthenticator`: Fixed problem with authorization and iOS 8
- [BUGFIX] Fixed a problem with integration test and iOS 8 
<br /><br/>

## Version 3.5.5

- [NEW] `BITCrashManager`: Added support for adding a binary attachment to crash reports
- [NEW] `BITCrashManager`: Integrated PLCrashReporter 1.2 RC5 (with 2 more fixes)
- [BUGFIX] `BITUpdateManager`: Fixed problem with `checkForUpdate` when `updateSetting` is set to `BITUpdateCheckManually`
- [BUGFIX] `BITAuthenticator`: Fixed keychain warning alert showing app on launch if keychain is locked
- [BUGFIX] `BITAuthenticator`: Fixed a possible assertion problem with auto-authentication (when using custom SDK builds without assertions being disabled)
- [BUGFIX] `BITAuthenticator`: Added user email to crash report for beta builds if BITAuthenticator is set to BITAuthenticatorIdentificationTypeWebAuth
- [BUGFIX] Fixed more analyzer warnings
<br /><br/>

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
