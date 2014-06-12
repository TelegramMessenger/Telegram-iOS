/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;
@class MTDiscoverDatacenterAddressAction;

@protocol MTDiscoverDatacenterAddressActionDelegate <NSObject>

- (void)discoverDatacenterAddressActionCompleted:(MTDiscoverDatacenterAddressAction *)action;

@end

@interface MTDiscoverDatacenterAddressAction : NSObject

@property (nonatomic, weak) id<MTDiscoverDatacenterAddressActionDelegate> delegate;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)cancel;

@end