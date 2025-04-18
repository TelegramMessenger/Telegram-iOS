#import "YUGPUImageHighPassSkinSmoothingFilter.h"

#import "GPUImageDissolveBlendFilter.h"
#import "GPUImageSharpenFilter.h"
#import "GPUImageToneCurveFilter.h"

NSString * const YUCIHighPassSkinSmoothingMaskBoostFilterFragmentShaderString =
SHADER_STRING
(
 precision lowp float;
 varying highp vec2 texCoord;
 uniform sampler2D sourceImage;
 
 void main() {
     vec4 color = texture2D(sourceImage,texCoord);
     
     float hardLightColor = color.b;
     for (int i = 0; i < 3; ++i)
     {
         if (hardLightColor < 0.5) {
             hardLightColor = hardLightColor  * hardLightColor * 2.0;
         } else {
             hardLightColor = 1.0 - (1.0 - hardLightColor) * (1.0 - hardLightColor) * 2.0;
         }
     }
     
     float k = 255.0 / (164.0 - 75.0);
     hardLightColor = (hardLightColor - 75.0 / 255.0) * k;
     
     gl_FragColor = vec4(vec3(hardLightColor),color.a);
 }
);

NSString * const YUGPUImageGreenAndBlueChannelOverlayFragmentShaderString =
SHADER_STRING
(
 precision lowp float;
 varying highp vec2 texCoord;
 uniform sampler2D sourceImage;
 
 void main() {
     vec4 source = texture2D(sourceImage, texCoord);
     vec4 image = vec4(source.rgb * pow(2.0, -1.0), source.w);
     vec4 base = vec4(image.g,image.g,image.g,1.0);
     vec4 overlay = vec4(image.b,image.b,image.b,1.0);
     float ba = 2.0 * overlay.b * base.b + overlay.b * (1.0 - base.a) + base.b * (1.0 - overlay.a);
     gl_FragColor = vec4(ba,ba,ba,image.a);
 }
);

NSString * const YUGPUImageStillImageHighPassFilterFragmentShaderString =
SHADER_STRING
(
 precision lowp float;
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;
 
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 
 void main() {
     vec4 image = texture2D(sourceImage, texCoord);
     vec4 blurredImage = texture2D(inputImageTexture2, texCoord2);
     gl_FragColor = vec4((image.rgb - blurredImage.rgb + vec3(0.5,0.5,0.5)), image.a);
 }
);

@interface YUGPUImageStillImageHighPassFilter : GPUImageFilterGroup

@property (nonatomic, weak) GPUImageGaussianBlurFilter *blurFilter;

@end

@implementation YUGPUImageStillImageHighPassFilter

- (instancetype)init {
    if (self = [super init]) {
        GPUImageGaussianBlurFilter *blurFilter = [[GPUImageGaussianBlurFilter alloc] init];
        [self addFilter:blurFilter];
        self.blurFilter = blurFilter;
        
        GPUImageTwoInputFilter *filter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:YUGPUImageStillImageHighPassFilterFragmentShaderString];
        [self addFilter:filter];
        
        [blurFilter addTarget:filter atTextureLocation:1];
        
        self.initialFilters = @[blurFilter,filter];
        self.terminalFilter = filter;
    }
    return self;
}

- (void)setRadiusInPixels:(CGFloat)radiusInPixels {
    self.blurFilter.blurRadiusInPixels = radiusInPixels;
}

@end

@interface YUCIHighPassSkinSmoothingMaskGenerator : GPUImageFilterGroup

@property (nonatomic) CGFloat highPassRadiusInPixels;

@property (nonatomic,weak) YUGPUImageStillImageHighPassFilter *highPassFilter;

@end

@implementation YUCIHighPassSkinSmoothingMaskGenerator

- (instancetype)init {
    if (self = [super init]) {
        GPUImageFilter *channelOverlayFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:YUGPUImageGreenAndBlueChannelOverlayFragmentShaderString];
        [self addFilter:channelOverlayFilter];
        
        YUGPUImageStillImageHighPassFilter *highpassFilter = [[YUGPUImageStillImageHighPassFilter alloc] init];
        [self addFilter:highpassFilter];
        self.highPassFilter = highpassFilter;
        
        GPUImageFilter *maskBoostFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:YUCIHighPassSkinSmoothingMaskBoostFilterFragmentShaderString];
        [self addFilter:maskBoostFilter];
        
        [channelOverlayFilter addTarget:highpassFilter];
        [highpassFilter addTarget:maskBoostFilter];
        
        self.initialFilters = @[channelOverlayFilter];
        self.terminalFilter = maskBoostFilter;
    }
    return self;
}


