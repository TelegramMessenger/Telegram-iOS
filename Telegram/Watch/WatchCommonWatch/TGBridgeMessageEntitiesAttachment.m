#import "TGBridgeMessageEntitiesAttachment.h"

const NSInteger TGBridgeMessageEntitiesAttachmentType = 0x8c2e3cce;

NSString *const TGBridgeMessageEntitiesKey = @"entities";

@implementation TGBridgeMessageEntitiesAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _entities = [aDecoder decodeObjectForKey:TGBridgeMessageEntitiesKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.entities forKey:TGBridgeMessageEntitiesKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeMessageEntitiesAttachmentType;
}


@end
