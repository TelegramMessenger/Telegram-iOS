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

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment;

- (void)startManager;

- (void)reportError:(NSError *)error;
- (NSString *)encodedAppIdentifier;
- (BOOL)isAppStoreEnvironment;

- (NSString *)getDevicePlatform;
- (NSString *)executableUUID;

- (UIWindow *)findVisibleWindow;
- (void)showView:(UIViewController *)viewController;

- (NSData *)appendPostValue:(NSString *)value forKey:(NSString *)key;

- (NSDate *)parseRFC3339Date:(NSString *)dateString;

- (BOOL)addStringValueToKeychain:(NSString *)stringValue forKey:(NSString *)key;
- (NSString *)stringValueFromKeychainForKey:(NSString *)key;
- (BOOL)removeKeyFromKeychain:(NSString *)key;

@end
