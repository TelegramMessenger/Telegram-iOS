#import <Foundation/Foundation.h>

#import <SSignalKit/SSignalKit.h>
#import <MTProtoKit/MTContext.h>

@interface MTDiscoverConnectionSignals : NSObject

+ (SSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList preferMedia:(bool)preferMedia;

@end
