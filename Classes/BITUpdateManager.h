/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import <UIKit/UIKit.h>
#import "BITHockeyBaseManager.h"


typedef enum {
	BITUpdateAuthorizationDenied,
	BITUpdateAuthorizationAllowed,
	BITUpdateAuthorizationPending
} BITUpdateAuthorizationState;

typedef enum {
  BITUpdateCheckStartup = 0,
  BITUpdateCheckDaily = 1,
  BITUpdateCheckManually = 2
} BITUpdateSetting;

@protocol BITUpdateManagerDelegate;

@class BITAppVersionMetaInfo;
@class BITUpdateViewController;

/**
 The update manager module.
 
 This is the HockeySDK module for handling app updates when using Ad-Hoc or Enterprise provisioning profiles.
 This modul handles version updates, presents update and version information in a App Store like user interface,
 collects usage information and provides additional authorization options when using Ad-Hoc provisioning profiles.
 
 This module automatically disables itself when running in an App Store build by default! If you integrate the
 Atlassian JMC client this module is used to automatically configure JMC, but will not do anything else.
 
 To use this module, it is important to implement set the `delegate` property and implement
 `[BITUpdateManagerDelegate customDeviceIdentifierForUpdateManager:]`.
 
 Example implementation if your Xcode configuration for the App Store is called "AppStore":
    - (NSString *)customDeviceIdentifierForUpdateManager:(BITUpdateManager *)updateManager {
    #ifndef (CONFIGURATION_AppStore)
      if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
        return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
    #endif
    
      return nil;
    }
  
    [[BITHockeyManager sharedHockeyManager].updateManager setDelegate:self];
 
 */

@interface BITUpdateManager : BITHockeyBaseManager <UIAlertViewDelegate>


///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the `BITUpdateManagerDelegate` delegate.
 
 When using `BITUpdateManager` to distribute updates of your beta or enterprise
 application, it is _REQUIRED_ to set this delegate and implement
 `[BITUpdateManagerDelegate customDeviceIdentifierForUpdateManager:]`!
 */
@property (nonatomic, weak) id delegate;


///-----------------------------------------------------------------------------
/// @name Update Checking
///-----------------------------------------------------------------------------

// see HockeyUpdateSetting-enum. Will be saved in user defaults.
// default value: HockeyUpdateCheckStartup
/**
 When to check for new updates.
 
 Defines when a the SDK should check if there is a new update available on the
 server. This must be assigned one of the following:
 
 - `BITUpdateCheckStartup`: On every startup or or when the app comes to the foreground
 - `BITUpdateCheckDaily`: Once a day
 - `BITUpdateCheckManually`: Manually
 
 When running the app from the App Store, this setting is ignored.

 **Default**: BITUpdateCheckStartup
 
 @warning When setting this to `BITUpdateCheckManually` you need to either
 invoke the update checking process yourself with `checkForUpdate` somehow, e.g. by
 proving an update check button for the user or integrating the Update View into your
 user interface.
 @see checkForUpdateOnLaunch
 @see checkForUpdate
 */
@property (nonatomic, assign) BITUpdateSetting updateSetting;


/**
 Flag that determines whether the automatic update checks should be done.
 
 If this is enabled the update checks will be performed automatically depending on the
 `updateSetting` property. If this is disabled the `updateSetting` property will have
 no effect, and checking for updates is totally up to be done by yourself.
 
 When running the app from the App Store, this setting is ignored.

 *Default*: _YES_

 @warning When setting this to `NO` you need to invoke update checks yourself!
 @see updateSetting
 @see checkForUpdate
 */
@property (nonatomic, assign, getter=isCheckForUpdateOnLaunch) BOOL checkForUpdateOnLaunch;


// manually start an update check
/**
 Check for an update
 
 Call this to trigger a check if there is a new update available on the HockeyApp servers.
 
 When running the app from the App Store, this setting is ignored.

 @see updateSetting
 @see checkForUpdateOnLaunch
 */
- (void)checkForUpdate;


///-----------------------------------------------------------------------------
/// @name Update Notification
///-----------------------------------------------------------------------------

/**
 Flag that determines if updates alert should be repeatedly shown
 
 If enabled the update alert shows on every startup and whenever the app becomes active,
 until the update is installed.
 If disabled the update alert is only shown once ever and it is up to you to provide an
 alternate way for the user to navigate to the update UI or update in another way.
 
 When running the app from the App Store, this setting is ignored.

 *Default*: _YES_
 */
@property (nonatomic, assign) BOOL alwaysShowUpdateReminder;


/**
 Flag that determines if the update alert should show an direct install option
 
 If enabled the update alert shows an additional option which allows to invoke the update
 installation process directly, instead of viewing the update UI first.
 By default the alert only shows a `Show` and `Ignore` option.
 
 When running the app from the App Store, this setting is ignored.

 *Default*: _NO_
 */
@property (nonatomic, assign, getter=isShowingDirectInstallOption) BOOL showDirectInstallOption;


///-----------------------------------------------------------------------------
/// @name Authorization
///-----------------------------------------------------------------------------

/**
 Flag that determines if each update should be authenticated
 
 If enabled each update will be authenticated on startup against the HockeyApp servers.
 The process will basically validate if the current device is part of the provisioning
 profile on the server. If not, it will present a blocking view on top of the apps UI
 so that no interaction is possible.
 
 When running the app from the App Store, this setting is ignored.
 
 *Default*: _NO_
 @see authenticationSecret
 @warning This only works when using Ad-Hoc provisioning profiles!
 */
@property (nonatomic, assign, getter=isRequireAuthorization) BOOL requireAuthorization;


/**
 The authentication token from HockeyApp.
 
 Set the token to the `Secret ID` which HockeyApp provides for every app.
 
 When running the app from the App Store, this setting is ignored.
 
 @see requireAuthorization
 */
@property (nonatomic, strong) NSString *authenticationSecret;


///-----------------------------------------------------------------------------
/// @name Expiry
///-----------------------------------------------------------------------------

/**
 Expiry date of the current app version
 
 If set, the app will get unusable at the given date by presenting a blocking view on
 top of the apps UI so that no interaction is possible. To present a custom you, check
 the documentation of the 
 `[BITUpdateManagerDelegate shouldDisplayExpiryAlertForUpdateManager:]` delegate.
 
 Once the expiry date is reached, the app will no longer check for updates or
 send any usage data to the server!
 
 When running the app from the App Store, this setting is ignored.
 
 *Default*: nil
 @see [BITUpdateManagerDelegate shouldDisplayExpiryAlertForUpdateManager:]
 @see [BITUpdateManagerDelegate didDisplayExpiryAlertForUpdateManager:]
 @warning This only works when using Ad-Hoc provisioning profiles!
 */
@property (nonatomic, strong) NSDate *expiryDate;


///-----------------------------------------------------------------------------
/// @name User Interface
///-----------------------------------------------------------------------------


/**
 Present the modal update user interface.
 */
- (void)showUpdateView;


/**
 Create an update view

 @param modal Return a view ready for modal presentation with integrated navigation bar
 @return BITUpdateViewController The update user interface view controller,
 e.g. to push it onto a navigation stack.
 */
- (BITUpdateViewController *)hockeyViewController:(BOOL)modal;


@end
