#import "GPUImageExposureFilter.h"

NSString *const kGPUImageExposureFragmentShaderString = SHADER_STRING
(
 varying highp vec2 texCoord;
 
 uniform sampler2D sourceImage;
 uniform highp float exposure;
 
 void main()
 {
     highp vec4 textureColor = texture2D(sourceImage, texCoord);
     
     gl_FragColor = vec4(textureColor.rgb * pow(2.0, exposure), textureColor.w);
 }
);

@implementation GPUImageExposureFilter

@synthesize exposure = _exposure;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageExposureFragmentShaderString]))
    {
		return nil;
    }
    
    exposureUniform = [filterProgram uniformIndex:@"exposure"];
    self.exposure = 0.0;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setExposure:(CGFloat)newValue;
{
    _exposure = newValue;
    
    [self setFloat:_exposure forUniform:exposureUniform program:filterProgram];
}

@end

