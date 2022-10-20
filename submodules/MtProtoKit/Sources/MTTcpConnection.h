#import <Foundation/Foundation.h>

@class MTDatacenterAddress;
@class MTContext;
@class MTQueue;
@class MTTcpConnection;
@class MTNetworkUsageCalculationInfo;
@class MTTransportScheme;

@protocol MTTcpConnectionDelegate <NSObject>

@optional

- (void)tcpConnectionOpened:(MTTcpConnection *)connection;
- (void)tcpConnectionClosed:(MTTcpConnection *)connection error:(bool)error;
- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data;
- (void)tcpConnectionReceivedQuickAck:(MTTcpConnection *)connection quickAck:(int32_t)quickAck;
- (void)tcpConnectionDecodePacketProgressToken:(MTTcpConnection *)connection data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id packetProgressToken))completion;
- (void)tcpConnectionProgressUpdated:(MTTcpConnection *)connection packetProgressToken:(id)packetProgressToken packetLength:(NSUInteger)packetLength progress:(float)progress;

@end

@interface MTTcpConnection : NSObject

@property (nonatomic, weak) id<MTTcpConnectionDelegate> delegate;

@property (nonatomic, copy) void (^connectionOpened)();
@property (nonatomic, copy) void (^connectionClosed)();
@property (nonatomic, copy) void (^connectionReceivedData)(NSData *);

@property (nonatomic, strong, readonly) id internalId;
@property (nonatomic, strong, readonly) MTTransportScheme *scheme;
@property (nonatomic, strong, readonly) NSString *interface;

@property (nonatomic, strong) NSString *(^getLogPrefix)();

+ (MTQueue *)tcpQueue;

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId scheme:(MTTransportScheme *)scheme interface:(NSString *)interface usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo getLogPrefix:(NSString *(^)())getLogPrefix;

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo;

- (void)start;
- (void)stop;

- (void)sendDatas:(NSArray *)datas completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse;

@end
