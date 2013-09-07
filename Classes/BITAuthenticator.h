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
  BITAuthenticatorAuthTypeUDIDProvider,
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
 *
 *  Authentication is actually a 2 step process:
 *    1) authenticate
 *       some kind of token is aquired depending on the authenticationType
 *    2) verification
 *       the aquired token from step 1 is verified dependong the validationType
 *
 *  There are currently 3 ways of authentication:
 *    1) authenticate the user via email only
 *    2) authenticate the user via email & passwort (needs to have a HockeyApp Account)
 *    3) authenticate the device via its UDID
 *
 *  Additionally, verification can be required:
 *    1) never
 *    2) optional
 *    3) on first launch of every app version, never again until the next version is installed
 *    4) every time the app becomes active (needs data connection)
 *
 */
@interface BITAuthenticator : BITHockeyBaseManager

#pragma mark - Configuration

@property (nonatomic, assign) BITAuthenticatorAuthType authenticationType;

/**
 *	defaults to BITAuthenticatorValidationTypeNever
 */
@property (nonatomic, assign) BITAuthenticatorValidationType validationType;

@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

/**
 The authentication token from HockeyApp.
 
 Set the token to the `Secret ID` which HockeyApp provides for every app.
 
 When running the app from the App Store, this setting is ignored.
 */
@property (nonatomic, copy) NSString *authenticationSecret;

#pragma mark - Identification
/**
 *	Provides an identification for the current app installation
 * 
 *  During Alpha and Beta-phase HockeyApp tries to uniquely identify each app installation
 *  to provide better error reporting & analytics. If authenticator is configured to login 
 *  (@see BITAuthenticatorValidationType), this identifier is retrieved from HockeyApp. In case
 *  it is disabled, it returns the vendorIdentifier provided by UIKit.
 *  KVO'able
 *
 *	@return	a string identifying this app installation
 */
@property (nonatomic, readonly) NSString *installationIdentification;

#pragma mark - UDID auth

/**
 *	baseURL of the webpage the user is redirected to if authenticationType is BITAuthenticatorAuthTypeWebbased
 *  defaults to https://rink.hockeyapp.net but can be overwritten if desired
 */
@property (nonatomic, strong) NSURL *webpageURL;

/**
 *	should be used by the app-delegate to forward handle application:openURL:sourceApplication:annotation calls
 *
 *	@param	url	URL that was passed to the app
 *	@param	sourceApplication	sourceApplication that was passed to the app
 *	@param	annotation	annotation that was passed to the app
 *
 *	@return	YES if the URL request was handled, NO if the URL could not be handled/identified
 *
 *  Sample usage (in AppDelegate)
 *  - (BOOL)application:(UIApplication *)application 
 *              openURL:(NSURL *)url
 *    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
 *    if ([[BITHockeyManager sharedHockeyManager].authenticator handleOpenURL:url
 *                                                          sourceApplication:sourceApplication
 *                                                                 annotation:annotation]) {
 *      return YES;
 *    } else {
 *      //do your own URL handling, return appropriate valu
 *    }
 *    return NO;
 }
 */
- (BOOL) handleOpenURL:(NSURL *) url
     sourceApplication:(NSString *) sourceApplication
            annotation:(id) annotation;

@end

@protocol BITAuthenticatorDelegate <NSObject>

@optional
/**
 *	if the authentication (or validation) needs to authenticate the user, 
 *  this delegate method is called with the viewController that we'll present.
 *
 *	@param	authenticator	authenticator object
 *	@param	viewController	viewcontroller used to authenticate the user
 *
 */
- (void) authenticator:(BITAuthenticator *)authenticator willShowAuthenticationController:(UIViewController*) viewController;

@end
