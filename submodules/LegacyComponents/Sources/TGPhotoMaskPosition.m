#import <LegacyComponents/TGPhotoMaskPosition.h>

#import "LegacyComponentsInternal.h"
#import <LegacyComponents/TGDocumentAttributeSticker.h>

@implementation TGPhotoMaskPosition

+ (instancetype)maskPositionWithCenter:(CGPoint)center scale:(CGFloat)scale angle:(CGFloat)angle
{
    TGPhotoMaskPosition *maskPosition = [[TGPhotoMaskPosition alloc] init];
    maskPosition->_center = center;
    maskPosition->_scale = scale;
    maskPosition->_angle = angle;
    return maskPosition;
}

+ (TGPhotoMaskAnchor)anchorOfMask:(TGStickerMaskDescription *)mask
{
    if (mask == nil || mask.n >= TGPhotoMaskAnchorChin)
        return TGPhotoMaskAnchorNone;
    
    return mask.n + 1;
}

@end
