#import "GPUImageDissolveBlendFilter.h"

NSString *const kGPUImageDissolveBlendFragmentShaderString = SHADER_STRING
(
 varying highp vec2 texCoord;
 varying highp vec2 texCoord2;

 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 uniform lowp float mixturePercent;
 
 void main()
 {
    lowp vec4 textureColor = texture2D(sourceImage, texCoord);
    lowp vec4 textureColor2 = texture2D(inputImageTexture2, texCoord2);
    
    gl_FragColor = mix(textureColor, textureColor2, mixturePercent);
 }
);

@implementation GPUImageDissolveBlendFilter

@synthesize mix = _mix;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageDissolveBlendFragmentShaderString]))
    {
		return nil;
    }
    
    mixUniform = [filterProgram uniformIndex:@"mixturePercent"];
    self.mix = 0.5;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setMix:(CGFloat)newValue;
{
    _mix = newValue;
    
    [self setFloat:_mix forUniform:mixUniform program:filterProgram];
}

@end

