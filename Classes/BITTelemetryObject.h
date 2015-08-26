#import <Foundation/Foundation.h>
#import "HockeySDKPrivate.h"

@class BITOrderedDictionary;

@interface BITTelemetryObject : NSObject <NSCoding>

- (BITOrderedDictionary *)serializeToDictionary;
- (NSString *)serializeToString;

@end
