#import "TGMessageEntity.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageEntity

- (instancetype)initWithRange:(NSRange)range
{
    self = [super init];
    if (self != nil)
    {
        _range = range;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithRange:NSMakeRange([coder decodeInt32ForCKey:"r.s"], [coder decodeInt32ForCKey:"r.l"])];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:(int32_t)_range.location forCKey:"r.s"];
    [coder encodeInt32:(int32_t)_range.length forCKey:"r.l"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithRange:NSMakeRange([aDecoder decodeInt32ForKey:@"r.s"], [aDecoder decodeInt32ForKey:@"r.l"])];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:(int32_t)_range.location forKey:@"r.s"];
    [aCoder encodeInt32:(int32_t)_range.length forKey:@"r.l"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGMessageEntity class]] && ((TGMessageEntity *)object)->_range.location == _range.location && ((TGMessageEntity *)object)->_range.length == _range.length;
}

@end
