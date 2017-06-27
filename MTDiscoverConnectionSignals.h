#import <Foundation/Foundation.h>

@class MTContext;
@class MTSignal;

@interface MTDiscoverConnectionSignals : NSObject

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy;

@end
