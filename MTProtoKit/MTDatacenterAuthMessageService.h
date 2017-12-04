/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTMessageService.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTMessageService.h>
#else
#   import <MTProtoKit/MTMessageService.h>
#endif

@class MTContext;
@class MTDatacenterAuthMessageService;
@class MTDatacenterAuthKey;

@protocol MTDatacenterAuthMessageServiceDelegate <NSObject>

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp;

@end

@interface MTDatacenterAuthMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTDatacenterAuthMessageServiceDelegate> delegate;

- (instancetype)initWithContext:(MTContext *)context tempAuth:(bool)tempAuth;

@end
