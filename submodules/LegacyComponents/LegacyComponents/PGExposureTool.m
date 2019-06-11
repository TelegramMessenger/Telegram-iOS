#import "PGExposureTool.h"

#import "LegacyComponentsInternal.h"

@interface PGExposureTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGExposureTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"exposure";
        _type = PGPhotoToolTypeShader;
        _order = 10;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.ExposureTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"exposure" type:@"lowp float"];
        _parameters = @[ _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = (value.floatValue / 100.0f);
    [_parameter setFloatValue:parameterValue];
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (abs(exposure) > toolEpsilon) {
         mediump float mag = exposure * 1.045;
         mediump float exppower = 1.0 + abs(mag);
         
         if (mag < 0.0) {
             exppower = 1.0 / exppower;
         }
     
         result.r = 1.0 - pow((1.0 - result.r), exppower);
         result.g = 1.0 - pow((1.0 - result.g), exppower);
         result.b = 1.0 - pow((1.0 - result.b), exppower);
     }
    );
}

@end
