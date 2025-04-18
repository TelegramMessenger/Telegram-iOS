#import "TGMessageEntityMentionName.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageEntityMentionName

- (instancetype)initWithRange:(NSRange)range userId:(int32_t)userId {
    self = [super initWithRange:range];
    if (self != nil) {
        _userId = userId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    self = [super initWithKeyValueCoder:coder];
    if (self != nil) {
        _userId = [coder decodeInt32ForCKey:"userId"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [super encodeWithKeyValueCoder:coder];
    [coder encodeInt32:_userId forCKey:"userId"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _userId = [aDecoder decodeInt32ForKey:@"userId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeInt32:_userId forKey:@"userId"];
}

@end
