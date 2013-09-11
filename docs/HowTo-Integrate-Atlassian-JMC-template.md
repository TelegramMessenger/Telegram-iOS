## Introduction

The SDK provides integrated support to automatically configure the Atlassian JIRA Mobile Connect (JMC). It will take the JIRA configuration that is associated to your app on HockeyApp and use that to configure JMC.

## Requirements

The binary distribution of HockeySDK does not provide this integration. You need to follow the [Installation & Setup Advanced](Guide-Installation-Setup-Advanced) Guide and activate the JMC integration as described below.

## HowTo

1. Select `HockeySDK.xcodeproj` project in the Xcode navigator
2. Select `HockeySDKLib` target
3. Search for `Preprocessor Macros`
4. Double tab in the `HockeySDKLib` column and add the following two values

        $(inherited)
        HOCKEYSDK_FEATURE_JIRA_MOBILE_CONNECT=1

5. Setup JMC as described in the [JMC instructions](https://developer.atlassian.com/display/JMC/Enabling+JIRA+Mobile+Connect)
6. Sign in to HockeyApp
7. Select the app and edit the apps bug tracker
8. Choose `JIRA` or `JIRA5`.
9. Enter your JIRA credentials. Make sure you supply the credentials for a user with admin rights, otherwise HockeyApp cannot fetch the JMC token from JIRA.
10. Download the latest JMC client file: [https://bitbucket.org/atlassian/jiraconnect-ios/downloads](https://bitbucket.org/atlassian/jiraconnect-ios/downloads)
11. Unzip the file and move the folder into your project directory.
12. Drag & drop the JMC folder from your project directory to your Xcode project. Select `Create groups for any added folders` and set the checkmark for your target. Then click `Finish`.
13. The class `BITHockeyManager` automatically fetches the API token and project key for JMC from HockeyApp, so you don't need to adjust the configuration in your AppDelegate.m file. The only thing you need to do is find a place in your UI to open the feedback view, such as a button and table view cell. You can then open the feedback view as follows:

        In SomeViewController.m:

        [self presentModalViewController:[[JMC sharedInstance] viewController] animated:YES];
        
14. You can customize the options of JMC like this:

        In AppDelegate.m:

        [[[JMC sharedInstance] options] setBarStyle:UIBarStyleBlack];
