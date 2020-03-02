#import "TGBotReplyMarkupButton.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

@implementation TGBotReplyMarkupButtonActionUrl

- (instancetype)initWithUrl:(NSString *)url {
    self = [super init];
    if (self != nil) {
        _url = url;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithUrl:[coder decodeStringForCKey:"url"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_url forCKey:"url"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUrl:[aDecoder decodeObjectForKey:@"url"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_url forKey:@"url"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionUrl class]] && TGStringCompare(_url, ((TGBotReplyMarkupButtonActionUrl *)object)->_url);
}

@end

@implementation TGBotReplyMarkupButtonActionCallback

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _data = data;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithData:[coder decodeDataCorCKey:"data"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeData:_data forCKey:"data"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithData:[aDecoder decodeObjectForKey:@"data"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_data forKey:@"data"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionCallback class]] && TGObjectCompare(_data, ((TGBotReplyMarkupButtonActionCallback *)object)->_data);
}

@end

@implementation TGBotReplyMarkupButtonActionRequestPhone

- (instancetype)init {
    return [super init];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)__unused coder {
    return [self init];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)__unused coder {
}

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder {
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder {
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionRequestPhone class]];
}

@end

@implementation TGBotReplyMarkupButtonActionRequestLocation

- (instancetype)init {
    return [super init];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)__unused coder {
    return [self init];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)__unused coder {
}

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder {
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder {
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionRequestLocation class]];
}

@end

@implementation TGBotReplyMarkupButtonActionSwitchInline

- (instancetype)initWithQuery:(NSString *)query samePeer:(bool)samePeer {
    self = [super init];
    if (self != nil) {
        _query = query;
        _samePeer = samePeer;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithQuery:[coder decodeStringForCKey:"query"] samePeer:[coder decodeInt32ForCKey:"samePeer"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_query forCKey:"query"];
    [coder encodeInt32:_samePeer ? 1 : 0 forCKey:"samePeer"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithQuery:[aDecoder decodeObjectForKey:@"query"] samePeer:[aDecoder decodeBoolForKey:@"samePeer"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_query forKey:@"query"];
    [aCoder encodeBool:_samePeer forKey:@"samePeer"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionSwitchInline class]] && TGStringCompare(_query, ((TGBotReplyMarkupButtonActionSwitchInline *)object)->_query) && _samePeer == ((TGBotReplyMarkupButtonActionSwitchInline *)object)->_samePeer;
}

@end

@implementation TGBotReplyMarkupButtonActionGame

- (instancetype)initWithText:(NSString *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithText:[coder decodeStringForCKey:"text"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_text forCKey:"text"];
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithText:[aDecoder decodeObjectForKey:@"text"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionGame class]] && TGStringCompare(_text, ((TGBotReplyMarkupButtonActionGame *)object)->_text);
}

@end

@implementation TGBotReplyMarkupButtonActionPurchase

- (instancetype)initWithText:(NSString *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithText:[coder decodeStringForCKey:"text"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_text forCKey:"text"];
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithText:[aDecoder decodeObjectForKey:@"text"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGBotReplyMarkupButtonActionPurchase class]] && TGStringCompare(_text, ((TGBotReplyMarkupButtonActionPurchase *)object)->_text);
}

@end

@implementation TGBotReplyMarkupButton

- (instancetype)initWithText:(NSString *)text action:(id<PSCoding, NSCoding>)action
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _action = action;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithText:[coder decodeStringForCKey:"text"] action:(id)[coder decodeObjectForKey:@"action"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeString:_text forCKey:"text"];
    [coder encodeObject:_action forCKey:"action"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithText:[aDecoder decodeObjectForKey:@"text"] action:[aDecoder decodeObjectForKey:@"action"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_action forKey:@"action"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGBotReplyMarkupButton class]] && [((TGBotReplyMarkupButton *)object)->_text isEqualToString:_text] && TGObjectCompare(_action, ((TGBotReplyMarkupButton *)object)->_action);
}

@end
