#import "TGBridgeMediaAttachment.h"

NSString *const TGBridgeMediaAttachmentTypeKey = @"type";

@implementation TGBridgeMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder
{
    
}

- (NSInteger)mediaType
{
    return 0;
}

+ (NSInteger)mediaType
{
    return 0;
}

@end
