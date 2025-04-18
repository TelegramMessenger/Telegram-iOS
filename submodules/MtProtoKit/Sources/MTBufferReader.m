#import "MTBufferReader.h"

@interface MTBufferReader ()
{
    NSData *_data;
    NSUInteger _offset;
}

@end

@implementation MTBufferReader

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
    }
    return self;
}

- (bool)readBytes:(void *)bytes length:(NSUInteger)length
{
    if (_offset + length > _data.length)
        return false;
    if (bytes != NULL)
        memcpy(bytes, _data.bytes + _offset, length);
    _offset += length;
    return true;
}

- (bool)readInt32:(int32_t *)value
{
    return [self readBytes:value length:4];
}

- (bool)readInt64:(int64_t *)value
{
    return [self readBytes:value length:8];
}

- (NSData *)readRest
{
    return [_data subdataWithRange:NSMakeRange(_offset, _data.length - _offset)];
}

@end

static inline int roundUpInput(int32_t numToRound, int32_t multiple)
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

@implementation MTBufferReader (TL)

- (bool)readTLString:(__autoreleasing NSString **)value
{
    NSData *bytes = nil;
    if ([self readTLBytes:&bytes])
    {
        if (value)
            *value = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        return true;
    }
    
    return false;
}

- (bool)readTLBytes:(__autoreleasing NSData **)value
{
    uint8_t tmp = 0;
    if ([self readBytes:&tmp length:1])
    {
        NSUInteger paddingBytes = 0;
        
        int32_t length = tmp;
        if (length == 254)
        {
            length = 0;
            
            if (![self readBytes:((uint8_t *)&length) + 1 length:3])
                return false;
            
            length >>= 8;
            
            paddingBytes = roundUpInput(length, 4) - length;
        }
        else
        {
            paddingBytes = roundUpInput(length + 1, 4) - (length + 1);
        }
        
        uint8_t *bytes = (uint8_t *)malloc(length);
        if (![self readBytes:bytes length:length])
            return false;
        
        NSData *result = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:true];
        
        for (int i = 0; i < paddingBytes; i++)
        {
            if (![self readBytes:&tmp length:1])
                return false;
        }
        
        if (value)
            *value = result;
        
        return true;
    }
    
    return false;
}

@end
