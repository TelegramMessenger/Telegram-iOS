#import "TGDocumentAttributeSticker.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

@implementation TGStickerMaskDescription

- (instancetype)initWithN:(int32_t)n point:(CGPoint)point zoom:(CGFloat)zoom {
    self = [super init];
    if (self != nil) {
        _n = n;
        _point = point;
        _zoom = zoom;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithN:[coder decodeInt32ForCKey:"n"] point:CGPointMake([coder decodeDoubleForCKey:"x"], [coder decodeDoubleForCKey:"y"]) zoom:[coder decodeDoubleForCKey:"z"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:_n forCKey:"n"];
    [coder encodeDouble:_point.x forCKey:"x"];
    [coder encodeDouble:_point.y forCKey:"y"];
    [coder encodeDouble:_zoom forCKey:"z"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithN:[aDecoder decodeInt32ForKey:@"n"] point:CGPointMake([aDecoder decodeDoubleForKey:@"x"], [aDecoder decodeDoubleForKey:@"y"]) zoom:[aDecoder decodeDoubleForKey:@"z"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_n forKey:@"n"];
    [aCoder encodeDouble:_point.x forKey:@"x"];
    [aCoder encodeDouble:_point.y forKey:@"y"];
    [aCoder encodeDouble:_zoom forKey:@"z"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TGStickerMaskDescription class]]) {
        return false;
    }
    TGStickerMaskDescription *other = object;
    if (_n != other->_n) {
        return false;
    }
    if (!CGPointEqualToPoint(_point, other->_point)) {
        return false;
    }
    if (ABS(_zoom - other->_zoom) > FLT_EPSILON) {
        return false;
    }
    return true;
}

@end

@implementation TGDocumentAttributeSticker

- (instancetype)initWithAlt:(NSString *)alt packReference:(id<TGStickerPackReference>)packReference mask:(TGStickerMaskDescription *)mask
{
    self = [super init];
    if (self != nil)
    {
        _alt = alt;
        _packReference = packReference;
        _mask = mask;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithAlt:[coder decodeStringForCKey:"alt"] packReference:(id<TGStickerPackReference>)[coder decodeObjectForCKey:"packReference"] mask:(TGStickerMaskDescription *)[coder decodeObjectForCKey:"mask"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeString:_alt forCKey:"alt"];
    [coder encodeObject:_packReference forCKey:"packReference"];
    [coder encodeObject:_mask forCKey:"mask"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithAlt:[aDecoder decodeObjectForKey:@"alt"] packReference:[aDecoder decodeObjectForKey:@"packReference"] mask:[aDecoder decodeObjectForKey:@"mask"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_alt != nil)
        [aCoder encodeObject:_alt forKey:@"alt"];
    if (_packReference != nil)
        [aCoder encodeObject:_packReference forKey:@"packReference"];
    if (_mask != nil)
        [aCoder encodeObject:_mask forKey:@"mask"];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGDocumentAttributeSticker class]]) {
        return false;
    }
    
    if (!TGObjectCompare(_packReference, ((TGDocumentAttributeSticker *)object)->_packReference)) {
        return false;
    }
    
    if (!TGObjectCompare(_mask, ((TGDocumentAttributeSticker *)object)->_mask)) {
        return false;
    }
    
    if (!TGStringCompare(_alt, ((TGDocumentAttributeSticker *)object)->_alt)) {
        return false;
    }
    
    return true;
}

@end
