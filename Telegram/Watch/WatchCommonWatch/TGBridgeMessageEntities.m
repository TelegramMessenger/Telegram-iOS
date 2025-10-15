#import "TGBridgeMessageEntities.h"

NSString *const TGBridgeMessageEntityLocationKey = @"loc";
NSString *const TGBridgeMessageEntityLengthKey = @"len";

@implementation TGBridgeMessageEntity

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        NSUInteger loc = [aDecoder decodeIntegerForKey:TGBridgeMessageEntityLocationKey];
        NSUInteger len = [aDecoder decodeIntegerForKey:TGBridgeMessageEntityLengthKey];
        _range = NSMakeRange(loc, len);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:self.range.location forKey:TGBridgeMessageEntityLocationKey];
    [aCoder encodeInteger:self.range.length forKey:TGBridgeMessageEntityLengthKey];
}

+ (instancetype)entitityWithRange:(NSRange)range
{
    TGBridgeMessageEntity *entity = [[self alloc] init];
    entity.range = range;
    return entity;
}

@end


@implementation TGBridgeMessageEntityUrl

@end


@implementation TGBridgeMessageEntityEmail

@end


@implementation TGBridgeMessageEntityTextUrl

@end


@implementation TGBridgeMessageEntityMention

@end


@implementation TGBridgeMessageEntityHashtag

@end


@implementation TGBridgeMessageEntityBotCommand

@end


@implementation TGBridgeMessageEntityBold

@end


@implementation TGBridgeMessageEntityItalic

@end


@implementation TGBridgeMessageEntityCode

@end


@implementation TGBridgeMessageEntityPre

@end
