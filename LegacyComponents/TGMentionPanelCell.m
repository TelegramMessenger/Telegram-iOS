#import "TGMentionPanelCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"
#import "TGUser.h"
#import "TGImageUtils.h"

#import "TGLetteredAvatarView.h"
#import "TGModernConversationAssociatedInputPanel.h"

NSString *const TGMentionPanelCellKind = @"TGMentionPanelCell";

@interface TGMentionPanelCell ()
{
    TGModernConversationAssociatedInputPanelStyle _style;
    TGLetteredAvatarView *_avatarView;
    UILabel *_nameLabel;
    UILabel *_usernameLabel;
}

@end

@implementation TGMentionPanelCell

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGMentionPanelCellKind];
    if (self != nil)
    {
        _style = style;
        
        UIColor *backgroundColor = [UIColor whiteColor];
        UIColor *nameColor = [UIColor blackColor];
        UIColor *usernameColor = [UIColor blackColor];
        UIColor *selectionColor = TGSelectionColor();
        
        if (style == TGModernConversationAssociatedInputPanelDarkStyle)
        {
            backgroundColor = UIColorRGB(0x171717);
            nameColor = [UIColor whiteColor];
            usernameColor = UIColorRGB(0x828282);
            selectionColor = UIColorRGB(0x292929);            
        }
        else if (style == TGModernConversationAssociatedInputPanelDarkBlurredStyle)
        {
            backgroundColor = [UIColor clearColor];
            nameColor = [UIColor whiteColor];
            usernameColor = UIColorRGB(0x828282);
            selectionColor = UIColorRGB(0x3d3d3d);
        }
        
        self.backgroundColor = backgroundColor;
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = backgroundColor;
        self.backgroundView.opaque = false;
        
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = selectionColor;
        
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.textColor = nameColor;
        _nameLabel.font = TGMediumSystemFontOfSize(14.0f);
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLabel];
        
        _usernameLabel = [[UILabel alloc] init];
        _usernameLabel.backgroundColor = [UIColor clearColor];
        _usernameLabel.textColor = usernameColor;
        _usernameLabel.font = TGSystemFontOfSize(14.0f);
        _usernameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_usernameLabel];
        
    }
    return self;
}

- (void)setPallete:(TGConversationAssociatedInputPanelPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    _nameLabel.textColor = pallete.textColor;
    _usernameLabel.textColor = pallete.textColor;
    
    self.backgroundColor = pallete.backgroundColor;
    self.backgroundView.backgroundColor = self.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
}

- (void)setUser:(TGUser *)user
{
    _user = user;
    
    _nameLabel.text = user.displayName;
    _usernameLabel.text = user.userName.length == 0 ? @"" : [[NSString alloc] initWithFormat:@"@%@", user.userName];
    
    NSString *avatarUrl = user.photoFullUrlSmall;
    
    CGFloat diameter = 32.0f;
    
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
    
    UIImage *placeholder = staticPlaceholder;
    if (self.pallete != nil)
        placeholder = self.pallete.avatarPlaceholder;
        
    if (avatarUrl.length != 0)
    {
        _avatarView.fadeTransitionDuration = 0.3;
        if (![avatarUrl isEqualToString:_avatarView.currentUrl])
            [_avatarView loadImage:avatarUrl filter:@"circle:32x32" placeholder:placeholder];
    }
    else
    {
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(diameter, diameter) uid:user.uid firstName:user.firstName lastName:user.lastName placeholder:placeholder];
    }
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize boundsSize = self.bounds.size;
    
    _avatarView.frame = CGRectMake(7.0f + TGRetinaPixel, TGRetinaFloor((boundsSize.height - _avatarView.frame.size.height) / 2.0f), _avatarView.frame.size.width, _avatarView.frame.size.height);
    
    CGFloat leftInset = 51.0f;
    CGFloat spacing = 6.0f;
    CGFloat rightInset = 6.0f;
    
    CGSize nameSize = [_nameLabel.text sizeWithFont:_nameLabel.font];
    nameSize.width = CGCeil(MIN((boundsSize.width - leftInset - rightInset) * 3.0f / 4.0f, nameSize.width));
    nameSize.height = CGCeil(nameSize.height);
    
    CGSize usernameSize = [_usernameLabel.text sizeWithFont:_usernameLabel.font];
    usernameSize.width = CGCeil(MIN(boundsSize.width - leftInset - rightInset - nameSize.width - spacing, usernameSize.width));
    
    _nameLabel.frame = CGRectMake(leftInset, CGFloor((boundsSize.height - nameSize.height) / 2.0f), nameSize.width, nameSize.height);
    _usernameLabel.frame = CGRectMake(leftInset + nameSize.width + spacing, CGFloor((boundsSize.height - usernameSize.height) / 2.0f), usernameSize.width, usernameSize.height);
}

@end
