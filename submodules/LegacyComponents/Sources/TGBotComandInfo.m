#import "TGBotComandInfo.h"

#import "PSKeyValueCoder.h"

@implementation TGBotComandInfo

- (instancetype)initWithCommand:(NSString *)command commandDescription:(NSString *)commandDescription
{
    self = [super init];
    if (self != nil)
    {
        _command = command;
        _commandDescription = commandDescription;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithCommand:[coder decodeStringForCKey:"command"] commandDescription:[coder decodeStringForCKey:"commandDescription"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeString:_command forCKey:"command"];
    [coder encodeString:_commandDescription forCKey:"commandDescription"];
}

@end
