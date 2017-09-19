[![Build Status](https://travis-ci.org/bitstadium/HockeySDK-iOS.svg?branch=master)](https://travis-ci.org/bitstadium/HockeySDK-iOS)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](http://cocoapod-badges.herokuapp.com/v/HockeySDK/badge.png)](http://cocoadocs.org/docsets/HockeySDK)
 [![Slack Status](https://slack.hockeyapp.net/badge.svg)](https://slack.hockeyapp.net)
 
## Version 5.0.0

- [Changelog](http://www.hockeyapp.net/help/sdk/ios/5.0.0/docs/docs/Changelog.html)

**NOTE** If your are using the binary integration of our SDK, make sure that the `HockeySDKResources.bundle` inside the `HockeySDK.embeddedframework`-folder has been added to your application.

### Feedback and iOS 10
**4.1.1 and later of the HockeySDK remove the Feedback feature from the default version of the SDK.**
The reason for this is that iOS 10 requires developers to add a usage string to their Info.plist in case they include the photos framework in their app. If this string is missing, the app will be rejected when submitting the app to the app store. As HockeyApp's Feedback feature includes a dependency to the photos framework. This means that if you include HockeyApp into your app, adding the usage string would be a requirement even for developers who don't use the Feedback feature. If you don't use Feedback in your app, simply upgrade HockeySDK to version 4.1.1 or newer. If you are using Feedback, please have a look at the [Feedback section](#feedback).


We **strongly** suggest upgrading to version 4.1.1 or a later version of the SDK. Not specifying the usage description string and using previous versions of the HockeySDK-iOS will cause the app to crash at runtime as soon as the user taps the "attach image"-button or in case you have enabled `BITFeedbackObservationModeOnScreenshot`.

If you are using an older version of the SDK, you must add a `NSPhotoLibraryUsageDescription` to your `Info.plist` to avoid a AppStore rejection during upload of your app (please have a look at the [Feedback section](#feedback)).

## Introduction

HockeySDK-iOS implements support for using HockeyApp in your iOS applications.

The following features are currently supported:

1. **Collect crash reports:** If your app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, they are asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store.

2. **User Metrics:** Understand user behavior to improve your app. Track usage through daily and monthly active users, monitor crash impacted users, as well as customer engagement through session count.You can now track **Custom Events** in your app, understand user actions and see the aggregates on the HockeyApp portal.

3. **Update Ad-Hoc / Enterprise apps:** The app will check with HockeyApp if a new version for your Ad-Hoc or Enterprise build is available. If yes, it will show an alert view to the user and let them see the release notes, the version history and start the installation process right away. 

4. **Update notification for app store:** The app will check if a new version for your app store release is available. If yes, it will show an alert view to the user and let them open your app in the App Store app. (Disabled by default!)

5. **Feedback:** Collect feedback from your users from within your app and communicate directly with them using the HockeyApp backend.

6. **Authenticate:** Identify and authenticate users of Ad-Hoc or Enterprise builds

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
  1. [Development Environment](#developmentenvironment)
  2. [Code of Conduct](#codeofconduct)
  3. [Contributor License](#contributorlicense)
7. [Contact](#contact)

<a id="requirements"></a> 
## 1. Requirements

1. We assume that you already have a project in Xcode and that this project is opened in Xcode 8 or later.
2. The SDK supports iOS 8.0 and later.

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

The SDK comes in four flavors:

  * Default SDK without Feedback: `HockeySDK.embeddedframework`
  * Full featured SDK with Feedback: `HockeySDK.embeddedframework` in the subfolder `HockeySDKAllFeatures`. 
  * Crash reporting only: `HockeySDK.framework` in the subfolder `HockeySDKCrashOnly`.
  * Crash reporting only for extensions: `HockeySDK.framework` in the subfolder `HockeySDKCrashOnlyExtension` (which is required to be used for extensions).
  
Our examples will use the **default** SDK (`HockeySDK.embeddedframework`).

<a id="setupxcode"></a>

### 2.4 Add the SDK to the project in Xcode

> We recommend using Xcode's group-feature to create a group for 3rd-party-libraries similar to the structure of our files on disk. For example, similar to the file structure in 2.3 above, our projects have a group called `Vendor`.
	
1. Make sure the `Project Navigator` is visible (⌘+1).
2. Drag & drop `HockeySDK.embeddedframework` from your `Finder` to the `Vendor` group in `Xcode` using the `Project Navigator` on the left side.
3. An overlay will appear. Select `Create groups` and set the checkmark for your target. Then click `Finish`.

<a id="modifycode"></a>
### 2.5 Modify Code 

**Objective-C**

1. Open your `AppDelegate.m` file.
2. Add the following line at the top of the file below your own `import` statements:

  ```objc
  @import HockeySDK;
  ```

3. Search for the method `application:didFinishLaunchingWithOptions:`
4. Add the following lines to setup and start the HockeyApp SDK:

  ```objc
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
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
  ```

4. Add the following lines to setup and start the HockeyApp SDK:

  ```swift
  BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
  BITHockeyManager.shared().start()
  BITHockeyManager.shared().authenticator.authenticateInstallation() // This line is obsolete in the crash only builds

  ```


*Note:* The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on start-up can also be caught and each module executes other code with a delay some seconds. This ensures that `applicationDidFinishLaunching` will process as fast as possible and the SDK will not block the start-up sequence resulting in a possible kill by the watchdog process.


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
  1. Default SDK: 
    + `CoreText`
    + `CoreGraphics`
    + `Foundation`
    + `MobileCoreServices`
    + `QuartzCore`
    + `QuickLook`
    + `Security`
    + `SystemConfiguration`
    + `UIKit`
    + `libc++`
    + `libz`
  2. SDK with all features:
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
  3. Crash reporting only:
    + `Foundation`
    + `Security`
    + `SystemConfiguration`
    + `UIKit`
    + `libc++`
  4. Crash reporting only for extensions:
    + `Foundation`
    + `Security`
    + `SystemConfiguration`
    + `libc++`

Note that not using clang modules also means that you can't use the `@import` syntax mentioned in the [Modify Code](#modify) section but have to stick to the old `#import <HockeySDK/HockeySDK.h>` imports.

<a id="cocoapods"></a>
### 3.2 CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like HockeySDK in your projects. To learn how to setup CocoaPods for your project, visit the [official CocoaPods website](http://cocoapods.org/).

**Podfile**

```ruby
platform :ios, '8.0'
pod "HockeySDK"
```

#### 3.2.1 Binary Distribution Options

The default and recommended distribution is a binary (static library) and a resource bundle with translations and images for all SDK features.

```ruby
platform :ios, '8.0'
pod "HockeySDK"
```

Will integrate the *default* configuration of the SDK, with all features except the Feedback feature.

For the SDK with all features, including Feedback, add

```ruby
pod "HockeySDK", :subspecs => ['AllFeaturesLib']
```
to your podfile.

To add the variant that only includes crash reporting, use

```ruby
pod "HockeySDK", :subspecs => ['CrashOnlyLib']
```

Or you can use the Crash Reporting build only for extensions by using the following line in your `Podfile`:

```ruby
pod "HockeySDK", :subspecs => ['CrashOnlyExtensionsLib']
```

#### 3.2.2 Source Integration Options

Alternatively, you can integrate the SDK by source if you want to do modifications or want a different feature set. The following entry will integrate the SDK:

```ruby
pod "HockeySDK-Source"
```

<a id="carthage"></a>
### 3.3 Carthage

[Carthage](https://github.com/Carthage/Carthage) is an alternative way to add frameworks to your app. For general information about how to use Carthage, please follow their [documentation](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

To add HockeySDK to your project, simply put this line into your `Cartfile`:

`github "bitstadium/HockeySDK-iOS"`

and then follow the steps described in the [Carthage documentation](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos).

This will integrate the **full-featured SDK** so you must include the `NSPhotoLibraryUsageDescription` and read the [feedback section](#feedback). If you want to include any other version of the SDK, version 4.1.4 added the ability to do that. You need to specify the configuration that you want to use

#### Version without Feedback

`carthage build --platform iOS --configuration ReleaseDefault HockeySDK-iOS`

#### Crash-only version

`carthage build --platform iOS --configuration ReleaseCrashOnly HockeySDK-iOS`

### Crash-only extension

`carthage build --platform iOS --configuration ReleaseCrashOnlyExtension HockeySDK-iOS`

<a id="extensions"></a>
### 3.4 iOS Extensions

The following points need to be considered to use the HockeySDK SDK with iOS Extensions:

1. Each extension is required to use the same values for version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) as the main app uses. (This is required only if you are using the same `APP_IDENTIFIER` for your app and extensions).
2. You need to make sure the SDK setup code is only invoked **once**. Since there is no `applicationDidFinishLaunching:` equivalent and `viewDidLoad` can run multiple times, you need to use a setup like the following example:

**Objective-C**

  ```objc
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

  **Swift**

  ```swift
  class TodayViewController: UIViewController, NCWidgetProviding {

    static var didSetupHockeySDK = false;

    override func viewDidLoad() {
      super.viewDidLoad()
      if !TodayViewController.didSetupHockeySDK {
        BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
        BITHockeyManager.shared().start()
        TodayViewController.didSetupHockeySDK = true
      }
    }
  }
  ```

3. The binary distribution provides a special framework build in the `HockeySDKCrashOnly` or `HockeySDKCrashOnlyExtension` folder of the distribution zip file, which only contains crash reporting functionality (also automatic sending crash reports only).

<a id="watchkit"></a>
### 3.5 WatchKit 1 Extensions

The following points need to be considered to use HockeySDK with WatchKit 1 Extensions:

1. WatchKit extensions don't use regular `UIViewControllers` but rather `WKInterfaceController` subclasses. These have a different lifecycle than you might be used to.

  To make sure that the HockeySDK is only instantiated once in the WatchKit extension's lifecycle we recommend using a helper class similar to this:

  **Objective-C**

  ```objc
  @import Foundation;
  
  @interface BITWatchSDKSetup : NSObject
  
  * (void)setupHockeySDKIfNeeded;
  
  @end
  ```

  ```objc
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

  **Swift**

  ```swift
  import HockeySDK

  class BITWatchSDKSetup {

    static var hockeySDKIsSetup = false;

    static func setupHockeySDKIfNeeded() {
      if !BITWatchSDKSetup.hockeySDKIsSetup {
        BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
        BITHockeyManager.shared().start()
        BITWatchSDKSetup.hockeySDKIsSetup = true;
      }
    }
  }
  ```


  Then, in each of your WKInterfaceControllers where you want to use the HockeySDK, you should do this:

  **Objective-C**

  ```objc
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

  **Swift**

  ```swift
  class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
      super.awake(withContext: context)
      BITWatchSDKSetup.setupHockeySDKIfNeeded()
    }

    override func willActivate() {
      super.willActivate()
    }

    override func didDeactivate() {
      super.didDeactivate()
    }

  }
  ```
2. The binary distribution provides a special framework build in the `HockeySDKCrashOnly` or `HockeySDKCrashOnlyExtension` folder of the distribution zip file, which only contains crash reporting functionality (also automatic sending crash reports only).

<a name="crashreporting"></a>
### 3.6 Crash Reporting

The following options only show some of the possibilities to interact and fine-tune the crash reporting feature. For more please check the full documentation of the `BITCrashManager` class in our [documentation](#documentation).

#### 3.6.1 Disable Crash Reporting
The HockeySDK enables crash reporting **per default**. Crashes will be immediately sent to the server the next time the app is launched.

To provide you with the best crash reporting, we are using a build of [PLCrashReporter]("https://github.com/plausiblelabs/plcrashreporter") based on [Version 1.2.1 / Commit 356901d7f3ca3d46fbc8640f469304e2b755e461]("https://github.com/plausiblelabs/plcrashreporter/commit/356901d7f3ca3d46fbc8640f469304e2b755e461").

This feature can be disabled as follows:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableCrashManager: YES]; //disable crash reporting

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().isCrashManagerDisabled = true
BITHockeyManager.shared().start()
```
#### 3.6.2 Auto send crash reports

Crashes are send the next time the app starts. If `crashManagerStatus` is set to `BITCrashManagerStatusAutoSend`, crashes will be send without any user interaction, otherwise an alert will appear allowing the users to decide whether they want to send the report or not.

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager].crashManager setCrashManagerStatus: BITCrashManagerStatusAutoSend];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().crashManager.crashManagerStatus = BITCrashManagerStatus.autoSend
BITHockeyManager.shared().start()
```

The SDK is not sending the reports right when the crash happens deliberately, because if is not safe to implement such a mechanism while being async-safe (any Objective-C code is _NOT_ async-safe!) and not causing more danger like a deadlock of the device, than helping. We found that users do start the app again because most don't know what happened, and you will get by far most of the reports.

Sending the reports on start-up is done asynchronously (non-blocking). This is the only safe way to ensure that the app won't be possibly killed by the iOS watchdog process, because start-up could take too long and the app could not react to any user input when network conditions are bad or connectivity might be very slow.

#### 3.6.3 Mach Exception Handling

By default the SDK is using the safe and proven in-process BSD Signals for catching crashes. This option provides an option to enable catching fatal signals via a Mach exception server instead.

We strongly advise _NOT_ to enable Mach exception handler in release versions of your apps!

*Warning:* The Mach exception handler executes in-process, and will interfere with debuggers when they attempt to suspend all active threads (which will include the Mach exception handler). Mach-based handling should _NOT_ be used when a debugger is attached. The SDK will not enable catching exceptions if the app is started with the debugger running. If you attach the debugger during runtime, this may cause issues the Mach exception handler is enabled!

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager].crashManager setEnableMachExceptionHandler: YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().crashManager.isMachExceptionHandlerEnabled = true
BITHockeyManager.shared().start()
```

#### 3.6.4 Attach additional data

The `BITHockeyManagerDelegate` protocol provides methods to add additional data to a crash report:

1. UserID:

**Objective-C**

`- (NSString *)userIDForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userID(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

2. UserName:

**Objective-C**

`- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userName(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

3. UserEmail:

**Objective-C**

`- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;`

**Swift**

`optional public func userEmail(for hockeyManager: BITHockeyManager!, componentManager: BITHockeyBaseManager!) -> String!`

The `BITCrashManagerDelegate` protocol (which is automatically included in `BITHockeyManagerDelegate`) provides methods to add more crash specific data to a crash report:

1. Text attachments: 

**Objective-C**

`-(NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager`

**Swift**

`optional public func applicationLog(for crashManager: BITCrashManager!) -> String!`

  Check the following tutorial for an example on how to add CocoaLumberjack log data: [How to Add Application Specific Log Data on iOS or OS X](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-add-application-specific-log-data-on-ios-or-os-x)
2. Binary attachments: 

**Objective-C**

`-(BITHockeyAttachment *)attachmentForCrashManager:(BITCrashManager *)crashManager`

**Swift**

`optional public func attachment(for crashManager: BITCrashManager!) -> BITHockeyAttachment!`

Make sure to implement the protocol

**Objective-C**

```objc
@interface YourAppDelegate () <BITHockeyManagerDelegate> {}

@end
```

**Swift**

```swift
class YourAppDelegate: BITHockeyManagerDelegate {

}
```

and set the delegate:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDelegate: self];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().delegate = self
BITHockeyManager.shared().start()
```

<a name="user-metrics"></a>
### 3.7 User Metrics

HockeyApp automatically provides you with nice, intelligible, and informative metrics about how your app is used and by whom. 

- **Sessions**: A new session is tracked by the SDK whenever the containing app is restarted (this refers to a 'cold start', i.e., when the app has not already been in memory prior to being launched) or whenever it becomes active again after having been in the background for 20 seconds or more.
- **Users**: The SDK anonymously tracks the users of your app by creating a random UUID that is then securely stored in the iOS keychain. This anonymous ID is stored in the keychain, as of iOS 10, it no longer persists across re-installations.
- **Custom Events**: With HockeySDK 4.1.0 and later, you can now track Custom Events in your app, understand user actions and see the aggregates on the HockeyApp portal.
- **Batching & offline behavior**: The SDK batches up to 50 events or waits for 15s and then persist and send the events, whichever comes first. So for sessions, this might actually mean we send 1 single event per batch. If you are sending Custom Events, it can be 1 session event plus X of your Custom Events (up to 50 events per batch total). In case the device is offline, up to 300 events are stored until the SDK starts to drop new events.

Just in case you want to opt-out of the automatic collection of anonymous users and sessions statistics, there is a way to turn this functionality off at any time:

**Objective-C**

```objc
[BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;
```

**Swift**

```swift
BITHockeyManager.shared().isMetricsManagerDisabled = true
```

#### 3.7.1 Custom Events

By tracking custom events, you can now get insight into how your customers use your app, understand their behavior and answer important business or user experience questions while improving your app.

- Before starting to track events, ask yourself the questions that you want to get answers to. For instance, you might be interested in business, performance/quality or user experience aspects.
- Name your events in a meaningful way and keep in mind that you will use these names when searching for events in the HockeyApp web portal. It is your responsibility to not collect personal information as part of the events tracking.

**Objective-C**

```objc
BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;

[metricsManager trackEventWithName:eventName]
```

**Swift**

```swift
let metricsManager = BITHockeyManager.shared().metricsManager

metricsManager.trackEvent(withName: eventName)
```

**Limitations**

- Accepted characters for tracking events are: [a-zA-Z0-9_. -]. If you use other than the accepted characters, your events will not show up in the HockeyApp web portal.
- There is currently a limit of 300 unique event names per app per week.
- There is _no_ limit on the number of times an event can happen.

#### 3.7.2 Attaching custom properties and measurements to a custom event

It's possible to attach properties and/or measurements to a custom event. There is one limitation to attaching properties and measurements. They currently don't show up in the HockeyApp dashboard but you have to link your app to Application Insights to be able to query them. Please have a look at [our blog post](https://www.hockeyapp.net/blog/2016/08/30/custom-events-public-preview.html) to find out how to do that. 

- Properties have to be a string.
- Measurements have to be of a numeric type.

**Objective-C**

```objc
BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;

NSDictionary *myProperties = @{@"Property 1" : @"Something",
                               @"Property 2" : @"Other thing",
                               @"Property 3" : @"Totally different thing"};
NSDictionary *myMeasurements = @{@"Measurement 1" : @1,
                                 @"Measurement 2" : @2.34,
                                 @"Measurement 3" : @2000000};

[metricsManager trackEventWithName:eventName properties:myProperties measurements:myMeasurements]
```

**Swift**

```swift
let myProperties = ["Property 1": "Something", "Property 2": "Other thing", "Property 3" : "Totally different thing."]
let myMeasurements = ["Measurement 1": 1, "Measurement 2": 2.3, "Measurement 3" : 30000]
      
let metricsManager = BITHockeyManager.shared().metricsManager
metricsManager.trackEvent(withName: eventName, properties: myProperties, measurements: myMeasurements)
```

<a name="feedback"></a>
### 3.8 Feedback

As of HockeySDK 4.1.1, Feedback is no longer part of the default SDK. To use feedback in your app, integrate the SDK with all features as follows:

#### 3.8.1 Integrate the full-featured SDK.

If you're integrating the binary yourself, use the `HockeySDK.embeddedframework` in the subfolder `HockeySDKAllFeatures`. If you're using CocoaPods, use

```ruby
pod "HockeySDK", :subspecs => ['AllFeaturesLib']
```

in your podfile.

`BITFeedbackManager` lets your users communicate directly with you via the app and an integrated user interface. It provides a single threaded discussion with a user running your app. This feature is only enabled if you integrate the actual view controllers into your app.
 
You should never create your own instance of `BITFeedbackManager` but use the one provided by the `[BITHockeyManager sharedHockeyManager]`:

**Objective-C**

```objc
[BITHockeyManager sharedHockeyManager].feedbackManager
```

**Swift**

```swift
BITHockeyManager.shared().feedbackManager
```

Please check the [documentation](#documentation) of the `BITFeedbackManager` and `BITFeedbackManagerDelegate` classes on more information on how to leverage this feature.

#### 3.8.2 Add the NSPhotoLibraryUsageDescription to your Info.plist.

As of iOS 10, developers have to add UsageDescription-strings before using system frameworks with privacy features (read more on this in [Apple's own documentation](https://developer.apple.com/library/prerelease/content/releasenotes/General/WhatsNewIniOS/Articles/iOS10.html#//apple_ref/doc/uid/TP40017084-SW3)). To make allow users to attach photos to feedback, add the `NSPhotoLibraryUsageDescription` to your `Info.plist` and provide a description. Make sure to localize your description as described in [Apple's documentation about localizing Info.plist strings](https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html).

If the value is missing from your `Info.plist`, the SDK will disable attaching photos to feedback and disable the creation of a new feedback item in case of a screenshot. 


<a name="storeupdates"></a>
### 3.9 Store Updates

This is the HockeySDK module for handling app updates when having your app released in the App Store.

When an update is detected, this module will show an alert asking the user if he/she wants to update or ignore this version. If the update was chosen, it will open the apps page in the app store app.

By default this module is **NOT** enabled! To enable it use the following code:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setEnableStoreUpdateManager: YES];

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().isStoreUpdateManagerEnabled = true
BITHockeyManager.shared().start()
```

When this module is enabled and **NOT** running in an App Store build/environment, it won't do any checks!

Please check the [documentation](#documentation) of the `BITStoreUpdateManager` class on more information on how to leverage this feature and know about its limits.

<a name="betaupdates"></a>
### 3.10 In-App-Updates (Beta & Enterprise only)

The following options only show some of the possibilities to interact and fine-tune the update feature when using Ad-Hoc or Enterprise provisioning profiles. For more please check the full documentation of the `BITUpdateManager` class in our [documentation](#documentation).

The feature handles version updates, presents the update and version information in a App Store like user interface, collects usage information and provides additional authorization options when using Ad-Hoc provisioning profiles.

This module automatically disables itself when running in an App Store build by default!

This feature can be disabled manually as follows:

**Objective-C**

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[[BITHockeyManager sharedHockeyManager] setDisableUpdateManager: YES]; //disable auto updating

[[BITHockeyManager sharedHockeyManager] startManager];
```

**Swift**

```swift
BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
BITHockeyManager.shared().isUpdateManagerDisabled = true
BITHockeyManager.shared().start()
```

Please note that the SDK expects your CFBundleVersion values to always increase and never reset to detect a new update.

If you want to see beta analytics, use the beta distribution feature with in-app updates, restrict versions to specific users, or want to know who is actually testing your app, you need to follow the instructions on our guide [Authenticating Users on iOS](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/authenticating-users-on-ios)

<a id="debug"></a>
### 3.11 Debug information

To check if data is send properly to HockeyApp and also see some additional SDK debug log data in the console, add the following line before `startManager`:

```objc
[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];

[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;

[[BITHockeyManager sharedHockeyManager] startManager];
```

<a id="documentation"></a>
## 4. Documentation

Our documentation can be found on [HockeyApp](http://hockeyapp.net/help/sdk/ios/5.0.0/index.html).

<a id="troubleshooting"></a>
## 5.Troubleshooting

### Linker warnings

  Make sure that all mentioned frameworks and libraries are linked

### iTunes Connect rejection

  Make sure none of the following files are copied into your app bundle, check under app target, `Build Phases`, `Copy Bundle Resources` or in the `.app` bundle after building:

  - `HockeySDK.framework` (except if you build a dynamic framework version of the SDK yourself!)
  - `de.bitstadium.HockeySDK-iOS-5.0.0.docset`

### Features are not working as expected

  Enable debug output to the console to see additional information from the SDK initializing the modules,  sending and receiving network requests and more by adding the following code before calling `startManager`:

  `[BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelDebug;`

### Wrong strings or "Missing HockeySDKResources.bundle" error

1. Please check if the `HockeySDKResources.bundle` is added to your app bundle. Use Finder to inspect your `.app` bundle to see if the bundle is added.
    
2. If it is missing, please check if the resources bundle is mentioned in your app target's `Copy Bundle Resources` build step in the `Build Phases` tab. Add the resource bundle manually if necessary.  

3. Make a clean build and try again.
    
![Screenshot_2015-12-22_01.07.27.png](https://support.hockeyapp.net/help/assets/0e9d2eb58de8355363b89bd491d6fcf4c14f596e/normal/Screenshot_2015-12-22_01.07.27.png)
    
<a id="contributing"></a>
## 6. Contributing

We're looking forward to your contributions via pull requests on our [GitHub repository](https://github.com/bitstadium/HockeySDK-iOS).

<a id="developmentenvironment"></a>
### 6.1 Development environment

* A Mac running the latest version of macOS.
* Get the latest Xcode from the Mac App Store.
* [Jazzy](https://github.com/realm/jazzy) to generate documentation.
* [CocoaPods](https://cocoapods.org/) to test integration with CocoaPods.
* [Carthage](https://github.com/Carthage/Carthage) to test integration with Carthage.

<a id="codeofconduct"></a>
### 6.2 Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

<a id="contributorlicense"></a>
### 6.3 Contributor License

You must sign a [Contributor License Agreement](https://cla.microsoft.com/) before submitting your pull request. To complete the Contributor License Agreement (CLA), you will need to submit a request via the [form](https://cla.microsoft.com/) and then electronically sign the CLA when you receive the email containing the link to the document. You need to sign the CLA only once to cover submission to any Microsoft OSS project. 

<a id="contact"></a>
## 7. Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps here, feel free to open [a GitHub issue](https://github.com/bitstadium/HockeySDK-iOS/issues), contact us at [support@hockeyapp.net](mailto:support@hockeyapp.net) or join our [Slack](https://slack.hockeyapp.net).
