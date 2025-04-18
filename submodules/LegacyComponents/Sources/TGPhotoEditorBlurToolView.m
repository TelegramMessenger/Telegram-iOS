#import "TGPhotoEditorBlurToolView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import "TGPhotoEditorBlurTypeButton.h"
#import "TGPhotoEditorSliderView.h"

#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "PGBlurTool.h"

@interface TGPhotoEditorBlurToolView ()
{
    PGBlurToolType _currentType;
    
    UIView *_buttonsWrapper;
    UILabel *_titleLabel;
    TGPhotoEditorBlurTypeButton *_offButton;
    TGPhotoEditorBlurTypeButton *_radialButton;
    TGPhotoEditorBlurTypeButton *_linearButton;
    TGPhotoEditorBlurTypeButton *_portraitButton;
    
    TGPhotoEditorSliderView *_sliderView;
    
    bool _editingIntensity;
    CGFloat _startIntensity;
}

@property (nonatomic, weak) PGBlurTool *blurTool;

@end

@implementation TGPhotoEditorBlurToolView

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
        _buttonsWrapper = [[UIView alloc] initWithFrame:self.bounds];
        _buttonsWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_buttonsWrapper];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 160, 20)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [TGPhotoEditorInterfaceAssets editorItemTitleFont];
        _titleLabel.text = TGLocalized(@"PhotoEditor.TiltShift");
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [TGPhotoEditorInterfaceAssets editorItemTitleColor];
        _titleLabel.userInteractionEnabled = false;
        [self addSubview:_titleLabel];
               
        _offButton = [[TGPhotoEditorBlurTypeButton alloc] initWithFrame:CGRectZero];
        _offButton.tag = PGBlurToolTypeNone;
        [_offButton addTarget:self action:@selector(blurButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_offButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/BlurOff"], [UIColor whiteColor])];
        [_offButton setTitle:TGLocalized(@"PhotoEditor.BlurToolOff")];
        [_buttonsWrapper addSubview:_offButton];
        
        _radialButton = [[TGPhotoEditorBlurTypeButton alloc] initWithFrame:CGRectZero];
        _radialButton.tag = PGBlurToolTypeRadial;
        [_radialButton addTarget:self action:@selector(blurButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_radialButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/BlurRadial"], [UIColor whiteColor])];
        [_radialButton setTitle:TGLocalized(@"PhotoEditor.BlurToolRadial")];
        [_buttonsWrapper addSubview:_radialButton];

        _linearButton = [[TGPhotoEditorBlurTypeButton alloc] initWithFrame:CGRectZero];
        _linearButton.tag = PGBlurToolTypeLinear;
        [_linearButton addTarget:self action:@selector(blurButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_linearButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/BlurLinear"], [UIColor whiteColor])];
        [_linearButton setTitle:TGLocalized(@"PhotoEditor.BlurToolLinear")];
        [_buttonsWrapper addSubview:_linearButton];
        
        _portraitButton = [[TGPhotoEditorBlurTypeButton alloc] initWithFrame:CGRectZero];
        _portraitButton.tag = PGBlurToolTypePortrait;
        [_portraitButton addTarget:self action:@selector(blurButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_portraitButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/BlurPortrait"], [UIColor whiteColor])];
        [_portraitButton setTitle:TGLocalized(@"PhotoEditor.BlurToolPortrait")];
//        [_buttonsWrapper addSubview:_portraitButton];
        
        _sliderView = [[TGPhotoEditorSliderView alloc] initWithFrame:CGRectZero];
        _sliderView.alpha = 0.0f;
        _sliderView.hidden = true;
        _sliderView.layer.rasterizationScale = TGScreenScaling();
        _sliderView.minimumValue = editorItem.minimumValue;
        _sliderView.maximumValue = editorItem.maximumValue;
        _sliderView.startValue = 0;
        if (editorItem.value != nil && [editorItem.value isKindOfClass:[NSNumber class]])
            _sliderView.value = [(NSNumber *)editorItem.value integerValue];
        [_sliderView addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_sliderView];
        
        if ([editorItem isKindOfClass:[PGBlurTool class]])
        {
            PGBlurTool *blurTool = (PGBlurTool *)editorItem;
            self.blurTool = blurTool;
            [self setValue:editorItem.value];
            
            if (blurTool.value != nil)
            {
                PGBlurToolValue *value = blurTool.value;
                _sliderView.value = value.intensity;
            }
            else
            {
                _sliderView.value = 0.0f;
            }
        }
    }
    return self;
}

- (bool)buttonPressed:(bool)__unused cancelButton
{
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
    dispatch_async(dispatch_get_main_queue(), ^
    {
        PGBlurToolValue *value = [(PGBlurToolValue *)self.value copy];
        value.intensity = (NSInteger)(CGFloor(sender.value));

        _value = value;
        
        if (self.valueChanged != nil)
            self.valueChanged(value, false);
    });
}

- (void)setSelectedBlurType:(PGBlurToolType)blurType update:(bool)update
{
    for (TGPhotoEditorBlurTypeButton *button in _buttonsWrapper.subviews)
        button.selected = (button.tag == blurType);
    
    if (blurType == _currentType)
        return;
    
    _currentType = blurType;
    
    PGBlurToolValue *value = [(PGBlurToolValue *)self.value copy];
    value.type = _currentType;
    
    if (update && self.valueChanged != nil)
        self.valueChanged(value, true);
}

- (void)blurButtonPressed:(TGPhotoEditorBlurTypeButton *)sender
{
//    if (sender.tag != 0 && sender.tag == _currentType)
//    {
//        _editingIntensity = true;
//        _startIntensity = [(PGBlurToolValue *)self.value intensity];
//        
//        PGBlurToolValue *value = [(PGBlurToolValue *)self.value copy];
//        value.editingIntensity = true;
//        
//        _value = value;
//        
//        if (self.valueChanged != nil)
//            self.valueChanged(value);
//        
//        [self setIntensitySliderHidden:false animated:true];
//    }
//    else
//    {
        [self setSelectedBlurType:(PGBlurToolType)sender.tag update:true];
//    }
}

- (void)setValue:(id)value
{
    if (![value isKindOfClass:[PGBlurToolValue class]])
    {
        [self setSelectedBlurType:PGBlurToolTypeNone update:false];
        return;
    }
    
    _value = value;
    
    PGBlurToolValue *blurValue = (PGBlurToolValue *)value;
    [self setSelectedBlurType:blurValue.type update:false];
    [_sliderView setValue:blurValue.intensity];
    
    if (blurValue.editingIntensity != _editingIntensity)
    {
        _editingIntensity = blurValue.editingIntensity;

        [self setIntensitySliderHidden:!_editingIntensity animated:false];
    }
}

- (void)setIntensitySliderHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        CGFloat buttonsDelay = hidden ? 0.07f : 0.0f;
        CGFloat sliderDelay = hidden ? 0.0f : 0.07f;
        
        CGFloat buttonsDuration = hidden ? 0.23f : 0.1f;
        CGFloat sliderDuration = hidden ? 0.1f : 0.23f;
        
        _buttonsWrapper.hidden = false;
        [UIView animateWithDuration:buttonsDuration delay:buttonsDelay options:UIViewAnimationOptionCurveLinear animations:^
        {
            _buttonsWrapper.alpha = hidden ? 1.0f : 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _buttonsWrapper.hidden = !hidden;
        }];
        
        _sliderView.hidden = false;
        _sliderView.layer.shouldRasterize = true;
        [UIView animateWithDuration:sliderDuration delay:sliderDelay options:UIViewAnimationOptionCurveLinear animations:^
        {
            _sliderView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            _sliderView.layer.shouldRasterize = false;
            if (finished)
                _sliderView.hidden = hidden;
        }];
    }
    else
    {
        _sliderView.hidden = hidden;
        _sliderView.alpha = hidden ? 0.0f : 1.0f;
        
        _buttonsWrapper.hidden = !hidden;
        _buttonsWrapper.alpha = hidden ? 1.0f : 0.0f;
    }
}

- (void)layoutSubviews
{
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    _sliderView.interfaceOrientation = orientation;
    
    if (CGRectIsEmpty(self.frame))
        return;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        _titleLabel.frame = CGRectMake((self.frame.size.width - _titleLabel.frame.size.width) / 2, 10, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
        
        _offButton.frame = CGRectMake(CGFloor(self.frame.size.width / 4 - 50), self.frame.size.height / 2 - 42, 100, 100);
        _radialButton.frame = CGRectMake(self.frame.size.width / 2 - 50, self.frame.size.height / 2 - 42, 100, 100);
        _linearButton.frame = CGRectMake(CGCeil(self.frame.size.width / 2 + self.frame.size.width / 4 - 50), self.frame.size.height / 2 - 42, 100, 100);

        _sliderView.frame = CGRectMake(TGPhotoEditorSliderViewMargin, (self.frame.size.height - 32) / 2, self.frame.size.width - 2 * TGPhotoEditorSliderViewMargin, 32);
    }
    else
    {
        _offButton.frame = CGRectMake(self.frame.size.width / 2 - 50, self.frame.size.height / 2 + self.frame.size.height / 4 - 50, 100, 100);
        _radialButton.frame = CGRectMake(self.frame.size.width / 2 - 50, self.frame.size.height / 2 - 50, 100, 100);
        _linearButton.frame = CGRectMake(self.frame.size.width / 2 - 50, self.frame.size.height / 4 - 50, 100, 100);

        _sliderView.frame = CGRectMake((self.frame.size.width - 32) / 2, TGPhotoEditorSliderViewMargin, 32, self.frame.size.height - 2 * TGPhotoEditorSliderViewMargin);
        
        CGFloat titleOffset = 10;
        if (MAX(_offButton.title.length, MAX(_radialButton.title.length, _linearButton.title.length)) > 7) {
            titleOffset = -2;
        }
        
        [UIView performWithoutAnimation:^
        {
            if (orientation == UIInterfaceOrientationLandscapeLeft)
            {
                _titleLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
                _titleLabel.frame = CGRectMake(self.frame.size.width - _titleLabel.frame.size.width - titleOffset, (self.frame.size.height - _titleLabel.frame.size.height) / 2, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            }
            else if (orientation == UIInterfaceOrientationLandscapeRight)
            {
                _titleLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
                _titleLabel.frame = CGRectMake(titleOffset, (self.frame.size.height - _titleLabel.frame.size.height) / 2, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            }
        }];
    }
    
    _sliderView.hitTestEdgeInsets = UIEdgeInsetsMake(-_sliderView.frame.origin.x,
                                                     -_sliderView.frame.origin.y,
                                                     -(self.frame.size.height - _sliderView.frame.origin.y - _sliderView.frame.size.height),
                                                     -_sliderView.frame.origin.x);
}

@end
