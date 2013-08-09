//
//  BITAuthenticator
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import <Foundation/Foundation.h>

#import "BITHockeyBaseManager.h"

typedef NS_ENUM(NSUInteger, BITAuthenticatorAuthType) {
  BITAuthenticatorAuthTypeEmail,
  BITAuthenticatorAuthTypeEmailAndPassword,
  //TODO: add Facebook?
};

//TODO: think about name. call it registration?!
typedef NS_ENUM(NSUInteger, BITAuthenticatorValidationType) {
  BITAuthenticatorValidationTypeNever = 0,     //never try to validate the current installation
  BITAuthenticatorValidationTypeOptional,      //asks the user if he wants to authenticate himself
  BITAuthenticatorValidationTypeOnFirstLaunch, //checks if the user is authenticated first time a new version is run
  BITAuthenticatorValidationTypeOnAppActive,   //checks if the user is authenticated everytime the app becomes active
};

typedef void(^tAuthenticationCompletion)(NSString* authenticationToken, NSError *error);
typedef void(^tValidationCompletion)(BOOL validated, NSError *error);

@protocol BITAuthenticatorDelegate;

/**
 *	Authenticator module used to identify and optionally authenticate the current
 *  app installation
 */
@interface BITAuthenticator : BITHockeyBaseManager

#pragma mark - Configuration

@property (nonatomic, assign) BITAuthenticatorAuthType authenticationType;

/**
 *	defaults to BITAuthenticatorValidationTypeNever
 */
@property (nonatomic, assign) BITAuthenticatorValidationType validationType;

@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

#pragma mark - Identification
/**
 *	Provides an identification for the current app installation
 * 
 *  During Alpha and Beta-phase HockeyApp tries to uniquely identify each app installation
 *  to provide better error reporting & analytics. If authenticator is configured to login 
 *  (@see BITAuthenticatorValidationType), this identifier is retrieved from HockeyApp. In case
 *  it is disabled, it returns this the current vendorIdentifier provided by UIKit.
 *
 *	@return	a string identifying this app installation
 */
- (NSString *) installationIdentification;

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

#pragma mark - Validation
/**
 *	Validate the app installation
 *
 *  Depending on @see loginOption, this is reset after the app becomes active and tries to revalidate
 *  the installation.
 *  You should not need to call this, as it's done automatically once the manager has
 *  been started, depending on validationType.
 *
 *  @param completion if nil, success/failure is reported via the delegate, if not nil, the
 *         delegate methods are not called
 */
- (void) validateInstallationWithCompletion:(tValidationCompletion) completion;

@end

@protocol BITAuthenticatorDelegate <NSObject>

/**
 *	if the authentication (or validation) needs to authenticate the user, 
 *  this delegate method is called with the viewController that we'll present.
 *
 *	@param	authenticator	authenticator object
 *	@param	viewController	viewcontroller used to authenticate the user
 *
 */
- (void) authenticator:(BITAuthenticator *)authenticator willShowAuthenticationController:(UIViewController*) viewController;
- (void) authenticatorDidAuthenticate:(BITAuthenticator*) authenticator;
- (void) authenticator:(BITAuthenticator*) authenticator failedToAuthenticateWithError:(NSError*) error;

- (void) authenticatorDidValidateInstallation:(BITAuthenticator*) authenticator;
- (void) authenticator:(BITAuthenticator*) authenticator failedToValidateInstallationWithError:(NSError*) error;


@end
