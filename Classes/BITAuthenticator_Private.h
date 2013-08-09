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

@interface BITAuthenticator ()<BITAuthenticationViewControllerDelegate>

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
@property (nonatomic, copy) tValidationCompletion validationCompletion;

/**
 *	removes all previously stored authentication tokens, UDIDs, etc
 */
- (void) cleanupInternalStorage;


/**
 * method registered as observer for applicationsDidBecomeActive events
 */
- (void) applicationDidBecomeActive:(NSNotification*) note;

#pragma mark - Validation callbacks
- (void) validationSucceeded;
- (void) validationFailedWithError:(NSError *) validationError;

@end
