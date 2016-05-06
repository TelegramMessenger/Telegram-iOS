## Version 4.0.1

- [Changelog](http://www.hockeyapp.net/help/sdk/ios/4.0.1/docs/docs/Changelog.html)

**NOTE:** With the release of HockeySDK 4.0.0-alpha.1 a bug was introduced which lead to the exclusion of the Application Support folder from iCloud and iTunes backups.

If you have been using one of the affected versions (4.0.0-alpha.2, Version 4.0.0-beta.1, 4.0.0, 4.1.0-alpha.1, 4.1.0-alpha.2, or Version 4.1.0-beta.1), please make sure to update to at least version 4.0.1 or 4.1.0-beta.2 of our SDK as soon as you can.

## Introduction

This document contains the following sections:

1. [Requirements](#requirements)
2. [Setup](#setup)
3. [Advanced Setup](#advancedsetup) 
  1. [Linking System Frameworks manually](#linkmanually)   
  2. [CocoaPods](#cocoapods)
  3. [Carthage](#carthage)
  4. [iOS Extensions](#extensions)
  5. [WatchKit 1 Extensions](#watchkit)
  6. [Crash Reporting](#crashreporting)
  7. [User Metrics](#user-metrics)
  8. [Feedback](#feedback)
  9. [Store Updates](#storeupdates)
  10. [In-App-Updates (Beta & Enterprise only)](#betaupdates)
  11. [Debug information](#debug)
4. [Documentation](#documentation)
5. [Troubleshooting](#troubleshooting)
6. [Contributing](#contributing)
7. [Contributor License](#contributorlicense)
8. [Contact](#contact)

<a id="requirements"></a> 
## 1. Requirements

1. We assume that you already have a project in Xcode and that this project is opened in Xcode 7 or later.
2. The SDK supports iOS 6.0 and later.

<a id="setup"></a>
## 2. Setup

We recommend integration of our binary into your Xcode project to setup HockeySDK for your iOS app. You can also use our interactive SDK integration wizard in <a href="http://hockeyapp.net/mac/">HockeyApp for Mac</a> which covers all the steps from below. For other ways to setup the SDK, see [Advanced Setup](#advancedsetup).

### 2.1 Obtain an App Identifier

Please see the "[How to create a new app](http://support.hockeyapp.net/kb/about-general-faq/how-to-create-a-new-app)" tutorial. This will provide you with an HockeyApp specific App Identifier to be used to initialize the SDK.

### 2.2 Download the SDK

1. Download the latest [HockeySDK-iOS](http://www.hockeyapp.net/releases/) framework which is provided as a zip-File.
2. Unzip the file and you will see a folder called `HockeySDK-iOS`. (Make sure not to use 3rd party unzip tools!)

### 2.3 Copy the SDK into your projects directory in Finder

From our experience, 3rd-party libraries usually reside inside a subdirectory (let's call our subdirectory `Vendor`), so if you don't have your project organized with a subdirectory for libraries, now would be a great start for it. To continue our example,  create a folder called `Vendor` inside your project directory and move the unzipped `HockeySDK-iOS`-folder into it. 

The SDK comes in three flavours:

  * Full featured `HockeySDK.embeddedframework`
  * Crash reporting only: `HockeySDK.framework` in the subfolder `HockeySDKCrashOnly`
  * Crash reporting only for extensions: `HockeySDK.framework` in the subfolder `HockeySDKCrashOnlyExtension` (which is required to be used for extensions).
  
Our examples will use the full featured SDK (`HockeySDK.embeddedframework`).

<a id="setupxcode"></a>

### 2.4 Add the SDK to the project in Xcode

> We recommend to use Xcode's group-feature to create a group for 3rd-party-libraries similar to the structure of our files on disk. For example, similar to the file structure in 2.3 above, our projects have a group called `Vendor`.
  
1. Make sure the `Project Navigator` is visible (⌘+1).
2. Drag & drop `HockeySDK.embeddedframework` from your `Finder` to the `Vendor` group in `Xcode` using the `Project Navigator` on the left side.
3. An overlay will appear. Select `Create groups` and set the checkmark for your target. Then click `Finish`.

<a id="modifycode"></a>
### 2.5 Modify Code 

**Objective-C**

1. Open your `AppDelegate.m` file.
2. Add the following line at the top of the file below your own `import` statements:

  ```objectivec
  @import HockeySDK;
  ```

3. Search for the method `application:didFinishLaunchingWithOptions:`
4. Add the following lines to setup and start the Application Insights SDK:

  ```objectivec
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
  // Do some additional configuration if needed here
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation]; // This line is obsolete in the crash only builds
  ```

**Swift**

1. Open your `AppDelegate.swift` file.
2. Add the following line at the top of the file below your own import statements:

  ```swift
  import HockeySDK
  ```

3. Search for the method 

  ```swift
  application(application: UIApplication, didFinishLaunchingWithOptions launchOptions:[NSObject: AnyObject]?) -> Bool
  ```

4. Add the following lines to setup and start the Application Insights SDK:

  ```swift
  BITHockeyManager.sharedHockeyManager().configureWithIdentifier("APP_IDENTIFIER");
  BITHockeyManager.sharedHockeyManager().startManager();
  BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation(); // This line is obsolete in the crash only builds
  ```

*Note:* The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that `applicationDidFinishLaunching` will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.

**Congratulation, now you're all set to use HockeySDK!**

<a id="advancedsetup"></a> 
## 3. Advanced Setup

<a id="linkmanually"></a>
### 3.1 Linking System Frameworks manually

If you are working with an older project which doesn't support clang modules yet or you for some reason turned off the `Enable Modules (C and Objective-C` and `Link Frameworks Automatically` options in Xcode, you have to manually link some system frameworks:

1. Select your project in the `Project Navigator` (⌘+1).
2. Select your app target.
3. Select the tab `Build Phases`.
4. Expand `Link Binary With Libraries`.
5. Add the following system frameworks, if they are missing:
  1. Full Featured: 
    + `AssetsLibrary`
    + `CoreText`
    + `CoreGraphics`
    + `Foundation`
    + `MobileCoreServices`
    + `QuartzCore`
    + `QuickLook`
    + `Photos`
    + `Security`
    + `SystemConfiguration`
    + `UIKit`
    + `libc++`
    + `libz`
  2. Crash reporting only:
    + `Foundation`
    + `Security`
    + `SystemConfiguration`
    + `UIKit`
    + `libc++`
  3. Crash reporting only for extensions:
    + `Foundation`
    + `Security`
    + `SystemConfiguration`
    + `libc++`

Note that this also means that you can't use the `@import` syntax mentioned in the [Modify Code](#modify) section but have to stick to the old `#import <HockeySDK/HockeySDK.h>`.

<a id="cocoapods"></a>
### 3.2 CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like HockeySDK in your projects. To learn how to setup CocoaPods for your project, visit the [official CocoaPods website](http://cocoapods.org/).

**Podfile**

```ruby
platform :ios, '8.0'
pod "HockeySDK"
```

#### 3.2.1 Binary Distribution Options

The default and recommended distribution is a binary (static library) and a resource bundle with translations and images for all SDK Features: Crash Reporting, User Feedback, Store Updates, Authentication, AdHoc Updates.

You can alternative use a Crash Reporting build only by using the following line in your `Podfile`:

```ruby
pod "HockeySDK", :subspecs => ['CrashOnlyLib']
```

Or you can use the Crash Reporting build only for extensions by using the following line in your `Podfile`:

```ruby
pod "HockeySDK", :subspecs => ['CrashOnlyExtensionsLib']
```

#### 3.2.2 Source Integration Options

Alternatively you can integrate the SDK by source if you want to do any modifications or want a different feature set. The following entry will integrate the SDK:

```ruby
pod "HockeySDK-Source"
```

<a id="carthage"></a>
### 3.3 Carthage

[Carthage](https://github.com/Carthage/Carthage) is an alternative way to add frameworks to your app. For general information about how to use Carthage, please follow their [documentation](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

To add HockeySDK to your project, simply put this line into your `Cartfile`:

`github "bitstadium/HockeySDK-iOS"`

and then follow the steps described in the [Carthage documentation](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos).

<a id="extensions"></a>
### 3.4 iOS Extensions

The following points need to be considered to use the HockeySDK SDK with iOS Extensions:

1. Each extension is required to use the same values for version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) as the main app uses. (This is required only if you are using the same `APP_IDENTIFIER` for your app and extensions).
2. You need to make sure the SDK setup code is only invoked **once**. Since there is no `applicationDidFinishLaunching:` equivalent and `viewDidLoad` can run multiple times, you need to use a setup like the following example:

  ```objectivec
  static BOOL didSetupHockeySDK = NO;

  @interface TodayViewController () <NCWidgetProviding>

  @end

  @implementation TodayViewController

  + (void)viewDidLoad {
    [super viewDidLoad];
    if (!didSetupHockeySDK) {
      [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
      [[BITHockeyManager sharedHockeyManager] startManager];
      didSetupHockeySDK = YES;
    }
  }
  ```

3. The binary distribution provides a special framework build in the `HockeySDKCrashOnly` or `HockeySDKCrashOnlyExtension` folder of the distribution zip file, which only contains crash reporting functionality (also automatic sending crash reports only).

<a id="watchkit"></a>
### 3.5 WatchKit 1 Extensions

The following points need to be considered to use HockeySDK with WatchKit 1 Extensions:

1. WatchKit extensions don't use regular `UIViewControllers` but rather `WKInterfaceController` subclasses. These have a different lifecycle than you might be used to.

  To make sure that the HockeySDK is only instantiated once in the WatchKit extension's lifecycle we recommend using a helper class similar to this:

  ```objectivec
  @import Foundation;
  
  @interface BITWatchSDKSetup : NSObject
  
  * (void)setupHockeySDKIfNeeded;
  
  @end
  ```

  ```objectivec
  #import "BITWatchSDKSetup.h"
  @import HockeySDK
  
  static BOOL hockeySDKIsSetup = NO;
  
  @implementation BITWatchSDKSetup
  
  * (void)setupHockeySDKIfNeeded {
    if (!hockeySDKIsSetup) {
      [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
      [[BITHockeyManager sharedHockeyManager] startManager];
      hockeySDKIsSetup = YES;
    }
  }
  
  @end
  ```

  Then, in each of your WKInterfaceControllers where you want to use the HockeySDK, you should do this:

  ```objectivec
  #import "InterfaceController.h"
  @import HockeySDK
  #import "BITWatchSDKSetup.h"
  
  @implementation InterfaceController
  
  + (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    [BITWatchSDKSetup setupHockeySDKIfNeeded];
  }
  
  + (void)willActivate {
    [super willActivate];
  }
  
  + (void)didDeactivate {
    [super didDeactivate];
  }
  
  @end
  ```

2. The binary distribution provides a special framework build in the `HockeySDKCrashOnly` or `HockeySDKCrashOnlyExtension` folder of the distribution zip file, which only contains crash reporting functionality (also automatic sending crash reports only).

<a name="crashreporting"></a>
### 3.6 Crash Reporting

The following options only show some of possibilities to interact and fine-tune the crash reporting feature. For more please check the full documentation of the `BITCrashManager` class in our [documentation](#documentation).

#### 3.6.1 Disable Crash Reporting
The HockeySDK enables crash reporting **per default**. Crashes will be immediately sent to the server the next time the app is launched.

To provide you with the best crash reporting, we are using [PLCrashReporter]("https://github.com/plausiblelabs/plcrashreporter") in [Version 1.2 / Commit 356901d7f3ca3d46fbc8640f469304e2b755e461]("https://github.com/plausiblelabs/plcrashreporter/commit/356901d7f3ca3d46fbc8640f469304e2b755e461").

This feature can be disabled as follows:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableCrashManager: YES]; //disable crash reporting

[[BITHockeyManager sharedHockeyManager] startManager];
```

#### 3.6.2 Autosend crash reports

Crashes are send the next time the app starts. If `crashManagerStatus` is set to `BITCrashManagerStatusAutoSend`, crashes will be send without any user interaction, otherwise an alert will appear allowing the users to decide whether they want to send the report or not.

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager].crashManager setCrashManagerStatus: BITCrashManagerStatusAutoSend];

[[BITHockeyManager sharedHockeyManager] startManager];
```

The SDK is not sending the reports right when the crash happens deliberately, because if is not safe to implement such a mechanism while being async-safe (any Objective-C code is _NOT_ async-safe!) and not causing more danger like a deadlock of the device, than helping. We found that users do start the app again because most don't know what happened, and you will get by far most of the reports.

Sending the reports on startup is done asynchronously (non-blocking). This is the only safe way to ensure that the app won't be possibly killed by the iOS watchdog process, because startup could take too long and the app could not react to any user input when network conditions are bad or connectivity might be very slow.

#### 3.6.3 Mach Exception Handling

By default the SDK is using the safe and proven in-process BSD Signals for catching crashes. This option provides an option to enable catching fatal signals via a Mach exception server instead.

We strongly advice _NOT_ to enable Mach exception handler in release versions of your apps!

*Warning:* The Mach exception handler executes in-process, and will interfere with debuggers when they attempt to suspend all active threads (which will include the Mach exception handler). Mach-based handling should _NOT_ be used when a debugger is attached. The SDK will not enabled catching exceptions if the app is started with the debugger running. If you attach the debugger during runtime, this may cause issues the Mach exception handler is enabled!
 
```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager].crashManager setEnableMachExceptionHandler: YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

#### 3.6.4 Attach additional data

The `BITHockeyManagerDelegate` protocol provides methods to add additional data to a crash report:

1. UserID: `- (NSString *)userIDForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
2. UserName: `- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`
3. UserEmail: `- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

The `BITCrashManagerDelegate` protocol (which is automatically included in `BITHockeyManagerDelegate`) provides methods to add more crash specific data to a crash report:

1. Text attachments: `-(NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager`

  Check the following tutorial for an example on how to add CocoaLumberjack log data: [How to Add Application Specific Log Data on iOS or OS X](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-add-application-specific-log-data-on-ios-or-os-x)
2. Binary attachments: `-(BITHockeyAttachment *)attachmentForCrashManager:(BITCrashManager *)crashManager`

Make sure to implement the protocol

```objectivec
@interface YourAppDelegate () <BITHockeyManagerDelegate> {}

@end
```

and set the delegate:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDelegate: self];

[[BITHockeyManager sharedHockeyManager] startManager];
```


<a name="user-metrics"></a>
### 3.6 User Metrics

HockeyApp automatically provides you with nice, intelligible, and informative metrics about how your app is used and by whom. 
- **Sessions**: A new session is tracked by the SDK whenever the containing app is restarted (this refers to a 'cold start', i.e. when the app has not already been in memory prior to being launched) or whenever it becomes active again after having been in the background for 20 seconds or more.
- **Users**: The SDK anonymously tracks the users of your app by creating a random UUID that is then securely stored in the iOS keychain. Because this anonymous ID is stored in the keychain it persists across reinstallations.

Just in case you want to opt-out of this feature, there is a way to turn this functionality off:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;

[[BITHockeyManager sharedHockeyManager] startManager];

```

<a name="feedback"></a>
### 3.7 Feedback

`BITFeedbackManager` lets your users communicate directly with you via the app and an integrated user interface. It provides a single threaded discussion with a user running your app. This feature is only enabled, if you integrate the actual view controllers into your app.
 
You should never create your own instance of `BITFeedbackManager` but use the one provided by the `[BITHockeyManager sharedHockeyManager]`:
 
```objectivec
[BITHockeyManager sharedHockeyManager].feedbackManager
```

Please check the [documentation](#documentation) of the `BITFeedbachManager` class on more information on how to leverage this feature.

<a name="storeupdates"></a>
### 3.8 Store Updates

This is the HockeySDK module for handling app updates when having your app released in the App Store.

When an update is detected, this module will show an alert asking the user if he/she wants to update or ignore this version. If update was chosen, it will open the apps page in the app store app.

By default this module is **NOT** enabled! To enable it use the following code:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setEnableStoreUpdateManager: YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

When this module is enabled and **NOT** running in an App Store build/environment, it won't do any checks!

Please check the [documentation](#documentation) of the `BITStoreUpdateManager` class on more information on how to leverage this feature and know about its limits.

<a name="betaupdates"></a>
### 3.9 In-App-Updates (Beta & Enterprise only)

The following options only show some of possibilities to interact and fine-tune the update feature when using Ad-Hoc or Enterprise provisioning profiles. For more please check the full documentation of the `BITUpdateManager` class in our [documentation](#documentation).

The feature handles version updates, presents update and version information in a App Store like user interface, collects usage information and provides additional authorization options when using Ad-Hoc provisioning profiles.

This module automatically disables itself when running in an App Store build by default!

This feature can be disabled manually as follows:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableUpdateManager: YES]; //disable auto updating

[[BITHockeyManager sharedHockeyManager] startManager];
```

If you want to see beta analytics, use the beta distribution feature with in-app updates, restrict versions to specific users, or want to know who is actually testing your app, you need to follow the instructions on our guide [Authenticating Users on iOS](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/authenticating-users-on-ios)

<a id="debug"></a>
### 3.10 Debug information

To check if data is send properly to HockeyApp and also see some additional SDK debug log data in the console, add the following line before `startManager`:

```objectivec
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDebugLogEnabled:YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

<a id="documentation"></a>
## 4. Documentation

Our documentation can be found on [HockeyApp](http://hockeyapp.net/help/sdk/ios/4.0.1/index.html).

<a id="troubleshooting"></a>
## 5.Troubleshooting

### Linker warnings

  Make sure that all mentioned frameworks and libraries are linked

### iTunes Connect rejection

  Make sure none of the following files are copied into your app bundle, check under app target, `Build Phases`, `Copy Bundle Resources` or in the `.app` bundle after building:

  - `HockeySDK.framework` (except if you build a dynamic framework version of the SDK yourself!)
  - `de.bitstadium.HockeySDK-iOS-4.0.1.docset`

### Feature are not working as expected

  Enable debug output to the console to see additional information from the SDK initializing the modules,  sending and receiving network requests and more by adding the following code before calling `startManager`:

  `[[BITHockeyManager sharedHockeyManager] setDebugLogEnabled: YES];`

<a id="contributing"></a>
## 6. Contributing

We're looking forward to your contributions via pull requests.

**Development environment**

* Mac running the latest version of OS X
* Get the latest Xcode from the Mac App Store
* [AppleDoc](https://github.com/tomaz/appledoc) 
* [CocoaPods](https://cocoapods.org/)
* [Carthage](https://github.com/Carthage/Carthage)

<a id="contributorlicense"></a>
## 7. Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before submitting your pull request. To complete the Contributor License Agreement (CLA), you will need to submit a request via the [form](https://cla.microsoft.com/) and then electronically sign the CLA when you receive the email containing the link to the document. You need to sign the CLA only once to cover submission to any Microsoft OSS project. 

<a id="contact"></a>
## 8. Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps here, feel free to open a Github issue here or contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net)
