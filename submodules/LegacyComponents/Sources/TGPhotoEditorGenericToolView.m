#import "TGPhotoEditorGenericToolView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import "TGPhotoEditorInterfaceAssets.h"

#import "TGPhotoEditorSliderView.h"

@interface TGPhotoEditorGenericToolView ()
{
    TGPhotoEditorSliderView *_sliderView;
    UILabel *_titleLabel;
    UILabel *_valueLabel;
    
    id<PGPhotoEditorItem> _editorItem;
    bool _showingValue;
    
    bool _explicit;
}

@end

@implementation TGPhotoEditorGenericToolView

@synthesize valueChanged = _valueChanged;
@synthesize value = _value;
@synthesize interactionBegan = _interactionBegan;
@synthesize interactionEnded = _interactionEnded;
@synthesize actualAreaSize;
@synthesize isLandscape;
@synthesize toolbarLandscapeSize;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem
{
    return [self initWithEditorItem:editorItem explicit:false nameWidth:0.0f];
}

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem explicit:(bool)explicit nameWidth:(CGFloat)__unused nameWidth
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _editorItem = editorItem;
        _explicit = explicit;
        
        _sliderView = [[TGPhotoEditorSliderView alloc] initWithFrame:CGRectZero];
        _sliderView.enablePanHandling = true;
        if (editorItem.segmented)
            _sliderView.positionsCount = (NSInteger)editorItem.maximumValue + 1;
        _sliderView.minimumValue = editorItem.minimumValue;
        _sliderView.maximumValue = editorItem.maximumValue;
        _sliderView.startValue = 0;
        _sliderView.lineSize = 2.0f;
        _sliderView.trackCornerRadius = 1.0f;
        if (editorItem.value != nil && [editorItem.value isKindOfClass:[NSNumber class]])
            _sliderView.value = [(NSNumber *)editorItem.value integerValue];
        [_sliderView addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        if (_explicit)
            _sliderView.backgroundColor = [UIColor clearColor];
        
        __weak TGPhotoEditorGenericToolView *weakSelf = self;
        _sliderView.reset = ^
        {
            __strong TGPhotoEditorGenericToolView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            CGFloat value = strongSelf->_sliderView.startValue;
            [strongSelf->_sliderView setValue:value];
            if (strongSelf.valueChanged != nil)
                strongSelf.valueChanged(@(value), true);
            
            strongSelf->_valueLabel.text = nil;
            [strongSelf updateColor];
        };
        [self addSubview:_sliderView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 160, 20)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
        _titleLabel.text = editorItem.title;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [TGPhotoEditorInterfaceAssets editorItemTitleColor];
        _titleLabel.userInteractionEnabled = false;
        [self addSubview:_titleLabel];
        
        //if (explicit)
        //{
            _titleLabel.frame = CGRectMake(0.0f, 4.0f, 160.0f, 20.0f);
            _titleLabel.textAlignment = NSTextAlignmentLeft;
            //_titleLabel.text = editorItem.title;
            
            _titleLabel.textColor = editorItem.stringValue != nil ? [TGPhotoEditorInterfaceAssets editorActiveItemTitleColor] : [TGPhotoEditorInterfaceAssets editorItemTitleColor];
            
            _valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width - 100.0f, 8.0f, 100.0f, 20.0f)];
            _valueLabel.backgroundColor = _titleLabel.backgroundColor;
            _valueLabel.font = _titleLabel.font;
            _valueLabel.text = [editorItem stringValue];
            _valueLabel.textAlignment = NSTextAlignmentRight;
            _valueLabel.textColor = [TGPhotoEditorInterfaceAssets accentColor];
            _valueLabel.userInteractionEnabled = false;
            [self addSubview:_valueLabel];
        //}
    }
    return self;
}

- (void)setInteractionBegan:(void (^)(void))interactionBegan
{
    _interactionBegan = [interactionBegan copy];
    
    __weak TGPhotoEditorGenericToolView *weakSelf = self;
    _sliderView.interactionBegan = ^
    {
        __strong TGPhotoEditorGenericToolView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (strongSelf->_explicit)
                [strongSelf setLabelsHidden:true animated:false];
            //else
            //    [strongSelf showValue];
            
            if (strongSelf.interactionBegan != nil)
                strongSelf.interactionBegan();
        }
    };
}

- (void)setInteractionEnded:(void (^)(void))interactionEnded
{
    _interactionEnded = [interactionEnded copy];

    __weak TGPhotoEditorGenericToolView *weakSelf = self;
    _sliderView.interactionEnded = ^
    {
        __strong TGPhotoEditorGenericToolView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (strongSelf->_explicit)
                [strongSelf setLabelsHidden:false animated:true];
            //else
            //    [strongSelf scheduleHideValue];
            
            if (strongSelf.interactionEnded != nil)
                strongSelf.interactionEnded();
        }
    };
}

- (bool)isTracking
{
    return _sliderView.isTracking;
}

