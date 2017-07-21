#import "TGVideoEditAdjustments.h"

#import "TGPhotoEditorUtils.h"

#import "TGPaintingData.h"

const NSTimeInterval TGVideoEditMinimumTrimmableDuration = 3.0;
const NSTimeInterval TGVideoEditMaximumGifDuration = 30.5;

@implementation TGVideoEditAdjustments

@synthesize originalSize = _originalSize;
@synthesize cropRect = _cropRect;
@synthesize cropOrientation = _cropOrientation;
@synthesize cropLockedAspectRatio = _cropLockedAspectRatio;
@synthesize cropMirrored = _cropMirrored;
@synthesize paintingData = _paintingData;

+ (instancetype)editAdjustmentsWithOriginalSize:(CGSize)originalSize
                                       cropRect:(CGRect)cropRect
                                cropOrientation:(UIImageOrientation)cropOrientation
                          cropLockedAspectRatio:(CGFloat)cropLockedAspectRatio
                                   cropMirrored:(bool)cropMirrored
                                 trimStartValue:(NSTimeInterval)trimStartValue
                                   trimEndValue:(NSTimeInterval)trimEndValue
                                   paintingData:(TGPaintingData *)paintingData
                                      sendAsGif:(bool)sendAsGif
                                         preset:(TGMediaVideoConversionPreset)preset
{
    TGVideoEditAdjustments *adjustments = [[[self class] alloc] init];
    adjustments->_originalSize = originalSize;
    adjustments->_cropRect = cropRect;
    adjustments->_cropOrientation = cropOrientation;
    adjustments->_cropLockedAspectRatio = cropLockedAspectRatio;
    adjustments->_cropMirrored = cropMirrored;
    adjustments->_trimStartValue = trimStartValue;
    adjustments->_trimEndValue = trimEndValue;
    adjustments->_paintingData = paintingData;
    adjustments->_sendAsGif = sendAsGif;
    adjustments->_preset = preset;
    
    if (trimStartValue > trimEndValue)
        return nil;
    
    return adjustments;
}

+ (instancetype)editAdjustmentsWithDictionary:(NSDictionary *)dictionary
{
    if (dictionary.count == 0)
        return nil;
    
    TGVideoEditAdjustments *adjustments = [[[self class] alloc] init];
    if (dictionary[@"cropOrientation"])
        adjustments->_cropOrientation = [dictionary[@"cropOrientation"] integerValue];
    if (dictionary[@"cropRect"])
        adjustments->_cropRect = [dictionary[@"cropRect"] CGRectValue];
    if (dictionary[@"cropMirrored"])
        adjustments->_cropMirrored = [dictionary[@"cropMirrored"] boolValue];
    if (dictionary[@"trimStart"] || dictionary[@"trimEnd"])
    {
        adjustments->_trimStartValue = [dictionary[@"trimStart"] doubleValue];
        adjustments->_trimEndValue = [dictionary[@"trimEnd"] doubleValue];
    }
    if (dictionary[@"originalSize"])
        adjustments->_originalSize = [dictionary[@"originalSize"] CGSizeValue];
    if (dictionary[@"paintingImagePath"])
        adjustments->_paintingData = [TGPaintingData dataWithPaintingImagePath:dictionary[@"paintingImagePath"]];
    if (dictionary[@"sendAsGif"])
        adjustments->_sendAsGif = [dictionary[@"sendAsGif"] boolValue];
    if (dictionary[@"preset"])
        adjustments->_preset = (TGMediaVideoConversionPreset)[dictionary[@"preset"] integerValue];
    
    return adjustments;
}

+ (instancetype)editAdjustmentsWithOriginalSize:(CGSize)originalSize
                                         preset:(TGMediaVideoConversionPreset)preset
{
    TGVideoEditAdjustments *adjustments = [[[self class] alloc] init];
    adjustments->_originalSize = originalSize;
    adjustments->_preset = preset;
    
    return adjustments;
}

