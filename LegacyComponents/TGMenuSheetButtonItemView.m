#import "TGMenuSheetButtonItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGColor.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGModernButton.h>

const CGFloat TGMenuSheetButtonItemViewHeight = 57.0f;

@interface TGMenuSheetButtonItemView ()
{
    bool _dark;
    bool _requiresDivider;
}
@end

@implementation TGMenuSheetButtonItemView

- (instancetype)initWithTitle:(NSString *)title type:(TGMenuSheetButtonType)type action:(void (^)(void))action
{
    self = [super initWithType:(type == TGMenuSheetButtonTypeCancel) ? TGMenuSheetItemTypeFooter : TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        self.action = action;
        _buttonType = type;
        _requiresDivider = true;
        
        _button = [[TGModernButton alloc] init];
        _button.exclusiveTouch = true;
        _button.highlightBackgroundColor = UIColorRGB(0xebebeb);
        [self _updateForType:type];
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
    }
    return self;
}

- (void)setDark
{
    _dark = true;
    _button.highlightBackgroundColor = nil;
    [self _updateForType:_buttonType];
    
    if (iosMajorVersion() >= 11)
        self.accessibilityIgnoresInvertColors = true;
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
    _button.titleLabel.font = (type == TGMenuSheetButtonTypeCancel || type == TGMenuSheetButtonTypeSend) ? TGMediumSystemFontOfSize(20) : TGSystemFontOfSize(20);
    UIColor *accentColor = _dark ? UIColorRGB(0x4fbcff) : TGAccentColor();
    [_button setTitleColor:(type == TGMenuSheetButtonTypeDestructive) ? TGDestructiveAccentColor() : accentColor];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    return TGMenuSheetButtonItemViewHeight;
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
}

@end