- (void)sliderValueChanged:(TGPhotoEditorSliderView *)sender
{
    NSInteger value = (NSInteger)(CGFloor(sender.value));
    if (self.valueChanged != nil)
        self.valueChanged(@(value), false);
    
    _valueLabel.text = [_editorItem stringValue];
        
    //if (_showingValue)
    //    _titleLabel.text = [self _value];
    //else
    [self updateColor];
}

- (NSString *)_value
{
    NSString *value = [_editorItem stringValue];
    if (value.length == 0)
        value = @"0.00";
    
    return value;
}

- (void)showValue
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    _showingValue = true;
    
    _titleLabel.textColor = [TGPhotoEditorInterfaceAssets accentColor];
    _titleLabel.text = [self _value];
}

- (void)scheduleHideValue
{
    if (_editorItem.segmented)
        return;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(hideValue) withObject:nil afterDelay:1.0];
}

- (void)hideValue
{
    _showingValue = false;
    
    [UIView transitionWithView:_titleLabel duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
    {
        [self updateColor];
        _titleLabel.text = _explicit ? _editorItem.title : [_editorItem.title uppercaseString];
    } completion:nil];
}

- (void)setLabelsHidden:(bool)hidden animated:(bool)animated
{
    void (^block)(void) = ^
    {
        _titleLabel.alpha = hidden ? 0.0f : 1.0f;
        _valueLabel.alpha = _titleLabel.alpha;
    };
    
    _sliderView.bordered = hidden;
    
    if (animated)
    {
        [UIView animateWithDuration:0.15 animations:block];
    }
    else
    {
        [_titleLabel.layer removeAllAnimations];
        [_valueLabel.layer removeAllAnimations];
        block();
    }
}

- (void)updateColor
{
    _titleLabel.textColor = !_explicit || _editorItem.stringValue != nil ? [TGPhotoEditorInterfaceAssets editorActiveItemTitleColor] : [TGPhotoEditorInterfaceAssets editorItemTitleColor];
}

- (void)setValue:(id)value
{
    _value = value;
    [_sliderView setValue:[value integerValue]];
}

- (void)layoutSubviews
{
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    _sliderView.interfaceOrientation = orientation;
    
    if (CGRectIsEmpty(self.frame))
        return;
    
    CGFloat margin = TGPhotoEditorSliderViewMargin + 7.0f;
    
    if (_explicit)
    {
        _titleLabel.frame = CGRectMake(TGPhotoEditorSliderViewMargin + 6.0f, 4.0f, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
        _sliderView.frame = CGRectMake(margin, 19, self.frame.size.width - margin * 2.0f, 32);
        _valueLabel.frame = CGRectMake(self.frame.size.width - TGPhotoEditorSliderViewMargin - _valueLabel.frame.size.width - 6.0f, 4.0f, 100.0f, 20.0f);
    }
    else
    {
        if (!self.isLandscape)
        {
            _titleLabel.frame = CGRectMake(TGPhotoEditorSliderViewMargin + 6.0f, 4.0f, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            _sliderView.frame = CGRectMake(margin, 19, self.frame.size.width - margin * 2.0f, 32);
            _valueLabel.frame = CGRectMake(self.frame.size.width - TGPhotoEditorSliderViewMargin - _valueLabel.frame.size.width - 6.0f, 4.0f, 100.0f, 20.0f);
        }
        else
        {
            _sliderView.frame = CGRectMake((self.frame.size.width - 32) / 2, margin, 32, self.frame.size.height - 2 * margin);
            
            [UIView performWithoutAnimation:^
            {
                if (orientation == UIInterfaceOrientationLandscapeLeft)
                {
                    _titleLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
                    _valueLabel.transform = _titleLabel.transform;
                    
                    _titleLabel.frame = CGRectMake(self.frame.size.width - _titleLabel.frame.size.width - 4.0f, TGPhotoEditorSliderViewMargin + 6.0f, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
                    _valueLabel.frame = CGRectMake(self.frame.size.width - _valueLabel.frame.size.width - 4.0f, self.frame.size.height - TGPhotoEditorSliderViewMargin - 6.0f - _valueLabel.frame.size.height, _valueLabel.frame.size.width, _valueLabel.frame.size.height);
                }
                else if (orientation == UIInterfaceOrientationLandscapeRight)
                {
                    _titleLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
                    _valueLabel.transform = _titleLabel.transform;
                    
                    _titleLabel.frame = CGRectMake(4.0f, self.frame.size.height - TGPhotoEditorSliderViewMargin - 6.0f - _titleLabel.frame.size.height, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
                    _valueLabel.frame = CGRectMake(4.0f, TGPhotoEditorSliderViewMargin + 6.0f, _valueLabel.frame.size.width, _valueLabel.frame.size.height);
                }
            }];
        }
    }
    
    _sliderView.hitTestEdgeInsets = UIEdgeInsetsMake(-_sliderView.frame.origin.x, -_sliderView.frame.origin.y, -(self.frame.size.height - _sliderView.frame.origin.y - _sliderView.frame.size.height), -_sliderView.frame.origin.x);
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
    return true;
}

@end
