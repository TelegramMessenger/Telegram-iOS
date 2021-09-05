#import "TGMediaPickerToolbarView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGColor.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGMediaAssetsController.h"

const CGFloat TGMediaPickerToolbarHeight = 44.0f;

@interface TGMediaPickerToolbarView ()
{
    UIView *_separatorView;
    TGModernButton *_leftButton;
    TGModernButton *_rightButton;
    TGModernButton *_centerButton;
    UIImageView *_countBadge;
    UILabel *_countLabel;
}
@end

@implementation TGMediaPickerToolbarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = UIColorRGBA(0xf7f7f7, 1.0f);
        
        _separatorView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, TGScreenPixel)];
        _separatorView.backgroundColor = UIColorRGB(0xb2b2b2);
        _separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_separatorView];
        
        _leftButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
        _leftButton.exclusiveTouch = true;
        [_leftButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        [_leftButton setTitleColor:TGAccentColor()];
        _leftButton.titleLabel.font = TGSystemFontOfSize(17);
        _leftButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
        [_leftButton sizeToFit];
        _leftButton.frame = CGRectMake(0, 0, MAX(60, _leftButton.frame.size.width), 44);
        _leftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_leftButton addTarget:self action:@selector(leftButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_leftButton];
        
        _rightButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 40, 44)];
        _rightButton.exclusiveTouch = true;
        [_rightButton setTitle:TGLocalized(@"MediaPicker.Send") forState:UIControlStateNormal];
        [_rightButton setTitleColor:TGAccentColor()];
        _rightButton.titleLabel.font = TGMediumSystemFontOfSize(17);
        _rightButton.contentEdgeInsets = UIEdgeInsetsMake(0, 27, 0, 10);
        [_rightButton sizeToFit];
        
        CGFloat doneButtonWidth = MAX(40, _rightButton.frame.size.width);
        _rightButton.frame = CGRectMake(self.frame.size.width - doneButtonWidth, 0, doneButtonWidth, 44);
        _rightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_rightButton addTarget:self action:@selector(rightButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _rightButton.enabled = false;
        [self addSubview:_rightButton];
        
        static UIImage *countBadgeBackground = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(22, 22), false, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0, 0, 22, 22));
            countBadgeBackground = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:11 topCapHeight:11];
            UIGraphicsEndImageContext();
        });
        
        _countBadge = [[UIImageView alloc] initWithImage:countBadgeBackground];
        _countBadge.alpha = 0.0f;
        
        _countLabel = [[UILabel alloc] init];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.textColor = [UIColor whiteColor];
        _countLabel.font = [TGFont roundedFontOfSize:17];
        [_countBadge addSubview:_countLabel];
        
        [_rightButton addSubview:_countBadge];
    }
    return self;
}

- (void)setPallete:(TGMediaAssetsPallete *)pallete
{
    self.backgroundColor = pallete.barBackgroundColor;
    _separatorView.backgroundColor = pallete.barSeparatorColor;
    
    [_leftButton setTitleColor:pallete.accentColor];
    [_rightButton setTitleColor:pallete.accentColor];
    
    _countBadge.image = pallete.badge;
    _countLabel.textColor = pallete.badgeTextColor;
}

- (void)leftButtonPressed
{
    if (self.leftPressed != nil)
        self.leftPressed();
}

- (void)rightButtonPressed
{
    if (self.rightPressed != nil)
        self.rightPressed();
}

- (void)centerButtonPressed
{
    if (self.centerPressed != nil)
        self.centerPressed();
}

#pragma mark - Properties

- (void)_setTitle:(NSString *)title forButton:(TGModernButton *)button
{
    NSString *currentTitle = [button titleForState:UIControlStateNormal];
    
    if ([currentTitle isEqualToString:title])
        return;
    
    button.userInteractionEnabled = (title.length > 0);
    
    if (currentTitle.length == 0 && title.length > 0)
    {
        button.alpha = 0.0f;
        [button setTitle:title forState:UIControlStateNormal];
        [button sizeToFit];
        
        [UIView animateWithDuration:0.15f animations:^
        {
            button.alpha = 1.0f;
        }];
    }
    else if (currentTitle.length > 0 && title.length == 0)
    {
        [UIView animateWithDuration:0.15f animations:^
        {
            button.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                 [button setTitle:title forState:UIControlStateNormal];
        }];
    }
    else
    {
        [button setTitle:title forState:UIControlStateNormal];
        [button sizeToFit];
    }
}

- (NSString *)leftButtonTitle
{
    return [_leftButton titleForState:UIControlStateNormal];
}

