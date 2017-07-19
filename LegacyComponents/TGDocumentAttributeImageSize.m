#import "TGDocumentAttributeImageSize.h"

#import "PSKeyValueCoder.h"

@implementation TGDocumentAttributeImageSize

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _size = size;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithSize:CGSizeMake([coder decodeInt32ForCKey:"w"], [coder decodeInt32ForCKey:"h"])];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:(int32_t)_size.width forCKey:"w"];
    [coder encodeInt32:(int32_t)_size.height forCKey:"h"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithSize:[aDecoder decodeCGSizeForKey:@"size"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeCGSize:_size forKey:@"size"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGDocumentAttributeImageSize class]] && CGSizeEqualToSize(_size, ((TGDocumentAttributeImageSize *)object)->_size);
}

@end
