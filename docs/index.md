Introduction
============

HockeySDK-iOS implements support for using HockeyApp in your iOS applications.

The following features are currently supported:

1. **Update apps:** The app will check with HockeyApp if a new version is available. If yes, it will show an alert view to the user and let him see the release notes, the version history and start the installation process right away. 

2. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

The main SDK class is `BITHockeyManager`. It initializes all modules and provides access to them, so they can be further adjusted if required. Additionally all modules provide their own protocols.

Prerequisites
=============

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.
2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 4.
3. The SDK supports iOS 4.0 or newer.

Guides
======

- [Installation & Setup](Guide-Installation-Setup)
- [Migration from HockeyKit & QuincyKit](Guide-Migration-Kits)

HowTos
======

- [How to do app versioning](HowTo-App-Versioning)
- [How to upload symbols for crash reporting](HowTo-Upload-Symbols)

Troubleshooting
===============

- [Crashes do not appear on HockeyApp](Troubleshooting-Crashes-Dont-Appear)
