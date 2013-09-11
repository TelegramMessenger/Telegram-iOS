/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013 HockeyApp, Bit Stadium GmbH.
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
 * Authenticator module used to identify and optionally authenticate the current app installation
 *
 * This is the HockeySDK module for handling authentications when using Ad-Hoc or Enterprise provisioning profiles.
 * This modul allows you to make sure the current app installation is done on an authorzied device by choosing from
 * various authenticatoin and validation mechanisms which provide different levels of authentication.
 *
 * This does not provide DRM or copy protection in any form and each authentication type and validation type provide
 * a different level of authentication.
 *
 * This module automatically disables itself when running in an App Store build by default!
 *
 *  Authentication is actually a 2 step process:
 *    1) authenticate
 *       some kind of token is aquired depending on the authenticationType
 *    2) validation
 *       the aquired token from step 1 is validated depending the validationType
 *
 *  There are currently 3 ways of authentication:
 *    1) authenticate the user via email only (`BITAuthenticatorAuthTypeEmail`)
 *    2) authenticate the user via email & passwort (needs to have a HockeyApp Account) (`BITAuthenticatorAuthTypeEmailAndPassword`)
 *    3) authenticate the device via its UDID (_Default_) (`BITAuthenticatorAuthTypeUDIDProvider`)
 *
 *  Additionally, verification can be required:
 *    1) never (`BITAuthenticatorValidationTypeNever`)
 *    2) optional (`BITAuthenticatorValidationTypeOptional`)
 *    3) on first launch of every app version, never again until the next version is installed (_Default_) (`BITAuthenticatorValidationTypeOnFirstLaunch`)
 *    4) every time the app becomes active (needs data connection) (`BITAuthenticatorValidationTypeOnAppActive`)
 *
 */
@interface BITAuthenticator : BITHockeyBaseManager

#pragma mark - Configuration

/**
 * Defines the authentication mechanism to be used
 * 
 * _Default_: BITAuthenticatorAuthTypeUDIDProvider
 */
@property (nonatomic, assign) BITAuthenticatorAuthType authenticationType;

/**
 *	_Default_: BITAuthenticatorValidationTypeNever
 */
@property (nonatomic, assign) BITAuthenticatorValidationType validationType;

@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

/**
 The authentication token from HockeyApp.
 
 Set the token to the `Secret ID` which HockeyApp provides for every app.
 
 When running the app from the App Store, this setting is ignored.
 */
@property (nonatomic, copy) NSString *authenticationSecret;

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
