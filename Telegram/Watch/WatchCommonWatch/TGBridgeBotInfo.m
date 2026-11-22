#import "TGBridgeBotInfo.h"

NSString *const TGBridgeBotInfoShortDescriptionKey = @"shortDescription";
NSString *const TGBridgeBotInfoCommandListKey = @"commandList";

@implementation TGBridgeBotInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _shortDescription = [aDecoder decodeObjectForKey:TGBridgeBotInfoShortDescriptionKey];
        _commandList = [aDecoder decodeObjectForKey:TGBridgeBotInfoCommandListKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.shortDescription forKey:TGBridgeBotInfoShortDescriptionKey];
    [aCoder encodeObject:self.commandList forKey:TGBridgeBotInfoCommandListKey];
}

@end
