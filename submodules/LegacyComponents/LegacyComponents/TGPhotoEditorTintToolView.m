#import "TGPhotoEditorTintToolView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGModernButton.h>

#import "TGPhotoEditorTintSwatchView.h"
#import "TGPhotoEditorSliderView.h"

#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "PGTintTool.h"

@interface TGPhotoEditorTintButtonsWrapperView : UIView

@end

@interface TGPhotoEditorTintToolView () <UIGestureRecognizerDelegate>
{
    UIView *_buttonsWrapper;
    NSArray *_swatchViews;
    
    TGModernButton *_shadowsButton;
    TGModernButton *_highlightsButton;
    UILabel *_intensityTitleLabel;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    
    TGPhotoEditorSliderView *_sliderView;
 
    bool _editingHighlights;
    bool _editingIntensity;
    
    CGFloat _startIntensity;
}

@property (nonatomic, weak) PGTintTool *tintTool;

@end

@implementation TGPhotoEditorTintToolView

@synthesize valueChanged = _valueChanged;
@synthesize value = _value;
@dynamic interactionBegan;
@dynamic interactionEnded;
@synthesize actualAreaSize;
@synthesize isLandscape;
@synthesize toolbarLandscapeSize;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor redColor];
        
        _sliderView = [[TGPhotoEditorSliderView alloc] initWithFrame:CGRectZero];
        _sliderView.backgroundColor = [UIColor clearColor];
        _sliderView.layer.rasterizationScale = TGScreenScaling();
        _sliderView.minimumValue = editorItem.minimumValue;
        _sliderView.maximumValue = editorItem.maximumValue;
        _sliderView.startValue = 0;
        _sliderView.lineSize = 2.0f;
        _sliderView.trackCornerRadius = 1.0f;
        _sliderView.trackColor = [UIColor whiteColor];
        if (editorItem.value != nil && [editorItem.value isKindOfClass:[NSNumber class]])
            _sliderView.value = [(NSNumber *)editorItem.value integerValue];
        [_sliderView addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_sliderView];
        
        _buttonsWrapper = [[TGPhotoEditorTintButtonsWrapperView alloc] initWithFrame:self.bounds];
        _buttonsWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_buttonsWrapper];
        
        NSArray *colors = [self shadowsColors];
        
        NSInteger i = 0;
        NSMutableArray *swatchViews = [[NSMutableArray alloc] init];
        
        for (UIColor *color in colors)
        {
            TGPhotoEditorTintSwatchView *swatchView = [[TGPhotoEditorTintSwatchView alloc] initWithFrame:CGRectMake(0, 0, TGPhotoEditorTintSwatchSize, TGPhotoEditorTintSwatchSize)];
            swatchView.color = color;
            [swatchView addTarget:self action:@selector(swatchPressed:) forControlEvents:UIControlEventTouchUpInside];
            [_buttonsWrapper addSubview:swatchView];
            
            if (i == 0)
                swatchView.selected = true;
            
            [swatchViews addObject:swatchView];
            i++;
        }
        _swatchViews = swatchViews;
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [_buttonsWrapper addGestureRecognizer:_panGestureRecognizer];
        
        if ([editorItem isKindOfClass:[PGTintTool class]])
        {
            PGTintTool *tintTool = (PGTintTool *)editorItem;
            self.tintTool = tintTool;
            [self setValue:editorItem.value];
        }
        
        _shadowsButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 120, 20)];
        _shadowsButton.selected = true;
        _shadowsButton.backgroundColor = [UIColor clearColor];
        _shadowsButton.titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
        [_shadowsButton setTitle:TGLocalized(@"PhotoEditor.ShadowsTint") forState:UIControlStateNormal];
        [_shadowsButton setTitleColor:UIColorRGB(0x808080) forState:UIControlStateNormal];
        [_shadowsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_shadowsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected | UIControlStateHighlighted];
        [_shadowsButton addTarget:self action:@selector(modeButtonPressed:) forControlEvents:UIControlEventTouchDown];
        [self addSubview:_shadowsButton];
        
        _highlightsButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 120, 20)];
        _highlightsButton.backgroundColor = [UIColor clearColor];
        _highlightsButton.titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
        [_highlightsButton setTitle:TGLocalized(@"PhotoEditor.HighlightsTint") forState:UIControlStateNormal];
        [_highlightsButton setTitleColor:UIColorRGB(0x808080) forState:UIControlStateNormal];
        [_highlightsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_highlightsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected | UIControlStateHighlighted];
        [_highlightsButton addTarget:self action:@selector(modeButtonPressed:) forControlEvents:UIControlEventTouchDown];
        [self addSubview:_highlightsButton];
    }
    return self;
}

