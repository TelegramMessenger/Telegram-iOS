#import "TGBridgeUnsupportedMediaAttachment.h"

const NSInteger TGBridgeUnsupportedMediaAttachmentType = 0x3837BEF7;

NSString *const TGBridgeUnsupportedMediaCompactTitleKey = @"compactTitle";
NSString *const TGBridgeUnsupportedMediaTitleKey = @"title";
NSString *const TGBridgeUnsupportedMediaSubtitleKey = @"subtitle";

@implementation TGBridgeUnsupportedMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _compactTitle = [aDecoder decodeObjectForKey:TGBridgeUnsupportedMediaCompactTitleKey];
        _title = [aDecoder decodeObjectForKey:TGBridgeUnsupportedMediaTitleKey];
        _subtitle = [aDecoder decodeObjectForKey:TGBridgeUnsupportedMediaSubtitleKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.compactTitle forKey:TGBridgeUnsupportedMediaCompactTitleKey];
    [aCoder encodeObject:self.title forKey:TGBridgeUnsupportedMediaTitleKey];
    [aCoder encodeObject:self.subtitle forKey:TGBridgeUnsupportedMediaSubtitleKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeUnsupportedMediaAttachmentType;
}

@end
