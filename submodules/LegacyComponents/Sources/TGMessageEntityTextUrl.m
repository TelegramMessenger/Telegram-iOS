#import "TGMessageEntityTextUrl.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageEntityTextUrl

- (instancetype)initWithRange:(NSRange)range url:(NSString *)url
{
    self = [super initWithRange:range];
    if (self != nil)
    {
        _url = url;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    self = [super initWithKeyValueCoder:coder];
    if (self != nil)
    {
        _url = [coder decodeStringForCKey:"url"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [super encodeWithKeyValueCoder:coder];
    [coder encodeString:_url forCKey:"url"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _url = [aDecoder decodeObjectForKey:@"url"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:_url forKey:@"url"];
}

@end
