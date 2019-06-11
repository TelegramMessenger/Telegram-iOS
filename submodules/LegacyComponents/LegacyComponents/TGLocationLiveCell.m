#import "TGLocationLiveCell.h"
#import "TGLocationVenueCell.h"

#import "TGLocationMapViewController.h"
#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGDateUtils.h"
#import "TGLocationUtils.h"

#import "TGUser.h"
#import "TGMessage.h"
#import "TGConversation.h"
#import "TGLocationMediaAttachment.h"

#import "TGLetteredAvatarView.h"
#import "TGLocationWavesView.h"
#import "TGLocationLiveElapsedView.h"

NSString *const TGLocationLiveCellKind = @"TGLocationLiveCell";
const CGFloat TGLocationLiveCellHeight = 68;

@interface TGLocationLiveCell ()
{
    UIView *_highlightView;
    
    UIImageView *_circleView;
    UIImageView *_iconView;
    TGLocationWavesView *_wavesView;
    TGLetteredAvatarView *_avatarView;
    
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    TGLocationLiveElapsedView *_elapsedView;
    
    UIView *_separatorView;
    
    SMetaDisposable *_locationDisposable;
    SMetaDisposable *_remainingDisposable;
    
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@end

@implementation TGLocationLiveCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = [UIColor clearColor];

        _highlightView = [[UIView alloc] initWithFrame:self.bounds];
        _highlightView.alpha = 0.0f;
        _highlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _highlightView.backgroundColor = TGSelectionColor();
        _highlightView.userInteractionEnabled = false;
        [self.contentView addSubview:_highlightView];
        
        _circleView = [[UIImageView alloc] init];
        [self.contentView addSubview:_circleView];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [_circleView addSubview:_iconView];
        
        _avatarView = [[TGLetteredAvatarView alloc] init];
        [_avatarView setSingleFontSize:22.0f doubleFontSize:22.0f useBoldFont:false];
        [self.contentView addSubview:_avatarView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(16.0);
        _titleLabel.text = TGLocalized(@"Map.SendMyCurrentLocation");
        _titleLabel.textColor = TGAccentColor();
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13);
        _subtitleLabel.text = TGLocalized(@"Map.Locating");
        _subtitleLabel.textColor = UIColorRGB(0xa6a6a6);
        [self.contentView addSubview:_subtitleLabel];
        
        _elapsedView = [[TGLocationLiveElapsedView alloc] init];
        [self.contentView addSubview:_elapsedView];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = TGSeparatorColor();
        [self addSubview:_separatorView];
        
        _wavesView = [[TGLocationWavesView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
        [_circleView addSubview:_wavesView];
        
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        [self addGestureRecognizer:_longPressGestureRecognizer];
    }
    return self;
}

- (void)dealloc
{
    [_locationDisposable dispose];
    [_wavesView invalidate];
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    _highlightView.backgroundColor = pallete.selectionColor;
    _titleLabel.textColor = pallete.accentColor;
    _subtitleLabel.textColor = pallete.secondaryTextColor;
    _separatorView.backgroundColor = pallete.separatorColor;
    _wavesView.color = pallete.iconColor;
    [_elapsedView setColor:pallete.accentColor];
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        if (self.longPressed != nil)
            self.longPressed();
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _highlightView.alpha = highlighted ? 1.0f : 0.0f;
            _edgeView.alpha = highlighted ? 1.0f : 0.0f;
        }];
    }
    else
    {
        _highlightView.alpha = highlighted ? 1.0f : 0.0f;
        _edgeView.alpha = highlighted ? 1.0f : 0.0f;
    }
}

- (void)configureWithPeer:(id)peer message:(TGMessage *)message remaining:(SSignal *)remaining userLocationSignal:(SSignal *)userLocationSignal
{
    bool changed = message.mid != _messageId;
    _messageId = message.mid;
    
    _circleView.hidden = true;
    _avatarView.hidden = false;

    CGFloat diameter = 48.0f;
    
    static UIImage *staticPlaceholder = nil;
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
        
        staticPlaceholder = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    UIImage *placeholder = _pallete != nil ? _pallete.avatarPlaceholder : staticPlaceholder;
    
    bool isUser = [peer isKindOfClass:[TGUser class]];
    NSString *avatarUrl = isUser ? ((TGUser *)peer).photoFullUrlSmall : ((TGConversation *)peer).chatPhotoFullSmall;
    if (avatarUrl.length != 0)
    {
        _avatarView.fadeTransitionDuration = 0.3;
        if (![avatarUrl isEqualToString:_avatarView.currentUrl])
            [_avatarView loadImage:avatarUrl filter:@"circle:48x48" placeholder:placeholder];
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
    
    _titleLabel.textColor = _pallete != nil ? _pallete.textColor : [UIColor blackColor];
    _titleLabel.text = isUser ? ((TGUser *)peer).displayName : ((TGConversation *)peer).chatTitle;
    
    NSString *subtitle = [TGDateUtils stringForRelativeUpdate:[message actualDate]];
    _subtitleLabel.text = subtitle;
    
    TGLocationMediaAttachment *locationAttachment = message.locationAttachment;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:locationAttachment.latitude longitude:locationAttachment.longitude];
    __weak TGLocationLiveCell *weakSelf = self;
    if (_locationDisposable == nil)
        _locationDisposable = [[SMetaDisposable alloc] init];
    [_locationDisposable setDisposable:[userLocationSignal startWithNext:^(CLLocation *next)
    {
        __strong TGLocationLiveCell *strongSelf = weakSelf;
        if (strongSelf != nil && next != nil)
        {
            CGFloat distance = [next distanceFromLocation:location];
            NSString *distanceString = [NSString stringWithFormat:TGLocalized(@"Map.DistanceAway"), [TGLocationUtils stringFromDistance:distance]];
            strongSelf->_subtitleLabel.text = [NSString stringWithFormat:@"%@ • %@", subtitle, distanceString];
        }
    }]];
    
    if (changed)
    {
        _elapsedView.hidden = false;
        
        _avatarView.alpha = 1.0f;
        [self setNeedsLayout];
        
        if (_remainingDisposable == nil)
            _remainingDisposable = [[SMetaDisposable alloc] init];
        
        [_remainingDisposable setDisposable:[remaining startWithNext:^(NSNumber *next)
        {
            __strong TGLocationLiveCell *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_elapsedView setRemaining:next.intValue period:locationAttachment.period];
        } completed:^
        {
            __strong TGLocationLiveCell *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_elapsedView.hidden = true;
                strongSelf->_avatarView.alpha = 0.5f;
                [strongSelf setNeedsLayout];
            }
        }]];
    }
}

