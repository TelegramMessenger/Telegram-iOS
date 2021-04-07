#import "PGPhotoEnhancePass.h"

#import "PGPhotoEnhanceColorConversionFilter.h"
#import "PGPhotoEnhanceLUTGenerator.h"
#import "PGPhotoEnhanceInterpolationFilter.h"
#import "PGPhotoEditorRawDataInput.h"

@interface PGPhotoEnhanceFilter : GPUImageOutput <GPUImageInput>
{
    GPUImageOutput <GPUImageInput> *_initialFilter;
    
    PGPhotoEnhanceColorConversionFilter *_rgbToHsvFilter;
    PGPhotoEnhanceLUTGenerator *_lutGenerator;
    PGPhotoEditorRawDataInput *_lutDataInput;
    PGPhotoEnhanceInterpolationFilter *_interpolationFilter;
    
    bool _hasLutData;
    
    bool _endProcessing;
}

@property (nonatomic, assign) CGFloat intensity;

@end

@implementation PGPhotoEnhanceFilter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _rgbToHsvFilter = [[PGPhotoEnhanceColorConversionFilter alloc] initWithMode:PGPhotoEnhanceColorConversionRGBToHSVMode];
        _initialFilter = _rgbToHsvFilter;
        
        _lutGenerator = [[PGPhotoEnhanceLUTGenerator alloc] init];
        [_rgbToHsvFilter addTarget:_lutGenerator];
        
        CGSize lutSize = CGSizeMake(PGPhotoEnhanceHistogramBins, PGPhotoEnhanceSegments * PGPhotoEnhanceSegments);
        
        _lutDataInput = [[PGPhotoEditorRawDataInput alloc] initWithBytes:NULL size:lutSize pixelFormat:GPUPixelFormatRGBA type:GPUPixelTypeUByte];
        
        __weak PGPhotoEnhanceFilter *weakSelf = self;
        _lutGenerator.lutDataReady = ^(GLubyte *lutData)
        {
            __strong PGPhotoEnhanceFilter *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_lutDataInput updateDataWithBytes:lutData size:lutSize];
            strongSelf->_hasLutData = true;
            [strongSelf->_lutDataInput processData];
        };

        _interpolationFilter = [[PGPhotoEnhanceInterpolationFilter alloc] init];
        [_rgbToHsvFilter addTarget:_interpolationFilter atTextureLocation:0];
        [_lutDataInput addTarget:_interpolationFilter atTextureLocation:1];
    }
    return self;
}

- (void)setIntensity:(CGFloat)intensity
{
    _intensity = intensity;
    
    [_interpolationFilter setIntensity:intensity];
}

#pragma mark GPUImageOutput

- (void)setTargetToIgnoreForUpdates:(id<GPUImageInput>)targetToIgnoreForUpdates
{
    [_interpolationFilter setTargetToIgnoreForUpdates:targetToIgnoreForUpdates];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation
{
    [_interpolationFilter addTarget:newTarget atTextureLocation:textureLocation];
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove
{
    [_interpolationFilter removeTarget:targetToRemove];
}

- (void)removeAllTargets
{
    [_interpolationFilter removeAllTargets];
}

- (void)setFrameProcessingCompletionBlock:(void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock
{
    [_interpolationFilter setFrameProcessingCompletionBlock:frameProcessingCompletionBlock];
}

- (void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock
{
    return [_interpolationFilter frameProcessingCompletionBlock];
}

- (GPUImageFramebuffer *)framebufferForOutput {
    return [_interpolationFilter framebufferForOutput];
}

- (void)removeOutputFramebuffer {
    [_interpolationFilter removeOutputFramebuffer];
}

#pragma mark - GPUImageInput

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex
{
    _lutGenerator.skip = _hasLutData;
    if (_hasLutData)
        [_lutDataInput processData];
    
    [_initialFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex
{
    [_initialFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex
{
    [_initialFilter setInputSize:newSize atIndex:textureIndex];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex
{
    [_initialFilter setInputRotation:newInputRotation atIndex:textureIndex];
}

- (CGSize)maximumOutputSize
{
    return CGSizeZero;
}

- (void)endProcessing
{
    if (!_endProcessing)
    {
        _endProcessing = true;
        [_initialFilter endProcessing];
    }
}

- (BOOL)wantsMonochromeInput
{
    return false;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)__unused newValue
{
    
}

- (void)invalidate
{
    _hasLutData = false;
}

@end

@implementation PGPhotoEnhancePass

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        PGPhotoEnhanceFilter *filter = [[PGPhotoEnhanceFilter alloc] init];
        _filter = filter;
    }
    return self;
}

- (void)setIntensity:(CGFloat)intensity
{
    _intensity = intensity;
    [self updateParameters];
}

- (void)updateParameters
{
    [(PGPhotoEnhanceFilter *)_filter setIntensity:_intensity];
}

- (void)invalidate
{
    [(PGPhotoEnhanceFilter *)_filter invalidate];
}

@end
