#import "TGBridgeReplyMarkupMediaAttachment.h"

const NSInteger TGBridgeReplyMarkupMediaAttachmentType = 0x5678acc1;

NSString *const TGBridgeReplyMarkupMediaMessageKey = @"replyMarkup";

@implementation TGBridgeReplyMarkupMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _replyMarkup = [aDecoder decodeObjectForKey:TGBridgeReplyMarkupMediaMessageKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.replyMarkup forKey:TGBridgeReplyMarkupMediaMessageKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeReplyMarkupMediaAttachmentType;
}

@end