#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTGzip : NSObject
    
+ (NSData * _Nullable)decompress:(NSData *)data;
+ (NSData * _Nullable)compress:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
