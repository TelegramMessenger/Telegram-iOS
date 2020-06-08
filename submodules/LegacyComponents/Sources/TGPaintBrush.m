#import "TGPaintBrush.h"

#import <LegacyComponents/LegacyComponents.h>

const CGSize TGPaintBrushTextureSize = { 384.0f, 384.0f };
const CGSize TGPaintBrushPreviewTextureSize = { 64.0f, 64.0f };

@interface TGPaintBrush ()
{
    NSInteger _uuid;
}
@end

@implementation TGPaintBrush

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(&_uuid, sizeof(NSInteger));
    }
    return self;
}

- (void)dealloc
{
    if (_previewStampRef != NULL)
        CGImageRelease(_previewStampRef);
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPaintBrush *brush = (TGPaintBrush *)object;
    return (_uuid == brush->_uuid);
}

- (CGFloat)spacing
{
    return 1.0f;
}

- (CGFloat)alpha
{
    return 1.0f;
}

- (CGFloat)angle
{
    return 0.0f;
}

- (CGFloat)scale
{
    return 1.0f;
}

- (CGFloat)dynamic
{
    return 0.0f;
}

- (bool)lightSaber
{
    return false;
}

- (CGImageRef)stampRef
{
    return NULL;
}

- (CGImageRef)previewStampRef
{
    if (_previewStampRef == NULL)
    {
        UIImage *image = TGScaleImageToPixelSize([UIImage imageWithCGImage:self.stampRef], TGPaintBrushPreviewTextureSize);
        _previewStampRef = image.CGImage;
        CGImageRetain(_previewStampRef);
    }
    
    return _previewStampRef;
}

@end
