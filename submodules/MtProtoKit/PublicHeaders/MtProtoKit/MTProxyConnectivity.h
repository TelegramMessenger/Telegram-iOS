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

@end
