#import "TGLocationPinView.h"

#import "TGImageUtils.h"
#import "LegacyComponentsInternal.h"

#import "TGLocationMapViewController.h"

const CGSize TGLocationPinSize = { 13.5f, 36 };
const CGFloat TGLocationPinDamping = 2.0f;
const CGFloat TGLocationPinPinnedOrigin = 47;
const CGFloat TGLocationPinRaisedOrigin = 7;
const CGPoint TGLocationPinShadowPinnedOrigin = { 43, 47 };
const CGPoint TGLocationPinShadowRaisedOrigin = { 87, -33 };

@interface TGLocationPinView ()
{
    UIImageView *_pinView;
    UIImageView *_pinPointView;
    UIImageView *_shadowView;
}
@end

@implementation TGLocationPinView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0, 0, 100, 100)];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(43, 47, 32, 39)];
        _shadowView.alpha = 0.9f;
        _shadowView.image = TGComponentsImageNamed(@"LocationPinShadow.png");
        [self addSubview:_shadowView];
        
        _pinPointView = [[UIImageView alloc] initWithFrame:CGRectMake(CGFloor(self.frame.size.width / 2 - 2), self.frame.size.height - 18.5f, 3.5f, 1.5f)];
        _pinPointView.image = TGComponentsImageNamed(@"LocationPinPoint.png");
        [self addSubview:_pinPointView];
        
        _pinView = [[UIImageView alloc] initWithFrame:CGRectMake(CGFloor(self.frame.size.width / 2 - 7), 47, 13.5f, 36)];
        _pinView.image = TGComponentsImageNamed(@"LocationPin.png");
        [self addSubview:_pinView];
    }
    return self;
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    _pallete = pallete;
    
    _pinView.image = TGTintedImage(_pinView.image, pallete.locationColor);
    _pinPointView.image = TGTintedImage(_pinPointView.image, pallete.locationColor);
}

- (void)setPinRaised:(bool)pinRaised
{
    [self setPinRaised:pinRaised animated:false completion:nil];
}

- (void)setPinRaised:(bool)raised animated:(bool)animated completion:(void (^)(void))completion
{
    _pinRaised = raised;
    
    [_pinView.layer removeAllAnimations];
    [_shadowView.layer removeAllAnimations];
    
    if (animated)
    {
        if (raised)
        {
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _pinView.frame = CGRectMake(_pinView.frame.origin.x, TGLocationPinRaisedOrigin, TGLocationPinSize.width, TGLocationPinSize.height);
                _shadowView.frame = CGRectMake(TGLocationPinShadowRaisedOrigin.x, TGLocationPinShadowRaisedOrigin.y, _shadowView.frame.size.width, _shadowView.frame.size.height);
            } completion:^(BOOL finished)
            {
                if (finished && completion != nil)
                    completion();
            }];
        }
        else
        {
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _pinView.frame = CGRectMake(_pinView.frame.origin.x, TGLocationPinPinnedOrigin, TGLocationPinSize.width, TGLocationPinSize.height);
                _shadowView.frame = CGRectMake(TGLocationPinShadowPinnedOrigin.x, TGLocationPinShadowPinnedOrigin.y, _shadowView.frame.size.width, _shadowView.frame.size.height);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
                    {
                        _pinView.frame = CGRectMake(_pinView.frame.origin.x, TGLocationPinPinnedOrigin + TGLocationPinDamping, TGLocationPinSize.width, TGLocationPinSize.height - TGLocationPinDamping);
                    } completion:^(BOOL finished)
                    {
                        if (finished)
                        {
                            [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
                            {
                                 _pinView.frame = CGRectMake(_pinView.frame.origin.x, TGLocationPinPinnedOrigin, TGLocationPinSize.width, TGLocationPinSize.height);
                            } completion:^(BOOL finished)
                            {
                                if (finished && completion != nil)
                                    completion();
                            }];
                        }
                    }];
                }
            }];
        }
    }
    else
    {
        _pinView.frame = CGRectMake(_pinView.frame.origin.x, raised ? TGLocationPinRaisedOrigin : TGLocationPinPinnedOrigin, TGLocationPinSize.width, TGLocationPinSize.height);
        
        CGPoint shadowOrigin = raised ? TGLocationPinShadowRaisedOrigin : TGLocationPinShadowPinnedOrigin;
        _shadowView.frame = CGRectMake(shadowOrigin.x, shadowOrigin.y, _shadowView.frame.size.width, _shadowView.frame.size.height);
        
        if (completion != nil)
            completion();
    }
}

@end
