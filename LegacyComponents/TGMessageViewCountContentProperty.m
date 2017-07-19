#import "TGMessageViewCountContentProperty.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageViewCountContentProperty

- (instancetype)initWithViewCount:(int32_t)viewCount {
    self = [super init];
    if (self != nil) {
        _viewCount = viewCount;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithViewCount:[coder decodeInt32ForCKey:"vc"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:_viewCount forCKey:"vc"];
}

@end
