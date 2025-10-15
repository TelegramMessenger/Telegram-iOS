#import "PGPhotoEnhanceInterpolationFilter.h"

#import "PGPhotoProcessPass.h"

NSString *const PGPhotoEnhanceToolInterpolationShaderString = PGShaderString
(
 precision highp float;
 
 varying vec2 texCoord;
 uniform sampler2D sourceImage;
 uniform sampler2D inputImageTexture2;
 uniform float intensity;
 
 vec3 hsv_to_rgb(vec3 c) {
     vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
     vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
     return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
 }
 
 float enhance(float value) {
     const vec2 offset = vec2(0.001953125, 0.03125); // vec2(0.5 / 256.0, 0.5 / 16.0)
     value = value + offset.x;
     
     vec2 coord = (clamp(texCoord, 0.125, 1.0 - 0.125001) - 0.125) * 4.0;
     vec2 frac = fract(coord);
     coord = floor(coord); // vec2(0..3, 0..3)
     
     // 1.0 / 16.0 = 0.0625
     float p00 = float(coord.y * 4.0 + coord.x) * 0.0625 + offset.y;
     float p01 = float(coord.y * 4.0 + coord.x + 1.0) * 0.0625 + offset.y;
     float p10 = float((coord.y + 1.0) * 4.0 + coord.x) * 0.0625 + offset.y;
     float p11 = float((coord.y + 1.0) * 4.0 + coord.x + 1.0) * 0.0625 + offset.y;
     
     vec3 c00 = texture2D(inputImageTexture2, vec2(value, p00)).rgb;
     vec3 c01 = texture2D(inputImageTexture2, vec2(value, p01)).rgb;
     vec3 c10 = texture2D(inputImageTexture2, vec2(value, p10)).rgb;
     vec3 c11 = texture2D(inputImageTexture2, vec2(value, p11)).rgb;
     
     // r - cdf, g - cdfMin, b - cdfMax
     float c1 = ((c00.r - c00.g) / (c00.b - c00.g));
     float c2 = ((c01.r - c01.g) / (c01.b - c01.g));
     float c3 = ((c10.r - c10.g) / (c10.b - c10.g));
     float c4 = ((c11.r - c11.g) / (c11.b - c11.g));
     
     float c1_2 = mix(c1, c2, frac.x);
     float c3_4 = mix(c3, c4, frac.x);
     
     return mix(c1_2, c3_4, frac.y);
 }
 
 void main() {
     vec4 texel = texture2D(sourceImage, texCoord);
     vec4 hsv = texel;
     
     hsv.y = min(1.0, hsv.y * 1.2);
     hsv.z = min(1.0, enhance(hsv.z) * 1.1);
     
     gl_FragColor = vec4(hsv_to_rgb(mix(texel.xyz, hsv.xyz, intensity)), texel.w);
 }
);

@interface PGPhotoEnhanceInterpolationFilter ()
{
    GLint _intensityUniform;
}
@end

@implementation PGPhotoEnhanceInterpolationFilter

@dynamic intensity;

- (instancetype)init
{
    self = [self initWithFragmentShaderFromString:PGPhotoEnhanceToolInterpolationShaderString];
    if (self != nil)
    {
        _intensityUniform = [filterProgram uniformIndex:@"intensity"];
    }
    return self;
}

- (void)setIntensity:(CGFloat)intensity
{
    [self setFloat:(float)intensity forUniformName:@"intensity"];
}

@end
