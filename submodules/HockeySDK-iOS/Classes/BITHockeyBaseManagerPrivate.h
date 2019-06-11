/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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
#import "BITHockeyManager.h"

@class BITHockeyBaseManager;
@class BITHockeyBaseViewController;

@interface BITHockeyBaseManager()

@property (nonatomic, copy) NSString *appIdentifier;

@property (nonatomic, assign, readonly) BITEnvironment appEnvironment;

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment;

- (void)startManager;

/** 
 * by default, just logs the message
 *
 * can be overridden by subclasses to do their own error handling,
 * e.g. to show UI
 *
 * @param error NSError
 */
- (void)reportError:(NSError *)error;

/** url encoded version of the appIdentifier
 
 where appIdentifier is either the value this object was initialized with,
 or the main bundles CFBundleIdentifier if appIdentifier is nil
 */
- (NSString *)encodedAppIdentifier;

// device / application helpers
- (NSString *)getDevicePlatform;
- (NSString *)executableUUID;

#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
// UI helpers
- (UIWindow *)findVisibleWindow;
- (UINavigationController *)customNavigationControllerWithRootViewController:(UIViewController *)viewController presentationStyle:(UIModalPresentationStyle)presentationStyle;

/**
 *  Present an UIAlertController on the visible root UIViewController.
 *
 *  Uses `visibleWindowRootViewController` to find a controller on which to present the UIAlertController on.
 *  This method is always dispatched on the main queue.
 *
 *  @param alertController The UIAlertController to be presented.
 */
- (void)showAlertController:(UIViewController *)alertController;

- (void)showView:(UIViewController *)viewController;
#endif

// Date helpers
- (NSDate *)parseRFC3339Date:(NSString *)dateString;

// keychain helpers
- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key;
- (BOOL)addStringValueToKeychainForThisDeviceOnly:(NSString *)stringValue forKey:(NSString *)key;
- (NSString *)stringValueFromKeychainForKey:(NSString *)key;
- (BOOL)removeKeyFromKeychain:(NSString *)key;

@end
