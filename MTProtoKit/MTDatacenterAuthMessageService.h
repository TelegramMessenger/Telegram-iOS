/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTMessageService.h>

@class MTContext;
@class MTDatacenterAuthMessageService;
@class MTDatacenterAuthInfo;

@protocol MTDatacenterAuthMessageServiceDelegate <NSObject>

- (void)authMessageServiceCompletedWithAuthInfo:(MTDatacenterAuthInfo *)authInfo;

@end

@interface MTDatacenterAuthMessageService : NSObject <MTMessageService>

#ifdef DEBUG
+ (NSDictionary *)testEncryptedRsaDataSha1ToData;
#endif

@property (nonatomic, weak) id<MTDatacenterAuthMessageServiceDelegate> delegate;

- (instancetype)initWithContext:(MTContext *)context;

@end
