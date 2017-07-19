#import "TGBotInfo.h"

#import "PSKeyValueCoder.h"

@implementation TGBotInfo

- (instancetype)initWithVersion:(int32_t)version shortDescription:(NSString *)shortDescription botDescription:(NSString *)botDescription commandList:(NSArray *)commandList
{
    self = [super init];
    if (self != nil)
    {
        _version = version;
        _botDescription = botDescription;
        _shortDescription = shortDescription;
        _commandList = commandList;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithVersion:[coder decodeInt32ForCKey:"version"] shortDescription:[coder decodeStringForCKey:"shortDescription"] botDescription:[coder decodeStringForCKey:"botDescription"] commandList:[coder decodeArrayForCKey:"commandList"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_version forCKey:"version"];
    [coder encodeString:_shortDescription forCKey:"shortDescription"];
    [coder encodeString:_botDescription forCKey:"botDescription"];
    [coder encodeArray:_commandList forCKey:"commandList"];
}

@end
