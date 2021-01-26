#import "TGPhotoPaintSettingsView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorInterfaceAssets.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGPhotoPaintColorPicker.h"
#import "TGPhotoEditorTintSwatchView.h"

const CGFloat TGPhotoPaintSettingsPadPickerWidth = 360.0f;

@interface TGPhotoPaintSettingsView ()
{
    TGPhotoPaintColorPicker *_colorPicker;
    TGModernButton *_eyedropperButton;
    TGModernButton *_settingsButton;
    TGPhotoPaintSettingsViewIcon _icon;
    
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGPhotoPaintSettingsView

@dynamic swatch;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        _context = context;
        
        __weak TGPhotoPaintSettingsView *weakSelf = self;
        _colorPicker = [[TGPhotoPaintColorPicker alloc] init];
        _colorPicker.beganPicking = ^
        {
            __strong TGPhotoPaintSettingsView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.beganColorPicking != nil)
                strongSelf.beganColorPicking();
        };
        _colorPicker.valueChanged = ^
        {
            __strong TGPhotoPaintSettingsView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.changedColor != nil)
                strongSelf.changedColor(strongSelf, strongSelf->_colorPicker.swatch);
        };
        _colorPicker.finishedPicking = ^
        {
            __strong TGPhotoPaintSettingsView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.finishedColorPicking != nil)
                strongSelf.finishedColorPicking(strongSelf, strongSelf->_colorPicker.swatch);
        };
        [self addSubview:_colorPicker];
        
        _icon = TGPhotoPaintSettingsViewIconBrushPen;
        
        _eyedropperButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 44.0f, 44.0f)];
        _eyedropperButton.exclusiveTouch = true;
        [_eyedropperButton setImage:TGTintedImage([UIImage imageNamed:@"Editor/Eyedropper"], [UIColor whiteColor]) forState:UIControlStateNormal];
        [_eyedropperButton addTarget:self action:@selector(eyedropperButtonPressed) forControlEvents:UIControlEventTouchUpInside];
//        [self addSubview:_eyedropperButton];
        
        _settingsButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 44.0f, 44.0f)];
        _settingsButton.exclusiveTouch = true;
        [_settingsButton setImage:[self _imageForIcon:_icon highlighted:false] forState:UIControlStateNormal];
        [_settingsButton addTarget:self action:@selector(settingsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_settingsButton];
    }
    return self;
}

- (TGPaintSwatch *)swatch
{
    return _colorPicker.swatch;
}

- (void)setSwatch:(TGPaintSwatch *)swatch
{
    [_colorPicker setSwatch:swatch];
}

- (UIInterfaceOrientation)interfaceOrientation
{
    return _colorPicker.orientation;
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _colorPicker.orientation = interfaceOrientation;
}

- (void)eyedropperButtonPressed
{
    if (self.eyedropperPressed != nil)
        self.eyedropperPressed();
}

- (void)settingsButtonPressed
{
    if (self.settingsPressed != nil)
        self.settingsPressed();
}

- (UIButton *)settingsButton
{
    return _settingsButton;
}

- (void)setIcon:(TGPhotoPaintSettingsViewIcon)icon animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        [_settingsButton setImage:[self _imageForIcon:icon highlighted:false] forState:UIControlStateNormal];
    };
    
    if (icon == _icon)
        return;
    
    _icon = icon;
    
    if (animated)
    {
        UIView *transitionView = [_settingsButton snapshotViewAfterScreenUpdates:false];
        transitionView.frame = _settingsButton.frame;
        [_settingsButton.superview addSubview:transitionView];
        
        changeBlock();
        _settingsButton.alpha = 0.0f;
        _settingsButton.transform = CGAffineTransformMakeScale(0.2f, 0.2);
        
        [UIView animateWithDuration:0.2 animations:^
        {
            transitionView.alpha = 0.0f;
            transitionView.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
            
            _settingsButton.alpha = 1.0f;
            _settingsButton.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL finished)
        {
            [transitionView removeFromSuperview];
        }];
    }
    else
    {
        changeBlock();
    }
}

- (void)setHighlighted:(bool)__unused highlighted
{
    [_settingsButton setImage:[self _imageForIcon:_icon highlighted:false] forState:UIControlStateNormal];
}

