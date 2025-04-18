#import "PGShadowsTool.h"

#import "LegacyComponentsInternal.h"

@interface PGShadowsTool ()
{
    PGPhotoProcessPassParameter *_parameter;
}
@end

@implementation PGShadowsTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"shadows";
        _type = PGPhotoToolTypeShader;
        _order = 4;
        
        _minimumValue = -100;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = @(_defaultValue);
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.ShadowsTool");
}

- (bool)shouldBeSkipped
{
    return (ABS(((NSNumber *)self.displayValue).floatValue - (float)self.defaultValue) < FLT_EPSILON);
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _parameter = [PGPhotoProcessPassParameter parameterWithName:@"shadows" type:@"lowp float"];
        _parameters = @[ _parameter ];
    }
    
    return _parameters;
}

- (void)updateParameters
{
    NSNumber *value = (NSNumber *)self.displayValue;
    
    CGFloat parameterValue = (value.floatValue * 0.55f + 100.0f) / 100.0f;
    [_parameter setFloatValue:parameterValue];
}

@end
