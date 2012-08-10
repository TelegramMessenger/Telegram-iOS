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
@class BITUpdateManager;

/** 
 The HockeySDK manager.
 
 This is the principal SDK class. It represents the entry point for the HockeySDK. The main promises of the class are initializing the SDK modules, providing access to global properties and to all modules. Initialization is divided into several distinct phases:
 
 1. Setup the [HockeyApp](http://hockeyapp.net/) app identifier and the optional delegate: This is the least required information on setting up the SDK and using it. It does some simple validation of the app identifier and checks if the app is running from the App Store or not. If the [Atlassian JMC framework](http://www.atlassian.com/jmc/) is found, it will disable its Crash Reporting module and configure it with the Jira configuration data from [HockeyApp](http://hockeyapp.net/).
 2. Provides access to the SDK modules `BITCrashManager` and `BITUpdateManager`. This way all modules can be further configured to personal needs, if the defaults don't fit the requirements.
 3. Start up all modules.
 
 Example:
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<AppIdentifierFromHockeyApp>" delegate:nil];
    [[BITHockeyManager sharedHockeyManager] startManager];
 
 @warning When also using the SDK for updating app versions (AdHoc or Enterprise) and collecting
 beta usage analytics, you also have to to set  `[BITUpdateManager delegate]` and
 implement `[BITUpdateManagerDelegate customDeviceIdentifierForUpdateManager:]`!
 
 
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

@interface BITHockeyManager : NSObject {
@private
  id _delegate;
  NSString *_appIdentifier;
  
  BOOL _validAppIdentifier;
  
  BOOL _startManagerIsInvoked;
}


#pragma mark - Public Methods

///-----------------------------------------------------------------------------
/// @name Initializion
///-----------------------------------------------------------------------------

/**
 Returns a shared BITHockeyManager object
 
 @return A singleton BITHockeyManager instance ready use
 */
+ (BITHockeyManager *)sharedHockeyManager;


/**
 Initializes the manager with a particular app identifier and delegate
 
 Initialize the manager with a HockeyApp app identifier and assign the class that
 implements the optional protocols `BITHockeyManagerDelegate`, `BITCrashManagerDelegate` or
 `BITUpdateManagerDelegate`.
 
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"<AppIdentifierFromHockeyApp>" delegate:nil];

 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see BITHockeyManagerDelegate
 @see BITCrashManagerDelegate
 @see BITUpdateManagerDelegate
 @param appIdentifier The app identifier that should be used.
 @param delegate `nil` or the class implementing the option protocols
 */
- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id)delegate;


/**
 Initializes the manager with an app identifier for beta, one for live usage and delegate
 
 Initialize the manager with different HockeyApp app identifiers for beta and live usage.
 All modules will automatically detect if the app is running in the App Store and use
 the live app identifier for that. In all other cases it will use the beta app identifier.
 And also assign the class that implements the optional protocols `BITHockeyManagerDelegate`,
 `BITCrashManagerDelegate` or `BITUpdateManagerDelegate`
 
    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:@"<AppIdentifierForBetaAppFromHockeyApp>"
                                                         liveIdentifier:@"<AppIdentifierForLiveAppFromHockeyApp>"
                                                               delegate:nil];

 @see configureWithIdentifier:delegate:
 @see startManager
 @see BITHockeyManagerDelegate
 @see BITCrashManagerDelegate
 @see BITUpdateManagerDelegate
 @param betaIdentifier The app identifier for the _non_ app store (beta) configurations
 @param liveIdentifier The app identifier for the app store configurations.
 @param delegate `nil` or the class implementing the optional protocols
 */
- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id)delegate;


/**
 Starts the manager and runs all modules
 
 Call this after configuring the manager and setting up all modules.
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 */
- (void)startManager;


#pragma mark - Public Properties

///-----------------------------------------------------------------------------
/// @name Modules
///-----------------------------------------------------------------------------


/**
 Defines the server URL to send data to or request data from
 
 By default this is set to the HockeyApp servers and there rarely should be a
 need to modify that.
 */
@property (nonatomic, retain) NSString *updateURL;


/**
 Reference to the initialized BITCrashManager module
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see disableCrashManager
 @return The BITCrashManager instance initialized by BITHockeyManager
 */
@property (nonatomic, retain, readonly) BITCrashManager *crashManager;


/**
 Flag the determines wether the Crash Manager should be disabled
 
 If this flag is enabled, then crash reporting is disabled and no crashes will
 be send.
 
 Please note that the Crash Manager will be initialized anyway!

 *Default*: _NO_
 @see crashManager
 */
@property (nonatomic, getter = isCrashManagerDisabled) BOOL disableCrashManager;


/**
 Reference to the initialized BITUpdateManager module
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see disableUpdateManager
 @return The BITCrashManager instance initialized by BITUpdateManager
 */
@property (nonatomic, retain, readonly) BITUpdateManager *updateManager;


/**
 Flag the determines wether the Update Manager should be disabled
 
 If this flag is enabled, then checking for updates and submitting beta usage
 analytics will be turned off!
 
 Please note that the Update Manager will be initialized anyway!
 
 *Default*: _NO_
 @see updateManager
 */
@property (nonatomic, getter = isUpdateManagerDisabled) BOOL disableUpdateManager;


///-----------------------------------------------------------------------------
/// @name Environment
///-----------------------------------------------------------------------------

/**
 Flag that determines whether the application is installed and running
 from an App Store installation.
 
 @return YES if the app is installed and running from the App Store
 @return NO if the app is installed via debug, ad-hoc or enterprise distribution
 */
@property (nonatomic, readonly, getter=isAppStoreEnvironment) BOOL appStoreEnvironment;


///-----------------------------------------------------------------------------
/// @name Debug Logging
///-----------------------------------------------------------------------------

/**
 Flag that determines whether additional logging output should be generated
 by the manager and all modules.
 
 This is ignored if the app is running in the App Store and reverts to the
 default value in that case.
 
 *Default*: _NO_
 */
@property (nonatomic, assign, getter=isDebugLogEnabled) BOOL debugLogEnabled;


@end
