#import "TGMessageEntityPre.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageEntityPre

- (instancetype)initWithRange:(NSRange)range language:(NSString *)language {
    self = [super initWithRange:range];
    if (self != nil) {
        _language = language;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    self = [super initWithKeyValueCoder:coder];
    if (self != nil) {
        _language = [coder decodeStringForCKey:"language"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [super encodeWithKeyValueCoder:coder];
    [coder encodeString:_language forCKey:"language"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _language = [aDecoder decodeObjectForKey:@"language"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:_language forKey:@"language"];
}

@end
