## Version 3.6.4

- [Changelog](http://www.hockeyapp.net/help/sdk/ios/3.6.4/docs/docs/Changelog.html)

## Introduction

This article describes how to integrate HockeyApp into your iOS apps. The SDK allows testers to update your app to another beta version right from within the application. It will notify the tester if a new update is available. The SDK also allows to send crash reports. If a crash has happened, it will ask the tester on the next start whether he wants to send information about the crash to the server.

This document contains the following sections:

- [Requirements](#requirements)
- [Download & Extract](#download)
- [Set up Xcode](#xcode) 
- [Modify Code](#modify)
- [iOS 8 Extensions](#extension)
- [Additional Options](#options)

<a id="requirements"></a> 
## Requirements

The SDK runs on devices with iOS 6.0 or higher.

<a id="download"></a> 
## Download & Extract

1. Download the latest [HockeySDK-iOS](http://www.hockeyapp.net/releases/) framework.

2. Unzip the file. A new folder `HockeySDK-iOS` is created.

3. Move the folder into your project directory. We usually put 3rd-party code into a subdirectory named `Vendor`, so we move the directory into it.

<a id="xcode"></a> 
## Set up Xcode

1. Drag & drop `HockeySDK.embeddedframework` from your project directory to your Xcode project.

2. Similar to above, our projects have a group `Vendor`, so we drop it there.

3. Select `Create groups for any added folders` and set the checkmark for your target. Then click `Finish`.

    <img src="XcodeCreateGroups_normal.png"/>

4. Select your project in the `Project Navigator` (⌘+1).

5. Select your app target.

6. Select the tab `Build Phases`.

7. Expand `Link Binary With Libraries`.

8. Add the following system frameworks, if they are missing:
    - `AssetsLibrary`
    - `CoreText`
    - `CoreGraphics`
    - `Foundation`
    - `MobileCoreServices`
    - `QuartzCore`
    - `QuickLook`
    - `Security`
    - `SystemConfiguration`
    - `UIKit`

<a id="modify"></a> 
## Modify Code 

### Objective-C

1. Open your `AppDelegate.m` file.

2. Add the following line at the top of the file below your own #import statements:

        #import <HockeySDK/HockeySDK.h>

3. Search for the method `application:didFinishLaunchingWithOptions:`

4. Add the following lines:

        [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
        [[BITHockeyManager sharedHockeyManager] startManager];
        [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

5. Continue with [General subsection](#generalcode)

### Swift

1. Open your `AppDelegate.swift` file.

2. Add the following line at the top of the file below your own #import statements:

        import HockeySDK

3. Search for the method `application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool`

4. Add the following lines:

        BITHockeyManager.sharedHockeyManager().configureWithIdentifier("APP_IDENTIFIER");
        BITHockeyManager.sharedHockeyManager().startManager();
        BITHockeyManager.sharedHockeyManager().authenticator.authenticateInstallation();

5. Continue with [General subsection](#generalcode)

<a id="generalcode"></a>
### General

1. Replace `APP_IDENTIFIER` with the app identifier of your app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

2. If you want to see beta analytics, use the beta distribution feature with in-app updates, restrict versions to specific users, or want to know who is actually testing your app, you need to follow the instructions on our guide [Identify and authenticate users of Ad-Hoc or Enterprise builds](HowTo-Authenticating-Users-on-iOS)

*Note:* The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.

<a id="extensions"></a>
## iOS 8 Extensions

The following points need to be considered to use HockeySDK with iOS 8 Extensions:

1. Each extension is required to use the same values for version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) as the main app uses. (This is required only if you are using the same APP_IDENTIFIER for your app and extensions).
2. You need to make sure the SDK setup code is only invoked once. Since there is no `applicationDidFinishLaunching:` equivalent and `viewDidLoad` can run multiple times, you need to use a setup like the following example:

        @interface TodayViewController () <NCWidgetProviding>

        @property (nonatomic, assign) BOOL didSetupHockeySDK;

        @end

        @implementation TodayViewController

        - (void)viewDidLoad {
          [super viewDidLoad];
          if (!self.didSetupHockeySDK) {
            [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER"];
            [[BITHockeyManager sharedHockeyManager] startManager];
            self.didSetupHockeySDK = YES;
          }
        }
3. The binary distribution provides a special framework build in the `HockeySDKCrashOnly` folder of the distribution zip file, which only contains crash reporting functionality (also automatic sending crash reports only). You can use this to further slim down the binary size of your extensions. 


<a id="options"></a> 
## Additional Options

### Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and how-tos.

1. Copy `de.bitstadium.HockeySDK-iOS-3.6.4.docset` into ~`/Library/Developer/Shared/Documentation/DocSets`

The documentation is also available via the following URL: [http://hockeyapp.net/help/sdk/ios/3.6.4/](http://hockeyapp.net/help/sdk/ios/3.6.4/)

### Set up with xcconfig

Instead of manually adding the missing frameworks, you can also use our bundled xcconfig file.

1. Select your project in the `Project Navigator` (⌘+1).

2. Select your project.

3. Select the tab `Info`.

4. Expand `Configurations`.

5. Select `HockeySDK.xcconfig` for all your configurations (if you don't already use a `.xcconfig` file)
    
    <img src="XcodeFrameworks1_normal.png"/>
    
    **Note:** You can also add the required frameworks manually to your targets `Build Phases` and continue with step `7.` instead.

6. If you are already using a `.xcconfig` file, simply add the following line to it

    `#include "../Vendor/HockeySDK/Support/HockeySDK.xcconfig"`
    
    (Adjust the path depending where the `Project.xcconfig` file is located related to the Xcode project package)
    
    **Important note:** Check if you overwrite any of the build settings and add a missing `$(inherited)` entry on the projects build settings level, so the `HockeySDK.xcconfig` settings will be passed through successfully.

7. If you are getting build warnings, then the `.xcconfig` setting wasn't included successfully or its settings in `Other Linker Flags` get ignored because `$(inherited)` is missing on project or target level. Either add `$(inherited)` or link the following frameworks manually in `Link Binary With Libraries` under `Build Phases`:
    - `AssetsLibrary`
    - `CoreText`
    - `CoreGraphics`
    - `Foundation`
    - `MobileCoreServices`
    - `QuartzCore`
    - `QuickLook`
    - `Security`
    - `SystemConfiguration`
    - `UIKit`
