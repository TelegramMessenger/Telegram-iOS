#import "TGStickerKeyboardTabCell.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGDocumentMediaAttachment.h"
#import "TGStringUtils.h"

#import "TGLetteredAvatarView.h"

#import <LegacyComponents/TGImageView.h>

static void setViewFrame(UIView *view, CGRect frame)
{
    CGAffineTransform transform = view.transform;
    view.transform = CGAffineTransformIdentity;
    if (!CGRectEqualToRect(view.frame, frame))
        view.frame = frame;
    view.transform = transform;
}

@interface TGStickerKeyboardTabCell ()
{
    TGImageView *_imageView;
    TGLetteredAvatarView *_avatarView;
    TGStickerKeyboardViewStyle _style;
    bool _favorite;
    bool _recent;
    
    TGStickerKeyboardPallete *_pallete;
}

@end

@implementation TGStickerKeyboardTabCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _style = TGStickerKeyboardViewDefaultStyle;
        
        self.clipsToBounds = true;
        self.selectedBackgroundView = [[UIView alloc] init];
        
        _imageView = [[TGImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_imageView];
    }
    return self;
}

- (void)setPallete:(TGStickerKeyboardPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [_imageView reset];
}

- (void)_updateIcon:(UIImage *)image
{
    if (_style == TGStickerKeyboardViewPaintDarkStyle)
    {
        UIColor *color = self.selected ? [UIColor blackColor] : UIColorRGB(0xb4b5b5);
        _imageView.image = TGTintedImage(image, color);
        
        if (iosMajorVersion() >= 11)
            _imageView.accessibilityIgnoresInvertColors = true;
    }
    else
    {
        _imageView.image = image;
        
        if (iosMajorVersion() >= 11)
            _imageView.accessibilityIgnoresInvertColors = false;
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    if (_pallete != nil)
    {
        if (_recent)
            [self _updateIcon:_pallete.recentIcon];
        else if (_favorite)
            [self _updateIcon:_pallete.favoritesIcon];
    }
    else
    {
        if (_recent)
            [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardRecentTab.png")];
        else if (_favorite)
            [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardFavoriteTab.png")];
    }
}

- (void)setFavorite
{
    _recent = false;
    _favorite = true;
    
    _avatarView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.contentMode = UIViewContentModeCenter;
    
    [self _updateIcon:_pallete != nil ? _pallete.favoritesIcon : TGComponentsImageNamed(@"StickerKeyboardFavoriteTab.png")];
}

- (void)setRecent
{
    _recent = true;
    _favorite = false;
    
    _avatarView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.contentMode = UIViewContentModeCenter;
    
    [self _updateIcon:_pallete != nil ? _pallete.recentIcon : TGComponentsImageNamed(@"StickerKeyboardRecentTab.png")];
}

- (void)setNone
{
    _recent = false;
    _favorite = false;
    
    _avatarView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.image = nil;
}

- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia
{
    _recent = false;
    _favorite = false;
    
    _avatarView.hidden = true;
    _imageView.hidden = false;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    if (documentMedia.documentId != 0)
    {
        [uri appendFormat:@"documentId=%" PRId64 "", documentMedia.documentId];
        
        TGMediaOriginInfo *originInfo = documentMedia.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:documentMedia];
        if (originInfo != nil)
            [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    }
    else
    {
        [uri appendFormat:@"localDocumentId=%" PRId64 "", documentMedia.localDocumentId];
    }
    [uri appendFormat:@"&accessHash=%" PRId64 "", documentMedia.accessHash];
    [uri appendFormat:@"&datacenterId=%" PRId32 "", (int32_t)documentMedia.datacenterId];
    
    NSString *legacyThumbnailUri = [documentMedia.thumbnailInfo imageUrlForLargestSize:NULL];
    if (legacyThumbnailUri != nil)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    
    [uri appendFormat:@"&width=33&height=33"];
    [uri appendFormat:@"&highQuality=1"];
    
    [_imageView loadUri:uri withOptions:nil];
    
    if (iosMajorVersion() >= 11)
        _imageView.accessibilityIgnoresInvertColors = true;
}

- (void)setUrl:(NSString *)avatarUrl peerId:(int64_t)peerId title:(NSString *)title
{
    _recent = false;
    _favorite = false;
    
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGFloat diameter = 32.0f;
    
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
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:_imageView.frame];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        [_imageView.superview addSubview:_avatarView];
    }
    
    if (avatarUrl.length != 0)
    {
        _avatarView.fadeTransitionDuration = 0.3;
        if (![avatarUrl isEqualToString:_avatarView.currentUrl])
            [_avatarView loadImage:avatarUrl filter:@"circle:32x32" placeholder:placeholder];
    }
    else
    {
        [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(diameter, diameter) conversationId:peerId title:title placeholder:placeholder];
    }
    
    _avatarView.hidden = false;
    _imageView.hidden = true;
}

- (void)setStyle:(TGStickerKeyboardViewStyle)style
{
    _style = style;
    
    switch (style)
    {
        case TGStickerKeyboardViewDarkBlurredStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGB(0x393939);
        }
            break;
            
        case TGStickerKeyboardViewPaintStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGB(0xdadada);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
        }
            break;
            
        case TGStickerKeyboardViewPaintDarkStyle:
        {
            self.selectedBackgroundView.backgroundColor = UIColorRGBA(0xfbfffe, 0.47f);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
            
            if (_recent)
                [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardRecentTab.png")];
            else if (_favorite)
                [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardFavoriteTab.png")];
        }
            break;
            
        default:
        {
            self.selectedBackgroundView.backgroundColor = _pallete != nil ? _pallete.selectionColor : UIColorRGB(0xe6e7e9);
            self.selectedBackgroundView.layer.cornerRadius = 8.0f;
            self.selectedBackgroundView.clipsToBounds = true;
        }
            break;
    }
}

- (void)setInnerAlpha:(CGFloat)innerAlpha
{
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 36.0f / 2.0f * (1.0f - innerAlpha));
    transform = CGAffineTransformScale(transform, innerAlpha, innerAlpha);
    
    _imageView.transform = transform;
    _avatarView.transform = transform;
    self.selectedBackgroundView.transform = transform;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat imageSide = 33.0f;
    
    if (_style == TGStickerKeyboardViewDefaultStyle)
    {
        imageSide = 28.0f;
        setViewFrame(_imageView, CGRectMake(CGFloor((self.frame.size.width - imageSide) / 2.0f), 4.0f, imageSide, imageSide));
        setViewFrame(_avatarView, CGRectMake(CGFloor((self.frame.size.width - imageSide) / 2.0f), 4.0f, imageSide, imageSide));
        setViewFrame(self.selectedBackgroundView, CGRectMake(floor((self.frame.size.width - 36.0f) / 2.0f), 0, 36.0f, 36.0f));
    }
    else
    {
        _imageView.frame = CGRectMake(CGFloor((self.frame.size.width - imageSide) / 2.0f), 6.0f, imageSide, imageSide);
        _avatarView.frame = _imageView.frame;
        
        if (_style == TGStickerKeyboardViewPaintStyle)
        {
            self.selectedBackgroundView.frame = CGRectMake(floor((self.frame.size.width - self.frame.size.height) / 2.0f), 0, self.frame.size.height, self.frame.size.height);
        }
    }
}

@end
