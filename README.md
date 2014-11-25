## Version 3.6.2

- [Changelog](http://www.hockeyapp.net/help/sdk/ios/3.6.2/docs/docs/Changelog.html)


## Introduction

HockeySDK-iOS implements support for using HockeyApp in your iOS applications.

The following features are currently supported:

1. **Collect crash reports:** If your app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

2. **Update Ad-Hoc / Enterprise apps:** The app will check with HockeyApp if a new version for your Ad-Hoc or Enterprise build is available. If yes, it will show an alert view to the user and let him see the release notes, the version history and start the installation process right away. 

3. **Update notification for app store:** The app will check if a new version for your app store release is available. If yes, it will show an alert view to the user and let him open your app in the App Store app. (Disabled by default!)

4. **Feedback:** Collect feedback from your users from within your app and communicate directly with them using the HockeyApp backend.

5. **Authenticate:** Identify and authenticate users of Ad-Hoc or Enterprise builds


The main SDK class is `BITHockeyManager`. It initializes all modules and provides access to them, so they can be further adjusted if required. Additionally all modules provide their own protocols.

## Prerequisites

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.
2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 5.
3. The SDK supports iOS 6.0 or newer.


## Installation & Setup

- [Installation & Setup](http://www.hockeyapp.net/help/sdk/ios/3.6.2/docs/docs/Guide-Installation-Setup.html) (Recommended)
- [Installation & Setup Advanced](http://www.hockeyapp.net/help/sdk/ios/3.6.2/docs/docs/Guide-Installation-Setup-Advanced.html) (Using Git submodule and Xcode sub-project)
- [Identify and authenticate users of Ad-Hoc or Enterprise builds](http://www.hockeyapp.net/help/sdk/ios/3.6.2/docs/docs/HowTo-Authenticating-Users-on-iOS.html)
- [Migration from previous SDK Versions](http://www.hockeyapp.net/help/sdk/ios/3.6.2/docs/docs/Guide-Migration-Kits.html)


## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTo articles.

1. Download the [HockeySDK-iOS documentation](http://hockeyapp.net/releases/).

2. Unzip the file. A new folder `HockeySDK-iOS-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSets`

The documentation is also available via the following URL: [http://hockeyapp.net/help/sdk/ios/3.6.2/](http://hockeyapp.net/help/sdk/ios/3.6.2/)
