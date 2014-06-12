/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

@class MTQueue;
@class MTTcpConnectionBehaviour;

@protocol MTTcpConnectionBehaviourDelegate <NSObject>

@optional

- (void)tcpConnectionBehaviourRequestsReconnection:(MTTcpConnectionBehaviour *)behaviour;

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
