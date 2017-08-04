#import "TGCameraFlashControl.h"

#import "LegacyComponentsInternal.h"

#import "UIControl+HitTestEdgeInsets.h"

#import "TGCameraInterfaceAssets.h"
#import <LegacyComponents/TGModernButton.h>

const CGFloat TGCameraFlashControlHeight = 44.0f;

@interface TGCameraFlashControl ()
{
    UIButton *_flashIconView;
    UIButton *_autoButton;
    UIButton *_onButton;
    UIButton *_offButton;
    
    bool _active;
}
@end

@implementation TGCameraFlashControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
        
        _flashIconView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 34, 44)];
        _flashIconView.adjustsImageWhenHighlighted = false;
        _flashIconView.contentMode = UIViewContentModeCenter;
        _flashIconView.exclusiveTouch = true;
        _flashIconView.hitTestEdgeInsets = UIEdgeInsetsMake(0, -10, 0, -10);
        _flashIconView.tag = -1;
        [_flashIconView setImage:TGComponentsImageNamed(@"CameraFlashButton") forState:UIControlStateNormal];
        [_flashIconView addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_flashIconView];
        
        static UIImage *highlightedIconImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIImage *image = TGComponentsImageNamed(@"CameraFlashButton");
            UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
            CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
            CGContextSetFillColorWithColor(context, [TGCameraInterfaceAssets accentColor].CGColor);
            CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
            
            highlightedIconImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        [_flashIconView setImage:highlightedIconImage forState:UIControlStateSelected];
        [_flashIconView setImage:highlightedIconImage forState:UIControlStateHighlighted | UIControlStateSelected];
        
        _autoButton = [[UIButton alloc] init];
        _autoButton.backgroundColor = [UIColor clearColor];
        _autoButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _autoButton.exclusiveTouch = true;
        _autoButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -15, -10, -15);
        _autoButton.tag = PGCameraFlashModeAuto;
        _autoButton.titleLabel.font = [TGCameraInterfaceAssets normalFontOfSize:13];
        [_autoButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashAuto") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets normalColor], NSKernAttributeName: @2 }] forState:UIControlStateNormal];
        [_autoButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashAuto") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets accentColor], NSKernAttributeName: @2 }] forState:UIControlStateSelected];
        [_autoButton setAttributedTitle:[_autoButton attributedTitleForState:UIControlStateSelected] forState:UIControlStateHighlighted | UIControlStateSelected];
        [_autoButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_autoButton sizeToFit];
        _autoButton.frame = (CGRect){ CGPointZero, [TGCameraFlashControl _sizeForModeButtonWithTitle:[_autoButton attributedTitleForState:UIControlStateNormal]] };
        [self addSubview:_autoButton];

        _onButton = [[UIButton alloc] init];
        _onButton.backgroundColor = [UIColor clearColor];
        _onButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _onButton.exclusiveTouch = true;
        _onButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -15, -10, -15);
        _onButton.tag = PGCameraFlashModeOn;
        _onButton.titleLabel.font = [TGCameraInterfaceAssets normalFontOfSize:13];
        [_onButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashOn") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets normalColor], NSKernAttributeName: @2 }] forState:UIControlStateNormal];
        [_onButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashOn") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets accentColor], NSKernAttributeName: @2 }] forState:UIControlStateSelected];
        [_onButton setAttributedTitle:[_onButton attributedTitleForState:UIControlStateSelected] forState:UIControlStateHighlighted | UIControlStateSelected];
        [_onButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_onButton sizeToFit];
        _onButton.frame = (CGRect){ CGPointZero, [TGCameraFlashControl _sizeForModeButtonWithTitle:[_onButton attributedTitleForState:UIControlStateNormal]] };
        [self addSubview:_onButton];
        
        _offButton = [[UIButton alloc] init];
        _offButton.backgroundColor = [UIColor clearColor];
        _offButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _offButton.exclusiveTouch = true;
        _offButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -15, -10, -15);
        _offButton.tag = PGCameraFlashModeOff;
        _offButton.titleLabel.font = [TGCameraInterfaceAssets normalFontOfSize:13];
        [_offButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashOff") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets normalColor], NSKernAttributeName: @2 }] forState:UIControlStateNormal];
        [_offButton setAttributedTitle:[[NSAttributedString alloc] initWithString:TGLocalized(@"Camera.FlashOff") attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets accentColor], NSKernAttributeName: @2 }] forState:UIControlStateSelected];
        [_offButton setAttributedTitle:[_offButton attributedTitleForState:UIControlStateSelected] forState:UIControlStateHighlighted | UIControlStateSelected];
        [_offButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_offButton sizeToFit];
        _offButton.frame = (CGRect){ CGPointZero, [TGCameraFlashControl _sizeForModeButtonWithTitle:[_offButton attributedTitleForState:UIControlStateNormal]] };
        [self addSubview:_offButton];
        
        [UIView performWithoutAnimation:^
        {
            self.mode = PGCameraFlashModeOff;
            [self setActive:false animated:false];
        }];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isKindOfClass:[UIButton class]])
        return view;
    
    return nil;
}

