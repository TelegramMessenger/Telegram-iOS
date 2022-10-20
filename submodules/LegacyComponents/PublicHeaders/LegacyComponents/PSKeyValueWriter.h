#import <Foundation/Foundation.h>

#import <LegacyComponents/PSData.h>

@protocol PSKeyValueWriter <NSObject>

- (void)writeValueForRawKey:(const uint8_t *)key keyLength:(NSUInteger)keyLength value:(const uint8_t *)value valueLength:(NSUInteger)valueLength;
- (bool)deleteValueForRawKey:(PSData *)key;
- (void)deleteAllValues;

@end
