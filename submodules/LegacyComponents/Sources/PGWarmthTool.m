#import "PGWarmthTool.h"

#import "LegacyComponentsInternal.h"

@interface PGWarmthTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGWarmthTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"warmth";
        _type = PGPhotoToolTypeShader;
        _order = 11;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.WarmthTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"warmth" type:@"lowp float"];
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
     if (abs(warmth) > toolEpsilon) {
         highp vec3 yuvVec;
         
         if (warmth > 0.0 ) {
             yuvVec =  vec3(0.1765, -0.1255, 0.0902);
         }
         else {
             yuvVec = -vec3(0.0588,  0.1569, -0.1255);
         }
         highp vec3 yuvColor = rgbToYuv(result.rgb);
         
         highp float luma = yuvColor.r;
         
         highp float curveScale = sin(luma * 3.14159);
         
         yuvColor += 0.375 * warmth * curveScale * yuvVec;
         result.rgb = yuvToRgb(yuvColor);
     }
    );
}

@end
