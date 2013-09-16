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

/**
 * Auth types
 */
typedef NS_ENUM(NSUInteger, BITAuthenticatorAuthType) {
  /**
   * Ask for the HockeyApp account email
   */
  BITAuthenticatorAuthTypeEmail,
  /**
   * Ask for the HockeyApp account email and password
   */
  BITAuthenticatorAuthTypeEmailAndPassword,
  /**
   * Request the device UDID
   */
  BITAuthenticatorAuthTypeUDIDProvider
};

/**
 *  Validation types
 */
typedef NS_ENUM(NSUInteger, BITAuthenticatorValidationType) {
  /**
   * Never validate if the user is allowed to run the app
   */
  BITAuthenticatorValidationTypeNever = 0,
  /**
   * Optionally validate if the user is authorized; user can skip the process
   */
  BITAuthenticatorValidationTypeOptional,
  /**
   * Check if the user is authenticated at the first time a new version is started
   */
  BITAuthenticatorValidationTypeOnFirstLaunch,
  /**
   * Check if the user is authenticated everytime the app becomes active
   */
  BITAuthenticatorValidationTypeOnAppActive,
};

typedef void(^tAuthenticationCompletion)(NSString* authenticationToken, NSError *error);
typedef void(^tValidationCompletion)(BOOL validated, NSError *error);

@protocol BITAuthenticatorDelegate;

/**
 * Authenticator module used to identify and optionally authenticate the current app user
 *
 * This is the HockeySDK module for handling authentication when using Ad-Hoc or Enterprise provisioning profiles.
 * This module allows you to make sure the current app installation is done on an authorzied device by choosing from
 * various authentication and validation mechanisms which provide different levels of authentication.
 *
 * This does not provide DRM or copy protection in any form. Each authentication type and validation type provide
 * a different level of user authorization.
 *
 * This module automatically disables itself when running in an App Store build by default!
 *
 * Authentication is a 2 step process:
 *
 *    1. authenticate:
 *       a token is acquired depending on the `authenticationType`
 *    2. validation:
 *       the acquired token from step 1 is validated depending the `validationType`
 *
 * There are currently 3 ways of authentication (`BITAuthenticatorAuthType`):
 *
 *    1. authenticate the user via email only (`BITAuthenticatorAuthTypeEmail`)
 *    2. authenticate the user via email & password (`BITAuthenticatorAuthTypeEmailAndPassword`)
 *    3. authenticate the device via its UDID (_Default_) (`BITAuthenticatorAuthTypeUDIDProvider`)
 *
 * There are currently 4 ways of validation (`BITAuthenticatorValidationType`):
 *
 *    1. never (_Default_) (`BITAuthenticatorValidationTypeNever`)
 *    2. optional (`BITAuthenticatorValidationTypeOptional`)
 *    3. on first launch of a new app version (`BITAuthenticatorValidationTypeOnFirstLaunch`)
 *    4. every time the app becomes active (needs internet connection) (`BITAuthenticatorValidationTypeOnAppActive`)
 *
 */
@interface BITAuthenticator : BITHockeyBaseManager

#pragma mark - Configuration

/**
 * Defines the authentication mechanism to be used
 *
 * The values are listed here: `BITAuthenticatorAuthType`:
 *
 *    1. `BITAuthenticatorAuthTypeEmail`: authenticate the user via email only
 *    2. `BITAuthenticatorAuthTypeEmailAndPassword`: authenticate the user via email & password
 *    3. `BITAuthenticatorAuthTypeUDIDProvider`: authenticate the device via its UDID (_Default_)
 *
 * _Default_: `BITAuthenticatorAuthTypeUDIDProvider`
 */
@property (nonatomic, assign) BITAuthenticatorAuthType authenticationType;

/**
 * Defines the validation mechanism to be used
 *
 * The values are listed here: `BITAuthenticatorValidationType`:
 *
 *    1. `BITAuthenticatorValidationTypeNever`: never (_Default_)
 *    2. `BITAuthenticatorValidationTypeOptional`: optional
 *    3. `BITAuthenticatorValidationTypeOnFirstLaunch`: on first launch of a new app version
 *    4. `BITAuthenticatorValidationTypeOnAppActive`: every time the app becomes active (needs internet connection)
 *
 * _Default_: `BITAuthenticatorValidationTypeNever`
 */
@property (nonatomic, assign) BITAuthenticatorValidationType validationType;

@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

/**
 * The authentication secret from HockeyApp. To find the right secret, click on your app on the HockeyApp dashboard,
 * then on Show next to "Secret:".
 *
 * When running the app from the App Store, this setting is ignored.
 */
@property (nonatomic, copy) NSString *authenticationSecret;

#pragma mark - UDID auth

/**
 * baseURL of the webpage the user is redirected to if authenticationType is BITAuthenticatorAuthTypeUDIDProvider
 * defaults to https://rink.hockeyapp.net
 */
@property (nonatomic, strong) NSURL *webpageURL;

/**
 Should be used by the app-delegate to forward handle application:openURL:sourceApplication:annotation: calls

 Sample usage (in AppDelegate):
 
    - (BOOL)application:(UIApplication *)application
                openURL:(NSURL *)url
      sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
      if ([[BITHockeyManager sharedHockeyManager].authenticator handleOpenURL:url
                                                            sourceApplication:sourceApplication
                                                                   annotation:annotation]) {
        return YES;
      } else {
        //do your own URL handling, return appropriate valu
      }
      return NO;
    }
 
  @param url The URL that was passed to the app
  @param sourceApplication sourceApplication that was passed to the app
  @param annotation annotation that was passed to the app
 
  @return YES if the URL request was handled, NO if the URL could not be handled/identified
 
 */
- (BOOL) handleOpenURL:(NSURL *) url
     sourceApplication:(NSString *) sourceApplication
            annotation:(id) annotation;

@end

#pragma mark - Protocol

/**
 * BITAuthenticator protocol
 */
@protocol BITAuthenticatorDelegate <NSObject>

@optional
/**
 * If the authentication (or validation) needs to authenticate the user, 
 * this delegate method is called with the viewController that we'll present.
 *
 * @param authenticator authenticator object
 * @param viewController viewcontroller used to authenticate the user
 *
 */
- (void) authenticator:(BITAuthenticator *)authenticator willShowAuthenticationController:(UIViewController*) viewController;

@end
