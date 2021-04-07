#import "Api.h"
#import <objc/runtime.h>

static const char *Api1__Serializer_Key = "Api1__Serializer";

@interface Api1__Number : NSNumber
{
    NSNumber *_value;
}

@end

@implementation Api1__Number

- (instancetype)initWithNumber:(NSNumber *)number
{
    self = [super init];
    if (self != nil)
    {
        _value = number;
    }
    return self;
}

- (char)charValue
{
    return [_value charValue];
}

- (unsigned char)unsignedCharValue
{
    return [_value unsignedCharValue];
}

- (short)shortValue
{
    return [_value shortValue];
}

- (unsigned short)unsignedShortValue
{
    return [_value unsignedShortValue];
}

- (int)intValue
{
    return [_value intValue];
}

- (unsigned int)unsignedIntValue
{
    return [_value unsignedIntValue];
}

- (long)longValue
{
    return [_value longValue];
}

- (unsigned long)unsignedLongValue
{
    return [_value unsignedLongValue];
}

- (long long)longLongValue
{
    return [_value longLongValue];
}

- (unsigned long long)unsignedLongLongValue
{
    return [_value unsignedLongLongValue];
}

- (float)floatValue
{
    return [_value floatValue];
}

- (double)doubleValue
{
    return [_value doubleValue];
}

- (BOOL)boolValue
{
    return [_value boolValue];
}

- (NSInteger)integerValue
{
    return [_value integerValue];
}

- (NSUInteger)unsignedIntegerValue
{
    return [_value unsignedIntegerValue];
}

- (NSString *)stringValue
{
    return [_value stringValue];
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    return [_value compare:otherNumber];
}

- (BOOL)isEqualToNumber:(NSNumber *)number
{
    return [_value isEqualToNumber:number];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [_value descriptionWithLocale:locale];
}

- (void)getValue:(void *)value
{
    [_value getValue:value];
}

- (const char *)objCType
{
    return [_value objCType];
}

- (NSUInteger)hash
{
    return [_value hash];
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    return self;
}

@end

@interface Api1__Serializer : NSObject

@property (nonatomic) int32_t constructorSignature;
@property (nonatomic, copy) bool (^serializeBlock)(id object, NSMutableData *);

@end

@implementation Api1__Serializer

- (instancetype)initWithConstructorSignature:(int32_t)constructorSignature serializeBlock:(bool (^)(id, NSMutableData *))serializeBlock
{
    self = [super init];
    if (self != nil)
    {
        self.constructorSignature = constructorSignature;
        self.serializeBlock = serializeBlock;
    }
    return self;
}

+ (id)addSerializerToObject:(id)object withConstructorSignature:(int32_t)constructorSignature serializeBlock:(bool (^)(id, NSMutableData *))serializeBlock
{
    if (object != nil)
        objc_setAssociatedObject(object, Api1__Serializer_Key, [[Api1__Serializer alloc] initWithConstructorSignature:constructorSignature serializeBlock:serializeBlock], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return object;
}

+ (id)addSerializerToObject:(id)object serializer:(Api1__Serializer *)serializer
{
    if (object != nil)
        objc_setAssociatedObject(object, Api1__Serializer_Key, serializer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return object;
}

@end

@interface Api1__UnboxedTypeMetaInfo : NSObject

@property (nonatomic, readonly) int32_t constructorSignature;

@end

@implementation Api1__UnboxedTypeMetaInfo

- (instancetype)initWithConstructorSignature:(int32_t)constructorSignature
{
    self = [super init];
    if (self != nil)
    {
        _constructorSignature = constructorSignature;
    }
    return self;
}

@end

@interface Api1__PreferNSDataTypeMetaInfo : NSObject

@end

@implementation Api1__PreferNSDataTypeMetaInfo

+ (instancetype)preferNSDataTypeMetaInfo
{
    static Api1__PreferNSDataTypeMetaInfo *instance = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^
    {
        instance = [[Api1__PreferNSDataTypeMetaInfo alloc] init];
    });
    return instance;
}

@end

@interface Api1__BoxedTypeMetaInfo : NSObject

@end

@implementation Api1__BoxedTypeMetaInfo

+ (instancetype)boxedTypeMetaInfo
{
    static Api1__BoxedTypeMetaInfo *instance = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^
    {
        instance = [[Api1__BoxedTypeMetaInfo alloc] init];
    });
    return instance;
}

@end

@implementation Api1__Environment

