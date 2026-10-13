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

- (NSData *)readData:(NSUInteger)length
{
    if (length > _data.length - _offset)
        return nil;

    NSData *result = [_data subdataWithRange:NSMakeRange(_offset, length)];
    _offset += length;
    return result;
}

- (NSData *)readRest
{
    return [_data subdataWithRange:NSMakeRange(_offset, _data.length - _offset)];
}

@end

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

// TL `bytes`: a one-byte length (0..253), or 0xfe followed by a 3-byte
// little-endian length (up to 0xffffff), then the bytes, then zero padding to a
// 4-byte boundary counted from the first length byte.
- (bool)readTLBytes:(__autoreleasing NSData **)value
{
    uint8_t marker = 0;
    if (![self readBytes:&marker length:1])
        return false;

    NSUInteger length = 0;
    NSUInteger prefixLength = 0;
    if (marker == 254)
    {
        uint8_t lengthBytes[3];
        if (![self readBytes:lengthBytes length:3])
            return false;
        // Assembled unsigned: a signed shift here used to turn 8 MiB and above negative.
        length = ((NSUInteger)lengthBytes[0]) | (((NSUInteger)lengthBytes[1]) << 8) | (((NSUInteger)lengthBytes[2]) << 16);
        prefixLength = 4;
    }
    else
    {
        length = marker;
        prefixLength = 1;
    }
    NSUInteger paddingBytes = (4 - ((prefixLength + length) % 4)) % 4;

    NSData *result = [self readData:length];
    if (result == nil)
        return false;

    uint8_t padding[3];
    if (paddingBytes != 0 && ![self readBytes:padding length:paddingBytes])
        return false;

    if (value)
        *value = result;

    return true;
}

@end
