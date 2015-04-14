#import "MTBuffer.h"

@interface MTBuffer ()
{
    NSMutableData *_data;
}

@end

@implementation MTBuffer

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _data = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)appendInt32:(int32_t)value
{
    [_data appendBytes:&value length:4];
}

- (void)appendInt64:(int64_t)value
{
    [_data appendBytes:&value length:8];
}

- (void)appendBytes:(void const *)bytes length:(NSUInteger)length
{
    [_data appendBytes:bytes length:length];
}

- (NSData *)data
{
    return [[NSData alloc] initWithData:_data];
}

@end

static inline int roundUp(int numToRound, int multiple)
{
    return multiple == 0 ? numToRound : ((numToRound % multiple) == 0 ? numToRound : (numToRound + multiple - (numToRound % multiple)));
}

@implementation MTBuffer (TL)

- (void)appendTLBytes:(NSData *)bytes
{
    int32_t length = (int32_t)bytes.length;
    
    if (bytes == nil || length == 0)
    {
        [self appendInt32:0];
        return;
    }
    
    int paddingBytes = 0;
    
    if (length >= 254)
    {
        uint8_t tmp = 254;
        [self appendBytes:&tmp length:1];
        
        [self appendBytes:(const uint8_t *)&length length:3];
        
        paddingBytes = roundUp(length, 4) - length;
    }
    else
    {
        [self appendBytes:(const uint8_t *)&length length:1];
        paddingBytes = roundUp(length + 1, 4) - (length + 1);
    }
    
    [self appendBytes:bytes.bytes length:length];
    
    uint8_t tmp = 0;
    for (int i = 0; i < paddingBytes; i++)
        [self appendBytes:&tmp length:1];
}

- (void)appendTLString:(NSString *)string
{
    [self appendTLBytes:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
