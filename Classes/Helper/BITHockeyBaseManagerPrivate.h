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

@interface BITHockeyBaseManager() {
  UINavigationController *_navController;
  UIBarStyle _barStyle;
  UIModalPresentationStyle _modalPresentationStyle;
  
  NSDateFormatter *_rfc3339Formatter;

  BOOL _isAppStoreEnvironment;
}

// set the server URL
@property (nonatomic, retain) NSString *serverURL;

@property (nonatomic, retain) NSString *appIdentifier;

- (id)initWithAppIdentifier:(NSString *)appIdentifier isAppStoreEnvironemt:(BOOL)isAppStoreEnvironment;

- (void)startManager;

- (void)reportError:(NSError *)error;
- (NSString *)encodedAppIdentifier;

- (NSString *)getDevicePlatform;

- (UIWindow *)findVisibleWindow;
- (void)showView:(BITHockeyBaseViewController *)viewController;

- (NSData *)appendPostValue:(NSString *)value forKey:(NSString *)key;

- (NSDate *)parseRFC3339Date:(NSString *)dateString;

@end