- (void)setLeftButtonTitle:(NSString *)title
{
    [self _setTitle:title forButton:_leftButton];
}

- (NSString *)rightButtonTitle
{
    return [_rightButton titleForState:UIControlStateNormal];
}

- (void)setRightButtonTitle:(NSString *)title
{
    [self _setTitle:title forButton:_rightButton];
}

- (void)setRightButtonHidden:(bool)hidden
{
    _rightButton.hidden = hidden;
}

- (void)setRightButtonEnabled:(bool)enabled animated:(bool)__unused animated
{
    _rightButton.enabled = enabled;
}

- (void)setSelectedCount:(NSInteger)count animated:(bool)animated
{
    bool incremented = true;
    
    CGFloat alpha = 0.0f;
    if (count != 0)
    {
        alpha = 1.0f;
        
        if (_countLabel.text.length != 0)
            incremented = [_countLabel.text integerValue] < count;
        
        _countLabel.text = [[NSString alloc] initWithFormat:@"%ld", count];
        [_countLabel sizeToFit];
    }
    
    CGFloat badgeWidth = MAX(22, _countLabel.frame.size.width + 12);
    _countBadge.transform = CGAffineTransformIdentity;
    _countBadge.frame = CGRectMake(-badgeWidth + 22, 11, badgeWidth, 22);
    _countLabel.frame = CGRectMake(TGRetinaFloor((badgeWidth - _countLabel.frame.size.width) / 2), TGScreenPixel, _countLabel.frame.size.width, _countLabel.frame.size.height);
    
    if (animated)
    {
        if (_countBadge.alpha < FLT_EPSILON && alpha > FLT_EPSILON)
        {
            _countBadge.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _countBadge.alpha = alpha;
                _countBadge.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                    {
                        _countBadge.transform = CGAffineTransformIdentity;
                    } completion:nil];
                }
            }];
        }
        else if (_countBadge.alpha > FLT_EPSILON && alpha < FLT_EPSILON)
        {
            [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _countBadge.alpha = alpha;
                _countBadge.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            } completion:^(BOOL finished)
            {
                if (finished)
                    _countBadge.transform = CGAffineTransformIdentity;
            }];
        }
        else
        {
            [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _countBadge.transform = incremented ? CGAffineTransformMakeScale(1.2f, 1.2f) : CGAffineTransformMakeScale(0.8f, 0.8f);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                    {
                        _countBadge.transform = CGAffineTransformIdentity;
                    } completion:nil];
                }
            }];
        }
    }
    else
    {
        _countBadge.transform = CGAffineTransformIdentity;
        _countBadge.alpha = alpha;
    }
}

- (void)setCenterButtonImage:(UIImage *)centerButtonImage
{
    _centerButtonImage = centerButtonImage;

    if (_centerButton == nil)
    {
        _centerButton = [[TGModernButton alloc] initWithFrame:CGRectMake(round((self.frame.size.width - 60.0f) / 2.0f), 0, 60, 44)];
        _centerButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _centerButton.adjustsImageWhenHighlighted = false;
        _centerButton.exclusiveTouch = true;
        [_centerButton addTarget:self action:@selector(centerButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_centerButton];
    }
    [_centerButton setImage:centerButtonImage forState:UIControlStateNormal];
}

- (void)setCenterButtonSelectedImage:(UIImage *)centerButtonSelectedImage
{
    _centerButtonSelectedImage = centerButtonSelectedImage;
    
    [_centerButton setImage:centerButtonSelectedImage forState:UIControlStateSelected];
    [_centerButton setImage:centerButtonSelectedImage forState:UIControlStateSelected | UIControlStateHighlighted];
}

- (void)setCenterButtonSelected:(bool)selected
{
    _centerButton.selected = selected;
}

- (void)setCenterButtonHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _centerButton.userInteractionEnabled = !hidden;
        [UIView animateWithDuration:0.2 animations:^
        {
            _centerButton.alpha = hidden ? 0.0f : 1.0f;
        } completion:nil];
    }
    else
    {
        _centerButton.alpha = hidden ? 0.0f : 1.0f;
        _centerButton.userInteractionEnabled = !hidden;
    }
}

- (UIButton *)centerButton
{
    return _centerButton;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    _leftButton.frame = CGRectMake(self.safeAreaInset.left, 0.0f, _leftButton.frame.size.width, 44);
    _rightButton.frame = CGRectMake(self.frame.size.width - _rightButton.frame.size.width - self.safeAreaInset.right, 0, _rightButton.frame.size.width, 44);
}

@end
