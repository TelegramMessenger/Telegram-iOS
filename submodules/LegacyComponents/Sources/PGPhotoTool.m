#import "PGPhotoTool.h"
#import "TGPhotoEditorGenericToolView.h"

@implementation PGPhotoTool

@synthesize title = _title;
@synthesize value = _value;
@synthesize tempValue = _tempValue;
@synthesize parameters = _parameters;
@synthesize beingEdited = _beingEdited;
@synthesize shouldBeSkipped = _shouldBeSkipped;
@synthesize parametersChanged = _parametersChanged;
@synthesize disabled = _disabled;
@synthesize segmented = _segmented;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self parameters];
    }
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (PGPhotoToolType)type
{
    return _type;
}

- (bool)isSimple
{
    return true;
}

- (bool)isAvialableForVideo
{
    return true;
}

- (bool)requiresFaces
{
    return false;
}

- (NSInteger)order
{
    return _order;
}

- (Class)valueClass
{
    return [NSNumber class];
}

- (CGFloat)minimumValue
{
    return _minimumValue;
}

- (CGFloat)maximumValue
{
    return _maximumValue;
}

- (CGFloat)defaultValue
{
    return _defaultValue;
}

- (id)tempValue
{
    if (self.disabled)
    {
        if ([_tempValue isKindOfClass:[NSNumber class]])
            return @0;
    }
    
    return _tempValue;
}

- (id)displayValue
{
    if (self.disabled)
        return @(self.defaultValue);
    
    if (self.beingEdited)
        return self.tempValue;

    return self.value;
}

- (void)setDisabled:(bool)disabled
{
    _disabled = disabled;
    
    if (!self.beingEdited) {
        [self updateParameters];
        [self updatePassParameters];
    }
}

- (void)updatePassParameters {
    
}

- (void)setBeingEdited:(bool)beingEdited
{
    _beingEdited = beingEdited;
    
    [self updateParameters];
}

- (void)setValue:(id)value
{
    _value = value;
    
    if (!self.beingEdited)
        [self updateParameters];
}

- (void)setTempValue:(id)tempValue
{
    _tempValue = tempValue;
    
    if (self.beingEdited)
        [self updateParameters];
}

- (bool)isHidden
{
    return false;
}

- (void)updateParameters
{
    
}

- (void)reset
{

}

- (void)invalidate
{
    if (_pass != nil)
        [_pass invalidate];
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock
{
    return [self itemControlViewWithChangeBlock:changeBlock explicit:false nameWidth:0.0f];
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock explicit:(bool)explicit nameWidth:(CGFloat)nameWidth
{
    __weak PGPhotoTool *weakSelf = self;
    
    UIView <TGPhotoEditorToolView> *view = [[TGPhotoEditorGenericToolView alloc] initWithEditorItem:self explicit:explicit nameWidth:nameWidth];
    view.valueChanged = ^(id newValue, bool animated)
    {
        __strong PGPhotoTool *strongSelf = weakSelf;
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

- (UIView <TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id newValue))__unused changeBlock
{
    return [self itemAreaViewWithChangeBlock:changeBlock explicit:false];
}

- (UIView<TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id))__unused changeBlock explicit:(bool)__unused explicit
{
    return nil;
}

- (NSString *)stringValue
{
    return [self stringValue:false];
}

- (NSString *)stringValue:(bool)includeZero
{
    if ([self.displayValue isKindOfClass:[NSNumber class]])
    {
        NSNumber *value = (NSNumber *)self.displayValue;
        CGFloat fractValue = value.floatValue / ABS(self.maximumValue);
        if (floorf(ABS(value.floatValue)) == 0)
            return includeZero ? @"0.00" : nil;
        else if (fractValue > 0)
            return [NSString stringWithFormat:@"+%0.2f", fractValue];
        else if (fractValue < 0)
            return [NSString stringWithFormat:@"%0.2f", fractValue];
    }
    
    return nil;
}

- (NSString *)ancillaryShaderString
{
    return nil;
}

@end