- (instancetype)editAdjustmentsWithPreset:(TGMediaVideoConversionPreset)preset maxDuration:(NSTimeInterval)maxDuration
{
    TGVideoEditAdjustments *adjustments = [[[self class] alloc] init];
    adjustments->_originalSize = _originalSize;
    adjustments->_cropRect = _cropRect;
    adjustments->_cropOrientation = _cropOrientation;
    adjustments->_cropLockedAspectRatio = _cropLockedAspectRatio;
    adjustments->_cropMirrored = _cropMirrored;
    adjustments->_trimStartValue = _trimStartValue;
    adjustments->_trimEndValue = _trimEndValue;
    adjustments->_paintingData = _paintingData;
    adjustments->_sendAsGif = _sendAsGif;
    adjustments->_preset = preset;
    
    if (maxDuration > DBL_EPSILON)
    {
        if ([adjustments trimApplied])
        {
            if (adjustments.trimEndValue - adjustments.trimStartValue > maxDuration)
                adjustments->_trimEndValue = adjustments.trimStartValue + maxDuration;
        }
        else
        {
            adjustments->_trimEndValue = maxDuration;
        }
    }
        
    return adjustments;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"cropOrientation"] = @(self.cropOrientation);
    if ([self cropAppliedForAvatar:false])
        dict[@"cropRect"] = [NSValue valueWithCGRect:self.cropRect];
    dict[@"cropMirrored"] = @(self.cropMirrored);
    
    if (self.trimStartValue > DBL_EPSILON || self.trimEndValue > DBL_EPSILON)
    {
        dict[@"trimStart"] = @(self.trimStartValue);
        dict[@"trimEnd"] = @(self.trimEndValue);
    }
    
    dict[@"originalSize"] = [NSValue valueWithCGSize:self.originalSize];
    
    if (self.paintingData.imagePath != nil)
        dict[@"paintingImagePath"] = self.paintingData.imagePath;
    
    dict[@"sendAsGif"] = @(self.sendAsGif);
    
    if (self.preset != TGMediaVideoConversionPresetCompressedDefault)
        dict[@"preset"] = @(self.preset);
    
    return dict;
}

- (bool)hasPainting
{
    return (_paintingData != nil);
}

- (bool)cropAppliedForAvatar:(bool)__unused forAvatar 
{
    CGRect defaultCropRect = CGRectMake(0, 0, _originalSize.width, _originalSize.height);
    
    if (_CGRectEqualToRectWithEpsilon(self.cropRect, CGRectZero, [self _cropRectEpsilon]))
        return false;
    
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, defaultCropRect, [self _cropRectEpsilon]))
        return true;
        
    if (self.cropLockedAspectRatio > FLT_EPSILON)
        return true;
    
    if (self.cropOrientation != UIImageOrientationUp)
        return true;
    
    if (self.cropMirrored)
        return true;
    
    return false;
}

- (bool)trimApplied
{
    return (self.trimStartValue > DBL_EPSILON || self.trimEndValue > DBL_EPSILON);
}

- (CMTimeRange)trimTimeRange
{
    return CMTimeRangeMake(CMTimeMakeWithSeconds(self.trimStartValue , NSEC_PER_SEC), CMTimeMakeWithSeconds((self.trimEndValue - self.trimStartValue), NSEC_PER_SEC));
}

- (bool)isDefaultValuesForAvatar:(bool)forAvatar
{
    return ![self cropAppliedForAvatar:forAvatar] && ![self hasPainting] && !_sendAsGif && _preset == TGMediaVideoConversionPresetCompressedDefault;
}

- (bool)isCropEqualWith:(id<TGMediaEditAdjustments>)adjusments
{
    return (_CGRectEqualToRectWithEpsilon(self.cropRect, adjusments.cropRect, [self _cropRectEpsilon]));
}

- (bool)isCropAndRotationEqualWith:(id<TGMediaEditAdjustments>)adjustments
{
    return (_CGRectEqualToRectWithEpsilon(self.cropRect, adjustments.cropRect, [self _cropRectEpsilon])) && self.cropOrientation == ((TGVideoEditAdjustments *)adjustments).cropOrientation;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)object;
    
    if (!_CGRectEqualToRectWithEpsilon(self.cropRect, adjustments.cropRect, [self _cropRectEpsilon]))
        return NO;
    
    if (self.cropOrientation != adjustments.cropOrientation)
        return NO;
    
    if (ABS(self.cropLockedAspectRatio - adjustments.cropLockedAspectRatio) > FLT_EPSILON)
        return NO;
    
    if (self.cropMirrored != adjustments.cropMirrored)
        return NO;
    
    if (fabs(self.trimStartValue - adjustments.trimStartValue) > FLT_EPSILON)
        return NO;
    
    if (fabs(self.trimEndValue - adjustments.trimEndValue) > FLT_EPSILON)
        return NO;
    
    if ((self.paintingData != nil && ![self.paintingData isEqual:adjustments.paintingData]) || (self.paintingData == nil && adjustments.paintingData != nil))
        return NO;
    
    if (self.sendAsGif != adjustments.sendAsGif)
        return NO;
    
    return YES;
}

- (CGFloat)_cropRectEpsilon
{
    return MAX(_originalSize.width, _originalSize.height) * 0.005f;
}

@end
