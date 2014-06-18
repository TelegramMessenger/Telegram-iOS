/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
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


#import "BITAuthenticator.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITAuthenticationViewController.h"
@class BITHockeyAppClient;

@interface BITAuthenticator ()<BITAuthenticationViewControllerDelegate, UIAlertViewDelegate>

/**
 Delegate that can be used to do any last minute configurations on the
 presented viewController.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 @see BITAuthenticatorDelegate
 */
@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

/**
 * must be set
 */
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

#pragma mark -
/**
 *  holds the identifier of the last version that was authenticated
 *  only used if validation is set BITAuthenticatorValidationTypeOnFirstLaunch
 */
@property (nonatomic, copy) NSString *lastAuthenticatedVersion;

/**
 *  returns the type of the string stored in installationIdentifierParameterString
 */
@property (nonatomic, copy, readonly) NSString *installationIdentifierParameterString;

/**
 *  returns the string used to identify this app against the HockeyApp backend.
 */
@property (nonatomic, copy, readonly) NSString *installationIdentifier;

/**
 * method registered as observer for applicationDidEnterBackground events
 *
 * @param note NSNotification
 */
- (void) applicationDidEnterBackground:(NSNotification*) note;

/**
 * method registered as observer for applicationsDidBecomeActive events
 *
 * @param note NSNotification
 */
- (void) applicationDidBecomeActive:(NSNotification*) note;

@property (nonatomic, copy) void(^identificationCompletion)(BOOL identified, NSError* error);

#pragma mark - Overrides
@property (nonatomic, assign, readwrite, getter = isIdentified) BOOL identified;
@property (nonatomic, assign, readwrite, getter = isValidated) BOOL validated;

#pragma mark - Testing
- (void) storeInstallationIdentifier:(NSString*) identifier withType:(BITAuthenticatorIdentificationType) type;
- (BOOL) needsValidation;
- (void) authenticate;
@end
