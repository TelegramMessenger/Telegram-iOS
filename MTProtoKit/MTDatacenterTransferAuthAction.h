/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;

@class MTDatacenterTransferAuthAction;

@protocol MTDatacenterTransferAuthActionDelegate <NSObject>

- (void)datacenterTransferAuthActionCompleted:(MTDatacenterTransferAuthAction *)action;

@end

@interface MTDatacenterTransferAuthAction : NSObject

@property (nonatomic, weak) id<MTDatacenterTransferAuthActionDelegate> delegate;

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken;
- (void)cancel;

@end