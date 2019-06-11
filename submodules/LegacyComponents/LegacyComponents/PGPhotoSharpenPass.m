#import "PGPhotoSharpenPass.h"

NSString *const kSharpenVertexShaderString = PGShaderString
(
 attribute vec4 position;
 attribute vec4 inputTexCoord;
 
 uniform float imageWidthFactor;
 uniform float imageHeightFactor;
 uniform float sharpness;
 
 varying vec2 texCoord;
 varying vec2 leftTexCoord;
 varying vec2 rightTexCoord;
 varying vec2 topTexCoord;
 varying vec2 bottomTexCoord;
 
 varying float centerMultiplier;
 varying float edgeMultiplier;
 
 void main()
 {
     gl_Position = position;
     
     vec2 widthStep = vec2(imageWidthFactor, 0.0);
     vec2 heightStep = vec2(0.0, imageHeightFactor);
     
     texCoord = inputTexCoord.xy;
     leftTexCoord = inputTexCoord.xy - widthStep;
     rightTexCoord = inputTexCoord.xy + widthStep;
     topTexCoord = inputTexCoord.xy + heightStep;
     bottomTexCoord = inputTexCoord.xy - heightStep;
     
     centerMultiplier = 1.0 + 4.0 * sharpness;
     edgeMultiplier = sharpness;
 }
 );

NSString *const kSharpenFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 texCoord;
 varying highp vec2 leftTexCoord;
 varying highp vec2 rightTexCoord;
 varying highp vec2 topTexCoord;
 varying highp vec2 bottomTexCoord;
 
 varying highp float centerMultiplier;
 varying highp float edgeMultiplier;
 
 uniform sampler2D sourceImage;
 
 void main()
 {
     mediump vec3 textureColor = texture2D(sourceImage, texCoord).rgb;
     mediump vec3 leftTextureColor = texture2D(sourceImage, leftTexCoord).rgb;
     mediump vec3 rightTextureColor = texture2D(sourceImage, rightTexCoord).rgb;
     mediump vec3 topTextureColor = texture2D(sourceImage, topTexCoord).rgb;
     mediump vec3 bottomTextureColor = texture2D(sourceImage, bottomTexCoord).rgb;
     
     gl_FragColor = vec4((textureColor * centerMultiplier - (leftTextureColor * edgeMultiplier + rightTextureColor * edgeMultiplier + topTextureColor * edgeMultiplier + bottomTextureColor * edgeMultiplier)), texture2D(sourceImage, bottomTexCoord).w);
 }
 );

@interface PGSharpenFilter : GPUImageFilter

@property (nonatomic, assign) CGFloat sharpness;

@end

@implementation PGSharpenFilter
{
    GLint sharpnessUniform;
    GLint imageWidthFactorUniform;
    GLint imageHeightFactorUniform;
}

- (instancetype)init
{
    self = [super initWithVertexShaderFromString:kSharpenVertexShaderString fragmentShaderFromString:kSharpenFragmentShaderString];
    if (self != nil)
    {
        sharpnessUniform = [filterProgram uniformIndex:@"sharpness"];
        self.sharpness = 0.0f;
        
        imageWidthFactorUniform = [filterProgram uniformIndex:@"imageWidthFactor"];
        imageHeightFactorUniform = [filterProgram uniformIndex:@"imageHeightFactor"];
    }
    return self;
}

- (void)setupFilterForSize:(CGSize)filterFrameSize
{
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [GPUImageContext setActiveShaderProgram:filterProgram];

        if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
        {
            glUniform1f(imageWidthFactorUniform, (GLfloat)(1.0f / filterFrameSize.height));
            glUniform1f(imageHeightFactorUniform, (GLfloat)(1.0f / filterFrameSize.width));
        }
        else
        {
            glUniform1f(imageWidthFactorUniform, (GLfloat)(1.0f / filterFrameSize.width));
            glUniform1f(imageHeightFactorUniform, (GLfloat)(1.0f / filterFrameSize.height));
        }
    });
}

- (void)setSharpness:(CGFloat)newValue
{
    _sharpness = newValue;
    
    [self setFloat:(float)_sharpness forUniform:sharpnessUniform program:filterProgram];
}

@end

@implementation PGPhotoSharpenPass

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _filter = [[PGSharpenFilter alloc] init];
    }
    return self;
}

- (void)setSharpness:(CGFloat)sharpness
{
    _sharpness = sharpness;
    [self updateParameters];
}

- (void)updateParameters
{
    [((PGSharpenFilter *) _filter) setSharpness:_sharpness];
}

@end