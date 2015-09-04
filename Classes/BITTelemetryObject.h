#import <Foundation/Foundation.h>

@class BITOrderedDictionary;

@interface BITTelemetryObject : NSObject <NSCoding>

- (BITOrderedDictionary *)serializeToDictionary;
- (NSString *)serializeToString;

@end
