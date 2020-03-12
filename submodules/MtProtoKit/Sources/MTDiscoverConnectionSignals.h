#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAddress;
@class MTSignal;
@class MTDatacenterAuthKey;

typedef struct {
    uint8_t nonce[16];
} MTPayloadData;

@interface MTDiscoverConnectionSignals : NSObject

+ (NSData *)payloadData:(MTPayloadData *)outPayloadData context:(MTContext *)context address:(MTDatacenterAddress *)address;

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy;

+ (MTSignal * _Nonnull)checkIfAuthKeyRemovedWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authKey:(MTDatacenterAuthKey *)authKey;

@end
