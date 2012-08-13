## Introduction

This guide will help you migrate from QuincyKit, HockeyKit or an older version of HockeySDK-iOS to the latest release of the unified HockeySDK for iOS.

First of all we will cleanup the obsolete installation files and then convert your existing code to the new API calls.

## Cleanup

First of all you should remove all files from prior versions of either QuincyKit, HockeyKit or HockeySDK-iOS. If you not sure which files you added, here are a few easy steps for each SDK.

### QuincyKit

In Xcode open the `Project Navigator` (⌘+1). In the search field at the bottom enter "Quincy". Search should find the following files:

* BWQuincyManager.h
* BWQuincyManager.m
* Quincy.bundle

Delete them all ("Move to Trash"). Or if you have them grouped into a folder (for example Vendor/QuincyKit) delete the folder.

### HockeyKit

In Xcode open the `Project Navigator` (⌘+1). In the search field at the bottom enter "Hockey". You should find different files with the string "Hockey" in it, for example:

* BWHockeyManager.h
* Hockey.bundle

All of them should be in one folder/group in Xcode. Remove that folder.

### HockeySDK-iOS

In Xcode open the `Project Navigator` (⌘+1). In the search field at the bottom enter "CNSHockeyManager". If search returns any results you have the first release of our unified SDK added to your project. Even if you added it as a git submodule we would suggest you remove it first. 

### Final Steps

Search again in the `Project Navigator` (⌘+1) for "CrashReporter.framework". You shouldn't get any results now. If not, remove the CrashReporter.framework from your project.

## Installation

Follow the steps in our installation guide for either [Installation with binary framework distribution](http://support.hockeyapp.net/kb/client-integration/hockeyapp-for-ios-hockeysdk#framework) (Recommended) or [Installation as a subproject](http://support.hockeyapp.net/kb/client-integration/hockeyapp-for-ios-hockeysdk#subproject)

After you finished the steps for either of the installation procedures, we have to migrate your existing code.

## Setup

### QuincyKit / HockeyKit

In your application delegate (for example `AppDelegate.m`) search for the following lines:

    [[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"0123456789abcdef"];
    
    [[BWHockeyManager sharedHockeyManager] setAppIdentifier:@"0123456789abcdef"];
    [[BWHockeyManager sharedHockeyManager] setUpdateURL:@"https://rink.hockeyapp.net/"];

If you use (as recommended) different identifiers for beta and store distribution some lines may be wrapped with compiler macros like this:

    #if defined (CONFIGURATION_Beta)
      [[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"BETA_IDENTIFIER"];
    #endif

    #if defined (CONFIGURATION_Distribution)
      [[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"LIVE_IDENTIFIER"];
    #endif

For now comment out all lines with either `[BWQuincyManager sharedQuincyManager]` or `[BWHockeyManager sharedHockeyManager]`. 

Open the header file of your application delegate (for example `AppDelegate.m`) or just press ^ + ⌘ + ↑ there should be a line like this (AppDelegate should match the name of the file)

    @interface AppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate, BWHockeyManagerDelegate> {  

Remove the `BWHockeyManagerDelegate`. Also look for the following line: 
  
    #import "BWHockeyManager.h"

And remove it too. (This line may have a #if macro around it, remove that too)

Now follow the steps described in our [setup guide](http://support.hockeyapp.net/kb/client-integration/hockeyapp-for-ios-hockeysdk#setup) The values for `LIVE_IDENTIFIER` and `BETA_IDENTIFIER` are used in the setup guide.

After you have finished the setup guide make sure everything works as expected and then delete the out commented lines from above.

### HockeySDK-iOS

In your application delegate (for example `AppDelegate.m`) search for the following lines:

    [[CNSHockeyManager sharedHockeyManager] configureWithBetaIdentifier:BETA_IDENTIFIER 
                                                       liveIdentifier:LIVE_IDENTIFIER
                                                             delegate:self];

For now comment out all lines whith `[CNSHockeyManager sharedHockeyManager]`. Open the header file of your application delegate by pressing ^ + ⌘ + ↑. There should be a line like this: 

    @interface AppDelegate : NSObject <UIApplicationDelegate, CNSHockeyManagerDelegate> {

Remove `CNSHockeyManagerDelegate`, also look for this line:

    #import "CNSHockeyManager.h"

And remove that too. 

Now follow the steps described in our [setup guide](http://support.hockeyapp.net/kb/client-integration/hockeyapp-for-ios-hockeysdk#setup) The values for `LIVE_IDENTIFIER` and `BETA_IDENTIFIER` are used in the setup guide.

After you have finished the setup guide make sure everything works as expected and then delete the out commented lines from above.

## Troubleshooting

### ld: warning: directory not found for option '....QuincyKit.....'

This warning means there is still a `Framework Search Path` pointing to the folder of the old SDK. Open the `Project Navigator` (⌘+1) and go to the tab `Build Settings`. In the search field enter the name of the folder mentioned in the warning (for example "QuincyKit") . If the search finds something in `Framework Search Paths` you should double click that entry and remove the line which points to the old folder.

## Advanced Migration

If you used any optional API calls, for example adding a custom description to a crash report, migrating those would exceed the scope of this guide. Please have a look at the [API documentation](https://github.com/bitstadium/HockeySDK-iOS/downloads). 