- (NSArray *)shadowsColors
{
    static dispatch_once_t onceToken;
    static NSArray *shadowColors;
    dispatch_once(&onceToken, ^
    {
        shadowColors = @[ [UIColor clearColor],
                          UIColorRGB(0xff4d4d),
                          UIColorRGB(0xf48022),
                          UIColorRGB(0xffcd00),
                          UIColorRGB(0x81d281),
                          UIColorRGB(0x71c5d6),
                          UIColorRGB(0x0072bc),
                          UIColorRGB(0x662d91) ];
    });
    return shadowColors;
}

- (NSArray *)highlightsColors
{
    static dispatch_once_t onceToken;
    static NSArray *highlightsColors;
    dispatch_once(&onceToken, ^
    {
        highlightsColors = @[ [UIColor clearColor],
                              UIColorRGB(0xef9286),
                              UIColorRGB(0xeacea2),
                              UIColorRGB(0xf2e17c),
                              UIColorRGB(0xa4edae),
                              UIColorRGB(0x89dce5),
                              UIColorRGB(0x2e8bc8),
                              UIColorRGB(0xcd98e5) ];
    });
    return highlightsColors;
}

- (void)modeButtonPressed:(TGModernButton *)sender
{
    bool editingHighlights = false;
    if (sender == _shadowsButton)
    {
        _shadowsButton.selected = true;
        _highlightsButton.selected = false;
        
        editingHighlights = false;
    }
    else if (sender == _highlightsButton)
    {
        _shadowsButton.selected = false;
        _highlightsButton.selected = true;
        
        editingHighlights = true;
    }
    
    if (editingHighlights != _editingHighlights)
    {
        _editingHighlights = editingHighlights;
        
        PGTintToolValue *value = [(PGTintToolValue *)self.value copy];
        value.editingHighlights = editingHighlights;
        
        _value = value;
        
        [self setHighlightsColors:editingHighlights];
        [self setSelectedColor:editingHighlights ? value.highlightsColor : value.shadowsColor];
        [_sliderView setValue:editingHighlights ? value.highlightsIntensity : value.shadowsIntensity];
        
        self.valueChanged(value, false);
    }
    
    [self updateSliderView];
}

- (void)swatchPressed:(TGPhotoEditorTintSwatchView *)sender
{
    PGTintToolValue *value = [(PGTintToolValue *)self.value copy];
    
    for (TGPhotoEditorTintSwatchView *swatchView in _swatchViews)
    {
        swatchView.selected = (swatchView == sender);
        
        if (swatchView.selected)
        {
            if (_editingHighlights)
                value.highlightsColor = sender.color;
            else
                value.shadowsColor = sender.color;
            
            _value = value;
            
            if (self.valueChanged != nil)
                self.valueChanged(value, false);
        }
    }
    
    [self updateSliderView];
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
    return true;
}

