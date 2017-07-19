#import "TGStickerPackReference.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

@implementation TGStickerPackBuiltinReference

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder
{
    return [self init];
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)__unused coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder
{
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)__unused coder
{
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGStickerPackBuiltinReference class]];
}

- (NSUInteger)hash {
    return 1;
}

@end

@implementation TGStickerPackIdReference

- (instancetype)initWithPackId:(int64_t)packId packAccessHash:(int64_t)packAccessHash shortName:(NSString *)shortName
{
    self = [super init];
    if (self != nil)
    {
        _packId = packId;
        _packAccessHash = packAccessHash;
        _shortName = shortName;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithPackId:[aDecoder decodeInt64ForKey:@"packId"] packAccessHash:[aDecoder decodeInt64ForKey:@"packAccessHash"] shortName:[aDecoder decodeObjectForKey:@"shortName"]];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithPackId:[coder decodeInt64ForCKey:"i"] packAccessHash:[coder decodeInt64ForCKey:"a"] shortName:[coder decodeStringForCKey:"s"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:_packId forKey:@"packId"];
    [aCoder encodeInt64:_packAccessHash forKey:@"packAccessHash"];
    if (_shortName != nil)
        [aCoder encodeObject:_shortName forKey:@"shortName"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt64:_packId forCKey:"i"];
    [coder encodeInt64:_packAccessHash forCKey:"a"];
    [coder encodeString:_shortName forCKey:"s"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGStickerPackIdReference class]] && ((TGStickerPackIdReference *)object)->_packId == _packId && ((TGStickerPackIdReference *)object)->_packAccessHash == _packAccessHash;
}

- (NSString *)description {
    return [[NSString alloc] initWithFormat:@"(TGStickerPackIdReference packId: %lld, %lld, %@)", _packId, _packAccessHash, _shortName];
}

- (NSUInteger)hash {
    return (NSUInteger)_packId;
}

@end

@implementation TGStickerPackShortnameReference

- (instancetype)initWithShortName:(NSString *)shortName
{
    self = [super init];
    if (self != nil)
    {
        _shortName = shortName;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithShortName:[aDecoder decodeObjectForKey:@"shortName"]];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithShortName:[coder decodeStringForCKey:"s"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_shortName forKey:@"shortName"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeString:_shortName forCKey:"s"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGStickerPackShortnameReference class]] && TGStringCompare(((TGStickerPackShortnameReference *)object)->_shortName, _shortName);
}

- (NSUInteger)hash {
    return 2;
}

@end
