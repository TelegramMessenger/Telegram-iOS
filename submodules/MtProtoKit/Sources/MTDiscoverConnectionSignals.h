#import <Foundation/Foundation.h>

@class MTContext;
@class MTDatacenterAddress;
@class MTSignal;
@class MTQueue;
@class MTDatacenterAuthKey;
@class MTSocksProxySettings;

typedef struct {
    uint8_t nonce[16];
} MTPayloadData;

@interface MTDiscoverConnectionSignals : NSObject

+ (NSData * _Nonnull)payloadData:(MTPayloadData * _Nonnull)outPayloadData context:(MTContext * _Nonnull)context address:(MTDatacenterAddress * _Nonnull)address;

+ (MTSignal * _Nonnull)discoverSchemeWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId addressList:(NSArray * _Nonnull)addressList media:(bool)media isProxy:(bool)isProxy;

// The addresses a discovery round actually probes. Under an MTProxy or WEB relay the
// destination address is ignored by the proxy, so the list collapses to one entry.
+ (NSArray<MTDatacenterAddress *> * _Nonnull)probeAddressesForAddressList:(NSArray * _Nonnull)addressList media:(bool)media isProxy:(bool)isProxy proxySettings:(MTSocksProxySettings * _Nullable)proxySettings;

// Extra TCP ports tried beside each IPv4 address; empty when a proxy is configured.
+ (NSArray<NSNumber *> * _Nonnull)alternatePortsForProxySettings:(MTSocksProxySettings * _Nullable)proxySettings;

// Re-runs `signal` after it completes, waiting `initialDelay` before the second run and
// doubling the wait each time up to `maxDelay`. Values pass straight through; `take:` to stop.
+ (MTSignal * _Nonnull)repeatSignal:(MTSignal * _Nonnull)signal withBackoffFrom:(NSTimeInterval)initialDelay upTo:(NSTimeInterval)maxDelay onQueue:(MTQueue * _Nonnull)queue;

+ (MTSignal * _Nonnull)checkIfAuthKeyRemovedWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authKey:(MTDatacenterAuthKey * _Nonnull)authKey;

@end