- (void)updateSliderView
{
    UIColor *color = [UIColor whiteColor];
    for (TGPhotoEditorTintSwatchView *swatchView in _swatchViews)
    {
        if (swatchView.selected)
        {
            color = swatchView.color;
            break;
        }
    }
    
    bool enabled = ![color isEqual:[UIColor clearColor]];
    _sliderView.trackColor = enabled ? color : [UIColor whiteColor];

    _sliderView.layer.rasterizationScale = TGScreenScaling();
    _sliderView.layer.shouldRasterize = !enabled;
    _sliderView.alpha = enabled ? 1.0f : 0.3f;
    _sliderView.userInteractionEnabled = enabled;
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    for (TGPhotoEditorTintSwatchView *swatchView in _swatchViews)
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            if (point.x >= swatchView.frame.origin.x && point.x <= swatchView.frame.origin.x + swatchView.frame.size.width && !swatchView.isSelected)
            {
                [self swatchPressed:swatchView];
                break;
            }
        }
        else
        {
            if (point.y >= swatchView.frame.origin.y && point.y <= swatchView.frame.origin.y + swatchView.frame.size.height && !swatchView.isSelected)
            {
                [self swatchPressed:swatchView];
                break;
            }
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    if (self.frame.size.width > self.frame.size.height)
    {
        return point.y < _sliderView.frame.origin.y;
    }
    else
    {
        UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
        if (orientation == UIInterfaceOrientationLandscapeLeft)
            return point.x < _sliderView.frame.origin.x;
        else
            return point.x > CGRectGetMaxX(_sliderView.frame);

    }
    
    return true;
}

- (void)setInteractionEnded:(void (^)(void))interactionEnded
{
    _sliderView.interactionEnded = interactionEnded;
}

- (bool)isTracking
{
    return _sliderView.isTracking;
}

- (void)sliderValueChanged:(TGPhotoEditorSliderView *)sender
{
    PGTintToolValue *value = [(PGTintToolValue *)self.value copy];
    
    NSInteger newValue = (NSInteger)(CGFloor(sender.value));
    if (_editingHighlights)
        value.highlightsIntensity = newValue;
    else
        value.shadowsIntensity = newValue;
    
    _value = value;
    
    if (self.valueChanged != nil)
        self.valueChanged(value, false);
}

- (void)setValue:(id)value
{
    if (![value isKindOfClass:[PGTintToolValue class]])
        return;
    
    _value = value;
    
    PGTintToolValue *tintValue = (PGTintToolValue *)value;
    
    if (tintValue.editingHighlights != _editingHighlights)
    {
        _editingHighlights = tintValue.editingHighlights;
        _shadowsButton.selected = !_editingHighlights;
        _highlightsButton.selected = _editingHighlights;
        
        [self setHighlightsColors:_editingHighlights];
    }
    
    if (_editingHighlights)
    {
        [_sliderView setValue:tintValue.highlightsIntensity];
        [self setSelectedColor:tintValue.highlightsColor];
    }
    else
    {
        [_sliderView setValue:tintValue.shadowsIntensity];
        [self setSelectedColor:tintValue.shadowsColor];
    }
    
    [self updateSliderView];
}

- (void)setHighlightsColors:(bool)highlightsColors
{
    NSArray *colors = nil;
    if (highlightsColors)
        colors = [self highlightsColors];
    else
        colors = [self shadowsColors];
    
    NSInteger i = 0;
    for (TGPhotoEditorTintSwatchView *swatchView in _swatchViews)
    {
        swatchView.color = colors[i];
        i++;
    }
}

- (void)setSelectedColor:(UIColor *)color
{
    for (TGPhotoEditorTintSwatchView *swatchView in _swatchViews)
        swatchView.selected = [swatchView.color isEqual:color];
}

