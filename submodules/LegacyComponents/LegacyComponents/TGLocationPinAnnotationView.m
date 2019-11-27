#import "TGLocationPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGLocationMapViewController.h"

#import "TGUser.h"
#import "TGConversation.h"
#import "TGLocationAnnotation.h"
#import "TGLocationMediaAttachment.h"

#import "TGImageView.h"
#import "TGLetteredAvatarView.h"
#import "TGLocationPulseView.h"

NSString *const TGLocationPinAnnotationKind = @"TGLocationPinAnnotation";

@interface TGLocationPinAnnotationView ()
{
    TGLocationPulseView *_pulseView;
    UIImageView *_smallView;
    UIImageView *_shadowView;
    UIImageView *_backgroundView;
    TGImageView *_iconView;
    UIImageView *_dotView;
    TGLetteredAvatarView *_avatarView;
    
    bool _liveLocation;
    SMetaDisposable *_userDisposable;
    
    bool _animating;
    
    bool _observingExpiration;
}
@end

@implementation TGLocationPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation
{
    self = [super initWithAnnotation:annotation reuseIdentifier:TGLocationPinAnnotationKind];
    if (self != nil)
    {
        _pulseView = [[TGLocationPulseView alloc] init];
        [self addSubview:_pulseView];
        
        _shadowView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"LocationPinShadow")];
        [self addSubview:_shadowView];
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 83.0f, 83.0f)];
        [_shadowView addSubview:_backgroundView];
        
        _iconView = [[TGImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 64.0f, 64.0f)];
        _iconView.contentMode = UIViewContentModeCenter;
        [_backgroundView addSubview:_iconView];
        
        static dispatch_once_t onceToken;
        static UIImage *dotImage;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(6.0f, 6.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGB(0x008df2).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 6.0f, 6.0f));
            
            dotImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _smallView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"LocationSmallCircle")];
        _smallView.hidden = true;
        [self addSubview:_smallView];
        
        _dotView = [[UIImageView alloc] initWithImage:dotImage];
        [self addSubview:_dotView];
        
        [self setAnnotation:annotation];
    }
    return self;
}

- (void)dealloc
{
    [self unsubscribeFromExpiration];
}

- (void)prepareForReuse
{
    [_pulseView stop];
    [_iconView reset];
    _smallView.hidden = true;
    _backgroundView.hidden = false;
}

