/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAuthAction;

@protocol MTDatacenterAuthActionDelegate <NSObject>

- (void)datacenterAuthActionCompleted:(MTDatacenterAuthAction *)action;

@end

@interface MTDatacenterAuthAction : NSObject

@property (nonatomic, weak) id<MTDatacenterAuthActionDelegate> delegate;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)cancel;

@end
