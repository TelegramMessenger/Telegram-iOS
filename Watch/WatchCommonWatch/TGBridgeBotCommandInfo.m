#import "TGBridgeBotCommandInfo.h"

NSString *const TGBridgeBotCommandInfoCommandKey = @"command";
NSString *const TGBridgeBotCommandDescriptionKey = @"commandDescription";

@implementation TGBridgeBotCommandInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _command = [aDecoder decodeObjectForKey:TGBridgeBotCommandInfoCommandKey];
        _commandDescription = [aDecoder decodeObjectForKey:TGBridgeBotCommandDescriptionKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.command forKey:TGBridgeBotCommandInfoCommandKey];
    [aCoder encodeObject:self.commandDescription forKey:TGBridgeBotCommandDescriptionKey];
}

@end
