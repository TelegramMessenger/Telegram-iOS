

#import <Foundation/Foundation.h>

@interface MTInputStream : NSObject

- (instancetype)initWithData:(NSData *)data;
- (NSInputStream *)wrappedInputStream;

- (int32_t)readInt32;
- (int32_t)readInt32:(bool *)failed __attribute__((nonnull(1)));
- (int64_t)readInt64;
- (int64_t)readInt64:(bool *)failed __attribute__((nonnull(1)));
- (double)readDouble;
- (double)readDouble:(bool *)failed __attribute__((nonnull(1)));
- (NSData *)readData:(int)length;
- (NSData *)readData:(int)length failed:(bool *)failed __attribute__((nonnull(2)));
- (NSMutableData *)readMutableData:(NSUInteger)length;
- (NSMutableData *)readMutableData:(NSUInteger)length failed:(bool *)failed __attribute__((nonnull(2)));
- (NSString *)readString;
- (NSString *)readString:(bool *)failed __attribute__((nonnull(1)));
- (NSData *)readBytes;
- (NSData *)readBytes:(bool *)failed __attribute__((nonnull(1)));

@end
