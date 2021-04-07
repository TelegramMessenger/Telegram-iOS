#import "PGGrainTool.h"

#import "LegacyComponentsInternal.h"

@interface PGGrainTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGGrainTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"grain";
        _type = PGPhotoToolTypeShader;
        _order = 12;
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.GrainTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"grain" type:@"lowp float"];
        _parameters = @[ _parameter,
                         [PGPhotoProcessPassParameter constWithName:@"permTexUnit" type:@"lowp float" value:@"1.0 / 256.0"],
                         [PGPhotoProcessPassParameter constWithName:@"permTexUnitHalf" type:@"lowp float" value:@"0.5 / 256.0"],
                         [PGPhotoProcessPassParameter constWithName:@"grainsize" type:@"lowp float" value:@"2.3"] ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = value.floatValue / 100.0f * 0.04f;
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)ancillaryShaderString
{
    return PGShaderString
    (
        highp vec4 rnm(in highp vec2 tc) {
          highp float noise = sin(dot(tc,vec2(12.9898,78.233))) * 43758.5453;
          
          highp float noiseR = fract(noise)*2.0-1.0;
          highp float noiseG = fract(noise*1.2154)*2.0-1.0;
          highp float noiseB = fract(noise*1.3453)*2.0-1.0;
          highp float noiseA = fract(noise*1.3647)*2.0-1.0;
          
          return vec4(noiseR,noiseG,noiseB,noiseA);
        }

        highp float fade(in highp float t) {
          return t*t*t*(t*(t*6.0-15.0)+10.0);
        }

        highp float pnoise3D(in highp vec3 p)
        {
          highp vec3 pi = permTexUnit*floor(p)+permTexUnitHalf;
          highp vec3 pf = fract(p);
          
          // Noise contributions from (x=0, y=0), z=0 and z=1
          highp float perm00 = rnm(pi.xy).a ;
          highp vec3  grad000 = rnm(vec2(perm00, pi.z)).rgb * 4.0 - 1.0;
          highp float n000 = dot(grad000, pf);
          highp vec3  grad001 = rnm(vec2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
          highp float n001 = dot(grad001, pf - vec3(0.0, 0.0, 1.0));
          
          // Noise contributions from (x=0, y=1), z=0 and z=1
          highp float perm01 = rnm(pi.xy + vec2(0.0, permTexUnit)).a ;
          highp vec3  grad010 = rnm(vec2(perm01, pi.z)).rgb * 4.0 - 1.0;
          highp float n010 = dot(grad010, pf - vec3(0.0, 1.0, 0.0));
          highp vec3  grad011 = rnm(vec2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
          highp float n011 = dot(grad011, pf - vec3(0.0, 1.0, 1.0));
          
          // Noise contributions from (x=1, y=0), z=0 and z=1
          highp float perm10 = rnm(pi.xy + vec2(permTexUnit, 0.0)).a ;
          highp vec3  grad100 = rnm(vec2(perm10, pi.z)).rgb * 4.0 - 1.0;
          highp float n100 = dot(grad100, pf - vec3(1.0, 0.0, 0.0));
          highp vec3  grad101 = rnm(vec2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
          highp float n101 = dot(grad101, pf - vec3(1.0, 0.0, 1.0));
          
          // Noise contributions from (x=1, y=1), z=0 and z=1
          highp float perm11 = rnm(pi.xy + vec2(permTexUnit, permTexUnit)).a ;
          highp vec3  grad110 = rnm(vec2(perm11, pi.z)).rgb * 4.0 - 1.0;
          highp float n110 = dot(grad110, pf - vec3(1.0, 1.0, 0.0));
          highp vec3  grad111 = rnm(vec2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
          highp float n111 = dot(grad111, pf - vec3(1.0, 1.0, 1.0));
          
          // Blend contributions along x
          highp vec4 n_x = mix(vec4(n000, n001, n010, n011), vec4(n100, n101, n110, n111), fade(pf.x));
          
          // Blend contributions along y
          highp vec2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));
          
          // Blend contributions along z
          highp float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));
          
          return n_xyz;
        }

        lowp vec2 coordRot(in lowp vec2 tc, in lowp float angle)
        {
          lowp float rotX = ((tc.x * 2.0 - 1.0) * cos(angle)) - ((tc.y * 2.0 - 1.0) * sin(angle));
          lowp float rotY = ((tc.y * 2.0 - 1.0) * cos(angle)) + ((tc.x * 2.0 - 1.0) * sin(angle));
          rotX = rotX * 0.5 + 0.5;
          rotY = rotY * 0.5 + 0.5;
          return vec2(rotX,rotY);
        }
     );
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (abs(grain) > toolEpsilon) {
         highp vec3 rotOffset = vec3(1.425, 3.892, 5.835);
         highp vec2 rotCoordsR = coordRot(texCoord, rotOffset.x);
         highp vec3 noise = vec3(pnoise3D(vec3(rotCoordsR * vec2(width / grainsize, height / grainsize),0.0)));
         
         lowp vec3 lumcoeff = vec3(0.299,0.587,0.114);
         lowp float luminance = dot(result.rgb, lumcoeff);
         lowp float lum = smoothstep(0.2, 0.0, luminance);
         lum += luminance;
         
         noise = mix(noise,vec3(0.0),pow(lum,4.0));
         result.rgb = result.rgb + noise * grain;
     }
    );
}

- (bool)isAvialableForVideo
{
    return false;
}

@end
