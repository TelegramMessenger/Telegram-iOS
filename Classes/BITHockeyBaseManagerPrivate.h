//
//  CNSHockeyBaseManager+Private.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class BITHockeyBaseManager;
@class BITHockeyBaseViewController;

@interface BITHockeyBaseManager()

@property (nonatomic, strong) NSString *appIdentifier;

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironment:(BOOL)isAppStoreEnvironment;

- (void)startManager;

/** the value this object was initialized with */
- (BOOL)isAppStoreEnvironment;

/** Check if the device is running an iOS version previous to iOS 7 */
- (BOOL)isPreiOS7Environment;

/** 
 * by default, just logs the message
 *
 * can be overriden by subclasses to do their own error handling,
 * e.g. to show UI
 *
 * @param error NSError
 */
- (void)reportError:(NSError *)error;

/** url encoded version of the appIdentifier
 
 where appIdentifier is either the value this object was initialized with,
 or the main bundles CFBundleIdentifier if appIdentifier ist nil
 */
- (NSString *)encodedAppIdentifier;

// device / application helpers
- (NSString *)getDevicePlatform;
- (NSString *)executableUUID;

// UI helpers
- (UINavigationController *)customNavigationControllerWithRootViewController:(UIViewController *)viewController presentationStyle:(UIModalPresentationStyle)presentationStyle;
- (void)showView:(UIViewController *)viewController;

// Date helpers
- (NSDate *)parseRFC3339Date:(NSString *)dateString;

// keychain helpers
- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key;
- (BOOL)addStringValueToKeychainForThisDeviceOnly:(NSString *)stringValue forKey:(NSString *)key;
- (NSString *)stringValueFromKeychainForKey:(NSString *)key;
- (BOOL)removeKeyFromKeychain:(NSString *)key;

@end
