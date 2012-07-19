/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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

#import "BITUpdateManager.h"


@protocol BITHockeyManagerDelegate;

@class BITCrashManager;

@interface BITHockeyManager : NSObject {
@private
  id<BITHockeyManagerDelegate> delegate;
  NSString *_appIdentifier;
  
  BOOL _validAppIdentifier;
  
  BOOL _startManagerIsInvoked;
}

#pragma mark - Public Properties

@property (nonatomic, retain) BITCrashManager *crashManager;

@property (nonatomic, retain) BITUpdateManager *updateManager;


// if YES the app is installed from the app store
// if NO the app is installed via ad-hoc or enterprise distribution
@property (nonatomic, readonly) BOOL isAppStoreEnvironment;

// Enable debug logging; ONLY ENABLE THIS FOR DEBUGGING!
//
// Default: NO
@property (nonatomic, assign, getter=isLoggingEnabled) BOOL loggingEnabled;


#pragma mark - Public Methods

// Returns the shared manager object
+ (BITHockeyManager *)sharedHockeyManager;

// Configure HockeyApp with a single app identifier and delegate; use this
// only for debug or beta versions of your app!
- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id<BITHockeyManagerDelegate>)delegate;

// Configure HockeyApp with different app identifiers for beta and live versions
// of the app; the update alert will only be shown for the beta identifier
- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id<BITHockeyManagerDelegate>)delegate;

// Initialize all submodules and start them
- (void)startManager;


@end
