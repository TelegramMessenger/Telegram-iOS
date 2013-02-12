/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@protocol BITHockeyManagerDelegate;

@class BITHockeyBaseManager;
@class BITCrashManager;
@class BITUpdateManager;
@class BITFeedbackManager;

/** 
 The HockeySDK manager. Responsible for setup and management of all components
 
 This is the principal SDK class. It represents the entry point for the HockeySDK. The main promises of the class are initializing the SDK modules, providing access to global properties and to all modules. Initialization is divided into several distinct phases:
 
 1. Setup the [HockeyApp](http://hockeyapp.net/) app identifier and the optional delegate: This is the least required information on setting up the SDK and using it. It does some simple validation of the app identifier and checks if the app is running from the App Store or not. If the [Atlassian JMC framework](http://www.atlassian.com/jmc/) is found, it will disable its Crash Reporting module and configure it with the Jira configuration data from [HockeyApp](http://hockeyapp.net/).
 2. Provides access to the SDK modules `BITCrashManager`, `BITUpdateManager`, and `BITFeedbackManager`. This way all modules can be further configured to personal needs, if the defaults don't fit the requirements.
 3. Configure each module.
 4. Start up all modules.
 
 The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.

 All modules do **NOT** show any user interface if the module is not activated or not integrated.
 `BITCrashManager`: Shows an alert on startup asking the user if he/she agrees on sending the crash report, if `[BITCrashManager crashManagerStatus]` is set to `BITCrashManagerStatusAlwaysAsk` (default)
 `BITUpdateManager`: Is automatically deactivated when the SDK detects it is running from a build distributed via the App Store. Otherwise if it is not deactivated manually, it will show an alert after startup informing the user about a pending update, if one is available. If the user then decides to view the update another screen is presented with further details and an option to install the update.
 `BITFeedbackManager`: If this module is deactivated or the user interface is nowhere added into the app, this module will not do anything. It will not fetch the server for data or show any user interface. If it is integrated, activated, and the user already used it to provide feedback, it will show an alert after startup if a new answer has been received from the server with the option to view it.
 
 @warning You should **NOT** change any module configuration after calling `startManager`!
 
 Example:
    [[BITHockeyManager sharedHockeyManager]
      configureWithIdentifier:@"<AppIdentifierFromHockeyApp>"
                     delegate:nil];
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

@interface BITHockeyManager : NSObject

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
 
    [[BITHockeyManager sharedHockeyManager]
      configureWithIdentifier:@"<AppIdentifierFromHockeyApp>"
                     delegate:nil];

 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see BITHockeyManagerDelegate
 @see BITCrashManagerDelegate
 @see BITUpdateManagerDelegate
 @see BITFeedbackManagerDelegate
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
 
    [[BITHockeyManager sharedHockeyManager]
      configureWithBetaIdentifier:@"<AppIdentifierForBetaAppFromHockeyApp>"
                   liveIdentifier:@"<AppIdentifierForLiveAppFromHockeyApp>"
                         delegate:nil];

 We recommend using one app entry on HockeyApp for your beta versions and another one for
 your live versions. The reason is that you will have way more beta versions than live
 versions, but on the other side get way more crash reports on the live version. Separating
 them into two different app entries makes it easier to work with the data. In addition
 you will likely end up having the same version number for a beta and live version which
 would mix different data into the same version. Also the live version does not require
 you to upload any IPA files, uploading only the dSYM package for crash reporting is
 just fine.

 @see configureWithIdentifier:delegate:
 @see startManager
 @see BITHockeyManagerDelegate
 @see BITCrashManagerDelegate
 @see BITUpdateManagerDelegate
 @see BITFeedbackManagerDelegate
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
@property (nonatomic, strong) NSString *serverURL;


/**
 Reference to the initialized BITCrashManager module

 Returns the BITCrashManager instance initialized by BITHockeyManager
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see disableCrashManager
 */
@property (nonatomic, strong, readonly) BITCrashManager *crashManager;


/**
 Flag the determines whether the Crash Manager should be disabled
 
 If this flag is enabled, then crash reporting is disabled and no crashes will
 be send.
 
 Please note that the Crash Manager will be initialized anyway!

 *Default*: _NO_
 @see crashManager
 */
@property (nonatomic, getter = isCrashManagerDisabled) BOOL disableCrashManager;


/**
 Reference to the initialized BITUpdateManager module
 
 Returns the BITUpdateManager instance initialized by BITHockeyManager
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see disableUpdateManager
 */
@property (nonatomic, strong, readonly) BITUpdateManager *updateManager;


/**
 Flag the determines whether the Update Manager should be disabled
 
 If this flag is enabled, then checking for updates and submitting beta usage
 analytics will be turned off!
 
 Please note that the Update Manager will be initialized anyway!
 
 *Default*: _NO_
 @see updateManager
 */
@property (nonatomic, getter = isUpdateManagerDisabled) BOOL disableUpdateManager;


/**
 Reference to the initialized BITFeedbackManager module
 
 Returns the BITFeedbackManager instance initialized by BITHockeyManager
 
 @see configureWithIdentifier:delegate:
 @see configureWithBetaIdentifier:liveIdentifier:delegate:
 @see startManager
 @see disableFeedbackManager
 */
@property (nonatomic, strong, readonly) BITFeedbackManager *feedbackManager;


/**
 Flag the determines whether the Feedback Manager should be disabled
 
 If this flag is enabled, then letting the user give feedback and
 get responses will be turned off!
 
 Please note that the Feedback Manager will be initialized anyway!
 
 *Default*: _NO_
 @see feedbackManager
 */
@property (nonatomic, getter = isFeedbackManagerDisabled) BOOL disableFeedbackManager;


///-----------------------------------------------------------------------------
/// @name Environment
///-----------------------------------------------------------------------------

/**
 Flag that determines whether the application is installed and running
 from an App Store installation.
 
 Returns _YES_ if the app is installed and running from the App Store
 Returns _NO_ if the app is installed via debug, ad-hoc or enterprise distribution
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
