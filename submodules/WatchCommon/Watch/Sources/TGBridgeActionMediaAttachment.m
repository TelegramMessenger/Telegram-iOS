#import "TGBridgeActionMediaAttachment.h"
#import "TGBridgeImageMediaAttachment.h"

const NSInteger TGBridgeActionMediaAttachmentType = 0x1167E28B;

NSString *const TGBridgeActionMediaTypeKey = @"actionType";
NSString *const TGBridgeActionMediaDataKey = @"actionData";

@implementation TGBridgeActionMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _actionType = (TGBridgeMessageAction)[aDecoder decodeInt32ForKey:TGBridgeActionMediaTypeKey];
        _actionData = [aDecoder decodeObjectForKey:TGBridgeActionMediaDataKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.actionType forKey:TGBridgeActionMediaTypeKey];
    [aCoder encodeObject:self.actionData forKey:TGBridgeActionMediaDataKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeActionMediaAttachmentType;
}

@end
