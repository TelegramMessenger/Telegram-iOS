//  Copyright 2011 Codenauts UG (haftungsbeschränkt). All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BWHockeyManager.h"

#pragma mark - Delegate

@protocol CNSHockeyManagerDelegate <NSObject>

/*
 Return the device UDID which is required for beta testing, should return nil for app store configuration!
 Example implementation if your configuration for the App Store is called "AppStore":
 
 #ifndef (CONFIGURATION_AppStore)
 if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
 return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
 #endif
 return nil;
 
 */
- (NSString *)customDeviceIdentifier;

@optional

// Invoked when the manager is configured
// 
// Implement to force the usage of the live identifier, e.g. for enterprise apps
// which are distributed inside your company
- (BOOL)shouldUseLiveIdenfitier;

// Invoked when the internet connection is started
// 
// Implement to let the delegate enable the activity indicator
- (void)connectionOpened;

// Invoked when the internet connection is closed
// 
// Implement to let the delegate disable the activity indicator
- (void)connectionClosed;

// Invoked via the alert view to define the presenting view controller
// 
// Default is the root view controller of the main window instance
- (UIViewController *)viewControllerForHockeyController:(BWHockeyManager *)hockeyController;

// Invoked before a crash report will be sent
// 
// Return a userid or similar which the crashreport should contain
// 
// Maximum length: 255 chars
// 
// Default: empty
- (NSString *)crashReportUserID;

// Invoked before a crash report will be sent
// 
// Return contact data, e.g. an email address, for the crash report
// Maximum length: 255 chars
// 
// Default: empty
-(NSString *)crashReportContact;

// Invoked before a crash report will be sent
// 
// Return a the description for the crashreport should contain; the string
// will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do 
// that in your string.
// 
// Default: empty 
-(NSString *)crashReportDescription;

// Invoked before the user is asked to send a crash report
// 
// Implement to do additional actions, e.g. to make sure to not to ask the 
// user for an app rating :) 
- (void)willShowSubmitCrashReportAlert;

// Invoked after the user did choose to send crashes always in the alert 
-(void) userDidChooseSendAlways;

@end

@interface CNSHockeyManager : NSObject {
@private
  id<CNSHockeyManagerDelegate> delegate;
  NSString *appIdentifier;
}

#pragma mark - Public Properties

// Custom language style; set to a string which will be appended to 
// to the localization file name; the Hockey SDK includes an alternative
// file, to use this, set to @"Alternate"
// 
// Default: nil
@property (nonatomic, retain) NSString *languageStyle;

// Enable debug logging; ONLY ENABLE THIS FOR DEBUGGING!
//
// Default: NO
@property (nonatomic, assign, getter=isLoggingEnabled) BOOL loggingEnabled;

// Show button "Always" in crash alert; this will cause the dialog not to 
// show the alert description text landscape mode! (default)
//
// Default: NO
@property (nonatomic, assign, getter=isShowingAlwaysButton) BOOL showAlwaysButton;

// Show feedback from server with status of the crash; if you set a crash
// to resolved on HockeyApp and assign a fixed version, this version will
// be reported to the user
//
// Default: NO
@property (nonatomic, assign, getter=isFeedbackActivated) BOOL feedbackActivated;

// Submit crash report without asking the user
//
// Default: NO
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

// Send user data to HockeyApp when checking for a new version; works only 
// for beta apps and should not be activated for live apps. User data includes
// the device type, OS version, app version and device UDID.
//
// Default: YES
@property (nonatomic, assign, getter=shouldSendUserData) BOOL sendUserData;

// Send usage time to HockeyApp when checking for a new version; works only 
// for beta apps and should not be activated for live apps. 
//
// Default: YES
@property (nonatomic, assign, getter=shouldSendUsageTime) BOOL sendUsageTime;

// Enable to allow the user to change the settings from the update view
//
// Default: YES
@property (nonatomic, assign, getter=shouldShowUserSettings) BOOL showUserSettings;

// Set bar style of navigation controller
//
// Default: UIBarStyleDefault
@property (nonatomic, assign) UIBarStyle barStyle;

// Set modal presentation style of update view
//
// Default: UIModalPresentationStyleFormSheet
@property (nonatomic, assign) UIModalPresentationStyle modalPresentationStyle;

// Allow the user to disable the sending of user data; this settings should
// only be set if showUserSettings is enabled.
//
// Default: YES
@property (nonatomic, assign, getter=isUserAllowedToDisableSendData) BOOL allowUserToDisableSendData;

// Enable to show the new version alert every time the app becomes active and
// the current version is outdated
//
// Default: YES
@property (nonatomic, assign) BOOL alwaysShowUpdateReminder;

// Enable to check for a new version every time the app becomes active; if
// disabled you need to trigger the update mechanism manually
//
// Default: YES
@property (nonatomic, assign, getter=shouldCheckForUpdateOnLaunch) BOOL checkForUpdateOnLaunch;

// Show a button "Install" in the update alert to let the user directly start
// the update; note that the user will not see the release notes.
//
// Default: NO
@property (nonatomic, assign, getter=isShowingDirectInstallOption) BOOL showDirectInstallOption;

// Enable to check on the server that the app is authorized to run on this 
// device; the check is based on the UDID and the authentication secret which
// is shown on the app page on HockeyApp
//
// Default: NO
@property (nonatomic, assign, getter=shouldRequireAuthorization) BOOL requireAuthorization;

// Set to the authentication secret which is shown on the app page on HockeyApp;
// must be set if requireAuthorization is enabled; leave empty otherwise
//
// Default: nil
@property (nonatomic, retain) NSString *authenticationSecret;

// Define how the client determines if a new version is available.
//
// Values:
// HockeyComparisonResultDifferent - the version on the server is different
// HockeyComparisonResultGreate - the version on the server is greater
//
// Default: HockeyComparisonResultGreater
@property (nonatomic, assign) HockeyComparisonResult compareVersionType;

// if YES the app is installed from the app store
// if NO the app is installed via ad-hoc or enterprise distribution
@property (nonatomic, readonly) BOOL isAppStoreEnvironment;

#pragma mark - Public Methods

// Returns the shared manager object
+ (CNSHockeyManager *)sharedHockeyManager;

// Configure HockeyApp with a single app identifier and delegate; use this
// only for debug or beta versions of your app!
- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id<CNSHockeyManagerDelegate>)delegate;

// Configure HockeyApp with different app identifiers for beta and live versions
// of the app; the update alert will only be shown for the beta identifier
- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id<CNSHockeyManagerDelegate>)delegate;

// Returns true if the app crashes in the last session
- (BOOL)didCrashInLastSession;

// Returns true if an update is available
- (BOOL)isUpdateAvailable;

// Returns true if update check is running
- (BOOL)isCheckInProgress;

// Show update info view
- (void)showUpdateView;

// Manually start an update check
- (void)checkForUpdate;

// Checks for update and informs the user if an update was found or an 
// error occurred
- (void)checkForUpdateShowFeedback:(BOOL)feedback;

// Initiates app-download call; this displays an alert view of the OS
- (BOOL)initiateAppDownload;

// Returns true if this app version was authorized with the server
- (BOOL)appVersionIsAuthorized;

// Manually check if the device is authorized to run this version
- (void)checkForAuthorization;

// Return a new instance of BWHockeyViewController
- (BWHockeyViewController *)hockeyViewController:(BOOL)modal;

@end
