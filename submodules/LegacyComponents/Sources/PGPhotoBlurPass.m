#import "PGPhotoBlurPass.h"

#import "GPUImageTwoInputFilter.h"
#import "GPUImageThreeInputFilter.h"
#import "PGPhotoGaussianBlurFilter.h"

NSString *const PGPhotoRadialBlurShaderString = PGShaderString
(
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;
 
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 
 uniform lowp float excludeSize;
 uniform lowp vec2 excludePoint;
 uniform lowp float excludeFalloff;
 uniform highp float aspectRatio;
 
 void main()
 {
     lowp vec4 sharpImageColor = texture2D(sourceImage, texCoord);
     lowp vec4 blurredImageColor = texture2D(inputImageTexture2, texCoord2);
     
     highp vec2 texCoordToUse = vec2(texCoord2.x, (texCoord2.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     highp float distanceFromCenter = distance(excludePoint, texCoordToUse);
  
     gl_FragColor = mix(blurredImageColor, sharpImageColor, smoothstep(1.0, excludeFalloff, clamp(distanceFromCenter / excludeSize, 0.0, 1.0)));
 }
);

NSString *const PGPhotoLinearBlurShaderString = PGShaderString
(
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;
 
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 
 uniform lowp float excludeSize;
 uniform lowp vec2 excludePoint;
 uniform lowp float excludeFalloff;
 uniform highp float angle;
 uniform highp float aspectRatio;
 
 void main()
 {
     lowp vec4 sharpImageColor = texture2D(sourceImage, texCoord);
     lowp vec4 blurredImageColor = texture2D(inputImageTexture2, texCoord2);
     
     highp vec2 texCoordToUse = vec2(texCoord2.x, (texCoord2.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     highp float distanceFromCenter = abs((texCoordToUse.x - excludePoint.x) * cos(angle) + (texCoordToUse.y - excludePoint.y) * sin(angle));
     
     gl_FragColor = mix(blurredImageColor, sharpImageColor, smoothstep(1.0, excludeFalloff, clamp(distanceFromCenter / excludeSize, 0.0, 1.0)));
 }
);

NSString *const PGPhotoMaskedBlurShaderString = PGShaderString
(
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;
 varying highp vec2 texCoord3;
 
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 void main()
 {
     lowp vec4 sharpImageColor = texture2D(sourceImage, texCoord);
     lowp vec4 blurredImageColor = texture2D(inputImageTexture2, texCoord2);
     lowp vec4 maskImageColor = texture2D(inputImageTexture3, texCoord3);
     
     gl_FragColor = mix(blurredImageColor, sharpImageColor, maskImageColor.r);
 }
);

@interface PGPhotoBlurFilter : GPUImageOutput <GPUImageInput>
{
    PGPhotoGaussianBlurFilter *_blurFilter;
    
    GPUImageTwoInputFilter *_radialFocusFilter;
    GPUImageTwoInputFilter *_linearFocusFilter;
    GPUImageThreeInputFilter *_maskedFilter;
    
    GPUImageOutput <GPUImageInput> *_currentFocusFilter;
    
    bool _endProcessing;
}
@end

@implementation PGPhotoBlurFilter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _blurFilter = [[PGPhotoGaussianBlurFilter alloc] init];
        
        _radialFocusFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:PGPhotoRadialBlurShaderString];
        _linearFocusFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:PGPhotoLinearBlurShaderString];
    }
    return self;
}

- (void)setType:(PGBlurToolType)type
{
    id<GPUImageInput> target = nil;
    if (_currentFocusFilter.targets.count > 0)
        target = _currentFocusFilter.targets[0];
    
    [_currentFocusFilter removeAllTargets];
    
    switch (type)
    {
        case PGBlurToolTypeRadial:
        {
            _currentFocusFilter = _radialFocusFilter;
        }
            break;
    
        case PGBlurToolTypeLinear:
        {
            _currentFocusFilter = _linearFocusFilter;
        }
            break;
            
        case PGBlurToolTypePortrait:
        {
            _currentFocusFilter = _maskedFilter;
        }
        default:
            break;
    }
    
    if (target != nil)
        [_currentFocusFilter addTarget:target atTextureLocation:0];
    
    [_blurFilter removeAllTargets];
    [_blurFilter addTarget:_currentFocusFilter atTextureLocation:1];
}

