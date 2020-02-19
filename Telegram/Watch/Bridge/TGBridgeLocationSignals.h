#import <SSignalKit/SSignalKit.h>

@interface TGBridgeLocationSignals : NSObject

+ (SSignal *)currentLocation;
+ (SSignal *)nearbyVenuesWithLimit:(NSUInteger)limit;

@end

extern NSString *const TGBridgeLocationAccessRequiredKey;
extern NSString *const TGBridgeLocationLoadingKey;
