#import "NSInputStream+TL.h"

#import "LegacyComponentsInternal.h"

#import <endian.h>

static inline int roundUpInput(int numToRound, int multiple)
{
    if (multiple == 0)
    {
        return numToRound;
    }
    
    int remainder = numToRound % multiple;
    if (remainder == 0)
    {
        return numToRound;
    }
    
    return numToRound + multiple - remainder;
}

@implementation NSInputStream (TL)

- (int32_t)readInt32
{
    int32_t value = 0;
    
    if ([self read:(uint8_t *)&value maxLength:4] != 4)
    {
        TGLegacyLog(@"***** Couldn't read int32");
        
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readInt32 end of stream" userInfo:@{}];
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int32_t)readInt32:(bool *)failed
{
    int32_t value = 0;
    
    if ([self read:(uint8_t *)&value maxLength:4] != 4)
    {
        *failed = true;
        return 0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int64_t)readInt64
{
    int64_t value = 0;
    
    if ([self read:(uint8_t *)&value maxLength:8] != 8)
    {
        TGLegacyLog(@"***** Couldn't read int64");
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int64_t)readInt64:(bool *)failed
{
    int64_t value = 0;
    
    if ([self read:(uint8_t *)&value maxLength:8] != 8)
    {
        *failed = true;
        return 0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (double)readDouble
{
    double value = 0.0;
    
    if ([self read:(uint8_t *)&value maxLength:8] != 8)
    {
        TGLegacyLog(@"***** Couldn't read double");
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (double)readDouble:(bool *)failed
{
    double value = 0.0;
    
    if ([self read:(uint8_t *)&value maxLength:8] != 8)
    {
        *failed = true;
        return 0.0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (NSData *)readData:(int)length
{
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        TGLegacyLog(@"***** Couldn't read %d bytes", length);
    }
    NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes length:length freeWhenDone:true];
    return data;
}

- (NSData *)readData:(int)length failed:(bool *)failed
{
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        free(bytes);
        *failed = true;
        return nil;
    }
    NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes length:length freeWhenDone:true];
    return data;
}

- (NSMutableData *)readMutableData:(int)length
{
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        TGLegacyLog(@"***** Couldn't read %d bytes", length);
    }
    NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes length:length freeWhenDone:true];
    return data;
}

- (NSMutableData *)readMutableData:(int)length failed:(bool *)failed
{
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        free(bytes);
        *failed = true;
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithBytesNoCopy:bytes length:length freeWhenDone:true];
    return data;
}

- (NSString *)readString
{
    uint8_t tmp = 0;
    [self read:&tmp maxLength:1];
    
    int paddingBytes = 0;
    
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        [self read:((uint8_t *)&length) + 1 maxLength:3];
        length >>= 8;
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
    {
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);
    }
    
    NSString *string = nil;
    
    if (length > 0)
    {
        uint8_t *bytes = (uint8_t *)malloc(length);
        int readLen = (int)[self read:bytes maxLength:length];
        if (readLen != length)
        {
            TGLegacyLog(@"***** Couldn't read %d bytes", length);
        }
        
        string = [[NSString alloc] initWithBytesNoCopy:bytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    }
    else
    {
        string = @"";
    }
    
    for (int i = 0; i < paddingBytes; i++)
        [self read:&tmp maxLength:1];
    
    return string;
}

- (NSString *)readString:(bool *)failed
{
    uint8_t tmp = 0;
    [self read:&tmp maxLength:1];
    
    int paddingBytes = 0;
    
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        [self read:((uint8_t *)&length) + 1 maxLength:3];
        length >>= 8;
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
    {
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);
    }
    
    NSString *string = nil;
    
    if (length > 0)
    {
        uint8_t *bytes = (uint8_t *)malloc(length);
        int readLen = (int)[self read:bytes maxLength:length];
        if (readLen != length)
        {
            free(bytes);
            *failed = true;
            return nil;
        }
        
        string = [[NSString alloc] initWithBytesNoCopy:bytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    }
    else
    {
        string = @"";
    }
    
    for (int i = 0; i < paddingBytes; i++)
        [self read:&tmp maxLength:1];
    
    return string;
}

- (NSData *)readBytes
{
    uint8_t tmp = 0;
    [self read:&tmp maxLength:1];
    
    int paddingBytes = 0;
    
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        [self read:((uint8_t *)&length) + 1 maxLength:3];
        length >>= 8;
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
    {
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);
    }
    
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        TGLegacyLog(@"***** Couldn't read %d bytes", length);
    }
    
    NSData *result = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:true];
    
    for (int i = 0; i < paddingBytes; i++)
        [self read:&tmp maxLength:1];
    
    return result;
}

- (NSData *)readBytes:(bool *)failed
{
    uint8_t tmp = 0;
    [self read:&tmp maxLength:1];
    
    int paddingBytes = 0;
    
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        [self read:((uint8_t *)&length) + 1 maxLength:3];
        length >>= 8;
        
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
        
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
    {
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);
    }
    
    uint8_t *bytes = (uint8_t *)malloc(length);
    int readLen = (int)[self read:bytes maxLength:length];
    if (readLen != length)
    {
        free(bytes);
        *failed = true;
        return nil;
    }
    
    NSData *result = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:true];
    
    for (int i = 0; i < paddingBytes; i++)
        [self read:&tmp maxLength:1];
    
    return result;
}

@end