- (void)subscribeForExpiration
{
    if (_observingExpiration)
        return;
    _observingExpiration = true;
    [self addObserver:self forKeyPath:@"annotation.isExpired" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)unsubscribeFromExpiration
{
    if (!_observingExpiration)
        return;
    _observingExpiration = false;
    [self removeObserver:self forKeyPath:@"annotation.isExpired"];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if (iosMajorVersion() < 7)
        animated = false;
    
    [super setSelected:selected animated:animated];
 
    if (!_liveLocation)
        return;
    
    if (animated)
    {
        [self layoutSubviews];
        _animating = true;
        if (selected)
        {
            //dispatch_async(dispatch_get_main_queue(), ^
            //{
                UIView *avatarSnapshot = [_avatarView snapshotViewAfterScreenUpdates:false];
                [_smallView addSubview:avatarSnapshot];
                avatarSnapshot.transform = _avatarView.transform;
                avatarSnapshot.center = CGPointMake(_smallView.frame.size.width / 2.0f, _smallView.frame.size.height / 2.0f);
                
                _avatarView.transform = CGAffineTransformIdentity;
                [_backgroundView addSubview:_avatarView];
                _avatarView.center = CGPointMake(_backgroundView.frame.size.width / 2.0f, _backgroundView.frame.size.height / 2.0f - 5.0f);
                
                _dotView.alpha = 0.0f;
                
                _shadowView.center = CGPointMake(_shadowView.center.x, _shadowView.center.y + _shadowView.frame.size.height / 2.0f);
                _shadowView.layer.anchorPoint = CGPointMake(0.5f, 1.0f);
                _shadowView.hidden = false;
                _shadowView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
                [UIView animateWithDuration:0.35 delay:0.0 usingSpringWithDamping:0.6f initialSpringVelocity:0.5f options:kNilOptions animations:^
                {
                    _smallView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
                    _shadowView.transform = CGAffineTransformIdentity;
                    if (_dotView.hidden)
                        _smallView.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    _animating = false;
                    _shadowView.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
                    
                    _smallView.hidden = true;
                    _smallView.transform = CGAffineTransformIdentity;
                    [avatarSnapshot removeFromSuperview];
                    
                    [self addSubview:_avatarView];
                }];
                
                [UIView animateWithDuration:0.2 animations:^
                {
                    _dotView.alpha = 1.0f;
                }];
            //});
        }
        else
        {
            UIView *avatarSnapshot = [_avatarView snapshotViewAfterScreenUpdates:false];
            [_backgroundView addSubview:avatarSnapshot];
            avatarSnapshot.transform = _avatarView.transform;
            avatarSnapshot.center = CGPointMake(_backgroundView.frame.size.width / 2.0f, _backgroundView.frame.size.height / 2.0f - 5.0f);
            
            _avatarView.transform = CGAffineTransformMakeScale(0.64f, 0.64f);
            [_smallView addSubview:_avatarView];
            _avatarView.center = CGPointMake(_smallView.frame.size.width / 2.0f, _smallView.frame.size.height / 2.0f);
            
            _smallView.hidden = false;
            _smallView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
            
            _shadowView.center = CGPointMake(_shadowView.center.x, _shadowView.center.y + _shadowView.frame.size.height / 2.0f);
            _shadowView.layer.anchorPoint = CGPointMake(0.5f, 1.0f);
            [UIView animateWithDuration:0.35 delay:0.0 usingSpringWithDamping:0.6f initialSpringVelocity:0.5f options:kNilOptions animations:^
             {
                 _smallView.transform = CGAffineTransformIdentity;
                 _shadowView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
                 if (_dotView.hidden)
                     _smallView.alpha = 1.0f;
             } completion:^(BOOL finished)
             {
                 _animating = false;
                 _shadowView.layer.anchorPoint = CGPointMake(0.5f, 0.5f);
                 
                 _shadowView.hidden = true;
                 _shadowView.transform = CGAffineTransformIdentity;
                 [avatarSnapshot removeFromSuperview];
                 
                 [self addSubview:_avatarView];
             }];
         
            [UIView animateWithDuration:0.1 animations:^
            {
                _dotView.alpha = 0.0f;
            } completion:nil];
        }
    }
    else
    {
        _smallView.hidden = selected;
        _shadowView.hidden = !selected;
        _dotView.alpha = selected ? 1.0f : 0.0f;
        _smallView.alpha = 1.0f;
        [self layoutSubviews];
    }
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(6.0f, 6.0f), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, pallete.locationColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 6.0f, 6.0f));
    
    UIImage *dotImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _dotView.image = dotImage;
    
    [self setAnnotation:self.annotation];
}

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    [super setAnnotation:annotation];
    
    if ([annotation isKindOfClass:[TGLocationPickerAnnotation class]])
    {
        _avatarView.hidden = false;
        _avatarView.alpha = 1.0f;
        _iconView.hidden = true;
        _dotView.hidden = true;
        
        _backgroundView.image = TGComponentsImageNamed(@"LocationPinBackground");
        
        _liveLocation = false;
        [self setPeer:((TGLocationPickerAnnotation *)annotation).peer];
        
        [self unsubscribeFromExpiration];
    }
    else if ([annotation isKindOfClass:[TGLocationAnnotation class]])
    {
        TGLocationAnnotation *locationAnnotation = ((TGLocationAnnotation *)annotation);
        TGLocationMediaAttachment *location = locationAnnotation.location;
        if (location.period == 0)
        {
            _dotView.hidden = false;
            _avatarView.hidden = true;
            _avatarView.alpha = 1.0f;
            _iconView.hidden = false;
            
            UIColor *color = _pallete != nil ? _pallete.locationColor : UIColorRGB(0x008df2);
            UIColor *pinColor = _pallete != nil ? _pallete.iconColor : [UIColor whiteColor];
            if (locationAnnotation.color != nil) {
                color = locationAnnotation.color;
                pinColor = [UIColor whiteColor];
            }
            
            _backgroundView.image = TGTintedImage(TGComponentsImageNamed(@"LocationPinBackground"), color);
            if (location.venue.type.length > 0)
            {
                [_iconView loadUri:[NSString stringWithFormat:@"location-venue-icon://type=%@&width=%d&height=%d&color=%d", location.venue.type, 64, 64, TGColorHexCode(pinColor)] withOptions:nil];
            }
            else
            {
                [_iconView reset];
                UIImage *image = TGComponentsImageNamed(@"LocationPinIcon");
                if (_pallete != nil)
                    image = TGTintedImage(image, _pallete.iconColor);
                
                _iconView.image = image;
            }
            
            _liveLocation = false;
            
            [self unsubscribeFromExpiration];
        }
        else
        {
            _avatarView.hidden = false;
            _avatarView.alpha = locationAnnotation.isExpired ? 0.5f : 1.0f;
            _iconView.hidden = true;
            
            _backgroundView.image = TGComponentsImageNamed(@"LocationPinBackground");
            
            [self setPeer:locationAnnotation.peer];
            if (!locationAnnotation.isOwn)
            {
                if (!locationAnnotation.isExpired)
                    [_pulseView start];
                _dotView.hidden = false;
            }
            else
            {
                _dotView.hidden = true;
            }
            
            [self subscribeForExpiration];
            
            _liveLocation = true;
            
            if (!self.selected)
            {
                _shadowView.hidden = true;
                _smallView.hidden = false;
            }
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"annotation.isExpired"])
    {
        if (((TGLocationAnnotation *)self.annotation).isExpired)
        {
            [_pulseView stop];
            _avatarView.alpha = 0.5f;
        }
        else
        {
            [_pulseView start];
            _avatarView.alpha = 1.0f;
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setPeer:(id)peer
{
    CGFloat diameter = 55.0f;
    
    static UIImage *placeholder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        //!placeholder
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        CGContextSetStrokeColorWithColor(context, UIColorRGB(0xd9d9d9).CGColor);
        CGContextSetLineWidth(context, 1.0f);
        CGContextStrokeEllipseInRect(context, CGRectMake(0.5f, 0.5f, diameter - 1.0f, diameter - 1.0f));
        
        placeholder = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    if (_avatarView == nil)
    {
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 55.0f, 55.0f)];
        [_avatarView setSingleFontSize:24.0f doubleFontSize:24.0f useBoldFont:false];
        [self addSubview:_avatarView];
    }
    else
    {
        [_avatarView.superview bringSubviewToFront:_avatarView];
    }
    
    bool isUser = [peer isKindOfClass:[TGUser class]];
    NSString *avatarUrl = isUser ? ((TGUser *)peer).photoFullUrlSmall : ((TGConversation *)peer).chatPhotoFullSmall;
    if (avatarUrl.length != 0)
    {
        _avatarView.fadeTransitionDuration = 0.3;
        if (![avatarUrl isEqualToString:_avatarView.currentUrl])
            [_avatarView loadImage:avatarUrl filter:@"circle:55x55" placeholder:placeholder];
    }
    else
    {
        if (isUser)
        {
            [_avatarView loadUserPlaceholderWithSize:CGSizeMake(diameter, diameter) uid:((TGUser *)peer).uid firstName:((TGUser *)peer).firstName lastName:((TGUser *)peer).lastName placeholder:placeholder];
        }
        else
        {
            [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(diameter, diameter) conversationId:((TGConversation *)peer).conversationId title:((TGConversation *)peer).chatTitle placeholder:placeholder];
        }
    }
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_animating)
        return;
    
    _dotView.center = CGPointZero;
    _smallView.center = CGPointZero;
    _shadowView.center = CGPointMake(TGScreenPixel, -36.0f);
    _backgroundView.center = CGPointMake(_shadowView.frame.size.width / 2.0f, _shadowView.frame.size.height / 2.0f);
    _iconView.center = CGPointMake(_shadowView.frame.size.width / 2.0f, _shadowView.frame.size.height / 2.0f - 5.0f);
    
    if (_liveLocation)
    {
        if (self.selected)
        {
            _avatarView.center = CGPointMake(TGScreenPixel, -41.0f);
            _avatarView.transform = CGAffineTransformIdentity;
        }
        else
        {
            _avatarView.center = CGPointZero;
            _avatarView.transform = CGAffineTransformMakeScale(0.64f, 0.64f);
        }
    }
    else
    {
        _avatarView.center = CGPointMake(TGScreenPixel, -41.0f);
        _avatarView.transform = CGAffineTransformIdentity;
    }
}

