/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTQueue;
@class MTHttpWorkerBehaviour;

@protocol MTHttpWorkerBehaviourDelegate <NSObject>

@optional

- (void)httpWorkerBehaviourAllowsNewWorkerCreation:(MTHttpWorkerBehaviour *)behaviour;

@end

@interface MTHttpWorkerBehaviour : NSObject

@property (nonatomic, weak) id<MTHttpWorkerBehaviourDelegate> delegate;

- (instancetype)initWithQueue:(MTQueue *)queue;

- (void)clearBackoff;

- (void)setWorkersNeeded;
- (void)workerConnected;
- (void)workerReceivedValidData;
- (void)workerDisconnectedWithError;

@end