- (UIImage *)_imageForIcon:(TGPhotoPaintSettingsViewIcon)icon highlighted:(bool)highlighted
{
    UIColor *color = highlighted ? [TGPhotoEditorInterfaceAssets accentColor] : [UIColor whiteColor];
    UIImage *iconImage = nil;
    switch (icon)
    {
        case TGPhotoPaintSettingsViewIconBrushPen:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/BrushSelectedPen"], color);
            break;
        case TGPhotoPaintSettingsViewIconBrushMarker:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/BrushSelectedMarker"], color);
            break;
        case TGPhotoPaintSettingsViewIconBrushNeon:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/BrushSelectedNeon"], color);
            break;
        case TGPhotoPaintSettingsViewIconBrushArrow:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/BrushSelectedArrow"], color);
            break;
        case TGPhotoPaintSettingsViewIconTextRegular:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/TextSelectedRegular"], color);
            break;
        case TGPhotoPaintSettingsViewIconTextOutlined:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/TextSelectedOutlined"], color);
            break;
        case TGPhotoPaintSettingsViewIconTextFramed:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/TextSelectedFramed"], color);
            break;
        case TGPhotoPaintSettingsViewIconMirror:
            iconImage = TGTintedImage([UIImage imageNamed:@"Editor/Flip"], color);
            break;
    }
    return iconImage;
}

+ (NSArray *)colors
{
    static dispatch_once_t onceToken;
    static NSArray *colors;
    dispatch_once(&onceToken, ^
    {
        colors = @
        [
            UIColorRGB(0xfd2a69),
            UIColorRGB(0xfe921d),
            UIColorRGB(0xfec926),
            UIColorRGB(0x67d442),
            UIColorRGB(0x1dabf0),
            UIColorRGB(0xc273d7),
            UIColorRGB(0xffffff),
            UIColorRGB(0x282828)
        ];
    });
    return colors;
}

- (void)layoutSubviews
{
    CGFloat leftInset = 23.0f;
    CGFloat rightInset = 66.0f;
    CGFloat colorPickerHeight = 10.0f;
    if (self.frame.size.width > self.frame.size.height)
    {
        if ([_context currentSizeClass] == UIUserInterfaceSizeClassRegular)
        {
            _colorPicker.frame = CGRectMake(ceil((self.frame.size.width - TGPhotoPaintSettingsPadPickerWidth) / 2.0f), ceil((self.frame.size.height - colorPickerHeight) / 2.0f), TGPhotoPaintSettingsPadPickerWidth, colorPickerHeight);
            _settingsButton.frame = CGRectMake(CGRectGetMaxX(_colorPicker.frame) + 11.0f, floor((self.frame.size.height - _settingsButton.frame.size.height) / 2.0f) + 1.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
        }
        else
        {
            _colorPicker.frame = CGRectMake(leftInset, ceil((self.frame.size.height - colorPickerHeight) / 2.0f), self.frame.size.width - leftInset - rightInset, colorPickerHeight);
            _eyedropperButton.frame = CGRectMake(10.0f, floor((self.frame.size.height - _eyedropperButton.frame.size.height) / 2.0f) + 1.0f, _eyedropperButton.frame.size.width, _eyedropperButton.frame.size.height);
            _settingsButton.frame = CGRectMake(self.frame.size.width - _settingsButton.frame.size.width - 10.0f, floor((self.frame.size.height - _settingsButton.frame.size.height) / 2.0f) + 1.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
        }
    }
    else
    {
        _colorPicker.frame = CGRectMake(ceil((self.frame.size.width - colorPickerHeight) / 2.0f), rightInset, colorPickerHeight, self.frame.size.height - leftInset - rightInset);
        _eyedropperButton.frame = CGRectMake(floor((self.frame.size.width - _eyedropperButton.frame.size.width) / 2.0f), self.frame.size.height -  _eyedropperButton.frame.size.height - 10.0, _eyedropperButton.frame.size.width, _eyedropperButton.frame.size.height);
        _settingsButton.frame = CGRectMake(floor((self.frame.size.width - _settingsButton.frame.size.width) / 2.0f), 10.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
    }
}

@end
