#import "PGContrastTool.h"

#import "LegacyComponentsInternal.h"

@interface PGContrastTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGContrastTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"contrast";
        _type = PGPhotoToolTypeShader;
        _order = 6;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.ContrastTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"contrast" type:@"lowp float"];
        _parameters = @[ _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;

    CGFloat parameterValue = (value.floatValue / 100.0f) * 0.3f + 1;
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)shaderString
{
    return PGShaderString
    (
        result = vec4(clamp(((result.rgb - vec3(0.5)) * contrast + vec3(0.5)), 0.0, 1.0), result.a);
    );
}

@end