- (void)layoutSubviews
{
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    _sliderView.interfaceOrientation = orientation;
    
    if (CGRectIsEmpty(self.frame))
        return;
    
    if (!self.isLandscape)
    {
        CGFloat leftEdge = 30;
        CGFloat spacing = (self.frame.size.width - leftEdge * 2 - TGPhotoEditorTintSwatchSize * _swatchViews.count) / (_swatchViews.count - 1);
        NSInteger i = 0;
        
        for (UIView *view in _swatchViews)
        {
            view.frame = CGRectMake(leftEdge + (view.frame.size.width + spacing) * i, 38.0f, view.frame.size.width, view.frame.size.height);
            i++;
        }
        
        _sliderView.frame = CGRectMake(TGPhotoEditorSliderViewMargin, 70.0f, self.frame.size.width - 2 * TGPhotoEditorSliderViewMargin, 32);
        
        _shadowsButton.frame = CGRectMake(floor(self.frame.size.width / 4 - _shadowsButton.frame.size.width / 2 + 20), 10, _shadowsButton.frame.size.width, _shadowsButton.frame.size.height);
        
        _highlightsButton.frame = CGRectMake(floor(self.frame.size.width / 4 * 3 - _highlightsButton.frame.size.width / 2 - 20), 10, _highlightsButton.frame.size.width, _highlightsButton.frame.size.height);
    }
    else
    {
        CGFloat topEdge = 30;
        CGFloat spacing = (self.frame.size.height - 30 * 2 - TGPhotoEditorTintSwatchSize * _swatchViews.count) / (_swatchViews.count - 1);
        
        CGFloat swatchOffset = 0;
        
        if (orientation == UIInterfaceOrientationLandscapeLeft)
        {
            swatchOffset = self.frame.size.width - 38 - TGPhotoEditorTintSwatchSize;
            
            [UIView performWithoutAnimation:^
            {
                _shadowsButton.transform = CGAffineTransformMakeRotation(M_PI_2);
                _highlightsButton.transform = CGAffineTransformMakeRotation(M_PI_2);

                _shadowsButton.frame = CGRectMake(self.frame.size.width - _shadowsButton.frame.size.width - 10, floor(self.frame.size.height / 4 - _shadowsButton.frame.size.height / 2 + 20), _shadowsButton.frame.size.width, _shadowsButton.frame.size.height);
                
                _highlightsButton.frame = CGRectMake(self.frame.size.width - _highlightsButton.frame.size.width - 10, floor(self.frame.size.height / 4 * 3 - _highlightsButton.frame.size.height / 2 - 20), _highlightsButton.frame.size.width, _highlightsButton.frame.size.height);
            }];
            
            _sliderView.frame = CGRectMake(self.frame.size.width - 70.0f - 32.0f, TGPhotoEditorSliderViewMargin, 32, self.frame.size.height - 2 * TGPhotoEditorSliderViewMargin);
        }
        else if (orientation == UIInterfaceOrientationLandscapeRight)
        {
            swatchOffset = 38;
            
            [UIView performWithoutAnimation:^
            {
                _shadowsButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
                _highlightsButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
                
                _shadowsButton.frame = CGRectMake(10, floor(self.frame.size.height / 4 * 3 - _shadowsButton.frame.size.height / 2 - 20), _shadowsButton.frame.size.width, _shadowsButton.frame.size.height);
                
                _highlightsButton.frame = CGRectMake(10, floor(self.frame.size.height / 4 - _highlightsButton.frame.size.height / 2 + 20), _highlightsButton.frame.size.width, _highlightsButton.frame.size.height);
            }];
            
            _sliderView.frame = CGRectMake(70.0f, TGPhotoEditorSliderViewMargin, 32, self.frame.size.height - 2 * TGPhotoEditorSliderViewMargin);
        }
        
        [UIView performWithoutAnimation:^
        {
            NSInteger i = 0;
            for (UIView *view in _swatchViews)
            {
                view.frame = CGRectMake(swatchOffset, topEdge + (view.frame.size.height + spacing) * i, view.frame.size.width, view.frame.size.height);
                i++;
            }
        }];
    }
    
    _sliderView.hitTestEdgeInsets = UIEdgeInsetsMake(-_sliderView.frame.origin.x, -_sliderView.frame.origin.y, -(self.frame.size.height - _sliderView.frame.origin.y - _sliderView.frame.size.height), -_sliderView.frame.origin.x);
}

@end


@implementation TGPhotoEditorTintButtonsWrapperView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    if (result == self)
        return nil;
    
    return result;
}

@end
