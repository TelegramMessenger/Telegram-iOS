## Version 3.0.0

- [Changelog](http://www.hockeyapp.net/help/sdk/ios/3.0.0/docs/docs/Changelog.html)

## Introduction

This article describes how to integrate HockeyApp into your iOS apps using a Git submodule and Xcode subprojects. The SDK allows testers to update your app to another beta version right from within the application. It will notify the tester if a new update is available. The SDK also allows to send crash reports. If a crash has happened, it will ask the tester on the next start whether he wants to send information about the crash to the server.

This document contains the following sections:

- [Requirements](#requirements)
- [Set up Git submodule](#download)
- [Set up Xcode](#xcode)
- [Modify Code](#modify)
- [Submit the UDID](#udid)
- [Mac Desktop Uploader](#mac)
- [Xcode Documentation](#documentation)

<a id="requirements"></a> 
## Requirements

The SDK runs on devices with iOS 5.0 or higher.

If you need support for iOS 4.x, please check out [HockeySDK v2.5.5](http://hockeyapp.net/releases/)

If you need support for iOS 3.x, please check out [HockeyKit](http://support.hockeyapp.net/kb/client-integration/beta-distribution-on-ios-hockeykit) and [QuincyKit](http://support.hockeyapp.net/kb/client-integration/crash-reporting-on-ios-quincykit)

<a id="download"></a> 
## Set up Git submodule

1. Open a Terminal window

2. Change to your projects directory `cd /path/to/MyProject'

3. If this is a new project, initialize Git: `git init`

4. Add the submodule: `git submodule add git://github.com/bitstadium/HockeySDK-iOS.git Vendor/HockeySDK`. This would add the submodule into the `Vendor/HockeySDK` subfolder. Change this to the folder you prefer.

5. Releases are always in the `master` branch while the `develop` branch provides the latest in development source code (Using the git flow branching concept). We recommend using the `master` branch!

<a id="xcode"></a> 
## Set up Xcode

1. Find the `HockeySDK.xcodeproj` file inside of the cloned HockeySDK-iOS project directory.

2. Drag & Drop it into the `Project Navigator` (⌘+1).

3. Select your project in the `Project Navigator` (⌘+1).

4. Select your target. 

5. Select the tab `Build Phases`.

6. Expand `Link Binary With Libraries`.

7. Add `libHockeySDK.a`

    <img src="XcodeLinkBinariesLib_normal.png"/>

8. Select `Add Other...`.

9. Select `CrashReporter.framework` from the `Vendor/HockeySDK/Vendor` folder

    <img src="XcodeFrameworks4_normal.png"/>

10. Expand `Copy Bundle Resource`.

11. Drag `HockeySDKResources.bundle` from the `HockeySDK` sub-projects `Products` folder and drop into the `Copy Bundle Resource` section

12. Select `Build Settings`

13. Add the following `Header Search Path`

    `$(SRCROOT)/Vendor/HockeySDK/Classes`

14. Create a new `Project.xcconfig` file, if you don't already have one (You can give it any name)

    **Note:** You can also add the required frameworks manually to your targets `Build Phases` an continue with step `17.` instead.

    a. Select your project.

    b. Select the tab `Info`.

    c. Expand `Configurations`.

    d. Select `Project.xcconfig` for all your configurations
    
        <img src="XcodeFrameworks1_normal.png"/>

15. Open `Project.xcconfig` in the editor

16. Add the following line:

    `#include "../Vendor/HockeySDK/Support/HockeySDK.xcconfig"`
    
    (Adjust the path depending where the `Project.xcconfig` file is located related to the Xcode project package)
    
    **Important note:** Check if you overwrite any of the build settings and add a missing `$(inherited)` entry on the projects build settings level, so the `HockeySDK.xcconfig` settings will be passed through successfully.
    
17. If you are getting build warnings, then the `.xcconfig` setting wasn't included successfully or its settings in `Other Linker Flags` get ignored because `$(interited)` is missing on project or target level. Either add `$(inherited)` or link the following frameworks manually in `Link Binary With Libraries` under `Build Phases`:
    - `CoreText`
    - `CoreGraphics`
    - `Foundation`
    - `QuartzCore`
    - `Security`  
    - `SystemConfiguration`
    - `UIKit`  


<a id="modify"></a> 
## Modify Code

1. Open your `AppDelegate.m` file.

2. Add the following line at the top of the file below your own #import statements:

        #import "HockeySDK.h"

3. Let the AppDelegate implement the protocols `BITHockeyManagerDelegate`, `BITUpdateManagerDelegate` and `BITCrashManagerDelegate`:

        @interface AppDelegate(HockeyProtocols) <BITHockeyManagerDelegate, BITUpdateManagerDelegate, BITCrashManagerDelegate> {}
        @end

4. Search for the method `application:didFinishLaunchingWithOptions:`

5. Add the following lines:

        [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:@"BETA_IDENTIFIER"
                                                             liveIdentifier:@"LIVE_IDENTIFIER"
                                                                   delegate:self];
        [[BITHockeyManager sharedHockeyManager] startManager];

6. Replace `BETA_IDENTIFIER` with the app identifier of your beta app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

7. Replace `LIVE_IDENTIFIER` with the app identifier of your release app. We suggest to setup different apps on HockeyApp for your test and production builds. You usually will have way more test versions, but your production version usually has way more crash reports. This helps to keep data separated, getting a better overview and less trouble setting the right app versions downloadable for your beta users.

*Note:* The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.

<a id="udid"></a> 
## Submit the UDID

If you only want crash reporting, you can skip this step. If you want to use HockeyApp for beta distribution and analyze which testers have installed your app, you need to implement an additional delegate method in your AppDelegate.m:

    #pragma mark - BITUpdateManagerDelegate
    - (NSString *)customDeviceIdentifierForUpdateManager:(BITUpdateManager *)updateManager {
    #ifndef CONFIGURATION_AppStore
      if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
        return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
    #endif
      return nil;
    }
  
The method only returns the UDID when the build is not targeted to the App Sore. This assumes that a preprocessor macro name CONFIGURATION_AppStore exists and is set for App Store builds. The macros are already defined in `HockeySDK.xcconfig` or can be set manually by setting `GCC_PREPROCESSOR_DEFINITIONS` in your build configurations to `CONFIGURATION_$(CONFIGURATION)`.

<a id="mac"></a> 
## Mac Desktop Uploader

The Mac Desktop Uploader can provide easy uploading of your app versions to HockeyApp. Check out the [installation tutorial](Guide-Installation-Mac-App).

<a id="documentation"></a> 
## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTos.

1. Download the [HockeySDK-iOS documentation](http://hockeyapp.net/releases/).

2. Unzip the file. A new folder `HockeySDK-iOS-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSet`

The documentation is also available via the following URL: [http://hockeyapp.net/help/sdk/ios/3.0.0/](http://hockeyapp.net/help/sdk/ios/3.0.0/)
