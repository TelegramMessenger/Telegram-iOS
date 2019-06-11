#import "PGHighlightsTool.h"

#import "LegacyComponentsInternal.h"

@interface PGHighlightsTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGHighlightsTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"highlights";
        _type = PGPhotoToolTypeShader;
        _order = 5;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.HighlightsTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"highlights" type:@"lowp float"];
        _parameters = @[ [PGPhotoProcessPassParameter constWithName:@"hsLuminanceWeighting" type:@"mediump vec3" value:@"vec3(0.3, 0.3, 0.3)"],
                         _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = (value.floatValue * 0.75f + 100.0f) / 100.0f;
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)shaderString
{
    return PGShaderString
    (
         mediump float hsLuminance = dot(result.rgb, hsLuminanceWeighting);

         mediump float shadow = clamp((pow(hsLuminance, 1.0 / shadows) + (-0.76) * pow(hsLuminance, 2.0 / shadows)) - hsLuminance, 0.0, 1.0);
         mediump float highlight = clamp((1.0 - (pow(1.0 - hsLuminance, 1.0 / (2.0 - highlights)) + (-0.8) * pow(1.0 - hsLuminance, 2.0 / (2.0 - highlights)))) - hsLuminance, -1.0, 0.0);
         lowp vec3 hsresult = vec3(0.0, 0.0, 0.0) + ((hsLuminance + shadow + highlight) - 0.0) * ((result.rgb - vec3(0.0, 0.0, 0.0)) / (hsLuminance - 0.0));
         
         mediump float contrastedLuminance = ((hsLuminance - 0.5) * 1.5) + 0.5;
         mediump float whiteInterp = contrastedLuminance * contrastedLuminance * contrastedLuminance;
         mediump float whiteTarget = clamp(highlights, 1.0, 2.0) - 1.0;
         hsresult = mix(hsresult, vec3(1.0), whiteInterp * whiteTarget);
     
         mediump float invContrastedLuminance = 1.0 - contrastedLuminance;
         mediump float blackInterp = invContrastedLuminance * invContrastedLuminance * invContrastedLuminance;
         mediump float blackTarget = 1.0 - clamp(shadows, 0.0, 1.0);
         hsresult = mix(hsresult, vec3(0.0), blackInterp * blackTarget);
     
         result = vec4(hsresult.rgb, result.a);
    );
}

@end