- (void)setPinRaised:(bool)raised
{
    [self setPinRaised:raised avatar:false animated:false completion:nil];
}

- (void)setPinRaised:(bool)raised avatar:(bool)avatar animated:(bool)animated completion:(void (^)(void))completion
{
    _pinRaised = raised;
    avatar = false;
    
    [_shadowView.layer removeAllAnimations];
    if (iosMajorVersion() < 7)
        animated = false;
    
    if (animated)
    {
        if (raised)
        {
            [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 | UIViewAnimationOptionAllowAnimatedContent animations:^
            {
                _shadowView.center = CGPointMake(TGScreenPixel, -66.0f);
                if (avatar)
                    _avatarView.center = CGPointMake(TGScreenPixel, -71.0f);
            } completion:^(BOOL finished) {
                if (finished && completion != nil)
                    completion();
            }];
        }
        else
        {
            [UIView animateWithDuration:0.2 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.0 options:UIViewAnimationOptionAllowAnimatedContent animations:^
            {
                _shadowView.center = CGPointMake(TGScreenPixel, -36.0f);
                if (avatar)
                    _avatarView.center = CGPointMake(TGScreenPixel, -41.0f);
            } completion:^(BOOL finished)
            {
                if (finished && completion != nil)
                    completion();
            }];
        }
    }
    else
    {
        _shadowView.center = CGPointMake(TGScreenPixel, raised ? -66.0f : -36.0f);
        if (avatar)
            _avatarView.center = CGPointMake(TGScreenPixel, raised ? -71.0 : -41.0f);
        
        if (completion != nil)
            completion();
    }
}

