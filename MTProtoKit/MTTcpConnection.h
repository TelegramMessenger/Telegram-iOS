/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTDatacenterAddress.h>

@class MTQueue;
@class MTTcpConnection;

/*!
 MTTcpConnection delegate protocol
 
 Note: messages could be sent to the receiver from an arbitrary thread, do not make assumtions.
 */

@protocol MTTcpConnectionDelegate <NSObject>

@optional

- (void)tcpConnectionOpened:(MTTcpConnection *)connection;
- (void)tcpConnectionClosed:(MTTcpConnection *)connection;
- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data;
- (void)tcpConnectionReceivedQuickAck:(MTTcpConnection *)connection quickAck:(int32_t)quickAck;
- (void)tcpConnectionDecodePacketProgressToken:(MTTcpConnection *)connection data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id packetProgressToken))completion;
- (void)tcpConnectionProgressUpdated:(MTTcpConnection *)connection packetProgressToken:(id)packetProgressToken packetLength:(NSUInteger)packetLength progress:(float)progress;

@end

@interface MTTcpConnection : NSObject

@property (nonatomic, weak) id<MTTcpConnectionDelegate> delegate;
@property (nonatomic, strong, readonly) id internalId;
@property (nonatomic, strong, readonly) MTDatacenterAddress *address;
@property (nonatomic, strong, readonly) NSString *interface;

+ (MTQueue *)tcpQueue;

- (instancetype)initWithAddress:(MTDatacenterAddress *)address interface:(NSString *)interface;

- (void)start;
- (void)stop;

- (void)sendDatas:(NSArray *)datas completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse;

@end
