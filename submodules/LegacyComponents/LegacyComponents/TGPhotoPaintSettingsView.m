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
        
        _icon = TGPhotoPaintSettingsViewIconBrush;
        
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
    UIImage *iconImage = nil;
    switch (icon)
    {
        case TGPhotoPaintSettingsViewIconBrush:
            iconImage = TGComponentsImageNamed(@"PaintBrushIcon");
            break;
            
        case TGPhotoPaintSettingsViewIconText:
            iconImage = TGComponentsImageNamed(@"PaintTextSettingsIcon");
            break;
            
        case TGPhotoPaintSettingsViewIconMirror:
            iconImage = TGComponentsImageNamed(@"PaintMirrorIcon");
            break;
    }
    
    if (highlighted)
        iconImage = TGTintedImage(iconImage, [TGPhotoEditorInterfaceAssets accentColor]);
    
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
    if (self.frame.size.width > self.frame.size.height)
    {
        if ([_context currentSizeClass] == UIUserInterfaceSizeClassRegular)
        {
            _colorPicker.frame = CGRectMake(ceil((self.frame.size.width - TGPhotoPaintSettingsPadPickerWidth) / 2.0f), ceil((self.frame.size.height - 18.0f) / 2.0f), TGPhotoPaintSettingsPadPickerWidth, 18.0f);
            _settingsButton.frame = CGRectMake(CGRectGetMaxX(_colorPicker.frame) + 11.0f, floor((self.frame.size.height - _settingsButton.frame.size.height) / 2.0f) + 1.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
        }
        else
        {
            _colorPicker.frame = CGRectMake(23.0f, ceil((self.frame.size.height - 18.0f) / 2.0f), self.frame.size.width - 23.0f - 66.0f, 18.0f);
            _settingsButton.frame = CGRectMake(self.frame.size.width - _settingsButton.frame.size.width - 10.0f, floor((self.frame.size.height - _settingsButton.frame.size.height) / 2.0f) + 1.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
        }
    }
    else
    {
        _colorPicker.frame = CGRectMake(ceil((self.frame.size.width - 18.0f) / 2.0f), 66.0f, 18.0f, self.frame.size.height - 23.0f - 66.0f);
        _settingsButton.frame = CGRectMake(floor((self.frame.size.width - _settingsButton.frame.size.width) / 2.0f), 10.0f, _settingsButton.frame.size.width, _settingsButton.frame.size.height);
    }
}

+ (UIImage *)landscapeLeftBackgroundImage
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupLandscapeLeftBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
    });
    return image;
}

+ (UIImage *)landscapeRightBackgroundImage
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupLandscapeRightBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
    });
    return image;
}

+ (UIImage *)portraitBackgroundImage
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupPortraitBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
    });
    return image;
}

@end