- (void)configureForStart
{
    _messageId = 0;
    
    _avatarView.hidden = true;
    _circleView.hidden = false;
    _elapsedView.hidden = true;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessageLiveIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    
    _iconView.image = icon;
    [self setCircleColor:_pallete != nil ? _pallete.liveLocationColor : UIColorRGB(0xff6464)];
    
    _titleLabel.textColor = _pallete != nil ? _pallete.accentColor : TGAccentColor();
    _titleLabel.text = TGLocalized(@"Map.ShareLiveLocation");
    _subtitleLabel.text = TGLocalized(@"Map.ShareLiveLocationHelp");
    
    [_wavesView stop];
    _wavesView.hidden = true;

    [_locationDisposable setDisposable:nil];
    [_remainingDisposable setDisposable:nil];
    
    [self setNeedsLayout];
}

- (void)configureForStopWithMessage:(TGMessage *)message remaining:(SSignal *)remaining
{
    bool changed = message.mid != _messageId;
    _messageId = message.mid;
    
    _avatarView.hidden = true;
    _circleView.hidden = false;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessagePinIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    _iconView.image = icon;
    [self setCircleColor:_pallete != nil ? _pallete.liveLocationColor : UIColorRGB(0xff6464)];
    
    _titleLabel.textColor = _pallete != nil ? _pallete.destructiveColor : UIColorRGB(0xff3b2f);
    _titleLabel.text = TGLocalized(@"Map.StopLiveLocation");
    _subtitleLabel.text = [TGDateUtils stringForRelativeUpdate:[message actualDate]];
    
    _wavesView.hidden = false;
    _wavesView.color = _pallete != nil ? _pallete.iconColor : [UIColor whiteColor];
    [_wavesView start];
    
    [_locationDisposable setDisposable:nil];
    
    if (changed)
    {
        _elapsedView.hidden = false;
        [self setNeedsLayout];
        
        TGLocationMediaAttachment *locationAttachment = message.locationAttachment;
        if (_remainingDisposable == nil)
            _remainingDisposable = [[SMetaDisposable alloc] init];
        
        __weak TGLocationLiveCell *weakSelf = self;
        [_remainingDisposable setDisposable:[remaining startWithNext:^(NSNumber *next)
        {
            __strong TGLocationLiveCell *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_elapsedView setRemaining:next.intValue period:locationAttachment.period];
        } completed:^
        {
            __strong TGLocationLiveCell *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_elapsedView.hidden = true;
                [strongSelf setNeedsLayout];
            }
        }]];
    }
}

- (void)setCircleColor:(UIColor *)color
{
    UIImage *circleImage = [TGLocationVenueCell circleImage];
    _circleView.image = TGTintedImage(circleImage, color);
}

- (void)setSafeInset:(UIEdgeInsets)safeInset
{
    _safeInset = safeInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _circleView.frame = CGRectMake(12.0f + self.safeInset.left, 12.0f, 48.0f, 48.0f);
    _iconView.frame = _circleView.bounds;
    _avatarView.frame = _circleView.frame;
    
    CGFloat padding = 76.0f + self.safeInset.left;
    CGFloat separatorThickness = TGScreenPixel;
    
    _titleLabel.frame = CGRectMake(padding, 14, self.frame.size.width - padding - 14 - (_elapsedView.hidden ? 0.0f : 38.0f) - self.safeInset.right, 20);
    _subtitleLabel.frame = CGRectMake(padding, 36, self.frame.size.width - padding - 14 - (_elapsedView.hidden ? 0.0f : 38.0f) - self.safeInset.right, 20);
    _separatorView.frame = CGRectMake(padding, self.frame.size.height - separatorThickness, self.frame.size.width - padding, separatorThickness);
    _elapsedView.frame = CGRectMake(self.frame.size.width - 30.0f - 15.0f - self.safeInset.right, floor((self.frame.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);
}

@end
