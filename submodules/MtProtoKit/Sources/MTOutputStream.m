#import <MtProtoKit/MTOutputStream.h>

#if TARGET_OS_IPHONE
#   import <endian.h>
#endif

static inline int roundUp(int numToRound, int multiple)
{
    return multiple == 0 ? numToRound : ((numToRound % multiple) == 0 ? numToRound : (numToRound + multiple - (numToRound % multiple)));
}

@interface MTOutputStream ()
{
    NSOutputStream *_wrappedOutputStream;
}

@end

@implementation MTOutputStream

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _wrappedOutputStream = [[NSOutputStream alloc] initToMemory];
        [_wrappedOutputStream open];
    }
    return self;
}

- (NSOutputStream *)wrappedOutputStream
{
    return _wrappedOutputStream;
}

- (void)dealloc
{
    [_wrappedOutputStream close];
}

- (NSData *)currentBytes
{
    return [_wrappedOutputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len
{
    return [_wrappedOutputStream write:buffer maxLength:len];
}

- (void)writeInt32:(int32_t)value
{
#if __BYTE_ORDER == __LITTLE_ENDIAN
    [_wrappedOutputStream write:(const uint8_t *)&value maxLength:4];
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
}

- (void)writeInt64:(int64_t)value
{
#if __BYTE_ORDER == __LITTLE_ENDIAN
    [_wrappedOutputStream write:(const uint8_t *)&value maxLength:8];
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
}

- (void)writeDouble:(double)value
{
#if __BYTE_ORDER == __LITTLE_ENDIAN
    [_wrappedOutputStream write:(const uint8_t *)&value maxLength:8];
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
}

- (void)writeData:(NSData *)data
{
    [_wrappedOutputStream write:(uint8_t *)data.bytes maxLength:data.length];
}

- (void)writeString:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    int32_t length = (int32_t)data.length;
    
    if (data == nil || length == 0)
    {
        [self writeInt32:0];
        return;
    }
    
    int paddingBytes = 0;
    
    if (length >= 254)
    {
        uint8_t tmp = 254;
        [_wrappedOutputStream write:&tmp maxLength:1];
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
        [_wrappedOutputStream write:(const uint8_t *)&length maxLength:3];
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUp(length, 4) - length;
    }
    else
    {
        [_wrappedOutputStream write:(const uint8_t *)&length maxLength:1];
        paddingBytes = roundUp(length + 1, 4) - (length + 1);
    }
    
    [_wrappedOutputStream write:(uint8_t *)data.bytes maxLength:length];
    
    uint8_t tmp = 0;
    for (int i = 0; i < paddingBytes; i++)
        [_wrappedOutputStream write:&tmp maxLength:1];
}

- (void)writeBytes:(NSData *)data
{
    int32_t length = (int32_t)data.length;
    
    if (data == nil || length == 0)
    {
        [self writeInt32:0];
        return;
    }
    
    int paddingBytes = 0;
    
    if (length >= 254)
    {
        uint8_t tmp = 254;
        [_wrappedOutputStream write:&tmp maxLength:1];
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
        [_wrappedOutputStream write:(const uint8_t *)&length maxLength:3];
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUp(length, 4) - length;
    }
    else
    {
        [_wrappedOutputStream write:(const uint8_t *)&length maxLength:1];
        paddingBytes = roundUp(length + 1, 4) - (length + 1);
    }
    
    [_wrappedOutputStream write:(uint8_t *)data.bytes maxLength:length];
    
    uint8_t tmp = 0;
    for (int i = 0; i < paddingBytes; i++)
        [_wrappedOutputStream write:&tmp maxLength:1];
}

@end
