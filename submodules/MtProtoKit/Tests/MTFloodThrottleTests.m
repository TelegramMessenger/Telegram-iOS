#import <XCTest/XCTest.h>

#import <MtProtoKit/MTTcpTransport.h>
#import <MtProtoKit/MTTransport.h>
#import <MtProtoKit/MTTransportScheme.h>

#import "MTTestSupport.h"

static const NSInteger kDatacenterId = 2;

// A -429 transport error (the server's transport flood limit) throttles the connection: no
// transaction is requested until a 5 s timer lifts it. The timer must run, or the connection
// stays throttled for the rest of the process, connected and silent: every request waits forever
// (the main session after a login's burst of requests showed "Connecting…" until the app was killed).
@interface MTFloodThrottleTests : XCTestCase
@end

@implementation MTFloodThrottleTests

- (void)testAFloodErrorThrottlesTheConnectionOnlyUntilItsTimerFires {
    MTContext *context = MTTestMakeContext(false);
    MTTestSetAddress(context, kDatacenterId, false);
    MTProto *proto = [[MTProto alloc] initWithContext:context datacenterId:kDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];

    MTTransport *transport = [[MTTransport alloc] initWithDelegate:nil context:context datacenterId:kDatacenterId schemes:@[] proxySettings:nil usageCalculationInfo:nil getLogPrefix:nil];
    MTTestOnManagerQueue(^{
        // The transport the connection reads from (`_transport`); incoming data from any other is ignored.
        [proto setValue:transport forKey:@"transport"];
    });

    int32_t floodCode = -429;
    NSData *data = [NSData dataWithBytes:&floodCode length:4];
    MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:MTTestMakeAddress(false) media:false];
    [(id<MTTransportDelegate>)proto transportHasIncomingData:transport scheme:scheme networkType:0 data:data transactionId:@1 requestTransactionAfterProcessing:false decodeResult:^(__unused id transactionId, __unused bool success) {
    }];

    __block bool throttled = false;
    MTTestOnManagerQueue(^{
        throttled = [[proto valueForKey:@"connectionThrottled"] boolValue];
    });
    XCTAssertTrue(throttled, "a -429 throttles the connection");

    bool lifted = MTTestWaitUntil(8.0, ^bool{
        __block bool stillThrottled = true;
        MTTestOnManagerQueue(^{
            stillThrottled = [[proto valueForKey:@"connectionThrottled"] boolValue];
        });
        return !stillThrottled;
    });
    XCTAssertTrue(lifted, "the throttle is lifted 5 s after the -429");

    [proto stop];
}

@end