- (void)setHighPassRadiusInPixels:(CGFloat)highPassRadiusInPixels {
    _highPassRadiusInPixels = highPassRadiusInPixels;
    self.highPassFilter.radiusInPixels = highPassRadiusInPixels;
}

@end

NSString * const YUGPUImageHighpassSkinSmoothingCompositingFilterFragmentShaderString =
SHADER_STRING
(
 precision lowp float;
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;
 varying highp vec2 texCoord3;
 
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 void main() {
     vec4 image = texture2D(sourceImage, texCoord);
     vec4 toneCurvedImage = texture2D(inputImageTexture2, texCoord2);
     vec4 mask = texture2D(inputImageTexture3, texCoord3);
     gl_FragColor = vec4(mix(image.rgb, toneCurvedImage.rgb, 1.0 - mask.b), 1.0);
 }
);

@interface YUGPUImageHighPassSkinSmoothingFilter ()

@property (nonatomic,weak) YUCIHighPassSkinSmoothingMaskGenerator *maskGenerator;
@property (nonatomic,weak) GPUImageDissolveBlendFilter *dissolveFilter;
@property (nonatomic,weak) GPUImageSharpenFilter *sharpenFilter;
@property (nonatomic,weak) GPUImageToneCurveFilter *skinToneCurveFilter;

@property (nonatomic) CGSize currentInputSize;

@end

@implementation YUGPUImageHighPassSkinSmoothingFilter

- (instancetype)init {
    if (self = [super init]) {
        YUCIHighPassSkinSmoothingMaskGenerator *maskGenerator = [[YUCIHighPassSkinSmoothingMaskGenerator alloc] init];
        [self addFilter:maskGenerator];
        self.maskGenerator = maskGenerator;
        
        GPUImageToneCurveFilter *skinToneCurveFilter = [[GPUImageToneCurveFilter alloc] init];
        [self addFilter:skinToneCurveFilter];
        self.skinToneCurveFilter = skinToneCurveFilter;
        
        GPUImageDissolveBlendFilter *dissolveFilter = [[GPUImageDissolveBlendFilter alloc] init];
        dissolveFilter.rotateOnlyFirstTexture = true;
        [self addFilter:dissolveFilter];
        self.dissolveFilter = dissolveFilter;
        
        [skinToneCurveFilter addTarget:dissolveFilter atTextureLocation:1];
        
        GPUImageThreeInputFilter *composeFilter = [[GPUImageThreeInputFilter alloc] initWithFragmentShaderFromString:YUGPUImageHighpassSkinSmoothingCompositingFilterFragmentShaderString];
        composeFilter.rotateOnlyFirstTexture = true;
        [self addFilter:composeFilter];
        
        [maskGenerator addTarget:composeFilter atTextureLocation:2];
        [self.dissolveFilter addTarget:composeFilter atTextureLocation:1];
        
        GPUImageSharpenFilter *sharpen = [[GPUImageSharpenFilter alloc] init];
        [self addFilter:sharpen];
        [composeFilter addTarget:sharpen];
        self.sharpenFilter = sharpen;
        
        self.initialFilters = @[maskGenerator, skinToneCurveFilter, dissolveFilter, composeFilter];
        self.terminalFilter = sharpen;
        
        self.skinToneCurveFilter.rgbCompositeControlPoints = @[
            [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)],
            [NSValue valueWithCGPoint:CGPointMake(0.47, 0.57)],
            [NSValue valueWithCGPoint:CGPointMake(1.0, 1.0)]
        ];
    }
    return self;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex {
    [super setInputSize:newSize atIndex:textureIndex];
    self.currentInputSize = newSize;
    [self updateHighPassRadius];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex {
    [super setInputRotation:newInputRotation atIndex:textureIndex];
}

- (void)updateHighPassRadius {
    CGSize inputSize = self.currentInputSize;
    if (inputSize.width * inputSize.height > 0) {
        CGFloat radiusInPixels = inputSize.width * 0.006;
        if (radiusInPixels != self.maskGenerator.highPassRadiusInPixels) {
            self.maskGenerator.highPassRadiusInPixels = radiusInPixels;
        }
    }
}

- (void)setAmount:(CGFloat)amount {
    _amount = amount;
    self.dissolveFilter.mix = amount;
    self.sharpenFilter.sharpness = 0.4 * amount;
}

@end
