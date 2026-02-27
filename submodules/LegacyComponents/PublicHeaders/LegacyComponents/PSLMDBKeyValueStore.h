#import <LegacyComponents/PSKeyValueStore.h>

@interface PSLMDBKeyValueStore : NSObject <PSKeyValueStore>

+ (instancetype)storeWithPath:(NSString *)path size:(NSUInteger)size;

- (void)close;

@end
