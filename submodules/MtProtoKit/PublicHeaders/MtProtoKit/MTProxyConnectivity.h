#import <Foundation/Foundation.h>

@class MTSignal;
@class MTContext;
@class MTSocksProxySettings;

@interface MTProxyConnectivityStatus : NSObject

@property (nonatomic, readonly) bool reachable;
@property (nonatomic, readonly) NSTimeInterval roundTripTime;

@end

@interface MTProxyConnectivity : NSObject

+ (MTSignal *)pingProxyWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId settings:(MTSocksProxySettings *)settings;

/// Whether MtProtoKit's TCP reaches the datacenter: req_pq_multi to each of its addresses (the ones
/// discovery would probe, through the context's proxy and TCP connection factory, as MtProtoKit
/// connects), and a matching res_pq from any of them within `timeout` seconds. Puts @true or @false,
/// then completes. Used by the local health check of another engine; sends nothing else.
+ (MTSignal *)probeDatacenterWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId timeout:(NSTimeInterval)timeout;

@end