- (void)setExcludeSize:(CGFloat)excludeSize
{
    [_radialFocusFilter setFloat:(float)excludeSize forUniformName:@"excludeSize"];
    [_linearFocusFilter setFloat:(float)excludeSize forUniformName:@"excludeSize"];
}

- (void)setExcludeFalloff:(CGFloat)excludeFalloff
{
    [_radialFocusFilter setFloat:(float)excludeFalloff forUniformName:@"excludeFalloff"];
    [_linearFocusFilter setFloat:(float)excludeFalloff forUniformName:@"excludeFalloff"];
}

- (void)setExcludePoint:(CGPoint)excludePoint
{
    [_radialFocusFilter setPoint:excludePoint forUniformName:@"excludePoint"];
    [_linearFocusFilter setPoint:excludePoint forUniformName:@"excludePoint"];
}

- (void)setAngle:(CGFloat)angle
{
    [_linearFocusFilter setFloat:(float)angle forUniformName:@"angle"];
}

#pragma mark GPUImageOutput

- (void)setTargetToIgnoreForUpdates:(id<GPUImageInput>)targetToIgnoreForUpdates
{
    [_currentFocusFilter setTargetToIgnoreForUpdates:targetToIgnoreForUpdates];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation
{
    [_currentFocusFilter addTarget:newTarget atTextureLocation:textureLocation];
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove
{
    [_currentFocusFilter removeTarget:targetToRemove];
}

- (void)removeAllTargets
{
    [_currentFocusFilter removeAllTargets];
}

- (void)setFrameProcessingCompletionBlock:(void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock
{
    [_currentFocusFilter setFrameProcessingCompletionBlock:frameProcessingCompletionBlock];
}

- (void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock
{
    return [_currentFocusFilter frameProcessingCompletionBlock];
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)__unused textureIndex
{
    [_blurFilter newFrameReadyAtTime:frameTime atIndex:0];
    [_currentFocusFilter newFrameReadyAtTime:frameTime atIndex:0];
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)__unused textureIndex
{
    [_blurFilter setInputFramebuffer:newInputFramebuffer atIndex:0];
    [_currentFocusFilter setInputFramebuffer:newInputFramebuffer atIndex:0];
}

- (NSInteger)nextAvailableTextureIndex
{
    return 0;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex
{
    [_blurFilter setInputSize:newSize atIndex:textureIndex];
    [_radialFocusFilter setInputSize:newSize atIndex:textureIndex];
    [_linearFocusFilter setInputSize:newSize atIndex:textureIndex];
    [_maskedFilter setInputSize:newSize atIndex:textureIndex];
    
    CGFloat aspectRatio = newSize.height / newSize.width;
    [_radialFocusFilter setFloat:(float)aspectRatio forUniformName:@"aspectRatio"];
    [_linearFocusFilter setFloat:(float)aspectRatio forUniformName:@"aspectRatio"];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex
{
    [_blurFilter setInputRotation:newInputRotation  atIndex:textureIndex];
    [_radialFocusFilter setInputRotation:newInputRotation atIndex:textureIndex];
    [_linearFocusFilter setInputRotation:newInputRotation atIndex:textureIndex];
    [_maskedFilter setInputRotation:newInputRotation atIndex:textureIndex];
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
        [_currentFocusFilter endProcessing];
    }
}

- (BOOL)wantsMonochromeInput
{
    return false;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)__unused newValue
{
    
}

@end

@implementation PGPhotoBlurPass

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        PGPhotoBlurFilter *filter = [[PGPhotoBlurFilter alloc] init];
        _filter = filter;
    }
    return self;
}

- (void)setType:(PGBlurToolType)type
{
    _type = type;
    [(PGPhotoBlurFilter *)_filter setType:type];
}

- (void)setSize:(CGFloat)size
{
    _size = size;
    [(PGPhotoBlurFilter *)_filter setExcludeSize:size];
}

- (void)setFalloff:(CGFloat)falloff
{
    _falloff = falloff;
    [(PGPhotoBlurFilter *)_filter setExcludeFalloff:falloff];
}

- (void)setPoint:(CGPoint)point
{
    _point = point;
    [(PGPhotoBlurFilter *)_filter setExcludePoint:point];
}

- (void)setAngle:(CGFloat)angle
{
    _angle = angle;
    [(PGPhotoBlurFilter *)_filter setAngle:angle + (CGFloat)M_PI_2];
}

@end
