#import "MTBuffer.h"

@interface MTBufferReader : NSObject

- (instancetype)initWithData:(NSData *)data;

- (bool)readBytes:(void *)bytes length:(NSUInteger)length;
- (bool)readInt32:(int32_t *)value;
- (bool)readInt64:(int64_t *)value;
// Returns the next `length` bytes as their own NSData and advances, or nil when
// fewer remain. Checks before allocating, so an untrusted length costs nothing.
- (NSData *)readData:(NSUInteger)length;
- (NSData *)readRest;

@end

@interface MTBufferReader (TL)

- (bool)readTLString:(__autoreleasing NSString **)value;
- (bool)readTLBytes:(__autoreleasing NSData **)value;

@end
