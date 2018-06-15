#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAddress;
@class MTSignal;

typedef struct {
    uint8_t nonce[16];
} MTPayloadData;

@interface MTDiscoverConnectionSignals : NSObject

+ (NSData *)payloadData:(MTPayloadData *)outPayloadData context:(MTContext *)context address:(MTDatacenterAddress *)address;

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy;

@end
