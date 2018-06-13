

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
