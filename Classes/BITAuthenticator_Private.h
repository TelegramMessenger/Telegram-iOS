//
//  BITAuthenticator_Private.h
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import "BITAuthenticator.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITAuthenticationViewController.h"
@class BITHockeyAppClient;

@interface BITAuthenticator ()<BITAuthenticationViewControllerDelegate>

/**
 *	must be set
 */
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

//can be set for testing
@property (nonatomic) UIDevice *currentDevice;

/**
 *	if set, this serves as the installationIdentifier. 
 *  This is retrieved from the hockeyApp backend
 *  @see installationIdentifier
 */
@property (nonatomic, copy) NSString *authenticationToken;

/**
 *  holds the identifier of the last version that was authenticated
 *  only used if validation is set BITAuthenticatorValidationTypeOnFirstLaunch
 */
@property (nonatomic, copy) NSString *lastAuthenticatedVersion;

@property (nonatomic, copy) tAuthenticationCompletion authenticationCompletionBlock;

/**
 *	removes all previously stored authentication tokens, UDIDs, etc
 */
- (void) cleanupInternalStorage;

@property (nonatomic, readwrite) BOOL installationIdentificationValidated;

/**
 * method registered as observer for applicationWillBecomeInactive events
 */
- (void) applicationWillResignActive:(NSNotification*) note;

/**
 * method registered as observer for applicationsDidBecomeActive events
 */
- (void) applicationDidBecomeActive:(NSNotification*) note;

/**
 *	once the user skipped the optional login, this is set to YES
 *  (and thus the optional login should never be shown again)
 *  persisted to disk. Defaults to NO
 */
@property (nonatomic, assign) BOOL didSkipOptionalLogin;

#pragma mark - Authentication
/**
 *	Authenticate this app installation
 *
 *  Depending on 'authenticationType', this tries to authenticate the app installation
 *  against the HockeyApp server.
 *  You should not need to call this, as it's done automatically once the manager has
 *  been started, depending on validationType.
 *
 *  @param completion if nil, success/failure is reported via the delegate, if not nil, the
 *         delegate methods are not called.
 */
- (void) authenticateWithCompletion:(tAuthenticationCompletion) completion;

#pragma mark - Internal Auth callbacks
- (void) didAuthenticateWithToken:(NSString*) token;

#pragma mark - Validation
/**
 *	Validate the app installation
 *
 *  Depending on @see validationType, this is called by the manager after the app becomes active
 *  and tries to revalidate the installation.
 *  You should not need to call this, as it's done automatically once the manager has
 *  been started, depending on validationType.
 *
 *  @param completion if nil, success/failure is reported via the delegate, if not nil, the
 *         delegate methods are not called
 */
- (void) validateInstallationWithCompletion:(tValidationCompletion) completion;


#pragma mark - Validation callbacks
- (void) validationSucceededWithCompletion:(tValidationCompletion) completion;
- (void) validationFailedWithError:(NSError *) validationError completion:(tValidationCompletion) completion;

@end
