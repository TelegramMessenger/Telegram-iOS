/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTMessageService.h>

@class MTTimeSyncMessageService;

@protocol MTTimeSyncMessageServiceDelegate <NSObject>

@optional

- (void)timeSyncServiceCompleted:(MTTimeSyncMessageService *)timeSyncService timeDifference:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList;

@end

@interface MTTimeSyncMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTimeSyncMessageServiceDelegate> delegate;

@end
