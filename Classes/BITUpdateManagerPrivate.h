/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

/** TODO:
  * if during startup the auth-state is pending, we get never rid of the nag-alertview
 */
@interface BITUpdateManager ()

///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the `BITUpdateManagerDelegate` delegate.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 */
@property (nonatomic, weak) id delegate;


// is an update available?
@property (nonatomic, assign, getter=isUpdateAvailable) BOOL updateAvailable;

// are we currently checking for updates?
@property (nonatomic, assign, getter=isCheckInProgress) BOOL checkInProgress;

@property (nonatomic, strong) NSMutableData *receivedData;

@property (nonatomic, copy) NSDate *lastCheck;

// get array of all available versions
@property (nonatomic, copy) NSArray *appVersions;

@property (nonatomic, strong) NSNumber *currentAppVersionUsageTime;

@property (nonatomic, strong) NSURLConnection *urlConnection;

@property (nonatomic, copy) NSDate *usageStartTimestamp;

@property (nonatomic, strong) UIView *blockingView;

@property (nonatomic, strong) NSString *companyName;

@property (nonatomic, strong) NSString *installationIdentification;

@property (nonatomic, strong) NSString *installationIdentificationType;

@property (nonatomic) BOOL installationIdentified;

// used by BITHockeyManager if disable status is changed
@property (nonatomic, getter = isUpdateManagerDisabled) BOOL disableUpdateManager;

// checks for update, informs the user (error, no update found, etc)
- (void)checkForUpdateShowFeedback:(BOOL)feedback;

- (NSURLRequest *)requestForUpdateCheck;

// initiates app-download call. displays an system UIAlertView
- (BOOL)initiateAppDownload;

// get/set current active hockey view controller
@property (nonatomic, strong) BITUpdateViewController *currentHockeyViewController;

@property(nonatomic) BOOL sendUsageData;

// convenience method to get current running version string
- (NSString *)currentAppVersion;

// get newest app version
- (BITAppVersionMetaInfo *)newestAppVersion;

// check if there is any newer version mandatory
- (BOOL)hasNewerMandatoryVersion;

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