- (void)setCustomPin:(bool)customPin animated:(bool)animated
{
    if (animated)
    {
        _animating = true;
        UIImage *image = TGComponentsImageNamed(@"LocationPinIcon");
        if (_pallete != nil)
            image = TGTintedImage(image, _pallete.iconColor);
        
        _iconView.image = image;
        [_backgroundView addSubview:_avatarView];
        _avatarView.center = CGPointMake(_backgroundView.frame.size.width / 2.0f, _backgroundView.frame.size.height / 2.0f - 5.0f);
        _shadowView.center = CGPointMake(TGScreenPixel, -36.0f);
        _backgroundView.center = CGPointMake(_shadowView.frame.size.width / 2.0f, _shadowView.frame.size.height / 2.0f);
        _iconView.center = CGPointMake(_shadowView.frame.size.width / 2.0f, _shadowView.frame.size.height / 2.0f - 5.0f);
        
        TGDispatchAfter(0.01, dispatch_get_main_queue(), ^
        {
            [UIView transitionWithView:_backgroundView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent animations:^
             {
                 _backgroundView.image = customPin ? TGTintedImage(TGComponentsImageNamed(@"LocationPinBackground"), _pallete != nil ? _pallete.locationColor : UIColorRGB(0x008df2)) : TGComponentsImageNamed(@"LocationPinBackground");
                 _avatarView.hidden = customPin;
                 _iconView.hidden = !customPin;
             } completion:^(BOOL finished)
             {
                 if (!customPin)
                     [self addSubview:_avatarView];
                 _animating = false;
                 [self setNeedsLayout];
             }];
        });
        
        [self setNeedsLayout];
    }
    else
    {
        
    }
    
    _dotView.hidden = !customPin;
}

@end

@implementation TGLocationPinWrapperView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self)
        return nil;
    
    return view;
}

@end
