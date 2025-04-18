#import "PSKeyValueDecoder.h"

#import <objc/runtime.h>

@interface PSKeyValueDecoder ()
{
    NSData *_data;
 
@public
    uint8_t const *_currentPtr;
    uint8_t const *_begin;
    uint8_t const *_end;
    
    PSKeyValueDecoder *_tempCoder;
}

@end

static  uint32_t readLength(uint8_t const **currentPtr)
{
    uint32_t result = 0;
    
    result |= (*(*currentPtr)) & 127;
    
    if ((*(*currentPtr)) & 128)
    {
        (*currentPtr)++;
        result |= ((*(*currentPtr)) & 127) << (7 * 1);
        
        if ((*(*currentPtr)) & 128)
        {
            (*currentPtr)++;
            result |= ((*(*currentPtr)) & 127) << (7 * 2);
            
            if ((*(*currentPtr)) & 128)
            {
                (*currentPtr)++;
                result |= ((*(*currentPtr)) & 127) << (7 * 3);
                
                if ((*(*currentPtr)) & 128)
                {
                    (*currentPtr)++;
                    result |= ((*(*currentPtr)) & 127) << (7 * 4);
                }
            }
        }
    }
    
    (*currentPtr)++;
    
    return result;
}

static  NSString *readString(uint8_t const **currentPtr)
{
    uint32_t stringLength = readLength(currentPtr);
    
    NSString *string = [[NSString alloc] initWithBytes:*currentPtr length:stringLength encoding:NSUTF8StringEncoding];
    (*currentPtr) += stringLength;
    return string;
}

static  void skipString(uint8_t const **currentPtr)
{
    uint32_t stringLength = readLength(currentPtr);
    (*currentPtr) += stringLength;
}

static  int32_t readInt32(uint8_t const **currentPtr)
{
    int32_t number = *((int32_t *)(*currentPtr));
    (*currentPtr) += 4;
    return number;
}

static  void skipInt32(uint8_t const **currentPtr)
{
    (*currentPtr) += 4;
}

static  int64_t readInt64(uint8_t const **currentPtr)
{
    int64_t number;
    memcpy(&number, *currentPtr, 8);
    
    (*currentPtr) += 8;
    return number;
}

static double readDouble(uint8_t const **currentPtr)
{
    double number;
    memcpy(&number, *currentPtr, 8);
    
    (*currentPtr) += 8;
    return number;
}

static void skipInt64(uint8_t const **currentPtr)
{
    (*currentPtr) += 8;
}

static id<PSCoding> readObject(uint8_t const **currentPtr, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4;
    
    uint8_t const *objectEnd = (*currentPtr) + objectLength;

    
    const char *className = (const char *)(*currentPtr);
    NSUInteger classNameLength = strlen(className) + 1;
    (*currentPtr) += classNameLength;
    
    id<PSCoding> object = nil;
    
    Class<PSCoding> objectClass = objc_getClass(className);
    if (objectClass != nil)
    {
        tempCoder->_begin = *currentPtr;
        tempCoder->_end = objectEnd;
        tempCoder->_currentPtr = tempCoder->_begin;
        
        object = [(id<PSCoding>)[(id)objectClass alloc] initWithKeyValueCoder:tempCoder];
    }

    *currentPtr = objectEnd;
    
    return object;
}

static  void skipObject(uint8_t const **currentPtr)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4 + objectLength;
}

static  NSArray *readArray(uint8_t const **currentPtr, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4;
    
    uint8_t const *objectEnd = (*currentPtr) + objectLength;
    
    uint32_t count = readLength(currentPtr);
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:count];
    
    for (uint32_t i = 0; i < count; i++)
    {
        id<PSCoding> object = readObject(currentPtr, tempCoder);
        if (object != nil)
            [array addObject:object];
    }
    
    *currentPtr = objectEnd;
    
    return array;
}

static void skipArray(uint8_t const **currentPtr)
{
    uint32_t objectLength = ((uint32_t *)*currentPtr)[0];
    (*currentPtr) += 4 + objectLength;
}

static NSDictionary *readInt32Dictionary(uint8_t const **currentPtr, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4;
    
    uint8_t const *objectEnd = (*currentPtr) + objectLength;
    
    uint32_t count = readLength(currentPtr);
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:count];
    
    for (uint32_t i = 0; i < count; i++)
    {
        int32_t key = *((int32_t *)(*currentPtr));
        (*currentPtr) += 4;
        
        id<PSCoding> object = readObject(currentPtr, tempCoder);
        if (object != nil) {
            dict[@(key)] = object;
        }
    }
    
    *currentPtr = objectEnd;
    
    return dict;
}

