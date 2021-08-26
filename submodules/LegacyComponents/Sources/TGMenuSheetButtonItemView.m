#import "TGMenuSheetButtonItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGColor.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGModernButton.h>

#import "TGMenuSheetController.h"

const CGFloat TGMenuSheetButtonItemViewHeight = 57.0f;

@interface TGMenuSheetButtonItemView () //<UIPointerInteractionDelegate>
{
    bool _dark;
    bool _requiresDivider;
    UIView *_customDivider;
    CGFloat _fontSize;
    
    TGMenuSheetPallete *_pallete;
    UIView *_highlightView;
}
@end

@implementation TGMenuSheetButtonItemView

- (instancetype)initWithTitle:(NSString *)title type:(TGMenuSheetButtonType)type fontSize:(CGFloat)fontSize action:(void (^)(void))action
{
    self = [super initWithType:(type == TGMenuSheetButtonTypeCancel) ? TGMenuSheetItemTypeFooter : TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        self.action = action;
        _fontSize = fontSize;
        _buttonType = type;
        _requiresDivider = true;
        
        _highlightView = [[UIView alloc] init];
        _highlightView.alpha = 0.0f;
        _highlightView.userInteractionEnabled = false;
        [self addSubview:_highlightView];
        
        _button = [[TGModernButton alloc] init];
        _button.exclusiveTouch = true;
        _button.highlightBackgroundColor = UIColorRGB(0xebebeb);
        [self _updateForType:type];
        _button.titleLabel.adjustsFontSizeToFitWidth = true;
        _button.titleLabel.minimumScaleFactor = 0.7f;
        [_button setTitle:title forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];
        
        __weak TGMenuSheetButtonItemView *weakSelf = self;
        _button.highlitedChanged = ^(bool highlighted)
        {
            __strong TGMenuSheetButtonItemView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.highlightUpdateBlock != nil)
                strongSelf.highlightUpdateBlock(highlighted);
        };
        
//        if (iosMajorVersion() > 13 || (iosMajorVersion() == 13 && iosMinorVersion() >= 4)) {
//            UIPointerInteraction *pointerInteraction = [[UIPointerInteraction alloc] initWithDelegate:self];
//            [self addInteraction:pointerInteraction];
//        }
    }
    return self;
}

//- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
//    if (interaction.view != nil) {
//        UITargetedPreview *targetedPreview = [[UITargetedPreview alloc] initWithView:interaction.view];
//        UIPointerHoverEffect *effect = [UIPointerHoverEffect effectWithPreview:targetedPreview];
//        effect.preferredTintMode = UIPointerEffectTintModeNone;
//        effect.prefersScaledContent = false;
//        return [UIPointerStyle styleWithEffect:effect shape:nil];
//    }
//    return nil;
//}
//
//- (void)pointerInteraction:(UIPointerInteraction *)interaction willEnterRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator {
//    [animator addAnimations:^{
//        _highlightView.alpha = 0.75f;
//    }];
//}
//
//- (void)pointerInteraction:(UIPointerInteraction *)interaction willExitRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator {
//    [animator addAnimations:^{
//        _highlightView.alpha = 0.0f;
//    }];
//}

- (void)setDark
{
    _dark = true;
    _button.highlightBackgroundColor = nil;
    [self _updateForType:_buttonType];
    
    if (@available(iOS 11.0, *)) {
        self.accessibilityIgnoresInvertColors = true;
    }
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _pallete = pallete;
    _button.highlightBackgroundColor = pallete.selectionColor;
    _highlightView.backgroundColor = pallete.selectionColor;
    _customDivider.backgroundColor = _pallete.separatorColor;
    [self _updateForType:_buttonType];
}

- (void)buttonPressed
{
    if (self.action != nil)
        self.action();
}

- (void)buttonLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        if (self.longPressAction != nil)
            self.longPressAction();
    }
}

- (void)setLongPressAction:(void (^)(void))longPressAction
{
    _longPressAction = [longPressAction copy];
    if (_longPressAction != nil)
    {
        UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(buttonLongPressed:)];
        gestureRecognizer.minimumPressDuration = 0.4;
        [_button addGestureRecognizer:gestureRecognizer];
    }
}

- (NSString *)title
{
    return [_button titleForState:UIControlStateNormal];
}

- (void)setTitle:(NSString *)title
{
    [_button setTitle:title forState:UIControlStateNormal];
}

- (void)setButtonType:(TGMenuSheetButtonType)buttonType
{
    _buttonType = buttonType;
    [self _updateForType:buttonType];
}

- (void)_updateForType:(TGMenuSheetButtonType)type
{
    _button.titleLabel.font = (type == TGMenuSheetButtonTypeCancel || type == TGMenuSheetButtonTypeSend) ? TGMediumSystemFontOfSize(_fontSize) : TGSystemFontOfSize(_fontSize);
    UIColor *accentColor = _dark ? UIColorRGB(0x4fbcff) : TGAccentColor();
    if (_pallete != nil)
        accentColor = _pallete.accentColor;
    UIColor *destructiveColor = TGDestructiveAccentColor();
    if (_pallete != nil)
        destructiveColor = _pallete.destructiveColor;
    [_button setTitleColor:(type == TGMenuSheetButtonTypeDestructive) ? destructiveColor : accentColor];
}

- (void)setCollapsed:(bool)collapsed animated:(bool)animated
{
    _collapsed = collapsed;
    [self _updateHeightAnimated:animated];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    _button.alpha = _collapsed ? 0.0f : 1.0f;
    return _collapsed ? 0.0f : TGMenuSheetButtonItemViewHeight;
}

- (void)setThickDivider:(bool)thickDivider
{
    _thickDivider = thickDivider;
    
    if (thickDivider && _customDivider == nil)
    {
        _customDivider = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.bounds.size.width, TGScreenPixel)];
        _customDivider.backgroundColor = _pallete.separatorColor;
        [self addSubview:_customDivider];
    }
    else if (!thickDivider)
    {
        [_customDivider removeFromSuperview];
        _customDivider = nil;
    }
}

- (bool)requiresDivider
{
    return _requiresDivider;
}

- (void)setRequiresDivider:(bool)requiresDivider
{
    _requiresDivider = requiresDivider;
}

- (void)layoutSubviews
{
    _button.frame = self.bounds;
    _highlightView.frame = self.bounds;
    _customDivider.frame = CGRectMake(0.0f, 0.0f, self.bounds.size.width, TGScreenPixel);
}

@end
