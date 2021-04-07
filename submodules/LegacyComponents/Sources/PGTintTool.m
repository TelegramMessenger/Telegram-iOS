#import "PGTintTool.h"
#import "TGPhotoEditorTintToolView.h"

#import "LegacyComponentsInternal.h"

@implementation PGTintToolValue

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    PGTintToolValue *value = [[PGTintToolValue alloc] init];
    value.shadowsColor = self.shadowsColor;
    value.shadowsIntensity = self.shadowsIntensity;
    value.highlightsColor = self.highlightsColor;
    value.highlightsIntensity = self.highlightsIntensity;
    value.editingHighlights = self.editingHighlights;
    
    return value;
}

- (id<PGCustomToolValue>)cleanValue
{
    PGTintToolValue *value = [[PGTintToolValue alloc] init];
    value.shadowsColor = self.shadowsColor;
    value.shadowsIntensity = self.shadowsIntensity;
    value.highlightsColor = self.highlightsColor;
    value.highlightsIntensity = self.highlightsIntensity;
    
    return value;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    PGTintToolValue *value = (PGTintToolValue *)object;
    
    if (![value.shadowsColor isEqual:self.shadowsColor])
        return false;
    
    if (value.shadowsIntensity != self.shadowsIntensity)
        return false;
    
    if (![value.highlightsColor isEqual:self.highlightsColor])
        return false;
    
    if (value.highlightsIntensity != self.highlightsIntensity)
        return false;
        
    return true;
}

+ (instancetype)defaultValue {
    PGTintToolValue *value = [[PGTintToolValue alloc] init];
    value.shadowsColor = [UIColor clearColor];
    value.shadowsIntensity = 50.0f;
    value.highlightsColor = [UIColor clearColor];
    value.highlightsIntensity = 50.0f;
    return value;
}

@end


@interface PGTintTool ()
{
    PGPhotoProcessPassParameter *_shadowsIntensityParameter;
    PGPhotoProcessPassParameter *_highlightsIntensityParameter;
    PGPhotoProcessPassParameter *_shadowsTintColorParameter;
    PGPhotoProcessPassParameter *_highlightsTintColorParameter;
}
@end

@implementation PGTintTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"tint";
        _type = PGPhotoToolTypeShader;
        _order = 9;
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 0;
        
        self.value = [PGTintToolValue defaultValue];
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.TintTool");
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id, bool))changeBlock explicit:(bool)explicit nameWidth:(CGFloat)__unused nameWidth
{
    __weak PGTintTool *weakSelf = self;
    
    UIView <TGPhotoEditorToolView> *view = [[TGPhotoEditorTintToolView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, bool animated)
    {
        __strong PGTintTool *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (!explicit && [strongSelf.tempValue isEqual:newValue])
            return;
        
        if (explicit && [strongSelf.value isEqual:newValue])
            return;
        
        if (!explicit)
            strongSelf.tempValue = newValue;
        else
            strongSelf.value = newValue;
        
        if (changeBlock != nil)
            changeBlock(newValue, animated);
    };
    return view;
}

- (bool)shouldBeSkipped
{
    PGTintToolValue *value = (PGTintToolValue *)self.displayValue;
    return (value.highlightsIntensity < FLT_EPSILON && value.shadowsIntensity < FLT_EPSILON) || ([value.highlightsColor isEqual:[UIColor clearColor]] && [value.shadowsColor isEqual:[UIColor clearColor]]);
}

- (Class)valueClass
{
    return [PGTintToolValue class];
}

- (NSArray *)parameters
{
    if (!_parameters)
    {
        _shadowsIntensityParameter = [PGPhotoProcessPassParameter parameterWithName:@"shadowsTintIntensity" type:@"lowp float"];
        _highlightsIntensityParameter = [PGPhotoProcessPassParameter parameterWithName:@"highlightsTintIntensity" type:@"lowp float"];
        _shadowsTintColorParameter = [PGPhotoProcessPassParameter parameterWithName:@"shadowsTintColor" type:@"lowp vec3"];
        _highlightsTintColorParameter = [PGPhotoProcessPassParameter parameterWithName:@"highlightsTintColor" type:@"lowp vec3"];
        _parameters = @[ _shadowsIntensityParameter, _highlightsIntensityParameter,
                         _shadowsTintColorParameter, _highlightsTintColorParameter ];
    }
    
    return _parameters;
}

- (id)displayValue {
    if (self.disabled) {
        return [PGTintToolValue defaultValue];
    } else {
        return [super displayValue];
    }
}

- (void)updateParameters
{
    PGTintToolValue *value = (PGTintToolValue *)self.displayValue;
    if (value == nil)
        return;

    [_shadowsTintColorParameter setColorValue:value.shadowsColor];
    CGFloat shadowsIntensity = [value.shadowsColor isEqual:[UIColor clearColor]] ? 0 : value.shadowsIntensity;
    [_shadowsIntensityParameter setFloatValue:shadowsIntensity / 100.0f];
    
    [_highlightsTintColorParameter setColorValue:value.highlightsColor];
    CGFloat highlightsIntensity = [value.highlightsColor isEqual:[UIColor clearColor]] ? 0 : value.highlightsIntensity;
    [_highlightsIntensityParameter setFloatValue:highlightsIntensity / 100.0f];
}

- (NSString *)stringValue
{
    if (![self shouldBeSkipped])
        return @"◆";
    
    return nil;
}


- (NSString *)ancillaryShaderString
{
    return PGShaderString
    (
     lowp vec3 tintRaiseShadowsCurve(lowp vec3 color) {
         highp vec3 co1 = vec3(-0.003671);
         highp vec3 co2 = vec3(0.3842);
         highp vec3 co3 = vec3(0.3764);
         highp vec3 co4 = vec3(0.2515);
         
         highp vec3 comp1 = co1 * pow(color, vec3(3.0));
         highp vec3 comp2 = co2 * pow(color, vec3(2.0));
         highp vec3 comp3 = co3 * color;
         highp vec3 comp4 = co4;
         
         return comp1 + comp2 + comp3 + comp4;
     }
     
     lowp vec3 tintShadows(lowp vec3 texel, lowp vec3 tintColor, lowp float tintAmount) {
         highp vec3 raisedShadows = tintRaiseShadowsCurve(texel);
         
         highp vec3 tintedShadows = mix(texel, raisedShadows, tintColor);
         highp vec3 tintedShadowsWithAmount = mix(texel, tintedShadows, tintAmount);
         
         return clamp(tintedShadowsWithAmount, 0.0, 1.0);
     }
     
     lowp vec3 tintHighlights(lowp vec3 texel, lowp vec3 tintColor, lowp float tintAmount) {
         lowp vec3 loweredHighlights = vec3(1.0) - tintRaiseShadowsCurve(vec3(1.0) - texel);
         
         lowp vec3 tintedHighlights = mix(texel, loweredHighlights, (vec3(1.0) - tintColor));
         lowp vec3 tintedHighlightsWithAmount = mix(texel, tintedHighlights, tintAmount);
         
         return clamp(tintedHighlightsWithAmount, 0.0, 1.0);
     }
    );
}

- (NSString *)shaderString
{
    return PGShaderString
    (
     if (abs(shadowsTintIntensity) > toolEpsilon) {
         result.rgb = tintShadows(result.rgb, shadowsTintColor, shadowsTintIntensity * 2.0);
     }
     
     if (abs(highlightsTintIntensity) > toolEpsilon) {
         result.rgb = tintHighlights(result.rgb, highlightsTintColor, highlightsTintIntensity * 2.0);
     }
    );
}

- (bool)isSimple
{
    return false;
}

@end
