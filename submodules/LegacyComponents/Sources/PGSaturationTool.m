#import "PGSaturationTool.h"

#import "LegacyComponentsInternal.h"

@interface PGSaturationTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGSaturationTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"saturation";
        _type = PGPhotoToolTypeShader;
        _order = 8;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.SaturationTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"saturation" type:@"lowp float"];
        _parameters = @[ [PGPhotoProcessPassParameter constWithName:@"satLuminanceWeighting" type:@"mediump vec3" value:@"vec3(0.2126, 0.7152, 0.0722)"],
                         _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = (value.floatValue / 100.0f);
    if (parameterValue > 0)
        parameterValue *= 1.05f;
    parameterValue += 1;
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)shaderString
{
    return PGShaderString
    (
        lowp float satLuminance = dot(result.rgb, satLuminanceWeighting);
        lowp vec3 greyScaleColor = vec3(satLuminance);
     
        result = vec4(clamp(mix(greyScaleColor, result.rgb, saturation), 0.0, 1.0), result.a);
    );
}

@end
