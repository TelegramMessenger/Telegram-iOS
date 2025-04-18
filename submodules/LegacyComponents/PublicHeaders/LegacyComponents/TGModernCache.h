#import <Foundation/Foundation.h>

@class SSignal;

@interface TGModernCache : NSObject

- (instancetype)initWithPath:(NSString *)path size:(NSUInteger)size;

- (void)setValue:(NSData *)value forKey:(NSData *)key;
- (void)getValueForKey:(NSData *)key completion:(void (^)(NSData *))completion;
- (void)getValuePathForKey:(NSData *)key completion:(void (^)(NSString *))completion;
- (NSData *)getValueForKey:(NSData *)key;
- (NSString *)getValuePathForKey:(NSData *)key;
- (bool)containsValueForKey:(NSData *)key;
- (NSString *)_filePathForKey:(NSData *)key;

- (SSignal *)cachedItemForKey:(NSData *)key;

@end
