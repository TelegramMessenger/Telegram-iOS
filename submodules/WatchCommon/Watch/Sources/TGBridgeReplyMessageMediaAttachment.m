#import "TGBridgeReplyMessageMediaAttachment.h"
#import "TGBridgeMessage.h"

const NSInteger TGBridgeReplyMessageMediaAttachmentType = 414002169;

NSString *const TGBridgeReplyMessageMediaMidKey = @"mid";
NSString *const TGBridgeReplyMessageMediaMessageKey = @"message";

@implementation TGBridgeReplyMessageMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _mid = [aDecoder decodeInt32ForKey:TGBridgeReplyMessageMediaMidKey];
        _message = [aDecoder decodeObjectForKey:TGBridgeReplyMessageMediaMessageKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.mid forKey:TGBridgeReplyMessageMediaMidKey];
    [aCoder encodeObject:self.message forKey:TGBridgeReplyMessageMediaMessageKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeReplyMessageMediaAttachmentType;
}

@end
