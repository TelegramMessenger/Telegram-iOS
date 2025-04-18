#import "TGBridgeImageMediaAttachment.h"
#import <UIKit/UIKit.h>

const NSInteger TGBridgeImageMediaAttachmentType = 0x269BD8A8;

NSString *const TGBridgeImageMediaImageIdKey = @"imageId";
NSString *const TGBridgeImageMediaDimensionsKey = @"dimensions";

@implementation TGBridgeImageMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _imageId = [aDecoder decodeInt64ForKey:TGBridgeImageMediaImageIdKey];
        _dimensions = [aDecoder decodeCGSizeForKey:TGBridgeImageMediaDimensionsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.imageId forKey:TGBridgeImageMediaImageIdKey];
    [aCoder encodeCGSize:self.dimensions forKey:TGBridgeImageMediaDimensionsKey];
}

+ (NSInteger)mediaType
{
    return TGBridgeImageMediaAttachmentType;
}

@end
