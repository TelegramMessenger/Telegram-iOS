#import <Foundation/Foundation.h>

#import "MTSignal.h"
#import "MTContext.h"

@interface MTDiscoverConnectionSignals : NSObject

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList media:(bool)media;

@end
