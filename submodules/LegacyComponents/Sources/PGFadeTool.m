#import "PGFadeTool.h"

#import "LegacyComponentsInternal.h"

@interface PGFadeTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGFadeTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"fade";
        _type = PGPhotoToolTypeShader;
        _order = 7;
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.FadeTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"fadeAmount" type:@"lowp float"];
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

- (NSString *)ancillaryShaderString
{
    return PGShaderString
    (
     highp vec3 fadeAdjust(highp vec3 color, highp float fadeVal) {
         highp vec3 co1 = vec3(-0.9772);
         highp vec3 co2 = vec3(1.708);
         highp vec3 co3 = vec3(-0.1603);
         highp vec3 co4 = vec3(0.2878);
         
         highp vec3 comp1 = co1 * pow(vec3(color), vec3(3.0));
         highp vec3 comp2 = co2 * pow(vec3(color), vec3(2.0));
         highp vec3 comp3 = co3 * vec3(color);
         highp vec3 comp4 = co4;
         
         highp vec3 finalComponent = comp1 + comp2 + comp3 + comp4;
         highp vec3 difference = finalComponent - color;
         highp vec3 scalingValue = vec3(0.9);
         
         highp vec3 faded = color + (difference * scalingValue);
         
         return (color * (1.0 - fadeVal)) + (faded * fadeVal);
     }
    );
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (abs(fadeAmount) > toolEpsilon) {
         result.rgb = fadeAdjust(result.rgb, fadeAmount);
     }
    );
}

@end
