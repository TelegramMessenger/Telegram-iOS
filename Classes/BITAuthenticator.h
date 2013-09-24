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
 * Identification Types
 */
typedef NS_ENUM(NSUInteger, BITAuthenticatorIdentificationType) {
  /**
   * Assigns this app an anonymous user id
   */
  BITAuthenticatorIdentificationTypeAnonymous,
  /**
   * Ask for the HockeyApp account email
   */
  BITAuthenticatorIdentificationTypeHockeyAppEmail,
  /**
   * Ask for the HockeyApp account by email and password
   */
  BITAuthenticatorIdentificationTypeHockeyAppUser,
  /**
   * Identifies the current device
   */
  BITAuthenticatorIdentificationTypeDevice,
};

/**
 *  BITAuthenticatorAppRestrictionEnforcementFrequency
 *  Specifies how often the Authenticator checks if the user is allowed to use
 *  use this app.
 */
typedef NS_ENUM(NSUInteger, BITAuthenticatorAppRestrictionEnforcementFrequency) {
  /**
   * Check if the user is allowed to use the app the first time a version is started
   */
  BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch,
  /**
   * Check if the user is allowed to use the app everytime the app becomes active
   */
  BITAuthenticatorAppRestrictionEnforcementOnAppActive,
};

@protocol BITAuthenticatorDelegate;

@interface BITAuthenticator : BITHockeyBaseManager

#pragma mark - Configuration

/**
 * Defines the identification mechanism to be used
 *
 * _Default_: `BITAuthenticatorIdentificationTypeAnonymous`
 *
 * @see BITAuthenticatorIdentificationType
 */
@property (nonatomic, assign) BITAuthenticatorIdentificationType identificationType;

/**
 *  Defines if the BITAuthenticator automatically identifies the user and also
 *  checks if he's still allowed to use the app (depending on `restrictApplicationUsage`)
 *
 * _Default_: `YES`
 *
 */
@property (nonatomic, assign) BOOL automaticMode;

/**
 *  Enables or disables checking if the user is allowed to run this app
 *
 *  _Default_: `YES`
 */
@property (nonatomic, assign) BOOL restrictApplicationUsage;

/**
 * Defines how often the BITAuthenticator checks if the user is allowed
 * to run this application
 *
 * _Default_: `BITAuthenticatorAppRestrictionEnforcementOnFirstLaunch`
 *
 * @see BITAuthenticatorAppRestrictionEnforcementFrequency
 */
@property (nonatomic, assign) BITAuthenticatorAppRestrictionEnforcementFrequency restrictionEnforcementFrequency;

/**
 * The authentication secret from HockeyApp. To find the right secret, click on your app on the HockeyApp dashboard,
 * then on Show next to "Secret:".
 *
 * When running the app from the App Store, this setting is ignored.
 */
@property (nonatomic, copy) NSString *authenticationSecret;

/**
 *  Delegate that can be used to do any last minute configurations on the presented viewController.
 */
@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;


#pragma mark - UDID auth
/**
 * baseURL of the webpage the user is redirected to if authenticationType is BITAuthenticatorAuthTypeUDIDProvider
 * defaults to https://rink.hockeyapp.net
 */
@property (nonatomic, strong) NSURL *webpageURL;

/**
 * url-scheme used to do idenfify via `BITAuthenticatorAuthTypeUDIDProvider`
 *
 * If set to nil, the default scheme is used which is ha<APP_ID>.
 */
@property (nonatomic, strong) NSString *urlScheme;

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
        //do your own URL handling, return appropriate value
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

#pragma mark - Authentication

/**
 *  Identifies the user according to the type specified in `identificationType`
 *  If the BITAuthenticator is in manual mode, it's your responsibility to call
 *  this method. Depending on the `identificationType`, this method
 *  might present a viewController to let the user enter his/her credentials.
 *  If the Authenticator is in auto-mode, this is called by the authenticator itself
 *  once needed.
 */
- (void) identifyWithCompletion:(void(^)(BOOL identified, NSError *error)) completion;

/**
 *  returns YES if this app is identified according to the setting in `identificationType`
 */
@property (nonatomic, assign, readonly, getter = isIdentified) BOOL identified;

/**
 *  Validates if the identified user is allowed to run this application. This checks
 *  with the HockeyApp backend and calls the completion-block once completed.
 *  If the BITAuthenticator is in manual mode, it's your responsibility to call
 *  this method. If the application is not yet identified, validation is not possible
 *  and the completion-block is called with an error set.
 *  If the Authenticator is in auto-mode, this is called by the authenticator itself
 *  once needed.
 */
- (void) validateWithCompletion:(void(^)(BOOL validated, NSError *error)) completion;

@property (nonatomic, assign, readonly, getter = isValidated) BOOL validated;

/**
 * removes all previously stored authentication tokens, UDIDs, etc
 */
- (void) cleanupInternalStorage;

/**
 * can be used by the application to identify the user.
 * returns different values depending on `identificationType`.
 */
- (NSString*) publicInstallationIdentifier;
@end

#pragma mark - Protocol

/**
 * BITAuthenticator protocol
 */
@protocol BITAuthenticatorDelegate <NSObject>

@optional
/**
 * If the authentication (or validation) needs to identify the user,
 * this delegate method is called with the viewController that we'll present.
 *
 * @param authenticator authenticator object
 * @param viewController viewcontroller used to identify the user
 *
 */
- (void) authenticator:(BITAuthenticator *)authenticator willShowAuthenticationController:(UIViewController*) viewController;
@end