- (void)buttonPressed:(UIButton *)sender
{
    if (!_active)
    {
        [self setActive:true animated:true];
    }
    else
    {
        if (sender != _flashIconView)
            self.mode = (int)sender.tag;
        else
            self.mode = _mode;
        
        if (self.modeChanged != nil)
            self.modeChanged(self.mode);
    }
}

- (void)setFlashUnavailable:(bool)unavailable
{
    self.userInteractionEnabled = !unavailable;
    [self setActive:false animated:false];
    
    
}

- (void)setActive:(bool)active animated:(bool)animated
{
    _active = active;
    
    if (animated)
    {
        self.userInteractionEnabled = false;
        
        if (active)
        {
            UIView *animatedView = nil;
            UIView *snapshotView = nil;
            CGRect targetFrame = CGRectZero;
            
            if (self.mode != PGCameraFlashModeAuto)
            {
                _autoButton.frame = [self _autoButtonFrameForInterfaceOrientation:_interfaceOrientation];
                _autoButton.alpha = 0.0f;
                _autoButton.hidden = false;
            }
            else
            {
                animatedView = _autoButton;
                targetFrame = [self _autoButtonFrameForInterfaceOrientation:_interfaceOrientation];
                snapshotView = [animatedView snapshotViewAfterScreenUpdates:false];
            }
            _autoButton.selected = (self.mode == PGCameraFlashModeAuto);
            
            if (self.mode != PGCameraFlashModeOn)
            {
                _onButton.frame = [self _onButtonFrameForInterfaceOrientation:_interfaceOrientation];
                _onButton.alpha = 0.0f;
                _onButton.hidden = false;
            }
            else
            {
                animatedView = _onButton;
                targetFrame = [self _onButtonFrameForInterfaceOrientation:_interfaceOrientation];
            }
            _onButton.selected = (self.mode == PGCameraFlashModeOn);
            
            if (self.mode != PGCameraFlashModeOff)
            {
                _offButton.frame = [self _offButtonFrameForInterfaceOrientation:_interfaceOrientation];
                _offButton.alpha = 0.0f;
                _offButton.hidden = false;
            }
            else
            {
                animatedView = _offButton;
                targetFrame = [self _offButtonFrameForInterfaceOrientation:_interfaceOrientation];
                snapshotView = [animatedView snapshotViewAfterScreenUpdates:false];
            }
            _offButton.selected = (self.mode == PGCameraFlashModeOff);
            
            if (snapshotView != nil)
            {
                snapshotView.frame = animatedView.frame;
                [animatedView.superview insertSubview:snapshotView belowSubview:animatedView];
                animatedView.alpha = 0.0f;
            }

            UIView *iconSnapshotView = nil;
            if (_flashIconView.selected)
            {
                iconSnapshotView = [_flashIconView snapshotViewAfterScreenUpdates:false];
                iconSnapshotView.frame = _flashIconView.frame;
                [_flashIconView.superview insertSubview:iconSnapshotView belowSubview:_flashIconView];
                _flashIconView.selected = false;
                _flashIconView.alpha = 0.0f;
            }
            
            [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                _flashIconView.alpha = 1.0f;
                _flashIconView.frame = [self _flashIconFrameForActive:active interfaceOrientation:_interfaceOrientation];
                iconSnapshotView.frame = _flashIconView.frame;
                
                _autoButton.alpha = 1.0f;
                _onButton.alpha = 1.0f;
                _offButton.alpha = 1.0f;
                
                animatedView.alpha = 1.0f;
                animatedView.frame = targetFrame;
                snapshotView.frame = targetFrame;
            } completion:^(BOOL finished)
            {
                [snapshotView removeFromSuperview];
                [iconSnapshotView removeFromSuperview];
                if (finished)
                    self.userInteractionEnabled = true;
            }];
        }
        else
        {
            UIView *animatedView = nil;
            UIView *snapshotView = nil;
            UIView *iconSnapshotView = nil;
            
            switch (self.mode)
            {
                case PGCameraFlashModeAuto:
                {
                    animatedView = _autoButton;
                    snapshotView = [animatedView snapshotViewAfterScreenUpdates:false];
                    _autoButton.selected = false;
                }
                    break;
                    
                case PGCameraFlashModeOn:
                {
                    animatedView = _onButton;
                    if (!_onButton.selected)
                    {
                        snapshotView = [animatedView snapshotViewAfterScreenUpdates:false];
                        _onButton.selected = true;
                    }
                    
                    iconSnapshotView = [_flashIconView snapshotViewAfterScreenUpdates:false];
                    iconSnapshotView.frame = _flashIconView.frame;
                    [_flashIconView.superview insertSubview:iconSnapshotView belowSubview:_flashIconView];
                    _flashIconView.selected = true;
                    _flashIconView.alpha = 0.0f;
                }
                    break;
                    
                case PGCameraFlashModeOff:
                {
                    animatedView = _offButton;
                    snapshotView = [animatedView snapshotViewAfterScreenUpdates:false];
                    _offButton.selected = false;
                }
                    break;
                    
                default:
                    break;
            }
            
            if (snapshotView != nil)
            {
                snapshotView.frame = animatedView.frame;
                [animatedView.superview insertSubview:snapshotView belowSubview:animatedView];
                animatedView.alpha = 0.0f;
            }
            
            [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                _flashIconView.alpha = 1.0f;                
                _flashIconView.frame = [self _flashIconFrameForActive:active interfaceOrientation:_interfaceOrientation];
                iconSnapshotView.frame = _flashIconView.frame;
                
                if (self.mode != PGCameraFlashModeAuto)
                    _autoButton.alpha = 0.0f;
                
                if (self.mode != PGCameraFlashModeOn)
                    _onButton.alpha = 0.0f;
                
                if (self.mode != PGCameraFlashModeOff)
                    _offButton.alpha = 0.0f;
                
                animatedView.alpha = 1.0f;
                animatedView.frame = [self _selectedButtonFrameForSize:animatedView.frame.size interfaceOrientation:_interfaceOrientation];
                snapshotView.frame = animatedView.frame;
            } completion:^(BOOL finished)
            {
                [snapshotView removeFromSuperview];
                [iconSnapshotView removeFromSuperview];
                if (finished)
                {
                    self.userInteractionEnabled = true;
                
                    if (self.mode != PGCameraFlashModeAuto)
                        _autoButton.hidden = true;
                    
                    if (self.mode != PGCameraFlashModeOn)
                        _onButton.hidden = true;
                    
                    if (self.mode != PGCameraFlashModeOff)
                        _offButton.hidden = true;
                }
            }];
        }
    }
    else
    {
        _flashIconView.frame = [self _flashIconFrameForActive:active interfaceOrientation:_interfaceOrientation];
     
        if (active)
        {
            _flashIconView.selected = false;
            
            _autoButton.frame = [self _autoButtonFrameForInterfaceOrientation:_interfaceOrientation];
            _autoButton.alpha = 1.0f;
            _autoButton.hidden = false;
            _autoButton.selected = (self.mode == PGCameraFlashModeAuto);
            
            _onButton.frame = [self _onButtonFrameForInterfaceOrientation:_interfaceOrientation];
            _onButton.alpha = 1.0f;
            _onButton.hidden = false;
            _onButton.selected = (self.mode == PGCameraFlashModeOn);
            
            _offButton.frame = [self _offButtonFrameForInterfaceOrientation:_interfaceOrientation];
            _offButton.alpha = 1.0f;
            _offButton.hidden = false;
            _offButton.selected = (self.mode == PGCameraFlashModeOff);
        }
        else
        {
            switch (self.mode)
            {
                case PGCameraFlashModeOff:
                {
                    _flashIconView.selected = false;
                    
                    _autoButton.alpha = 0.0f;
                    _autoButton.hidden = true;
                    _autoButton.selected = false;
                    
                    _onButton.alpha = 0.0f;
                    _onButton.hidden = true;
                    _onButton.selected = false;
                    
                    _offButton.frame = [self _selectedButtonFrameForSize:_offButton.frame.size interfaceOrientation:_interfaceOrientation];
                    _offButton.alpha = 1.0f;
                    _offButton.hidden = false;
                    _offButton.selected = false;
                }
                    break;
                    
                case PGCameraFlashModeOn:
                {
                    _flashIconView.selected = true;
                    
                    _autoButton.alpha = 0.0f;
                    _autoButton.hidden = true;
                    _autoButton.selected = false;
                    
                    _onButton.frame = [self _selectedButtonFrameForSize:_onButton.frame.size interfaceOrientation:_interfaceOrientation];
                    _onButton.alpha = 1.0f;
                    _onButton.hidden = false;
                    _onButton.selected = true;
                    
                    _offButton.alpha = 0.0f;
                    _offButton.hidden = true;
                    _offButton.selected = false;
                }
                    break;
                    
                case PGCameraFlashModeAuto:
                {
                    _flashIconView.selected = false;
                    
                    _autoButton.frame = [self _selectedButtonFrameForSize:_autoButton.frame.size interfaceOrientation:_interfaceOrientation];
                    _autoButton.alpha = 1.0f;
                    _autoButton.hidden = false;
                    _autoButton.selected = false;
                    
                    _onButton.alpha = 0.0f;
                    _onButton.hidden = true;
                    _onButton.selected = false;
                    
                    _offButton.alpha = 0.0f;
                    _offButton.hidden = true;
                    _offButton.selected = false;
                }
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    if (active && self.becameActive != nil)
        self.becameActive();
}

- (void)setMode:(PGCameraFlashMode)mode
{
    _mode = mode;
    
    [self setActive:false animated:_active];
}

- (void)dismissAnimated:(bool)animated
{
    if (animated && _active)
        [self setActive:false animated:animated];
    else
        [self setActive:false animated:false];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
    
    [self setActive:false animated:false];
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f
                         animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
            
            [self setActive:false animated:false];
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
        
        [self setActive:false animated:false];
    }
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;

    [self setActive:false animated:false];
}

- (CGRect)_flashIconFrameForActive:(bool)active interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGPoint origin = CGPointZero;
    CGSize size = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        size = CGSizeMake(size.height, size.width);
    
    switch (interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            if (active)
                origin = CGPointMake(size.width - _flashIconView.frame.size.width - 5, (size.height - _flashIconView.frame.size.height) / 2);
            else
                origin = CGPointMake(size.width - _flashIconView.frame.size.width - 5, (size.height - _flashIconView.frame.size.height) / 2 - 9);
        }
            break;
        case UIInterfaceOrientationLandscapeRight:
        {
            if (active)
                origin = CGPointMake(5, (size.height - _flashIconView.frame.size.height) / 2);
            else
                origin = CGPointMake(5, (size.height - _flashIconView.frame.size.height) / 2 - 9);
        }
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            if (active)
            {
                origin = CGPointMake(0, 0);
            }
            else
            {
                CGFloat maxWidth = MAX(MAX(_offButton.frame.size.width, _onButton.frame.size.width), _autoButton.frame.size.width);
                origin = CGPointMake(size.width - _flashIconView.frame.size.width - maxWidth, 0);
            }
        }
            break;
            
        default:
        {
            origin = CGPointZero;
        }
            break;
    }
    
    return CGRectMake(origin.x, origin.y, _flashIconView.frame.size.width, _flashIconView.frame.size.height);
}

