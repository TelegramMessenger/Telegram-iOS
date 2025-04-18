#import "TGCameraFlashActiveView.h"

#import "LegacyComponentsInternal.h"

#import "TGCameraInterfaceAssets.h"

@interface TGCameraFlashActiveView ()
{
    UIView *_backgroundView;
    UIImageView *_iconView;
}
@end

@implementation TGCameraFlashActiveView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        _backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _backgroundView.backgroundColor = [TGCameraInterfaceAssets accentColor];
        _backgroundView.layer.cornerRadius = 2.0f;
        [self addSubview:_backgroundView];
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake((frame.size.width - 8) / 2, (frame.size.height - 13) / 2, 8, 13)];
        _iconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        _iconView.image = TGComponentsImageNamed(@"CameraFlashActive");
        [_backgroundView addSubview:_iconView];
        
        [self setActive:false animated:false];
    }
    return self;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _backgroundView.hidden = false;
        
        [UIView animateWithDuration:0.25f
                         animations:^
        {
            _backgroundView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _backgroundView.hidden = hidden;
        }];
    }
    else
    {
        _backgroundView.alpha = hidden ? 0.0f : 1.0f;
        _backgroundView.hidden = hidden;
    }
}

- (void)setActive:(bool)active animated:(bool)animated
{
    [self setHidden:!active animated:animated];
}

@end
