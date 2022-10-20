#import "PSKeyValueEncoder.h"

#import <objc/runtime.h>

@interface PSKeyValueEncoder ()
{
@public
    NSMutableData *_data;
}

@end

@implementation PSKeyValueEncoder

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _data = [[NSMutableData alloc] init];
    }
    return self;
}

static inline void writeLength(PSKeyValueEncoder *self, uint32_t value)
{
    uint8_t bytes[5];
    int length = 0;
    
    if (value > 127)
    {
        bytes[length++] = ((uint8_t)(value & 127)) | 128;
        value >>= 7;
    }
    
    if (value > 127)
    {
        bytes[length++] = ((uint8_t)(value & 127)) | 128;
        value >>= 7;
    }
    
    if (value > 127)
    {
        bytes[length++] = ((uint8_t)(value & 127)) | 128;
        value >>= 7;
    }
    
    if (value > 127)
    {
        bytes[length++] = ((uint8_t)(value & 127)) | 128;
        value >>= 7;
    }
    
    bytes[length++] = ((uint8_t)(value & 127));
    
    [self->_data appendBytes:bytes length:length];
}

- (void)encodeString:(NSString *)string forKey:(NSString *)key
{
    if (key == nil || string == nil)
        return;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)keyData.length);
    [_data appendData:keyData];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeString;
    [_data appendBytes:&fieldType length:1];
    
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)stringData.length);
    [_data appendData:stringData];
}

- (void)encodeString:(NSString *)string forCKey:(const char *)key
{
    if (key == nil || string == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeString;
    [_data appendBytes:&fieldType length:1];
    
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)stringData.length);
    [_data appendData:stringData];
}

- (void)encodeInt32:(int32_t)number forKey:(NSString *)key
{
    if (key == nil)
        return;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)keyData.length);
    [_data appendData:keyData];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt32;
    [_data appendBytes:&fieldType length:1];
    
    [_data appendBytes:&number length:4];
}

- (void)encodeInt32:(int32_t)number forCKey:(const char *)key
{
    if (key == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt32;
    [_data appendBytes:&fieldType length:1];
    
    [_data appendBytes:&number length:4];
}

- (void)encodeInt64:(int64_t)number forKey:(NSString *)key
{
    if (key == nil)
        return;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)keyData.length);
    [_data appendData:keyData];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt64;
    [_data appendBytes:&fieldType length:1];
    
    [_data appendBytes:&number length:8];
}

- (void)encodeInt64:(int64_t)number forCKey:(const char *)key
{
    if (key == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt64;
    [_data appendBytes:&fieldType length:1];
    
    [_data appendBytes:&number length:8];
}

- (void)encodeObject:(id<PSCoding>)object forKey:(NSString *)key
{
    if (key == nil || object == nil)
        return;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)keyData.length);
    [_data appendData:keyData];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeCustomClass;
    [_data appendBytes:&fieldType length:1];
    
    uint32_t objectLength = 0;
    NSUInteger objectLengthPosition = [_data length];
    [_data appendBytes:&objectLength length:4];
    
    NSString *className = NSStringFromClass([object class]);
    NSData *classNameData = [className dataUsingEncoding:NSUTF8StringEncoding];
    [_data appendData:classNameData];
    uint8_t zero = 0;
    [_data appendBytes:&zero length:1];
    
    [object encodeWithKeyValueCoder:self];
    
    objectLength = (int)([_data length] - objectLengthPosition - 4);
    [_data replaceBytesInRange:NSMakeRange(objectLengthPosition, 4) withBytes:&objectLength];
}

static void encodeObjectValue(PSKeyValueEncoder *self, id<PSCoding> object)
{
    uint32_t objectLength = 0;
    NSUInteger objectLengthPosition = [self->_data length];
    [self->_data appendBytes:&objectLength length:4];
    
    Class objectClass = object_getClass(object);
    const char *className = class_getName(objectClass);
    [self->_data appendBytes:className length:strlen(className) + 1];
    
    [object encodeWithKeyValueCoder:self];
    
    objectLength = (int)([self->_data length] - objectLengthPosition - 4);
    [self->_data replaceBytesInRange:NSMakeRange(objectLengthPosition, 4) withBytes:&objectLength];
}

