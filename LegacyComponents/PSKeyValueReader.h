#import <Foundation/Foundation.h>

#import <LegacyComponents/PSData.h>

typedef enum {
    PSKeyValueReaderSelectLowerKey = 0,
    PSKeyValueReaderSelectHigherKey = 1
} PSKeyValueReaderSelectKey;

typedef enum {
    PSKeyValueReaderEnumerationReverse = 1,
    PSKeyValueReaderEnumerationLowerBoundExclusive = 2,
    PSKeyValueReaderEnumerationUpperBoundExclusive = 4
} PSKeyValueReaderEnumerationOptions;

@protocol PSKeyValueReader <NSObject>

- (bool)readValueForRawKey:(PSConstData *)key value:(PSConstData *)value;

- (bool)readValueBetweenLowerBoundKey:(PSConstData *)lowerBoundKey upperBoundKey:(PSConstData *)upperBoundKey selectKey:(PSKeyValueReaderSelectKey)selectKey selectedKey:(PSConstData *)selectedKey selectedValue:(PSConstData *)selectedValue;

- (void)enumerateKeysAndValuesBetweenLowerBoundKey:(PSConstData *)lowerBoundKey upperBoundKey:(PSConstData *)upperBoundKey options:(NSInteger)options withBlock:(void (^)(PSConstData *key, PSConstData *value, bool *stop))block;

@end
