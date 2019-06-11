#import "TGPhotoEditorButton.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGModernButton.h>
#import "TGPhotoEditorInterfaceAssets.h"

@interface TGPhotoEditorButton ()
{
    TGModernButton *_button;
    UIImageView *_selectionView;
    
    UIImage *_activeIconImage;
}
@end

@implementation TGPhotoEditorButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static UIImage *selectionBackground = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(frame.size.width, frame.size.height), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets editorButtonSelectionBackgroundColor].CGColor);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, frame.size.width, frame.size.height) cornerRadius:8];
            [path fill];
            
            selectionBackground = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(frame.size.height / 4.0f, frame.size.height / 4.0f, frame.size.height / 4.0f, frame.size.height / 4.0f)];
            UIGraphicsEndImageContext();
        });

        self.hitTestEdgeInsets = UIEdgeInsetsMake(-16, -16, -16, -16);
        
        _selectionView = [[UIImageView alloc] initWithFrame:self.bounds];
        _selectionView.hidden = true;
        _selectionView.image = selectionBackground;
        [self addSubview:_selectionView];
        
        _button = [[TGModernButton alloc] initWithFrame:self.bounds];
        _button.hitTestEdgeInsets = self.hitTestEdgeInsets;
        _button.exclusiveTouch = true;
        [_button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];        
        [self addSubview:_button];
    }
    return self;
}

- (void)buttonPressed
{
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)setIconImage:(UIImage *)image
{
    [self setIconImage:image activeIconImage:nil];
}

- (void)setIconImage:(UIImage *)image activeIconImage:(UIImage *)activeIconImage
{
    _iconImage = image;
    _activeIconImage = activeIconImage;
    [self updateButton];
    
    UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
    CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets toolbarSelectedIconColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
    
    UIImage *selectedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [_button setImage:selectedImage forState:UIControlStateSelected];
    [_button setImage:selectedImage forState:UIControlStateSelected | UIControlStateHighlighted];
}

- (void)setActive:(bool)active
{
    _active = active;
    [self updateButton];
}

- (void)setDisabled:(bool)disabled
{
    _disabled = disabled;
    [self updateButton];
}

- (void)updateButton
{
    _button.alpha = _disabled ? 0.2f : 1.0f;
    _button.userInteractionEnabled = !_disabled;
    
    UIImage *image = _iconImage;
    if (!_disabled)
        image = _active ? [self _activeIconImage] : _iconImage;
    
    [_button setImage:image forState:UIControlStateNormal];
}

- (UIImage *)_activeIconImage
{
    if (_activeIconImage == nil)
    {
        UIGraphicsBeginImageContextWithOptions(_iconImage.size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [_iconImage drawInRect:CGRectMake(0, 0, _iconImage.size.width, _iconImage.size.height)];
        CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
        CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets toolbarAppliedIconColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, _iconImage.size.width, _iconImage.size.height));
        
        _activeIconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    return _activeIconImage;
}

- (void)setSelected:(BOOL)selected
{
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected];
    if (self.dontHighlightOnSelection)
        return;
    
    _button.selected = self.selected;
    _button.modernHighlight = !self.selected;
    
    if (animated)
    {
        if (selected) {
            _selectionView.hidden = false;
            _selectionView.alpha = 0.0f;
            [UIView animateWithDuration:0.15f
                             animations:^
            {
                _selectionView.alpha = 1.0f;
            } completion:nil];
        }
        else
        {
            _selectionView.hidden = true;
        }
    }
    else
    {
        _selectionView.hidden = !self.selected;
    }
}

@end
