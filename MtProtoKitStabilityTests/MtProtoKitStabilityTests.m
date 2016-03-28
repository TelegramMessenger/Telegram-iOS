#import <XCTest/XCTest.h>

#import <MTProtoKit/MTProtoKit.h>
#import <MTProtoKit/MTTcpTransport.h>
#import <MTProtoKit/MTTransportTransaction.h>

@interface TestSerialization : NSObject <MTSerialization>

@end

@implementation TestSerialization

- (NSUInteger)currentLayer {
    return 42;
}

- (id)parseMessage:(NSData *)__unused data {
    return nil;
}

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data {
    return nil;
}

- (NSData *)importAuthorization:(int32_t)authId bytes:(NSData *)bytes {
    return nil;
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressList:(int32_t)datacenterId data:(__autoreleasing NSData **)data {
    return nil;
}

@end

@interface MtProtoKitStabilityTests : XCTestCase <MTTransportDelegate> {
    MTTcpTransport *_transport;
}

@end

@implementation MtProtoKitStabilityTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    MTApiEnvironment *apiEnvironment = [[MTApiEnvironment alloc] init];
    MTContext *context = [[MTContext alloc] initWithSerialization:[[TestSerialization alloc] init] apiEnvironment:apiEnvironment];
    
    //for (int i = 0; i < 100; i++) {
        _transport = [[MTTcpTransport alloc] initWithDelegate:self context:context datacenterId:1 address:[[MTDatacenterAddress alloc] initWithIp:@"149.154.175.50" port:443 preferForMedia:false]];
        _transport.delegate = self;
        [_transport setDelegateNeedsTransaction];
    //}
    sleep(2);
}

- (void)transportConnectionStateChanged:(MTTransport *)transport isConnected:(bool)isConnected {
    if (isConnected) {
        _transport = nil;
    }
}

- (void)transportReadyForTransaction:(MTTransport *)transport transportSpecificTransaction:(MTMessageTransaction *)transportSpecificTransaction forceConfirmations:(bool)forceConfirmations transactionReady:(void (^)(NSArray *))transactionReady {
    transactionReady(@[[[MTTransportTransaction alloc] initWithPayload:[NSData data] completion:^(bool success, id transactionId) {
        
    }]]);
}

@end
