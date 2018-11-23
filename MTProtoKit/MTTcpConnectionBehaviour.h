

@class MTQueue;
@class MTTcpConnectionBehaviour;

#import <Foundation/Foundation.h>

@protocol MTTcpConnectionBehaviourDelegate <NSObject>

@optional

- (void)tcpConnectionBehaviourRequestsReconnection:(MTTcpConnectionBehaviour *)behaviour error:(bool)error;

@end

@interface MTTcpConnectionBehaviour : NSObject

@property (nonatomic, weak) id<MTTcpConnectionBehaviourDelegate> delegate;

@property (nonatomic, strong, readonly) MTQueue *queue;
@property (nonatomic) bool needsReconnection;

- (instancetype)initWithQueue:(MTQueue *)queue;

- (void)requestConnection;
- (void)connectionOpened;
- (void)connectionValidDataReceived;
- (void)connectionClosed;
- (void)clearBackoff;

@end
