#import <Foundation/Foundation.h>

@interface MTBuffer : NSObject

- (void)appendInt32:(int32_t)value;
- (void)appendInt64:(int64_t)value;
- (void)appendBytes:(void const *)bytes length:(NSUInteger)length;

- (NSData *)data;

@end

@interface MTBuffer (TL)

- (void)appendTLBytes:(NSData *)bytes;
- (void)appendTLString:(NSString *)string;

@end