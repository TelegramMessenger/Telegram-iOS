#import "PGBlurTool.h"

#import "LegacyComponentsInternal.h"

#import "PGPhotoBlurPass.h"
#import "TGPhotoEditorBlurToolView.h"
#import "TGPhotoEditorBlurAreaView.h"

@implementation PGBlurToolValue

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    PGBlurToolValue *value = [[PGBlurToolValue alloc] init];
    value.type = self.type;
    value.point = self.point;
    value.size = self.size;
    value.falloff = self.falloff;
    value.angle = self.angle;
    value.intensity = self.intensity;
    value.editingIntensity = self.editingIntensity;
    
    return value;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    PGBlurToolValue *value = (PGBlurToolValue *)object;
    
    if (value.type != self.type)
        return false;
    
    if (!CGPointEqualToPoint(value.point, self.point))
        return false;
    
    if (value.size != self.size)
        return false;
    
    if (value.falloff != self.falloff)
        return false;
    
    if (value.angle != self.angle)
        return false;
    
    if (value.intensity != self.intensity)
        return false;
    
    return true;
}

@end

@implementation PGBlurTool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _identifier = @"blur";
        _type = PGPhotoToolTypePass;
        _order = 3;
        
        _pass = [[PGPhotoBlurPass alloc] init];
        
        _minimumValue = 0;
        _maximumValue = 100;
        _defaultValue = 50;
        
        PGBlurToolValue *value = [[PGBlurToolValue alloc] init];
        value.type = PGBlurToolTypeNone;
        value.point = CGPointMake(0.5f, 0.5f);
        value.falloff = 0.12f;
        value.size = 0.24f;
        value.angle = 0;
        value.intensity = _defaultValue;
        
        self.value = value;
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.BlurTool");
}

- (NSString *)intensityEditingTitle
{
    return TGLocalized(@"PhotoEditor.BlurToolRadius");
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock
{
    return [self itemControlViewWithChangeBlock:changeBlock explicit:false nameWidth:0.0f];
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id, bool))changeBlock explicit:(bool)explicit nameWidth:(CGFloat)__unused nameWidth
{
    __weak PGBlurTool *weakSelf = self;
    
    UIView <TGPhotoEditorToolView> *view = [[TGPhotoEditorBlurToolView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, bool animated)
    {
        __strong PGBlurTool *strongSelf = weakSelf;
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

- (UIView <TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id))changeBlock explicit:(bool)explicit
{
    __weak PGBlurTool *weakSelf = self;
    
    UIView <TGPhotoEditorToolView> *view = [[TGPhotoEditorBlurAreaView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, __unused bool animated)
    {
        __strong PGPhotoTool *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (newValue != nil)
        {
            if (!explicit && [strongSelf.tempValue isEqual:newValue])
                return;
            
            if (explicit && [strongSelf.value isEqual:newValue])
                return;
            
            if (!explicit)
                strongSelf.tempValue = newValue;
            else
                strongSelf.value = newValue;
        }
        
        if (changeBlock != nil)
            changeBlock(newValue);
    };
    return view;
}

- (Class)valueClass
{
    return [PGBlurToolValue class];
}

- (PGPhotoProcessPass *)pass
{
    PGBlurToolValue *value = (PGBlurToolValue *)self.displayValue;
    
    if (value.type == PGBlurToolTypeNone)
        return nil;
    
    [self updatePassParameters];
    
    return _pass;
}

- (void)updatePassParameters
{
    PGBlurToolValue *value = (PGBlurToolValue *)self.displayValue;
    PGPhotoBlurPass *blurPass = (PGPhotoBlurPass *)_pass;
    if ([value isKindOfClass:[PGBlurToolValue class]]) {
        blurPass.type = value.type;
        blurPass.size = value.size;
        blurPass.point = value.point;
        blurPass.angle = value.angle;
        blurPass.falloff = value.falloff;
    } else {
        blurPass.type = PGBlurToolTypeNone;
    }
}

- (bool)shouldBeSkipped
{
    if (self.disabled)
        return true;
    
    return (((PGBlurToolValue *)self.displayValue).type == PGBlurToolTypeNone);
}

- (NSString *)stringValue
{
    if ([self.value isKindOfClass:[PGBlurToolValue class]])
    {
        PGBlurToolValue *value = (PGBlurToolValue *)self.value;
        if (value.type == PGBlurToolTypeRadial)
            return TGLocalized(@"PhotoEditor.BlurToolRadial");
        else if (value.type == PGBlurToolTypeLinear)
            return TGLocalized(@"PhotoEditor.BlurToolLinear");
    }
    
    return nil;
}

- (bool)isSimple
{
    return false;
}

- (bool)isAvialableForVideo
{
    return false;
}

@end
