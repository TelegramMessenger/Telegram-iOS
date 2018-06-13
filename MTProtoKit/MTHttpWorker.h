

#import "AFNetworking.h"

@class MTDatacenterAddress;
@class MTHttpWorker;
@class MTQueue;

@protocol MTHttpWorkerDelegate <NSObject>

@optional

- (void)httpWorker:(MTHttpWorker *)httpWorker completedWithData:(NSData *)data;
- (void)httpWorkerConnected:(MTHttpWorker *)httpWorker;
- (void)httpWorkerFailed:(MTHttpWorker *)httpWorker;

@end

@interface MTHttpWorkerBlockDelegate : NSObject <MTHttpWorkerDelegate>

@property (nonatomic, copy) void (^completedWithData)(NSData *);
@property (nonatomic, copy) void (^connected)();
@property (nonatomic, copy) void (^failed)();

@end

@interface MTHttpWorker : AFHTTPClient

@property (nonatomic, strong, readonly) id internalId;
@property (nonatomic, weak) id<MTHttpWorkerDelegate> delegate;
@property (nonatomic, readonly) bool performsLongPolling;

+ (MTQueue *)httpWorkerProcessingQueue;

- (instancetype)initWithDelegate:(id<MTHttpWorkerDelegate>)delegate address:(MTDatacenterAddress *)address payloadData:(NSData *)payloadData performsLongPolling:(bool)performsLongPolling;

- (bool)isConnected;

- (void)stop;
- (void)terminateWithFailure;

@end
