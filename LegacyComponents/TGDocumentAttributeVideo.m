#import "TGDocumentAttributeVideo.h"

#import "PSKeyValueCoder.h"

@implementation TGDocumentAttributeVideo

- (instancetype)initWithRoundMessage:(bool)isRoundMessage size:(CGSize)size duration:(int32_t)duration {
    self = [super init];
    if (self != nil) {
        _isRoundMessage = isRoundMessage;
        _size = size;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithRoundMessage:[aDecoder decodeBoolForKey:@"roundMessage"] size:[aDecoder decodeCGSizeForKey:@"size"] duration:[aDecoder decodeInt32ForKey:@"duration"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:_isRoundMessage forKey:@"roundMessage"];
    [aCoder encodeCGSize:_size forKey:@"size"];
    [aCoder encodeInt32:_duration forKey:@"duration"];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithRoundMessage:[coder decodeInt32ForCKey:"r"] size:CGSizeMake([coder decodeInt32ForCKey:"s.w"], [coder decodeInt32ForCKey:"s.h"]) duration:[coder decodeInt32ForCKey:"d"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:(int32_t)_isRoundMessage forKey:@"r"];
    [coder encodeInt32:(int32_t)_size.width forCKey:"s.w"];
    [coder encodeInt32:(int32_t)_size.height forCKey:"s.h"];
    [coder encodeInt32:_duration forCKey:"d"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGDocumentAttributeVideo class]] && _isRoundMessage == ((TGDocumentAttributeVideo *)object)->_isRoundMessage && CGSizeEqualToSize(_size, ((TGDocumentAttributeVideo *)object)->_size) && _duration == ((TGDocumentAttributeVideo *)object)->_duration;
}

@end
