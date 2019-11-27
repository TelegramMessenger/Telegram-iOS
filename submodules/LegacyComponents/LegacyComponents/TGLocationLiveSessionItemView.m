#import "TGLocationLiveSessionItemView.h"

#import "LegacyComponentsInternal.h"

#import "TGUser.h"
#import "TGConversation.h"

#import "TGLetteredAvatarView.h"
#import "TGLocationLiveElapsedView.h"

@interface TGLocationLiveSessionItemView ()
{
    TGLetteredAvatarView *_avatarView;
    TGLocationLiveElapsedView *_elapsedView;
    UILabel *_label;
    id<SDisposable> _disposable;
}
@end

@implementation TGLocationLiveSessionItemView

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer remaining:(SSignal *)remaining action:(void (^)(void))action
{
    bool isUser = [peer isKindOfClass:[TGUser class]];
    NSString *title = isUser ? ((TGUser *)peer).displayName : ((TGConversation *)peer).chatTitle;
    self = [super initWithTitle:@"" type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:action];
    if (self != nil)
    {
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = _button.titleLabel.font;
        _label.textColor = [UIColor blackColor];
        _label.text = title;
        [_label sizeToFit];
        [_button addSubview:_label];
        
        _avatarView = [[TGLetteredAvatarView alloc] init];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        [self addSubview:_avatarView];
        
        CGFloat diameter = 36.0f;
        
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
        
        NSString *avatarUrl = isUser ? ((TGUser *)peer).photoFullUrlSmall : ((TGConversation *)peer).chatPhotoFullSmall;
        if (avatarUrl.length != 0)
        {
            _avatarView.fadeTransitionDuration = 0.3;
            if (![avatarUrl isEqualToString:_avatarView.currentUrl])
                [_avatarView loadImage:avatarUrl filter:@"circle:36x36" placeholder:placeholder];
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
        
        _elapsedView = [[TGLocationLiveElapsedView alloc] init];
        [self addSubview:_elapsedView];
        
        TGLocationMediaAttachment *location = nil;
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGLocationMediaAttachmentType)
            {
                location = (TGLocationMediaAttachment *)attachment;
                break;
            }
        }
        
        __weak TGLocationLiveSessionItemView *weakSelf = self;
        _disposable = [remaining startWithNext:^(NSNumber *next)
        {
            __strong TGLocationLiveSessionItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_elapsedView setRemaining:next.intValue period:location.period];
        }];
    }
    return self;
}
         
- (void)dealloc
{
    [_disposable dispose];
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    [super setPallete:pallete];
    
    _label.textColor = pallete.textColor;
    [_elapsedView setColor:pallete.accentColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _label.frame = CGRectMake(74.0f, (self.frame.size.height - ceil(_label.frame.size.height)) / 2.0f, self.frame.size.width - 74.0f - 52.0f - 10.0f, ceil(_label.frame.size.height));
    _avatarView.frame = CGRectMake(23.0f, 11.0f, 36.0f, 36.0f);
    _elapsedView.frame = CGRectMake(self.frame.size.width - 30.0f - 22.0f, round((self.frame.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);
}

@end

