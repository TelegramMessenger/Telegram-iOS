#import "YUGPUImageHighPassSkinSmoothingFilter.h"

#import "GPUImageExposureFilter.h"
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
             hardLightColor = hardLightColor  * hardLightColor * 2.;
         } else {
             hardLightColor = 1. - (1. - hardLightColor) * (1. - hardLightColor) * 2.;
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
     vec4 image = texture2D(sourceImage, texCoord);
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

@property (nonatomic) CGFloat radiusInPixels;
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

- (CGFloat)radiusInPixels {
    return self.blurFilter.blurRadiusInPixels;
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
    self.highPassFilter.radiusInPixels = highPassRadiusInPixels;
}

- (CGFloat)highPassRadiusInPixels {
    return self.highPassFilter.radiusInPixels;
}

@end

@interface YUGPUImageHighPassSkinSmoothingRadius ()

@property (nonatomic) CGFloat value;
@property (nonatomic) YUGPUImageHighPassSkinSmoothingRadiusUnit unit;

@end

@implementation YUGPUImageHighPassSkinSmoothingRadius

+ (instancetype)radiusInPixels:(CGFloat)pixels {
    YUGPUImageHighPassSkinSmoothingRadius *radius = [YUGPUImageHighPassSkinSmoothingRadius new];
    radius.unit = YUGPUImageHighPassSkinSmoothingRadiusUnitPixel;
    radius.value = pixels;
    return radius;
}

+ (instancetype)radiusAsFractionOfImageWidth:(CGFloat)fraction {
    YUGPUImageHighPassSkinSmoothingRadius *radius = [YUGPUImageHighPassSkinSmoothingRadius new];
    radius.unit = YUGPUImageHighPassSkinSmoothingRadiusUnitFractionOfImageWidth;
    radius.value = fraction;
    return radius;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.value = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(value))] floatValue];
        self.unit = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(unit))] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.value) forKey:NSStringFromSelector(@selector(value))];
    [aCoder encodeObject:@(self.unit) forKey:NSStringFromSelector(@selector(unit))];
}

+ (BOOL)supportsSecureCoding {
    return YES;
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
     gl_FragColor = vec4(mix(image.rgb,toneCurvedImage.rgb,1.0 - mask.b),1.0);
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
        GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc] init];
        exposureFilter.exposure = -1.0;
        [self addFilter:exposureFilter];
        
        YUCIHighPassSkinSmoothingMaskGenerator *maskGenerator = [[YUCIHighPassSkinSmoothingMaskGenerator alloc] init];
        [self addFilter:maskGenerator];
        self.maskGenerator = maskGenerator;
        [exposureFilter addTarget:maskGenerator];
        
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
        
        self.initialFilters = @[exposureFilter,skinToneCurveFilter,dissolveFilter,composeFilter];
        self.terminalFilter = sharpen;
        
        //set defaults
        self.amount = 0.75;
        self.radius = [YUGPUImageHighPassSkinSmoothingRadius radiusAsFractionOfImageWidth:4.5/750.0];
        self.sharpnessFactor = 0.4;
        
        CGPoint controlPoint0 = CGPointMake(0, 0);
        CGPoint controlPoint1 = CGPointMake(120/255.0, 146/255.0);
        CGPoint controlPoint2 = CGPointMake(1.0, 1.0);
        
        self.controlPoints = @[[NSValue valueWithCGPoint:controlPoint0],
                               [NSValue valueWithCGPoint:controlPoint1],
                               [NSValue valueWithCGPoint:controlPoint2]];
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
        CGFloat radiusInPixels = 0;
        switch (self.radius.unit) {
            case YUGPUImageHighPassSkinSmoothingRadiusUnitPixel:
                radiusInPixels = self.radius.value;
                break;
            case YUGPUImageHighPassSkinSmoothingRadiusUnitFractionOfImageWidth:
                radiusInPixels = ceil(inputSize.width * self.radius.value);
                break;
            default:
                break;
        }
        if (radiusInPixels != self.maskGenerator.highPassRadiusInPixels) {
            self.maskGenerator.highPassRadiusInPixels = radiusInPixels;
        }
    }
}

- (void)setRadius:(YUGPUImageHighPassSkinSmoothingRadius *)radius {
    _radius = radius.copy;
    [self updateHighPassRadius];
}

- (void)setControlPoints:(NSArray<NSValue *> *)controlPoints {
    self.skinToneCurveFilter.rgbCompositeControlPoints = controlPoints;
}

- (NSArray<NSValue *> *)controlPoints {
    return self.skinToneCurveFilter.rgbCompositeControlPoints;
}

- (void)setAmount:(CGFloat)amount {
    _amount = amount;
    self.dissolveFilter.mix = amount;
    self.sharpenFilter.sharpness = self.sharpnessFactor * amount;
}

- (void)setSharpnessFactor:(CGFloat)sharpnessFactor {
    _sharpnessFactor = sharpnessFactor;
    self.sharpenFilter.sharpness = sharpnessFactor * self.amount;
}

@end
