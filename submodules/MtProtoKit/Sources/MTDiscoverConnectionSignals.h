#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAddress;
@class MTSignal;
@class MTDatacenterAuthKey;

typedef struct {
    uint8_t nonce[16];
} MTPayloadData;

@interface MTDiscoverConnectionSignals : NSObject

+ (NSData * _Nonnull)payloadData:(MTPayloadData * _Nonnull)outPayloadData context:(MTContext * _Nonnull)context address:(MTDatacenterAddress * _Nonnull)address;

+ (MTSignal * _Nonnull)discoverSchemeWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId addressList:(NSArray * _Nonnull)addressList media:(bool)media isProxy:(bool)isProxy;

+ (MTSignal * _Nonnull)checkIfAuthKeyRemovedWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authKey:(MTDatacenterAuthKey * _Nonnull)authKey;

@end
