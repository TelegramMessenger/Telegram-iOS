#import "TGStickerKeyboardTabCell.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGDocumentMediaAttachment.h"
#import "TGStringUtils.h"

#import <LegacyComponents/TGImageView.h>
#import <LegacyComponents/TGRemoteImageView.h>

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
    TGRemoteImageView *_remoteImageView;
    TGStickerKeyboardViewStyle _style;
    bool _favorite;
    bool _recent;
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
        self.selectedBackgroundView.backgroundColor = UIColorRGB(0xe6e6e6);
        
        _imageView = [[TGImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_imageView];
    }
    return self;
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
    }
    else
    {
        _imageView.image = image;
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    if (_recent)
         [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardRecentTab.png")];
    else if (_favorite)
         [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardFavoriteTab.png")];
}

- (void)setFavorite
{
    _recent = false;
    _favorite = true;
    
    _remoteImageView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.contentMode = UIViewContentModeCenter;
    
    [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardFavoriteTab.png")];
}

- (void)setRecent
{
    _recent = true;
    _favorite = false;
    
    _remoteImageView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.contentMode = UIViewContentModeCenter;
    
    [self _updateIcon:TGComponentsImageNamed(@"StickerKeyboardRecentTab.png")];
}

- (void)setNone
{
    _recent = false;
    _favorite = false;
    
    _remoteImageView.hidden = true;
    _imageView.hidden = false;
    
    [_imageView reset];
    _imageView.image = nil;
}

- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia
{
    _recent = false;
    _favorite = false;
    
    _remoteImageView.hidden = true;
    _imageView.hidden = false;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    if (documentMedia.documentId != 0)
        [uri appendFormat:@"documentId=%" PRId64 "", documentMedia.documentId];
    else
        [uri appendFormat:@"localDocumentId=%" PRId64 "", documentMedia.localDocumentId];
    [uri appendFormat:@"&accessHash=%" PRId64 "", documentMedia.accessHash];
    [uri appendFormat:@"&datacenterId=%" PRId32 "", (int32_t)documentMedia.datacenterId];
    
    NSString *legacyThumbnailUri = [documentMedia.thumbnailInfo imageUrlForLargestSize:NULL];
    if (legacyThumbnailUri != nil)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    
    [uri appendFormat:@"&width=33&height=33"];
    [uri appendFormat:@"&highQuality=1"];
    
    [_imageView loadUri:uri withOptions:nil];
}

- (void)setUrl:(NSString *)url
{
    _recent = false;
    _favorite = false;
    
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    if (_remoteImageView == nil)
    {
        _remoteImageView = [[TGRemoteImageView alloc] initWithFrame:_imageView.frame];
        [_imageView.superview addSubview:_remoteImageView];
    }
    
    _remoteImageView.hidden = false;
    _imageView.hidden = true;
    [_remoteImageView loadImage:url filter:@"circle:37x37" placeholder:nil];
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
            self.selectedBackgroundView.backgroundColor = UIColorRGB(0xe6e7e9);
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
    _remoteImageView.transform = transform;
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
        setViewFrame(_remoteImageView, CGRectMake(CGFloor((self.frame.size.width - imageSide) / 2.0f), 4.0f, imageSide, imageSide));
        setViewFrame(self.selectedBackgroundView, CGRectMake(floor((self.frame.size.width - 36.0f) / 2.0f), 0, 36.0f, 36.0f));
    }
    else
    {
        _imageView.frame = CGRectMake(CGFloor((self.frame.size.width - imageSide) / 2.0f), 6.0f, imageSide, imageSide);
        _remoteImageView.frame = _imageView.frame;
        
        if (_style == TGStickerKeyboardViewPaintStyle)
        {
            self.selectedBackgroundView.frame = CGRectMake(floor((self.frame.size.width - self.frame.size.height) / 2.0f), 0, self.frame.size.height, self.frame.size.height);
        }
    }
}

@end
