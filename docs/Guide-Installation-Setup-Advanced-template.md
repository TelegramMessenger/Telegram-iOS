
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

The SDK runs on devices with iOS 4.0 or higher.

If you need support for iOS 3.x, please check out [HockeyKit](http://support.hockeyapp.net/kb/client-integration/beta-distribution-on-ios-hockeykit) and [QuincyKit](http://support.hockeyapp.net/kb/client-integration/crash-reporting-on-ios-quincykit)

<a id="download"></a> 
## Set up Git submodule

1. Open a Terminal window

2. Change to your projects directory `cd /path/to/MyProject'

3. If this is a new project, initialize Git: `git init`

4. Add the submodule: `git submodule add git://github.com/BitStadium/HockeySDK-iOS.git Vendor/HockeySDK`. This would add the submodule into the `Vendor/HockeySDK` subfolder. Change this to the folder you prefer.

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

    <img src="XcodeFrameworks3_normal.png"/>
    
9. Select `CrashReporter.framework` from the `Vendor/HockeySDK/Vendor` folder

    <img src="XcodeFrameworks4_normal.png"/>

10. The following entries should be present:
	* `libHockeySDK.a`
	* `CrashReporter.framework`
	* `CoreGraphics.framework`
    * `Foundation.framework`
    * `QuartzCore.framework`
    * `SystemConfiguration.framework`
    * `UIKit.framework`

    <img src="XcodeFrameworks2_normal.png"/>

11. Expand `Copy Bundle Resources`.

12. Drag & Drop `HockeySDKResources.bundle` from the `Products` folder in `HockeySDK.xcodeproj`

    <img src="XcodeBundleResource1_normal.png"/>

13. Select `Build Settings`

14. Search for `Header Search Paths`

15. Add a path to `$(SRCROOT)/Vendor/HockeySDK/Vendor` and make sure that the list does not contain a path pointing to the `QuincyKit` SDK or another framework that contains `PLCrashReporter`

    <img src="XcodeFrameworkSearchPath_normal.png"/>

16. Hit `Done`.

17. HockeySDK-iOS also needs a JSON library. If your deployment target iOS 5.0 or later, then you don't have to do anything. If your deployment target is iOS 4.x, please include one of the following libraries:
	* [JSONKit](https://github.com/johnezang/JSONKit)
	* [SBJSON](https://github.com/stig/json-framework)
	* [YAJL](https://github.com/gabriel/yajl-objc)
	
<a id="modify"></a> 
## Modify Code

1. Open your `AppDelegate.m` file.

2. Add the following line at the top of the file below your own #import statements:

        #import "HockeySDK.h"

3. Let the AppDelegate implement the protocols `BITHockeyManagerDelegate`, `BITUpdateManagerDelegate` and `BITCrashManagerDelegate`:

        @interface AppDelegate() <BITHockeyManagerDelegate, BITUpdateManagerDelegate, BITCrashManagerDelegate> {}
        @end

4. Search for the method `application:didFinishLaunchingWithOptions:`

5. Add the following lines:

        [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:@"BETA_IDENTIFIER"
                                                             liveIdentifier:@"LIVE_IDENTIFIER"
                                                                   delegate:self];
        [[BITHockeyManager sharedHockeyManager] startManager];

6. Replace `BETA_IDENTIFIER` with the app identifier of your beta app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

7. Replace `LIVE_IDENTIFIER` with the app identifier of your release app.

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
  
The method only returns the UDID when the build is not targeted to the App Sore. This assumes that a preprocessor macro name CONFIGURATION_AppStore exists and is set for App Store builds. You can define the macro as follows:

1. Select your project in the `Project Navigator` (⌘+1).

2. Select your target.

3. Select the tab `Build Settings`.

4. Search for `preprocessor macros`

    ![XcodeMacros1_normal.png](XcodeMacros1_normal.png)

5. Select the top-most line and double-click the value field.

6. Click the + button.

7. Enter the following string into the input field and finish with "Done".<pre><code>CONFIGURATION_$(CONFIGURATION)</code></pre>

    ![XcodeMacros2_normal.png](XcodeMacros2_normal.png)

Now you can use `#if defined (CONFIGURATION_AppStore)` statements in your code. If your configurations have different names, please adjust the above use of `CONFIGURATION_AppStore`.

<a id="mac"></a> 
## Mac Desktop Uploader

The Mac Desktop Uploader can provide easy uploading of your app versions to HockeyApp. Check out the [installation tutorial](Guide-Installation-Mac-App).

<a id="documentation"></a> 
## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTos.

1. Download the latest [HockeySDK-iOS documentation](https://github.com/bitstadium/HockeySDK-iOS/downloads).

2. Unzip the file. A new folder `HockeySDK-iOS-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSet`