static void skipInt32Dictionary(uint8_t const **currentPtr)
{
    uint32_t objectLength = ((uint32_t *)*currentPtr)[0];
    (*currentPtr) += 4 + objectLength;
}

static NSData *readData(uint8_t const **currentPtr)
{
    uint32_t length = readLength(currentPtr);
    
    NSData *data = [[NSData alloc] initWithBytes:*currentPtr length:length];
    
    *currentPtr += length;
    
    return data;
}

static void readBytes(uint8_t const **currentPtr, uint8_t *value, NSUInteger maxLength)
{
    uint32_t length = readLength(currentPtr);
    
    memcpy(value, *currentPtr, MIN((uint32_t)maxLength, length));
    
    *currentPtr += length;
}

static void skipData(uint8_t const **currentPtr)
{
    uint32_t length = readLength(currentPtr);
    (*currentPtr) += length;
}

static  void skipField(uint8_t const **currentPtr)
{
    uint8_t fieldType = *(*currentPtr);
    (*currentPtr)++;
    
    switch (fieldType)
    {
        case PSKeyValueCoderFieldTypeString:
        {
            skipString(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeInt32:
        {
            skipInt32(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeInt64:
        {
            skipInt64(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeCustomClass:
        {
            skipObject(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeArray:
        {
            skipArray(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeData:
        {
            skipData(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeInt32Dictionary:
        {
            skipInt32Dictionary(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeDouble:
        {
            skipInt64(currentPtr);
            break;
        }
        default:
            break;
    }
}

@implementation PSKeyValueDecoder

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
        
        _begin = (uint8_t const *)[_data bytes];
        _end = _begin + [_data length];
        _currentPtr = _begin;
    }
    return self;
}

- (void)resetData:(NSData *)data
{
    _data = data;
    
    _begin = (uint8_t const *)[_data bytes];
    _end = _begin + [_data length];
    _currentPtr = _begin;
}

- (void)resetBytes:(uint8_t const *)bytes length:(NSUInteger)length
{
    _data = nil;
    
    _begin = bytes;
    _end = _begin + length;
    _currentPtr = _begin;
}

- (void)rewind {
    _begin = (uint8_t const *)[_data bytes];
    _end = _begin + [_data length];
    _currentPtr = _begin;
}

static bool skipToValueForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    uint8_t const *middlePtr = self->_currentPtr;
    
    for (int i = 0; i < 2; i++)
    {
        uint8_t const *scanEnd = self->_end;
        
        if (i == 1)
        {
            self->_currentPtr = self->_begin;
            scanEnd = middlePtr;
        }
        
        while (self->_currentPtr < scanEnd)
        {
            uint32_t compareKeyLength = readLength(&self->_currentPtr);
            
            if (compareKeyLength != keyLength || memcmp(key, self->_currentPtr, keyLength))
            {
                if (compareKeyLength > 1000) {
                    return false;
                }
                
                self->_currentPtr += compareKeyLength;
                skipField(&self->_currentPtr);
                
                continue;
            }
            
            self->_currentPtr += compareKeyLength;
            
            return true;
        }
    }
    
    return false;
}

static NSString *decodeStringForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return readString(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return [[NSString alloc] initWithFormat:@"%" PRId32 "", readInt32(&self->_currentPtr)];
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return [[NSString alloc] initWithFormat:@"%" PRId64 "", readInt64(&self->_currentPtr)];
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (NSString *)decodeStringForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeStringForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (NSString *)decodeStringForCKey:(const char *)key
{
    return decodeStringForRawKey(self, (uint8_t const *)key, (NSUInteger)strlen(key));
}

static int32_t decodeInt32ForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return (int32_t)[readString(&self->_currentPtr) intValue];
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return readInt32(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return (int32_t)readInt64(&self->_currentPtr);
        else
        {
            skipField(&self->_currentPtr);
            
            return 0;
        }
    }
    
    return 0;
}

- (int32_t)decodeInt32ForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeInt32ForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (int32_t)decodeInt32ForCKey:(const char *)key
{
    return decodeInt32ForRawKey(self, (uint8_t const *)key, strlen(key));
}

static int64_t decodeInt64ForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return (int64_t)[readString(&self->_currentPtr) longLongValue];
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return readInt32(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return readInt64(&self->_currentPtr);
        else
        {
            skipField(&self->_currentPtr);
            return 0;
        }
    }
    
    return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeInt64ForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (int64_t)decodeInt64ForCKey:(const char *)key
{
    return decodeInt64ForRawKey(self, (uint8_t const *)key, strlen(key));
}

static id<PSCoding> decodeObjectForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeCustomClass)
        {
            if (self->_tempCoder == nil)
                self->_tempCoder = [[PSKeyValueDecoder alloc] init];
            return readObject(&self->_currentPtr, self->_tempCoder);
        }
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (id<PSCoding>)decodeObjectForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeObjectForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (id<PSCoding>)decodeObjectForCKey:(const char *)key
{
    return decodeObjectForRawKey(self, (uint8_t const *)key, strlen(key));
}

static NSArray *decodeArrayForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeArray)
        {
            if (self->_tempCoder == nil)
                self->_tempCoder = [[PSKeyValueDecoder alloc] init];
            return readArray(&self->_currentPtr, self->_tempCoder);
        }
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (NSArray *)decodeArrayForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeArrayForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (NSArray *)decodeArrayForCKey:(const char *)key
{
    return decodeArrayForRawKey(self, (uint8_t const *)key, strlen(key));
}

static NSData *decodeDataForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeData)
        {
            return readData(&self->_currentPtr);
        }
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

static void decodeBytesForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength, uint8_t *value, NSUInteger maxLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeData)
        {
            readBytes(&self->_currentPtr, value, maxLength);
        }
        else
        {
            skipField(&self->_currentPtr);
        }
    }
}

- (NSData *)decodeDataCorCKey:(const char *)key
{
    return decodeDataForRawKey(self, (uint8_t const *)key, strlen(key));
}

- (void)decodeBytesForCKey:(const char *)key value:(uint8_t *)value length:(NSUInteger)length
{
    decodeBytesForRawKey(self, (uint8_t const *)key, strlen(key), value, length);
}

- (NSDictionary *)decodeObjectsByKeys
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if (self->_tempCoder == nil)
        self->_tempCoder = [[PSKeyValueDecoder alloc] init];
    
    self->_currentPtr = self->_begin;
    while (self->_currentPtr < self->_end)
    {
        uint32_t keyLength = readLength(&self->_currentPtr);
        NSString *key = [[NSString alloc] initWithBytes:self->_currentPtr length:keyLength encoding:NSUTF8StringEncoding];
        self->_currentPtr += keyLength;
        
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeCustomClass)
        {
            id<PSCoding> value = readObject(&self->_currentPtr, self->_tempCoder);
            if (value == nil)
                continue;
            
            dict[key] = value;
        }
        else
            break;
    }
    
    self->_currentPtr = self->_begin;
    
    return dict;
}

- (NSArray *)decodeInt32ArrayForCKey:(const char *)key {
    if (skipToValueForRawKey(self, (void *)key, strlen(key))) {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeInt32Array) {
            int32_t count = 0;
            memcpy(&count, self->_currentPtr, 4);
            self->_currentPtr += 4;
            NSMutableArray *array = [[NSMutableArray alloc] init];
            
            for (int32_t i = 0; i < count; i++) {
                int32_t number = 0;
                memcpy(&number, self->_currentPtr, 4);
                self->_currentPtr += 4;
                [array addObject:@(number)];
            }
            
            return array;
        } else {
            self->_currentPtr--;
            skipField(&self->_currentPtr);
            return nil;
        }
    } else {
        return nil;
    }
}

- (NSDictionary *)decodeInt32DictionaryForCKey:(const char *)key {
    if (skipToValueForRawKey(self, (uint8_t const *)key, strlen(key))) {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeInt32Dictionary) {
            if (self->_tempCoder == nil)
                self->_tempCoder = [[PSKeyValueDecoder alloc] init];
            return readInt32Dictionary(&self->_currentPtr, self->_tempCoder);
        }
        else {
            skipField(&self->_currentPtr);
        }
    }
    
    return nil;
}

- (double)decodeDoubleForCKey:(const char *)key {
    if (skipToValueForRawKey(self, (uint8_t const *)key, strlen(key)))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return (int32_t)[readString(&self->_currentPtr) doubleValue];
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return readInt32(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return (double)readInt64(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeDouble)
            return readDouble(&self->_currentPtr);
        else
        {
            skipField(&self->_currentPtr);
            
            return 0;
        }
    }
    
    return 0.0;
}

@end
