

#import <Foundation/Foundation.h>

@interface MTOutputStream : NSObject

- (NSOutputStream *)wrappedOutputStream;

- (NSData *)currentBytes;

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (void)writeInt32:(int32_t)value;
- (void)writeInt64:(int64_t)value;
- (void)writeDouble:(double)value;
- (void)writeData:(NSData *)data;
- (void)writeString:(NSString *)data;
- (void)writeBytes:(NSData *)data;

@end