+ (id (^)(NSData *data, NSUInteger *offset, id metaInfo))parserByConstructorSignature:(int32_t)constructorSignature
{
    static NSMutableDictionary *parsers = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^
    {
        parsers = [[NSMutableDictionary alloc] init];

        parsers[@((int32_t)0xA8509BDA)] = [^id (NSData *data, NSUInteger *offset, __unused id metaInfo)
        {
            if (*offset + 4 > data.length)
                return nil;
            int32_t value = 0;
            [data getBytes:(void *)&value range:NSMakeRange(*offset, 4)];
            *offset += 4;
            return @(value);
        } copy];

        parsers[@((int32_t)0x22076CBA)] = [^id (NSData *data, NSUInteger *offset, __unused id metaInfo)
        {
            if (*offset + 8 > data.length)
                return nil;
            int64_t value = 0;
            [data getBytes:(void *)&value range:NSMakeRange(*offset, 8)];
            *offset += 8;
            return @(value);
        } copy];

        parsers[@((int32_t)0x2210C154)] = [^id (NSData *data, NSUInteger *offset, __unused id metaInfo)
        {
            if (*offset + 8 > data.length)
                return nil;
            double value = 0;
            [data getBytes:(void *)&value range:NSMakeRange(*offset, 8)];
            *offset += 8;
            return @(value);
        } copy];

        parsers[@((int32_t)0xB5286E24)] = [^id (NSData *data, NSUInteger *offset, __unused id metaInfo)
        {
            if (*offset + 1 > data.length)
                return nil;
            uint8_t tmp = 0;
            [data getBytes:(void *)&tmp range:NSMakeRange(*offset, 1)];
            *offset += 1;

            int paddingBytes = 0;

            int32_t length = tmp;
            if (length == 254)
            {
                length = 0;
                if (*offset + 3 > data.length)
                    return nil;
                [data getBytes:((uint8_t *)&length) + 1 range:NSMakeRange(*offset, 3)];
                *offset += 3;
                length >>= 8;

                paddingBytes = (((length % 4) == 0 ? length : (length + 4 - (length % 4)))) - length;
            }
            else
                paddingBytes = ((((length + 1) % 4) == 0 ? (length + 1) : ((length + 1) + 4 - ((length + 1) % 4)))) - (length + 1);

            bool isData = [metaInfo isKindOfClass:[Api1__PreferNSDataTypeMetaInfo class]];
            id object = nil;

            if (length > 0)
            {
                if (*offset + length > data.length)
                    return nil;
                if (isData)
                    object = [[NSData alloc] initWithBytes:((uint8_t *)data.bytes) + *offset length:length];
                else
                    object = [[NSString alloc] initWithBytes:((uint8_t *)data.bytes) + *offset length:length encoding:NSUTF8StringEncoding];

                *offset += length;
            }

            *offset += paddingBytes;

            return object == nil ? (isData ? [NSData data] : @"") : object;
        } copy];

        parsers[@((int32_t)0x1cb5c415)] = [^id (NSData *data, NSUInteger *offset, id metaInfo)
        {
            if (*offset + 4 > data.length)
                return nil;

            int32_t count = 0;
            [data getBytes:(void *)&count range:NSMakeRange(*offset, 4)];
            *offset += 4;

            if (count < 0)
                return nil;

            bool isBoxed = false;
            int32_t unboxedConstructorSignature = 0;
            if ([metaInfo isKindOfClass:[Api1__BoxedTypeMetaInfo class]])
                isBoxed = true;
            else if ([metaInfo isKindOfClass:[Api1__UnboxedTypeMetaInfo class]])
                unboxedConstructorSignature = ((Api1__UnboxedTypeMetaInfo *)metaInfo).constructorSignature;
            else
                return nil;

            NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
            for (int32_t i = 0; i < count; i++)
            {
                int32_t itemConstructorSignature = 0;
                if (isBoxed)
                {
                    if (*offset + 4 > data.length)
                        return nil;
                    [data getBytes:(void *)&itemConstructorSignature range:NSMakeRange(*offset, 4)];
                    *offset += 4;
                }
                else
                    itemConstructorSignature = unboxedConstructorSignature;
                id item = [Api1__Environment parseObject:data offset:offset implicitSignature:itemConstructorSignature metaInfo:nil];
                if (item == nil)
                    return nil;

                [array addObject:item];
            }

            return array;
        } copy];

        parsers[@((int32_t)0x2331b22d)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            return [Api1_Photo photoEmptyWithPid:pid];
        } copy];
        parsers[@((int32_t)0xfb197a65)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * flags = nil;
            if ((flags = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * accessHash = nil;
            if ((accessHash = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSData * fileReference = nil;
            if ((fileReference = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            NSNumber * date = nil;
            if ((date = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSArray * sizes = nil;
            int32_t sizes_signature = 0; [_data getBytes:(void *)&sizes_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((sizes = [Api1__Environment parseObject:_data offset:_offset implicitSignature:sizes_signature metaInfo:[Api1__BoxedTypeMetaInfo boxedTypeMetaInfo]]) == nil)
               return nil;
            NSNumber * dcId = nil;
            if ((dcId = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            return [Api1_Photo photoWithFlags:flags pid:pid accessHash:accessHash fileReference:fileReference date:date sizes:sizes dcId:dcId];
        } copy];
        parsers[@((int32_t)0xe17e23c)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * type = nil;
            if ((type = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            return [Api1_PhotoSize photoSizeEmptyWithType:type];
        } copy];
        parsers[@((int32_t)0x77bfb61b)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * type = nil;
            if ((type = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            Api1_FileLocation * location = nil;
            int32_t location_signature = 0; [_data getBytes:(void *)&location_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((location = [Api1__Environment parseObject:_data offset:_offset implicitSignature:location_signature metaInfo:nil]) == nil)
               return nil;
            NSNumber * w = nil;
            if ((w = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * h = nil;
            if ((h = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * size = nil;
            if ((size = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            return [Api1_PhotoSize photoSizeWithType:type location:location w:w h:h size:size];
        } copy];
        parsers[@((int32_t)0x5aa86a51)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * type = nil;
            if ((type = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            Api1_FileLocation * location = nil;
            int32_t location_signature = 0; [_data getBytes:(void *)&location_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((location = [Api1__Environment parseObject:_data offset:_offset implicitSignature:location_signature metaInfo:nil]) == nil)
               return nil;
            NSNumber * w = nil;
            if ((w = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * h = nil;
            if ((h = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            
            NSMutableArray *sizes = [[NSMutableArray alloc] init];
            *_offset += 4;
            int32_t count = 0; [_data getBytes:(void *)&count range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            
            for (int32_t i = 0; i < count; i++) {
                int32_t value = 0; [_data getBytes:(void *)&value range:NSMakeRange(*_offset, 4)]; *_offset += 4;
                [sizes addObject:@(value)];
            }
            
            return [Api1_PhotoSize photoSizeProgressiveWithType:type location:location w:w h:h sizes:sizes];
        } copy];
        parsers[@((int32_t)0xe9a734fa)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * type = nil;
            if ((type = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            Api1_FileLocation * location = nil;
            int32_t location_signature = 0; [_data getBytes:(void *)&location_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((location = [Api1__Environment parseObject:_data offset:_offset implicitSignature:location_signature metaInfo:nil]) == nil)
               return nil;
            NSNumber * w = nil;
            if ((w = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * h = nil;
            if ((h = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSData * bytes = nil;
            if ((bytes = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            return [Api1_PhotoSize photoCachedSizeWithType:type location:location w:w h:h bytes:bytes];
        } copy];
        parsers[@((int32_t)0xe0b0bc2e)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * type = nil;
            if ((type = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            NSData * bytes = nil;
            if ((bytes = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            return [Api1_PhotoSize photoStrippedSizeWithType:type bytes:bytes];
        } copy];
        parsers[@((int32_t)0xbc7fc6cd)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * volumeId = nil;
            if ((volumeId = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * localId = nil;
            if ((localId = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            return [Api1_FileLocation fileLocationToBeDeprecatedWithVolumeId:volumeId localId:localId];
        } copy];
        parsers[@((int32_t)0x6c37c15c)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * w = nil;
            if ((w = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * h = nil;
            if ((h = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            return [Api1_DocumentAttribute documentAttributeImageSizeWithW:w h:h];
        } copy];
        parsers[@((int32_t)0x11b58939)] = [^id (__unused NSData *_data, __unused NSUInteger* _offset, __unused id metaInfo)
        {
            return [Api1_DocumentAttribute documentAttributeAnimated];
        } copy];
        parsers[@((int32_t)0x6319d612)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * flags = nil;
            if ((flags = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSString * alt = nil;
            if ((alt = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            Api1_InputStickerSet * stickerset = nil;
            int32_t stickerset_signature = 0; [_data getBytes:(void *)&stickerset_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((stickerset = [Api1__Environment parseObject:_data offset:_offset implicitSignature:stickerset_signature metaInfo:nil]) == nil)
               return nil;
            Api1_MaskCoords * maskCoords = nil;
            if (flags != nil && ([flags intValue] & (1 << 0))) {
            int32_t maskCoords_signature = 0; [_data getBytes:(void *)&maskCoords_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((maskCoords = [Api1__Environment parseObject:_data offset:_offset implicitSignature:maskCoords_signature metaInfo:nil]) == nil)
               return nil;
            }
            return [Api1_DocumentAttribute documentAttributeStickerWithFlags:flags alt:alt stickerset:stickerset maskCoords:maskCoords];
        } copy];
        parsers[@((int32_t)0xef02ce6)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * flags = nil;
            if ((flags = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * duration = nil;
            if ((duration = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * w = nil;
            if ((w = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * h = nil;
            if ((h = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            return [Api1_DocumentAttribute documentAttributeVideoWithFlags:flags duration:duration w:w h:h];
        } copy];
        parsers[@((int32_t)0x9852f9c6)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * flags = nil;
            if ((flags = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * duration = nil;
            if ((duration = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSString * title = nil;
            if (flags != nil && ([flags intValue] & (1 << 0))) {
            if ((title = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            }
            NSString * performer = nil;
            if (flags != nil && ([flags intValue] & (1 << 1))) {
            if ((performer = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            }
            NSData * waveform = nil;
            if (flags != nil && ([flags intValue] & (1 << 2))) {
            if ((waveform = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            }
            return [Api1_DocumentAttribute documentAttributeAudioWithFlags:flags duration:duration title:title performer:performer waveform:waveform];
        } copy];
        parsers[@((int32_t)0x15590068)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * fileName = nil;
            if ((fileName = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            return [Api1_DocumentAttribute documentAttributeFilenameWithFileName:fileName];
        } copy];
        parsers[@((int32_t)0x9801d2f7)] = [^id (__unused NSData *_data, __unused NSUInteger* _offset, __unused id metaInfo)
        {
            return [Api1_DocumentAttribute documentAttributeHasStickers];
        } copy];
        parsers[@((int32_t)0xffb62b95)] = [^id (__unused NSData *_data, __unused NSUInteger* _offset, __unused id metaInfo)
        {
            return [Api1_InputStickerSet inputStickerSetEmpty];
        } copy];
        parsers[@((int32_t)0x9de7a269)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * accessHash = nil;
            if ((accessHash = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            return [Api1_InputStickerSet inputStickerSetIDWithPid:pid accessHash:accessHash];
        } copy];
        parsers[@((int32_t)0x861cc8a0)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSString * shortName = nil;
            if ((shortName = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            return [Api1_InputStickerSet inputStickerSetShortNameWithShortName:shortName];
        } copy];
        parsers[@((int32_t)0x40181ffe)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * accessHash = nil;
            if ((accessHash = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSData * fileReference = nil;
            if ((fileReference = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            NSString * thumbSize = nil;
            if ((thumbSize = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            return [Api1_InputFileLocation inputPhotoFileLocationWithPid:pid accessHash:accessHash fileReference:fileReference thumbSize:thumbSize];
        } copy];
        parsers[@((int32_t)0xbad07584)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * accessHash = nil;
            if ((accessHash = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSData * fileReference = nil;
            if ((fileReference = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            NSString * thumbSize = nil;
            if ((thumbSize = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            return [Api1_InputFileLocation inputDocumentFileLocationWithPid:pid accessHash:accessHash fileReference:fileReference thumbSize:thumbSize];
        } copy];
        parsers[@((int32_t)0xaed6dbb2)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * n = nil;
            if ((n = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * x = nil;
            if ((x = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x2210c154 metaInfo:nil]) == nil)
               return nil;
            NSNumber * y = nil;
            if ((y = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x2210c154 metaInfo:nil]) == nil)
               return nil;
            NSNumber * zoom = nil;
            if ((zoom = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x2210c154 metaInfo:nil]) == nil)
               return nil;
            return [Api1_MaskCoords maskCoordsWithN:n x:x y:y zoom:zoom];
        } copy];
        parsers[@((int32_t)0x9ba29cc1)] = [^id (NSData *_data, NSUInteger* _offset, __unused id metaInfo)
        {
            NSNumber * flags = nil;
            if ((flags = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSNumber * pid = nil;
            if ((pid = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSNumber * accessHash = nil;
            if ((accessHash = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0x22076cba metaInfo:nil]) == nil)
               return nil;
            NSData * fileReference = nil;
            if ((fileReference = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:[Api1__PreferNSDataTypeMetaInfo preferNSDataTypeMetaInfo]]) == nil)
               return nil;
            NSNumber * date = nil;
            if ((date = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSString * mimeType = nil;
            if ((mimeType = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xb5286e24 metaInfo:nil]) == nil)
               return nil;
            NSNumber * size = nil;
            if ((size = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSArray * thumbs = nil;
            if (flags != nil && ([flags intValue] & (1 << 0))) {
            int32_t thumbs_signature = 0; [_data getBytes:(void *)&thumbs_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((thumbs = [Api1__Environment parseObject:_data offset:_offset implicitSignature:thumbs_signature metaInfo:[Api1__BoxedTypeMetaInfo boxedTypeMetaInfo]]) == nil)
               return nil;
            }
            NSNumber * dcId = nil;
            if ((dcId = [Api1__Environment parseObject:_data offset:_offset implicitSignature:(int32_t)0xa8509bda metaInfo:nil]) == nil)
               return nil;
            NSArray * attributes = nil;
            int32_t attributes_signature = 0; [_data getBytes:(void *)&attributes_signature range:NSMakeRange(*_offset, 4)]; *_offset += 4;
            if ((attributes = [Api1__Environment parseObject:_data offset:_offset implicitSignature:attributes_signature metaInfo:[Api1__BoxedTypeMetaInfo boxedTypeMetaInfo]]) == nil)
               return nil;
            return [Api1_Document documentWithFlags:flags pid:pid accessHash:accessHash fileReference:fileReference date:date mimeType:mimeType size:size thumbs:thumbs dcId:dcId attributes:attributes];
        } copy];
});

    return parsers[@(constructorSignature)];
}

+ (NSData *)serializeObject:(id)object
{
    NSMutableData *data = [[NSMutableData alloc] init];
    if ([self serializeObject:object data:data addSignature:true])
        return data;
    return nil;
}

+ (bool)serializeObject:(id)object data:(NSMutableData *)data addSignature:(bool)addSignature
{
     Api1__Serializer *serializer = objc_getAssociatedObject(object, Api1__Serializer_Key);
     if (serializer == nil)
         return false;
     if (addSignature)
     {
         int32_t value = serializer.constructorSignature;
         [data appendBytes:(void *)&value length:4];
     }
     return serializer.serializeBlock(object, data);
}

+ (id)parseObject:(NSData *)data
{
    if (data.length < 4)
        return nil;
    int32_t constructorSignature = 0;
    [data getBytes:(void *)&constructorSignature length:4];
    NSUInteger offset = 4;
    return [self parseObject:data offset:&offset implicitSignature:constructorSignature metaInfo:nil];
}

+ (id)parseObject:(NSData *)data offset:(NSUInteger *)offset implicitSignature:(int32_t)implicitSignature metaInfo:(id)metaInfo
{
    id (^parser)(NSData *data, NSUInteger *offset, id metaInfo) = [self parserByConstructorSignature:implicitSignature];
    if (parser)
        return parser(data, offset, metaInfo);
    return nil;
}

@end

@interface Api1_BuiltinSerializer_Int : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Int

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0xA8509BDA serializeBlock:^bool (NSNumber *object, NSMutableData *data)
    {
        int32_t value = (int32_t)[object intValue];
        [data appendBytes:(void *)&value length:4];
        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_Long : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Long

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0x22076CBA serializeBlock:^bool (NSNumber *object, NSMutableData *data)
    {
        int64_t value = (int64_t)[object longLongValue];
        [data appendBytes:(void *)&value length:8];
        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_Double : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Double

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0x2210C154 serializeBlock:^bool (NSNumber *object, NSMutableData *data)
    {
        double value = (double)[object doubleValue];
        [data appendBytes:(void *)&value length:8];
        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_String : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_String

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0xB5286E24 serializeBlock:^bool (NSString *object, NSMutableData *data)
    {
        NSData *value = [object dataUsingEncoding:NSUTF8StringEncoding];
        int32_t length = value.length;
        int32_t padding = 0;
        if (length >= 254)
        {
            uint8_t tmp = 254;
            [data appendBytes:&tmp length:1];
            [data appendBytes:(void *)&length length:3];
            padding = (((length % 4) == 0 ? length : (length + 4 - (length % 4)))) - length;
        }
        else
        {
            [data appendBytes:(void *)&length length:1];
            padding = ((((length + 1) % 4) == 0 ? (length + 1) : ((length + 1) + 4 - ((length + 1) % 4)))) - (length + 1);
        }
        [data appendData:value];
        for (int i = 0; i < padding; i++)
        {
            uint8_t tmp = 0;
            [data appendBytes:(void *)&tmp length:1];
        }

        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_Bytes : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Bytes

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0xB5286E24 serializeBlock:^bool (NSData *object, NSMutableData *data)
    {
        NSData *value = object;
        int32_t length = (int32_t)value.length;
        int32_t padding = 0;
        if (length >= 254)
        {
            uint8_t tmp = 254;
            [data appendBytes:&tmp length:1];
            [data appendBytes:(void *)&length length:3];
            padding = (((length % 4) == 0 ? length : (length + 4 - (length % 4)))) - length;
        }
        else
        {
            [data appendBytes:(void *)&length length:1];
            padding = ((((length + 1) % 4) == 0 ? (length + 1) : ((length + 1) + 4 - ((length + 1) % 4)))) - (length + 1);
        }
        [data appendData:value];
        for (int i = 0; i < padding; i++)
        {
            uint8_t tmp = 0;
            [data appendBytes:(void *)&tmp length:1];
        }

        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_Int128 : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Int128

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0x4BB5362B serializeBlock:^bool (NSData *object, NSMutableData *data)
    {
        if (object.length != 16)
            return false;
        [data appendData:object];
        return true;
    }];
}

@end

@interface Api1_BuiltinSerializer_Int256 : Api1__Serializer
@end

@implementation Api1_BuiltinSerializer_Int256

- (instancetype)init
{
    return [super initWithConstructorSignature:(int32_t)0x0929C32F serializeBlock:^bool (NSData *object, NSMutableData *data)
    {
        if (object.length != 32)
            return false;
        [data appendData:object];
        return true;
    }];
}

@end



@implementation Api1_FunctionContext

- (instancetype)initWithPayload:(NSData *)payload responseParser:(id (^)(NSData *))responseParser metadata:(id)metadata
{
    self = [super init];
    if (self != nil)
    {
        _payload = payload;
        _responseParser = [responseParser copy];
        _metadata = metadata;
    }
    return self;
}

@end

@interface Api1_Photo ()

@property (nonatomic, strong) NSNumber * pid;

@end

@interface Api1_Photo_photoEmpty ()

@end

@interface Api1_Photo_photo ()

@property (nonatomic, strong) NSNumber * flags;
@property (nonatomic, strong) NSNumber * accessHash;
@property (nonatomic, strong) NSData * fileReference;
@property (nonatomic, strong) NSNumber * date;
@property (nonatomic, strong) NSArray * sizes;
@property (nonatomic, strong) NSNumber * dcId;

@end

@implementation Api1_Photo

+ (Api1_Photo_photoEmpty *)photoEmptyWithPid:(NSNumber *)pid
{
    Api1_Photo_photoEmpty *_object = [[Api1_Photo_photoEmpty alloc] init];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    return _object;
}

+ (Api1_Photo_photo *)photoWithFlags:(NSNumber *)flags pid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference date:(NSNumber *)date sizes:(NSArray *)sizes dcId:(NSNumber *)dcId
{
    Api1_Photo_photo *_object = [[Api1_Photo_photo alloc] init];
    _object.flags = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:flags] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.accessHash = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:accessHash] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.fileReference = [Api1__Serializer addSerializerToObject:[fileReference copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    _object.date = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:date] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.sizes = 
({
NSMutableArray *sizes_copy = [[NSMutableArray alloc] initWithCapacity:sizes.count];
for (id sizes_item in sizes)
{
    [sizes_copy addObject:sizes_item];
}
id sizes_result = [Api1__Serializer addSerializerToObject:sizes_copy serializer:[[Api1__Serializer alloc] initWithConstructorSignature:(int32_t)0x1cb5c415 serializeBlock:^bool (NSArray *object, NSMutableData *data)
{
    int32_t count = (int32_t)object.count;
    [data appendBytes:(void *)&count length:4];
    for (id item in object)
    {
        if (![Api1__Environment serializeObject:item data:data addSignature:true])
        return false;
    }
    return true;
}]]; sizes_result;});
    _object.dcId = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:dcId] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    return _object;
}


@end

@implementation Api1_Photo_photoEmpty

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x2331b22d serializeBlock:^bool (Api1_Photo_photoEmpty *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoEmpty id:%@)", self.pid];
}

@end

@implementation Api1_Photo_photo

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xd07504a5 serializeBlock:^bool (Api1_Photo_photo *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.flags data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.accessHash data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.fileReference data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.date data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.sizes data:data addSignature:true])
                return false;
            if (![Api1__Environment serializeObject:object.dcId data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photo flags:%@ id:%@ access_hash:%@ file_reference:%d date:%@ sizes:%@ dc_id:%@)", self.flags, self.pid, self.accessHash, (int)[self.fileReference length], self.date, self.sizes, self.dcId];
}

@end




@interface Api1_PhotoSize ()

@property (nonatomic, strong) NSString * type;

@end

@interface Api1_PhotoSize_photoSizeEmpty ()

@end

@interface Api1_PhotoSize_photoSize ()

@property (nonatomic, strong) Api1_FileLocation * location;
@property (nonatomic, strong) NSNumber * w;
@property (nonatomic, strong) NSNumber * h;
@property (nonatomic, strong) NSNumber * size;

@end

@interface Api1_PhotoSize_photoCachedSize ()

@property (nonatomic, strong) Api1_FileLocation * location;
@property (nonatomic, strong) NSNumber * w;
@property (nonatomic, strong) NSNumber * h;
@property (nonatomic, strong) NSData * bytes;

@end

@interface Api1_PhotoSize_photoStrippedSize ()

@property (nonatomic, strong) NSData * bytes;

@end

@implementation Api1_PhotoSize

+ (Api1_PhotoSize_photoSizeEmpty *)photoSizeEmptyWithType:(NSString *)type
{
    Api1_PhotoSize_photoSizeEmpty *_object = [[Api1_PhotoSize_photoSizeEmpty alloc] init];
    _object.type = [Api1__Serializer addSerializerToObject:[type copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    return _object;
}

+ (Api1_PhotoSize_photoSize *)photoSizeWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h size:(NSNumber *)size
{
    Api1_PhotoSize_photoSize *_object = [[Api1_PhotoSize_photoSize alloc] init];
    _object.type = [Api1__Serializer addSerializerToObject:[type copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.location = location;
    _object.w = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:w] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.h = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:h] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.size = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:size] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    return _object;
}

+ (Api1_PhotoSize_photoCachedSize *)photoCachedSizeWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h bytes:(NSData *)bytes
{
    Api1_PhotoSize_photoCachedSize *_object = [[Api1_PhotoSize_photoCachedSize alloc] init];
    _object.type = [Api1__Serializer addSerializerToObject:[type copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.location = location;
    _object.w = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:w] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.h = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:h] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.bytes = [Api1__Serializer addSerializerToObject:[bytes copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    return _object;
}

+ (Api1_PhotoSize_photoStrippedSize *)photoStrippedSizeWithType:(NSString *)type bytes:(NSData *)bytes
{
    Api1_PhotoSize_photoStrippedSize *_object = [[Api1_PhotoSize_photoStrippedSize alloc] init];
    _object.type = [Api1__Serializer addSerializerToObject:[type copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.bytes = [Api1__Serializer addSerializerToObject:[bytes copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    return _object;
}

+ (Api1_PhotoSize_photoSizeProgressive *)photoSizeProgressiveWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h sizes:(NSArray *)sizes {
    Api1_PhotoSize_photoSizeProgressive *_object = [[Api1_PhotoSize_photoSizeProgressive alloc] init];
    _object.type = [Api1__Serializer addSerializerToObject:[type copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.location = location;
    _object.w = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:w] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.h = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:h] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.sizes = sizes;
    return _object;
}

@end

@implementation Api1_PhotoSize_photoSizeEmpty

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xe17e23c serializeBlock:^bool (Api1_PhotoSize_photoSizeEmpty *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.type data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoSizeEmpty type:%d)", (int)[self.type length]];
}

@end

@implementation Api1_PhotoSize_photoSize

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x77bfb61b serializeBlock:^bool (Api1_PhotoSize_photoSize *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.type data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.location data:data addSignature:true])
                return false;
            if (![Api1__Environment serializeObject:object.w data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.h data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.size data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoSize type:%d location:%@ w:%@ h:%@ size:%@)", (int)[self.type length], self.location, self.w, self.h, self.size];
}

@end

@implementation Api1_PhotoSize_photoCachedSize

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xe9a734fa serializeBlock:^bool (Api1_PhotoSize_photoCachedSize *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.type data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.location data:data addSignature:true])
                return false;
            if (![Api1__Environment serializeObject:object.w data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.h data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.bytes data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoCachedSize type:%d location:%@ w:%@ h:%@ bytes:%d)", (int)[self.type length], self.location, self.w, self.h, (int)[self.bytes length]];
}

@end

@implementation Api1_PhotoSize_photoStrippedSize

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xe0b0bc2e serializeBlock:^bool (Api1_PhotoSize_photoStrippedSize *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.type data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.bytes data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoStrippedSize type:%d bytes:%d)", (int)[self.type length], (int)[self.bytes length]];
}

@end


@implementation Api1_PhotoSize_photoSizeProgressive : Api1_PhotoSize

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(photoSizeProgressive type:%d location:%@ w:%@ h:%@ sizes:%@)", (int)[self.type length], self.location, self.w, self.h, self.sizes];
}

@end

@interface Api1_FileLocation ()

@property (nonatomic, strong) NSNumber * volumeId;
@property (nonatomic, strong) NSNumber * localId;

@end

@interface Api1_FileLocation_fileLocationToBeDeprecated ()

@end

@implementation Api1_FileLocation

+ (Api1_FileLocation_fileLocationToBeDeprecated *)fileLocationToBeDeprecatedWithVolumeId:(NSNumber *)volumeId localId:(NSNumber *)localId
{
    Api1_FileLocation_fileLocationToBeDeprecated *_object = [[Api1_FileLocation_fileLocationToBeDeprecated alloc] init];
    _object.volumeId = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:volumeId] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.localId = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:localId] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    return _object;
}


@end

@implementation Api1_FileLocation_fileLocationToBeDeprecated

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xbc7fc6cd serializeBlock:^bool (Api1_FileLocation_fileLocationToBeDeprecated *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.volumeId data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.localId data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(fileLocationToBeDeprecated volume_id:%@ local_id:%@)", self.volumeId, self.localId];
}

@end




@interface Api1_DocumentAttribute ()

@end

@interface Api1_DocumentAttribute_documentAttributeImageSize ()

@property (nonatomic, strong) NSNumber * w;
@property (nonatomic, strong) NSNumber * h;

@end

@interface Api1_DocumentAttribute_documentAttributeAnimated ()

@end

@interface Api1_DocumentAttribute_documentAttributeSticker ()

@property (nonatomic, strong) NSNumber * flags;
@property (nonatomic, strong) NSString * alt;
@property (nonatomic, strong) Api1_InputStickerSet * stickerset;
@property (nonatomic, strong) Api1_MaskCoords * maskCoords;

@end

@interface Api1_DocumentAttribute_documentAttributeVideo ()

@property (nonatomic, strong) NSNumber * flags;
@property (nonatomic, strong) NSNumber * duration;
@property (nonatomic, strong) NSNumber * w;
@property (nonatomic, strong) NSNumber * h;

@end

@interface Api1_DocumentAttribute_documentAttributeAudio ()

@property (nonatomic, strong) NSNumber * flags;
@property (nonatomic, strong) NSNumber * duration;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSString * performer;
@property (nonatomic, strong) NSData * waveform;

@end

@interface Api1_DocumentAttribute_documentAttributeFilename ()

@property (nonatomic, strong) NSString * fileName;

@end

@interface Api1_DocumentAttribute_documentAttributeHasStickers ()

@end

@implementation Api1_DocumentAttribute

+ (Api1_DocumentAttribute_documentAttributeImageSize *)documentAttributeImageSizeWithW:(NSNumber *)w h:(NSNumber *)h
{
    Api1_DocumentAttribute_documentAttributeImageSize *_object = [[Api1_DocumentAttribute_documentAttributeImageSize alloc] init];
    _object.w = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:w] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.h = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:h] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeAnimated *)documentAttributeAnimated
{
    Api1_DocumentAttribute_documentAttributeAnimated *_object = [[Api1_DocumentAttribute_documentAttributeAnimated alloc] init];
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeSticker *)documentAttributeStickerWithFlags:(NSNumber *)flags alt:(NSString *)alt stickerset:(Api1_InputStickerSet *)stickerset maskCoords:(Api1_MaskCoords *)maskCoords
{
    Api1_DocumentAttribute_documentAttributeSticker *_object = [[Api1_DocumentAttribute_documentAttributeSticker alloc] init];
    _object.flags = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:flags] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.alt = [Api1__Serializer addSerializerToObject:[alt copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.stickerset = stickerset;
    _object.maskCoords = maskCoords;
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeVideo *)documentAttributeVideoWithFlags:(NSNumber *)flags duration:(NSNumber *)duration w:(NSNumber *)w h:(NSNumber *)h
{
    Api1_DocumentAttribute_documentAttributeVideo *_object = [[Api1_DocumentAttribute_documentAttributeVideo alloc] init];
    _object.flags = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:flags] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.duration = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:duration] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.w = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:w] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.h = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:h] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeAudio *)documentAttributeAudioWithFlags:(NSNumber *)flags duration:(NSNumber *)duration title:(NSString *)title performer:(NSString *)performer waveform:(NSData *)waveform
{
    Api1_DocumentAttribute_documentAttributeAudio *_object = [[Api1_DocumentAttribute_documentAttributeAudio alloc] init];
    _object.flags = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:flags] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.duration = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:duration] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.title = [Api1__Serializer addSerializerToObject:[title copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.performer = [Api1__Serializer addSerializerToObject:[performer copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.waveform = [Api1__Serializer addSerializerToObject:[waveform copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeFilename *)documentAttributeFilenameWithFileName:(NSString *)fileName
{
    Api1_DocumentAttribute_documentAttributeFilename *_object = [[Api1_DocumentAttribute_documentAttributeFilename alloc] init];
    _object.fileName = [Api1__Serializer addSerializerToObject:[fileName copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    return _object;
}

+ (Api1_DocumentAttribute_documentAttributeHasStickers *)documentAttributeHasStickers
{
    Api1_DocumentAttribute_documentAttributeHasStickers *_object = [[Api1_DocumentAttribute_documentAttributeHasStickers alloc] init];
    return _object;
}


@end

@implementation Api1_DocumentAttribute_documentAttributeImageSize

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x6c37c15c serializeBlock:^bool (Api1_DocumentAttribute_documentAttributeImageSize *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.w data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.h data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeImageSize w:%@ h:%@)", self.w, self.h];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeAnimated

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x11b58939 serializeBlock:^bool (__unused Api1_DocumentAttribute_documentAttributeAnimated *object, __unused NSMutableData *data)
        {
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeAnimated)"];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeSticker

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x6319d612 serializeBlock:^bool (Api1_DocumentAttribute_documentAttributeSticker *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.flags data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.alt data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.stickerset data:data addSignature:true])
                return false;
            if ([object.flags intValue] & (1 << 0)) {
            if (![Api1__Environment serializeObject:object.maskCoords data:data addSignature:true])
                return false;
            }
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeSticker flags:%@ alt:%d stickerset:%@ mask_coords:%@)", self.flags, (int)[self.alt length], self.stickerset, self.maskCoords];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeVideo

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xef02ce6 serializeBlock:^bool (Api1_DocumentAttribute_documentAttributeVideo *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.flags data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.duration data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.w data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.h data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeVideo flags:%@ duration:%@ w:%@ h:%@)", self.flags, self.duration, self.w, self.h];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeAudio

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x9852f9c6 serializeBlock:^bool (Api1_DocumentAttribute_documentAttributeAudio *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.flags data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.duration data:data addSignature:false])
                return false;
            if ([object.flags intValue] & (1 << 0)) {
            if (![Api1__Environment serializeObject:object.title data:data addSignature:false])
                return false;
            }
            if ([object.flags intValue] & (1 << 1)) {
            if (![Api1__Environment serializeObject:object.performer data:data addSignature:false])
                return false;
            }
            if ([object.flags intValue] & (1 << 2)) {
            if (![Api1__Environment serializeObject:object.waveform data:data addSignature:false])
                return false;
            }
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeAudio flags:%@ duration:%@ title:%d performer:%d waveform:%d)", self.flags, self.duration, (int)[self.title length], (int)[self.performer length], (int)[self.waveform length]];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeFilename

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x15590068 serializeBlock:^bool (Api1_DocumentAttribute_documentAttributeFilename *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.fileName data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeFilename file_name:%d)", (int)[self.fileName length]];
}

@end

@implementation Api1_DocumentAttribute_documentAttributeHasStickers

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x9801d2f7 serializeBlock:^bool (__unused Api1_DocumentAttribute_documentAttributeHasStickers *object, __unused NSMutableData *data)
        {
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(documentAttributeHasStickers)"];
}

@end




@interface Api1_InputStickerSet ()

@end

@interface Api1_InputStickerSet_inputStickerSetEmpty ()

@end

@interface Api1_InputStickerSet_inputStickerSetID ()

@property (nonatomic, strong) NSNumber * pid;
@property (nonatomic, strong) NSNumber * accessHash;

@end

@interface Api1_InputStickerSet_inputStickerSetShortName ()

@property (nonatomic, strong) NSString * shortName;

@end

@implementation Api1_InputStickerSet

+ (Api1_InputStickerSet_inputStickerSetEmpty *)inputStickerSetEmpty
{
    Api1_InputStickerSet_inputStickerSetEmpty *_object = [[Api1_InputStickerSet_inputStickerSetEmpty alloc] init];
    return _object;
}

+ (Api1_InputStickerSet_inputStickerSetID *)inputStickerSetIDWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash
{
    Api1_InputStickerSet_inputStickerSetID *_object = [[Api1_InputStickerSet_inputStickerSetID alloc] init];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.accessHash = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:accessHash] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    return _object;
}

+ (Api1_InputStickerSet_inputStickerSetShortName *)inputStickerSetShortNameWithShortName:(NSString *)shortName
{
    Api1_InputStickerSet_inputStickerSetShortName *_object = [[Api1_InputStickerSet_inputStickerSetShortName alloc] init];
    _object.shortName = [Api1__Serializer addSerializerToObject:[shortName copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    return _object;
}


@end

@implementation Api1_InputStickerSet_inputStickerSetEmpty

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xffb62b95 serializeBlock:^bool (__unused Api1_InputStickerSet_inputStickerSetEmpty *object, __unused NSMutableData *data)
        {
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(inputStickerSetEmpty)"];
}

@end

@implementation Api1_InputStickerSet_inputStickerSetID

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x9de7a269 serializeBlock:^bool (Api1_InputStickerSet_inputStickerSetID *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.accessHash data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(inputStickerSetID id:%@ access_hash:%@)", self.pid, self.accessHash];
}

@end

@implementation Api1_InputStickerSet_inputStickerSetShortName

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x861cc8a0 serializeBlock:^bool (Api1_InputStickerSet_inputStickerSetShortName *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.shortName data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(inputStickerSetShortName short_name:%d)", (int)[self.shortName length]];
}

@end




@interface Api1_InputFileLocation ()

@property (nonatomic, strong) NSNumber * pid;
@property (nonatomic, strong) NSNumber * accessHash;
@property (nonatomic, strong) NSData * fileReference;
@property (nonatomic, strong) NSString * thumbSize;

@end

@interface Api1_InputFileLocation_inputPhotoFileLocation ()

@end

@interface Api1_InputFileLocation_inputDocumentFileLocation ()

@end

@implementation Api1_InputFileLocation

+ (Api1_InputFileLocation_inputPhotoFileLocation *)inputPhotoFileLocationWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference thumbSize:(NSString *)thumbSize
{
    Api1_InputFileLocation_inputPhotoFileLocation *_object = [[Api1_InputFileLocation_inputPhotoFileLocation alloc] init];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.accessHash = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:accessHash] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.fileReference = [Api1__Serializer addSerializerToObject:[fileReference copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    _object.thumbSize = [Api1__Serializer addSerializerToObject:[thumbSize copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    return _object;
}

+ (Api1_InputFileLocation_inputDocumentFileLocation *)inputDocumentFileLocationWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference thumbSize:(NSString *)thumbSize
{
    Api1_InputFileLocation_inputDocumentFileLocation *_object = [[Api1_InputFileLocation_inputDocumentFileLocation alloc] init];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.accessHash = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:accessHash] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.fileReference = [Api1__Serializer addSerializerToObject:[fileReference copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    _object.thumbSize = [Api1__Serializer addSerializerToObject:[thumbSize copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    return _object;
}


@end

@implementation Api1_InputFileLocation_inputPhotoFileLocation

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x40181ffe serializeBlock:^bool (Api1_InputFileLocation_inputPhotoFileLocation *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.accessHash data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.fileReference data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.thumbSize data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(inputPhotoFileLocation id:%@ access_hash:%@ file_reference:%d thumb_size:%d)", self.pid, self.accessHash, (int)[self.fileReference length], (int)[self.thumbSize length]];
}

@end

@implementation Api1_InputFileLocation_inputDocumentFileLocation

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xbad07584 serializeBlock:^bool (Api1_InputFileLocation_inputDocumentFileLocation *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.accessHash data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.fileReference data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.thumbSize data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(inputDocumentFileLocation id:%@ access_hash:%@ file_reference:%d thumb_size:%d)", self.pid, self.accessHash, (int)[self.fileReference length], (int)[self.thumbSize length]];
}

@end




@interface Api1_MaskCoords ()

@property (nonatomic, strong) NSNumber * n;
@property (nonatomic, strong) NSNumber * x;
@property (nonatomic, strong) NSNumber * y;
@property (nonatomic, strong) NSNumber * zoom;

@end

@interface Api1_MaskCoords_maskCoords ()

@end

@implementation Api1_MaskCoords

+ (Api1_MaskCoords_maskCoords *)maskCoordsWithN:(NSNumber *)n x:(NSNumber *)x y:(NSNumber *)y zoom:(NSNumber *)zoom
{
    Api1_MaskCoords_maskCoords *_object = [[Api1_MaskCoords_maskCoords alloc] init];
    _object.n = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:n] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.x = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:x] serializer:[[Api1_BuiltinSerializer_Double alloc] init]];
    _object.y = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:y] serializer:[[Api1_BuiltinSerializer_Double alloc] init]];
    _object.zoom = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:zoom] serializer:[[Api1_BuiltinSerializer_Double alloc] init]];
    return _object;
}


@end

@implementation Api1_MaskCoords_maskCoords

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0xaed6dbb2 serializeBlock:^bool (Api1_MaskCoords_maskCoords *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.n data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.x data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.y data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.zoom data:data addSignature:false])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(maskCoords n:%@ x:%@ y:%@ zoom:%@)", self.n, self.x, self.y, self.zoom];
}

@end




@interface Api1_Document ()

@property (nonatomic, strong) NSNumber * flags;
@property (nonatomic, strong) NSNumber * pid;
@property (nonatomic, strong) NSNumber * accessHash;
@property (nonatomic, strong) NSData * fileReference;
@property (nonatomic, strong) NSNumber * date;
@property (nonatomic, strong) NSString * mimeType;
@property (nonatomic, strong) NSNumber * size;
@property (nonatomic, strong) NSArray * thumbs;
@property (nonatomic, strong) NSNumber * dcId;
@property (nonatomic, strong) NSArray * attributes;

@end

@interface Api1_Document_document ()

@end

@implementation Api1_Document

+ (Api1_Document_document *)documentWithFlags:(NSNumber *)flags pid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference date:(NSNumber *)date mimeType:(NSString *)mimeType size:(NSNumber *)size thumbs:(NSArray *)thumbs dcId:(NSNumber *)dcId attributes:(NSArray *)attributes
{
    Api1_Document_document *_object = [[Api1_Document_document alloc] init];
    _object.flags = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:flags] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.pid = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:pid] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.accessHash = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:accessHash] serializer:[[Api1_BuiltinSerializer_Long alloc] init]];
    _object.fileReference = [Api1__Serializer addSerializerToObject:[fileReference copy] serializer:[[Api1_BuiltinSerializer_Bytes alloc] init]];
    _object.date = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:date] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.mimeType = [Api1__Serializer addSerializerToObject:[mimeType copy] serializer:[[Api1_BuiltinSerializer_String alloc] init]];
    _object.size = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:size] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.thumbs = 
({
NSMutableArray *thumbs_copy = [[NSMutableArray alloc] initWithCapacity:thumbs.count];
for (id thumbs_item in thumbs)
{
    [thumbs_copy addObject:thumbs_item];
}
id thumbs_result = [Api1__Serializer addSerializerToObject:thumbs_copy serializer:[[Api1__Serializer alloc] initWithConstructorSignature:(int32_t)0x1cb5c415 serializeBlock:^bool (NSArray *object, NSMutableData *data)
{
    int32_t count = (int32_t)object.count;
    [data appendBytes:(void *)&count length:4];
    for (id item in object)
    {
        if (![Api1__Environment serializeObject:item data:data addSignature:true])
        return false;
    }
    return true;
}]]; thumbs_result;});
    _object.dcId = [Api1__Serializer addSerializerToObject:[[Api1__Number alloc] initWithNumber:dcId] serializer:[[Api1_BuiltinSerializer_Int alloc] init]];
    _object.attributes = 
({
NSMutableArray *attributes_copy = [[NSMutableArray alloc] initWithCapacity:attributes.count];
for (id attributes_item in attributes)
{
    [attributes_copy addObject:attributes_item];
}
id attributes_result = [Api1__Serializer addSerializerToObject:attributes_copy serializer:[[Api1__Serializer alloc] initWithConstructorSignature:(int32_t)0x1cb5c415 serializeBlock:^bool (NSArray *object, NSMutableData *data)
{
    int32_t count = (int32_t)object.count;
    [data appendBytes:(void *)&count length:4];
    for (id item in object)
    {
        if (![Api1__Environment serializeObject:item data:data addSignature:true])
        return false;
    }
    return true;
}]]; attributes_result;});
    return _object;
}


@end

@implementation Api1_Document_document

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [Api1__Serializer addSerializerToObject:self withConstructorSignature:0x9ba29cc1 serializeBlock:^bool (Api1_Document_document *object, NSMutableData *data)
        {
            if (![Api1__Environment serializeObject:object.flags data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.pid data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.accessHash data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.fileReference data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.date data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.mimeType data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.size data:data addSignature:false])
                return false;
            if ([object.flags intValue] & (1 << 0)) {
            if (![Api1__Environment serializeObject:object.thumbs data:data addSignature:true])
                return false;
            }
            if (![Api1__Environment serializeObject:object.dcId data:data addSignature:false])
                return false;
            if (![Api1__Environment serializeObject:object.attributes data:data addSignature:true])
                return false;
            return true;
        }];
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(document flags:%@ id:%@ access_hash:%@ file_reference:%d date:%@ mime_type:%d size:%@ thumbs:%@ dc_id:%@ attributes:%@)", self.flags, self.pid, self.accessHash, (int)[self.fileReference length], self.date, (int)[self.mimeType length], self.size, self.thumbs, self.dcId, self.attributes];
}

@end




@implementation Api1: NSObject

@end
