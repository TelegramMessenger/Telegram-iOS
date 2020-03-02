#import "PGPhotoLookupFilterPass.h"

#import "GPUImageTwoInputFilter.h"
#import "PGPhotoEditorPicture.h"

NSString *const PGPhotoLookupFilterFragmentShaderString = PGShaderString(
 uniform sampler2D inputImageTexture2;
 
 vec4 filter(vec4 texel)
 {
     vec3 index = texel.rgb * 15.0;
     vec3 frac = fract(index);
     vec3 i1 = floor(index);
     vec3 i2 = clamp(i1 + 1.0, 0.0, 15.0);
     
     const vec2 offset = vec2(0.001953125, 0.03125); // vec2(0.5 / 256.0, 0.5 / 16.0)
     
     vec3 color1 = i1 * 0.0625; // 1.0 * 0.0625 = 1.0 / 16.0;
     color1.r = color1.r * 0.0625;
     
     vec3 color2 = i2 * 0.0625;
     color2.r = color2.r * 0.0625;
     
     vec2 p000 = vec2(color1.r + color1.b, color1.g);
     vec3 c000 = texture2D(inputImageTexture2, offset + p000).rgb;
     
     vec2 p001 = vec2(color1.r + color2.b, color1.g);
     vec3 c001 = texture2D(inputImageTexture2, offset + p001).rgb;
     
     vec2 p010 = vec2(color1.r + color1.b, color2.g);
     vec3 c010 = texture2D(inputImageTexture2, offset + p010).rgb;
     
     vec2 p011 = vec2(color1.r + color2.b, color2.g);
     vec3 c011 = texture2D(inputImageTexture2, offset + p011).rgb;
     
     vec2 p100 = vec2(color2.r + color1.b, color1.g);
     vec3 c100 = texture2D(inputImageTexture2, offset + p100).rgb;
     
     vec2 p101 = vec2(color2.r + color2.b, color1.g);
     vec3 c101 = texture2D(inputImageTexture2, offset + p101).rgb;
     
     vec2 p110 = vec2(color2.r + color1.b, color2.g);
     vec3 c110 = texture2D(inputImageTexture2, offset + p110).rgb;
     
     vec2 p111 = vec2(color2.r + color2.b, color2.g);
     vec3 c111 = texture2D(inputImageTexture2, offset + p111).rgb;
     
     vec3 c1 = mix(c000, c100, frac.r);
     vec3 c2 = mix(c010, c110, frac.r);
     vec3 c3 = mix(c001, c101, frac.r);
     vec3 c4 = mix(c011, c111, frac.r);
     
     vec3 c1_c2 = mix(c1, c2, frac.g);
     vec3 c3_c4 = mix(c3, c4, frac.g);
     
     return vec4(clamp(mix(c1_c2, c3_c4, frac.b), 0.0, 1.0), texel.a);
 }
);

@implementation PGPhotoLookupFilterPass

- (instancetype)initWithLookupImage:(UIImage *)lookupImage
{
    return [super initWithShaderString:PGPhotoLookupFilterFragmentShaderString textureImages:@[ lookupImage ]];
}

@end
