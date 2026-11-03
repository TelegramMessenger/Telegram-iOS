#import <Foundation/Foundation.h>

@class MTSignal;
@class MTContext;
@class MTSocksProxySettings;

@interface MTConnectionProbing : NSObject

+ (MTSignal *)probeProxyWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId settings:(MTSocksProxySettings *)settings;

@end
