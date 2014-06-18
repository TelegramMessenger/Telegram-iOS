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


#if HOCKEYSDK_FEATURE_STORE_UPDATES

@interface BITStoreUpdateManager () <UIAlertViewDelegate> {
}

///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the optional `BITStoreUpdateManagerDelegate` delegate.
 */
@property (nonatomic, weak) id delegate;


// is an update available?
@property (nonatomic, assign, getter=isUpdateAvailable) BOOL updateAvailable;

// are we currently checking for updates?
@property (nonatomic, assign, getter=isCheckInProgress) BOOL checkInProgress;

@property (nonatomic, strong) NSDate *lastCheck;

// used by BITHockeyManager if disable status is changed
@property (nonatomic, getter = isStoreUpdateManagerEnabled) BOOL enableStoreUpdateManager;

#pragma mark - For Testing

@property (nonatomic, strong) NSBundle *mainBundle;
@property (nonatomic, strong) NSLocale *currentLocale;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

- (BOOL)shouldAutoCheckForUpdates;
- (BOOL)hasNewVersion:(NSDictionary *)dictionary;
- (BOOL)processStoreResponseWithString:(NSString *)responseString;
- (void)checkForUpdateDelayed;

@end

#endif /* HOCKEYSDK_FEATURE_STORE_UPDATES */
