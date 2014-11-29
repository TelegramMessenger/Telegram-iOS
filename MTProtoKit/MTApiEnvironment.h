/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTApiEnvironment : NSObject

@property (nonatomic) int32_t apiId;
@property (nonatomic, strong, readonly) NSString *deviceModel;
@property (nonatomic, strong, readonly) NSString *systemVersion;
@property (nonatomic, strong, readonly) NSString *appVersion;
@property (nonatomic, strong, readonly) NSString *langCode;
@property (nonatomic, strong) NSNumber *layer;

@property (nonatomic, strong, readonly) NSString *apiInitializationHash;

@property (nonatomic, copy) void (^passwordInputHandler)();

@end
