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
        
        _flashIconView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        _flashIconView.adjustsImageWhenHighlighted = false;
        _flashIconView.contentMode = UIViewContentModeCenter;
        _flashIconView.exclusiveTouch = true;
        _flashIconView.hitTestEdgeInsets = UIEdgeInsetsMake(0, -10, 0, -10);
        _flashIconView.tag = -1;
        [_flashIconView setImage:[UIImage imageNamed:@"Camera/FlashOff"] forState:UIControlStateNormal];
        [_flashIconView addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_flashIconView];
                
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
    if (_mode == PGCameraFlashModeOff) {
        self.mode = PGCameraFlashModeOn;
        [_flashIconView setImage:[UIImage imageNamed:@"Camera/FlashOn"] forState:UIControlStateNormal];
    } else {
        self.mode = PGCameraFlashModeOff;
        [_flashIconView setImage:[UIImage imageNamed:@"Camera/FlashOff"] forState:UIControlStateNormal];
    }

    if (self.modeChanged != nil)
        self.modeChanged(self.mode);
}

- (void)setFlashUnavailable:(bool)unavailable
{
    self.userInteractionEnabled = !unavailable;
    [self setActive:false animated:false];
}

- (void)setActive:(bool)active animated:(bool)animated
{
    return;
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
}

@end
