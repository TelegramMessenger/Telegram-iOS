This document describes how to integrate the HockeyApp SDK into your app. The SDK has two main features:

1. **Update apps:** The app will check with HockeyApp if a new version is available. If yes, it will show an alert view to the user and let him see the release notes, the version history and start the installation process right away. 

2. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

## Prerequisites

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.

2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 4.

## Versioning

We suggest to handle beta and release versions in two separate *apps* on HockeyApp with their own bundle identifier (e.g. by adding "beta" to the bundle identifier), so

* both apps can run on the same device or computer at the same time without interfering,

* release versions do not appear on the beta download pages, and

* easier analysis of crash reports and user feedback.

We propose the following method to set version numbers in your beta versions:

* Use both "Bundle Version" and "Bundle Version String, short" in your Info.plist.

* "Bundle Version" should contain a sequential build number, e.g. 1, 2, 3.

* "Bundle Version String, short" should contain the target official version number, e.g. 1.0.

## Download & Extract

1. Download the latest [HockeySDK](https://github.com/codenauts/HockeySDK-iOS/downloads).

2. Unzip the file. A new folder HockeySDK-iOS is created.

3. Move the folder into your project directory. We usually put 3rd-party code into a subdirectory named "Vendor", so we move the directory into it.

## Integrate into Xcode

Drag & drop the HockeySDK folder from your project directory to your Xcode project. Similar to above, our projects have a group "Vendor", so we drop it there. Select "Create groups for any added folders" and set the checkmark for your target. Then click "Finish".

## Add Frameworks

1. Select your project in the Project Navigator.

2. Select your target.

3. Select the tab "Build Phases".

4. Expand "Link Binary With Libraries".

5. You need all of the following frameworks:

    * CoreGraphics.framework
    * CrashReporter.framework
    * Foundation.framework
    * QuartzCore.framework
    * SystemConfiguration.framework
    * UIKit.framework

6. If one of the frameworks is missing, then click the + button, search the framework and confirm with the "Add" button.

7. HockeySDK also needs a JSON library. If you target iOS 5, you can use the built-in NSJSONSerialization classes. If your deployment target is iOS 3.x or 4.x, please include one of the following libraries:

	* https://github.com/johnezang/JSONKit
	* https://github.com/stig/json-framework

## Modify Source Code

1. Open your AppDelegate.m file.

2. Add the following line at the top of the file below your own #import statements:<pre><code>#import "CNSHockeyManager.h"</code></pre>

3. Search for the method application:didFinishLaunchingWithOptions:

4. Add the following lines:<pre><code>[[CNSHockeyManager sharedHockeyManager] configureWithBetaIdentifier:@"BETA_IDENTIFIER" 
                                                         liveIdentifier:@"LIVE_IDENTIFIER"
                                                               delegate:nil];</code></pre>
    
5. Replace BETA_IDENTIFIER with the app identifier of your beta app. If you don't know what the app identifier is or how to find it, please read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-find-the-app-identifier). 

6. Replace LIVE_IDENTIFIER with the app identifier of your release app.

7. If you have added the lines to the method application:didFinishLaunchingWithOptions:, you should be ready to go. If you do some GCD magic or added the lines at a different place, please make sure to invoke the above code on the main thread. 

## Optional Delegate Methods

Besides the crash log, HockeyApp can show you fields with information about the user and an optional description. You can fill out these fields by implementing the following methods:

* **crashReportUserID** should be a user ID or email, e.g. if your app requires to sign in into your server, you could specify the login here. The string should be no longer than 255 chars. You can also set autoSubmitDeviceUDID to YES, then crashReportUserID will be automatically set to the device's UDID. 

* **crashReportContact** should be the user's name or similar. The string should be no longer than 255 chars.

* **crashReportDescription** can be as long as you want it to be and contain additional information about the 
crash. For example, you can return a custom log or the last XML or JSON response from your server here.

If you implement these delegate methods and keep them in your live app too, please consider the privacy implications.

## Upload the .dSYM File

Once you have your app ready for beta testing or even to submit it to the App Store, you need to upload the .dSYM bundle to HockeyApp to enable symbolication. If you have built your app with Xcode4, menu Product > Archive, you can find the .dSYM as follows:

1. Chose Window > Organizer in Xcode.

2. Select the tab Archives.

3. Select your app in the left sidebar.

4. Right-click on the latest archive and select Show in Finder.

5. Right-click the .xcarchive in Finder and select Show Package Contents. 

6. You should see a folder named dSYMs which contains your dSYM bundle. If you use Safari, just drag this file from Finder and drop it on to the corresponding drop zone in HockeyApp. If you use another browser, copy the file to a different location, then right-click it and choose Compress "YourApp.dSYM". The file will be compressed as a .zip file. Drag & drop this file to HockeyApp. 

As an alternative for step 5 and 6, you can use our [HockeyMac](https://github.com/codenauts/HockeyMac) app to upload the complete archive in one step.

## Checklist if Crashes Do Not Appear in HockeyApp

1. Check if the BETA_IDENTIFIER or LIVE_IDENTIFIER matches the App ID in HockeyApp.

2. Check if CFBundleIdentifier in your Info.plist matches the Bundle Identifier of the app in HockeyApp. HockeyApp accepts crashes only if both the App ID and the Bundle Identifier equal their corresponding values in your plist and source code.

3. Unless you have set autoSubmitCrashReport to YES: If your app crashes and you start it again, is the alert shown which asks the user to send the crash report? If not, please crash your app again, then connect the debugger and set a break point in BWQuincyManager.m, method [startManager](https://github.com/codenauts/HockeySDK-iOS/blob/develop/Classes/BWQuincyManager.m#L251) to see why the alert is not shown.

4. If it still does not work, please [contact us](http://support.hockeyapp.net/discussion/new).