- (void)encodeObject:(id<PSCoding>)object forCKey:(const char *)key
{
    if (key == nil || object == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeCustomClass;
    [_data appendBytes:&fieldType length:1];
    
    encodeObjectValue(self, object);
}

- (void)encodeArray:(NSArray *)array forKey:(NSString *)key
{
    if (key == nil || array == nil)
        return;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    writeLength(self, (uint32_t)keyData.length);
    [_data appendData:keyData];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeArray;
    [_data appendBytes:&fieldType length:1];
    
    uint32_t objectLength = 0;
    NSUInteger objectLengthPosition = [self->_data length];
    [self->_data appendBytes:&objectLength length:4];
    
    uint32_t count = (uint32_t)[array count];
    writeLength(self, count);
    
    for (uint32_t i = 0; i < count; i++)
    {
        encodeObjectValue(self, array[i]);
    }
    
    objectLength = (int)([_data length] - objectLengthPosition - 4);
    [_data replaceBytesInRange:NSMakeRange(objectLengthPosition, 4) withBytes:&objectLength];
}

- (void)encodeArray:(NSArray *)array forCKey:(const char *)key
{
    if (key == nil || array == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeArray;
    [_data appendBytes:&fieldType length:1];
    
    uint32_t objectLength = 0;
    NSUInteger objectLengthPosition = [self->_data length];
    [self->_data appendBytes:&objectLength length:4];
    
    uint32_t count = (uint32_t)[array count];
    writeLength(self, count);
    
    for (uint32_t i = 0; i < count; i++)
    {
        encodeObjectValue(self, array[i]);
    }
    
    objectLength = (int)([_data length] - objectLengthPosition - 4);
    [_data replaceBytesInRange:NSMakeRange(objectLengthPosition, 4) withBytes:&objectLength];
}

- (void)encodeData:(NSData *)data forCKey:(const char *)key
{
    if (key == nil || data == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeData;
    [_data appendBytes:&fieldType length:1];
    
    writeLength(self, (uint32_t)data.length);
    [_data appendData:data];
}

- (void)encodeBytes:(uint8_t const *)value length:(NSUInteger)length forCKey:(const char *)key
{
    if (key == nil)
        return;
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeData;
    [_data appendBytes:&fieldType length:1];
    
    writeLength(self, (uint32_t)length);
    [_data appendBytes:value length:length];
}

- (void)encodeInt32Array:(NSArray *)value forCKey:(const char *)key {
    if (key == NULL) {
        return;
    }
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt32Array;
    [_data appendBytes:&fieldType length:1];
    
    int32_t count = (int32_t)value.count;
    [_data appendBytes:&count length:4];
    
    for (NSNumber *nNumber in value) {
        int32_t number = [nNumber intValue];
        [_data appendBytes:&number length:4];
    }
}

- (void)encodeInt32Dictionary:(NSDictionary *)value forCKey:(const char *)key {
    if (key == NULL) {
        return;
    }
    
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeInt32Dictionary;
    [_data appendBytes:&fieldType length:1];
    
    uint32_t objectLength = 0;
    NSUInteger objectLengthPosition = [self->_data length];
    [self->_data appendBytes:&objectLength length:4];
    
    NSArray *allKeys = [value allKeys];
    uint32_t count = (uint32_t)[allKeys count];
    writeLength(self, count);
    
    for (NSNumber *nKey in allKeys) {
        id<PSCoding> object = value[nKey];
        int32_t objectKey = [nKey intValue];
        [self->_data appendBytes:&objectKey length:4];
        encodeObjectValue(self, object);
    }
    
    objectLength = (int)([_data length] - objectLengthPosition - 4);
    [_data replaceBytesInRange:NSMakeRange(objectLengthPosition, 4) withBytes:&objectLength];
}

- (void)encodeDouble:(double)value forCKey:(const char *)key {
    uint32_t keyLength = (uint32_t)strlen(key);
    writeLength(self, keyLength);
    [_data appendBytes:key length:keyLength];
    
    uint8_t fieldType = PSKeyValueCoderFieldTypeDouble;
    [_data appendBytes:&fieldType length:1];
    
    [_data appendBytes:&value length:8];
}

- (void)reset
{
    [_data setLength:0];
}

- (NSData *)data
{
    return _data;
}

@end
