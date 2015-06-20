## Introduction

HockeySDK-iOS implements support for using HockeyApp in your iOS applications.

The following features are currently supported:

1. **Update apps:** The app will check with HockeyApp if a new version is available. If yes, it will show an alert view to the user and let him see the release notes, the version history and start the installation process right away. 

2. **Collect crash reports:** If you app crashes, a crash log with the same format as from the Apple Crash Reporter is written to the device's storage. If the user starts the app again, he is asked to submit the crash report to HockeyApp. This works for both beta and live apps, i.e. those submitted to the App Store!

3. **Feedback:** Collect feedback from your users from within your app and communicate directly with them using the HockeyApp backend.

The main SDK class is `BITHockeyManager`. It initializes all modules and provides access to them, so they can be further adjusted if required. Additionally all modules provide their own protocols.

## Prerequisites

1. Before you integrate HockeySDK into your own app, you should add the app to HockeyApp if you haven't already. Read [this how-to](http://support.hockeyapp.net/kb/how-tos/how-to-create-a-new-app) on how to do it.
2. We also assume that you already have a project in Xcode and that this project is opened in Xcode 6.
3. The SDK supports iOS 6.0 or newer.

## Release Notes

- [Changelog](Changelog)

## Guides

- [Installation & Setup](Guide-Installation-Setup)
- [Migration from previous SDK Versions](Guide-Migration-Kits)
- [Mac Desktop Uploader](http://support.hockeyapp.net/kb/services-webhooks-desktop-apps/how-to-upload-to-hockeyapp-on-a-mac)

## HowTos

- [How to do app versioning](HowTo-App-Versioning)
- [How to upload symbols for crash reporting](HowTo-Upload-Symbols)
- [How to handle crashes on startup](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-handle-crashes-during-startup-on-ios)
- [How to add application specific log data](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-add-application-specific-log-data-on-ios-or-osx)
- [How to ask the user for more details about a crash](HowTo-Set-Custom-AlertViewHandler)

## Troubleshooting

- [Symbolication doesn't work](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-solve-symbolication-problems) (Or the rules of binary UUIDs and dSYMs)
- [Crash Reporting is not working](Troubleshooting-Crash-Reporting-Not-Working)

## Xcode Documentation

This documentation provides integrated help in Xcode for all public APIs and a set of additional tutorials and HowTos.

1. Download the [HockeySDK-iOS documentation](http://hockeyapp.net/releases/).

2. Unzip the file. A new folder `HockeySDK-iOS-documentation` is created.

3. Copy the content into ~`/Library/Developer/Shared/Documentation/DocSet`
