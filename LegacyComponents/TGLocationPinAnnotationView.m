#import "TGLocationPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGUser.h"
#import "TGConversation.h"
#import "TGLocationAnnotation.h"
#import "TGLocationMediaAttachment.h"

#import "TGImageView.h"
#import "TGLetteredAvatarView.h"

NSString *const TGLocationPinAnnotationKind = @"TGLocationPinAnnotation";

NSString *const TGLocationETAKey = @"eta";

@interface TGLocationPinAnnotationView ()
{
    UIImageView *_smallView;
    UIImageView *_shadowView;
    UIImageView *_backgroundView;
    TGImageView *_iconView;
    UIImageView *_dotView;
    TGLetteredAvatarView *_avatarView;
    
    bool _liveLocation;
    SMetaDisposable *_userDisposable;
    
    bool _animating;
}
@end

@implementation TGLocationPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation
{
    self = [super initWithAnnotation:annotation reuseIdentifier:TGLocationPinAnnotationKind];
    if (self != nil)
    {
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

- (void)prepareForReuse
{
    [_iconView reset];
    _smallView.hidden = true;
    _backgroundView.hidden = false;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
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
        _animating = true;
        if (selected)
        {
            UIView *avatarSnapshot = [_avatarView snapshotViewAfterScreenUpdates:false];
            [_smallView addSubview:avatarSnapshot];
            avatarSnapshot.transform = _avatarView.transform;
            avatarSnapshot.center = CGPointMake(_smallView.frame.size.width / 2.0f, _smallView.frame.size.height / 2.0f);
            
            _avatarView.transform = CGAffineTransformIdentity;
            [_backgroundView addSubview:_avatarView];
            _avatarView.center = CGPointMake(_backgroundView.frame.size.width / 2.0f, _backgroundView.frame.size.height / 2.0f - 5.0f);
            
            _dotView.alpha = 0.0f;
            _dotView.hidden = false;
            
            _shadowView.center = CGPointMake(_shadowView.center.x, _shadowView.center.y + _shadowView.frame.size.height / 2.0f);
            _shadowView.layer.anchorPoint = CGPointMake(0.5f, 1.0f);
            _shadowView.hidden = false;
            _shadowView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            [UIView animateWithDuration:0.35 delay:0.0 usingSpringWithDamping:0.6f initialSpringVelocity:0.5f options:kNilOptions animations:^
            {
                _smallView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
                _shadowView.transform = CGAffineTransformIdentity;
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
             } completion:^(BOOL finished) {
                 _dotView.alpha = 1.0f;
                 _dotView.hidden = true;
             }];
        }
    }
    else
    {
        _smallView.hidden = selected;
        _shadowView.hidden = !selected;
        _dotView.hidden = !selected;
        [self layoutSubviews];
    }
}

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    [super setAnnotation:annotation];
    
    bool ignoreInvertColors = false;
    if ([annotation isKindOfClass:[TGLocationPickerAnnotation class]])
    {
        _avatarView.hidden = false;
        _iconView.hidden = true;
        _dotView.hidden = true;
        
        _backgroundView.image = TGComponentsImageNamed(@"LocationPinBackground");
        
        _liveLocation = false;
        [self setPeer:((TGLocationPickerAnnotation *)annotation).peer];
    }
    else if ([annotation isKindOfClass:[TGLocationAnnotation class]])
    {
        _dotView.hidden = false;
        
        TGLocationMediaAttachment *location = ((TGLocationAnnotation *)annotation).location;
        if (location.period == 0)
        {
            _avatarView.hidden = true;
            _iconView.hidden = false;
            
            _backgroundView.image = TGTintedImage(TGComponentsImageNamed(@"LocationPinBackground"), UIColorRGB(0x008df2));
            if (location.venue.type.length > 0)
            {
                [_iconView loadUri:[NSString stringWithFormat:@"location-venue-icon://type=%@&width=%d&height=%d&color=%d", location.venue.type, 64, 64, 0xffffff] withOptions:nil];
            }
            else
            {
                [_iconView reset];
                _iconView.image = TGComponentsImageNamed(@"LocationPinIcon");
            }
            
            _liveLocation = false;
        }
        else
        {
            _avatarView.hidden = false;
            _iconView.hidden = true;
            
            _backgroundView.image = TGComponentsImageNamed(@"LocationPinBackground");
            
            [self setPeer:((TGLocationAnnotation *)annotation).peer];
            
            ignoreInvertColors = true;
            
            _liveLocation = true;
            
            if (!self.selected)
            {
                _shadowView.hidden = true;
                _smallView.hidden = false;
            }
        }
    }
    
    if (iosMajorVersion() >= 11)
    {
        _shadowView.accessibilityIgnoresInvertColors = ignoreInvertColors;
        _backgroundView.accessibilityIgnoresInvertColors = ignoreInvertColors;
        _dotView.accessibilityIgnoresInvertColors = ignoreInvertColors;
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
    NSString *avatarUrl = isUser ? ((TGUser *)peer).photoUrlSmall : ((TGConversation *)peer).chatPhotoSmall;
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

@end