- (CGRect)_selectedButtonFrameForSize:(CGSize)buttonSize interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGPoint origin = CGPointZero;
    CGSize size = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        size = CGSizeMake(size.height, size.width);
    
    switch (interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
        {
            origin = CGPointMake(CGRectGetMidX(_flashIconView.frame) - buttonSize.width / 2, 21);
        }
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            CGRect iconFrame = [self _flashIconFrameForActive:false interfaceOrientation:interfaceOrientation];
            origin = CGPointMake(iconFrame.origin.x + iconFrame.size.width - 3, (size.height - buttonSize.height) / 2);
        }
            break;
            
        default:
        {
            origin = CGPointMake(_flashIconView.frame.size.width - 5,
                                 (size.height - buttonSize.height) / 2);
        }
            break;
    }
    
    return CGRectMake(origin.x, origin.y, buttonSize.width, buttonSize.height);
}

- (CGRect)_autoButtonFrameForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGSize size = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        size = CGSizeMake(size.height, size.width);
    
    return CGRectMake(size.width / 4 - _autoButton.frame.size.width / 2,
                      (size.height - _autoButton.frame.size.height) / 2,
                      _autoButton.frame.size.width, _autoButton.frame.size.height);
}

- (CGRect)_onButtonFrameForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGSize size = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        size = CGSizeMake(size.height, size.width);
    
    return CGRectMake((size.width - _onButton.frame.size.width) / 2,
                      (size.height - _onButton.frame.size.height) / 2,
                      _onButton.frame.size.width, _onButton.frame.size.height);
}

- (CGRect)_offButtonFrameForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGSize size = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
        size = CGSizeMake(size.height, size.width);
    
    return CGRectMake(size.width / 4 * 3 - _offButton.frame.size.width / 2,
                      (size.height - _offButton.frame.size.height) / 2,
                      _offButton.frame.size.width, _offButton.frame.size.height);
}

+ (CGSize)_sizeForModeButtonWithTitle:(NSAttributedString *)title
{
    CGSize size = title.size;
    CGFloat width = CGCeil(size.width);
    if (iosMajorVersion() < 7)
        width += 2;
    return CGSizeMake(width, 20);
}

@end
