#import "PGPhotoEditorValues.h"
#import "TGPaintingData.h"

#import "TGPhotoEditorUtils.h"

@implementation PGPhotoEditorValues

@synthesize originalSize = _originalSize;
@synthesize cropRect = _cropRect;
@synthesize cropOrientation = _cropOrientation;
@synthesize cropRotation = _cropRotation;
@synthesize cropLockedAspectRatio = _cropLockedAspectRatio;
@synthesize cropMirrored = _cropMirrored;
@synthesize paintingData = _paintingData;
@synthesize sendAsGif = _sendAsGif;
@synthesize toolValues = _toolValues;

+ (instancetype)editorValuesWithOriginalSize:(CGSize)originalSize cropRectangle:(PGRectangle *)cropRectangle cropOrientation:(UIImageOrientation)cropOrientation cropSize:(CGSize)cropSize enhanceDocument:(bool)enhanceDocument paintingData:(TGPaintingData *)paintingData
{
    PGPhotoEditorValues *values = [[PGPhotoEditorValues alloc] init];
    values->_originalSize = originalSize;
    values->_cropRect = CGRectMake(0.0, 0.0, cropSize.width, cropSize.height);
    values->_cropSize = cropSize;
    values->_cropRectangle = cropRectangle;
    values->_cropOrientation = cropOrientation;
    values->_enhanceDocument = enhanceDocument;
    values->_paintingData = paintingData;
    return values;
}


+ (instancetype)editorValuesWithOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropRotation:(CGFloat)cropRotation cropOrientation:(UIImageOrientation)cropOrientation cropLockedAspectRatio:(CGFloat)cropLockedAspectRatio cropMirrored:(bool)cropMirrored toolValues:(NSDictionary *)toolValues paintingData:(TGPaintingData *)paintingData sendAsGif:(bool)sendAsGif
{
    PGPhotoEditorValues *values = [[PGPhotoEditorValues alloc] init];
    values->_originalSize = originalSize;
    values->_cropRect = cropRect;
    values->_cropRotation = cropRotation;
    values->_cropOrientation = cropOrientation;
    values->_cropLockedAspectRatio = cropLockedAspectRatio;
    values->_cropMirrored = cropMirrored;
    values->_toolValues = toolValues;
    values->_paintingData = paintingData;
    values->_sendAsGif = sendAsGif;
    return values;
}

- (bool)hasPainting
{
    return (_paintingData != nil);
}

- (bool)cropAppliedForAvatar:(bool)forAvatar
{
    if (_cropRectangle != nil)
        return true;
    
    CGRect defaultCropRect = CGRectMake(0, 0, _originalSize.width, _originalSize.height);
    if (forAvatar)
    {
        CGFloat shortSide = MIN(_originalSize.width, _originalSize.height);
        defaultCropRect = CGRectMake((_originalSize.width - shortSide) / 2, (_originalSize.height - shortSide) / 2, shortSide, shortSide);
    }
    
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, defaultCropRect, [self _cropRectEpsilon]))
        return true;
    
    if (ABS(self.cropRotation) > FLT_EPSILON)
        return true;
    
    if (self.cropOrientation != UIImageOrientationUp)
        return true;
    
    if (self.cropLockedAspectRatio > FLT_EPSILON)
        return true;
    
    if (self.cropMirrored)
        return true;
    
    return false;
}

- (bool)toolsApplied
{
    if (_enhanceDocument)
        return true;
    
    if (self.toolValues.count > 0)
        return true;
    
    return false;
}

- (bool)isDefaultValuesForAvatar:(bool)forAvatar
{
    return ![self cropAppliedForAvatar:forAvatar] && ![self toolsApplied] && ![self hasPainting];
}

- (bool)isCropEqualWith:(id<TGMediaEditAdjustments>)adjusments
{
    return (_CGRectEqualToRectWithEpsilon(self.cropRect, adjusments.cropRect, [self _cropRectEpsilon]));
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    PGPhotoEditorValues *values = (PGPhotoEditorValues *)object;
    
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, values.cropRect, [self _cropRectEpsilon]))
        return false;
    
    if (ABS(self.cropRotation - values.cropRotation) > FLT_EPSILON)
        return false;
    
    if (self.cropOrientation != values.cropOrientation)
        return false;
    
    if (ABS(self.cropLockedAspectRatio - values.cropLockedAspectRatio) > FLT_EPSILON)
        return false;
    
    if (self.cropMirrored != values.cropMirrored)
        return false;
    
    if (![self.toolValues isEqual:values.toolValues])
        return false;
    
    if (self.paintingData != values.paintingData && ![self.paintingData isEqual:values.paintingData])
        return false;
    
    if (self.enhanceDocument != values.enhanceDocument)
        return false;
    
    return true;
}

- (CGFloat)_cropRectEpsilon
{
    return MAX(_originalSize.width, _originalSize.height) * 0.005f;
}

@end
