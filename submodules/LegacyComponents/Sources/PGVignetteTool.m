#import "PGVignetteTool.h"

#import "LegacyComponentsInternal.h"

@interface PGVignetteTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGVignetteTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"vignette";
        _type = PGPhotoToolTypeShader;
        _order = 13;
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.VignetteTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"vignette" type:@"lowp float"];
        _parameters = @[ _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = value.floatValue / 100.0f;
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (abs(vignette) > toolEpsilon) {
         const lowp float midpoint = 0.7;
         const lowp float fuzziness = 0.62;
         
         lowp float radDist = length(texCoord - 0.5) / sqrt(0.5);
         lowp float mag = easeInOutSigmoid(radDist * midpoint, fuzziness) * vignette * 0.645;
         result.rgb = mix(pow(result.rgb, vec3(1.0 / (1.0 - mag))), vec3(0.0), mag * mag);
     }
    );
}

@end
