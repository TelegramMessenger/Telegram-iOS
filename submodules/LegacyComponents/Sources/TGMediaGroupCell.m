#import "TGMediaGroupCell.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"
#import "TGColor.h"

#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGMediaAssetGroup.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGMediaAssetsController.h>

NSString *const TGMediaGroupCellKind = @"TGMediaGroupCellKind";
const CGFloat TGMediaGroupCellHeight = 86.0f;

@interface TGMediaGroupImageView : TGImageView

@end

@implementation TGMediaGroupImageView

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    if (self.backgroundColor != nil)
        return;
    
    [super setBackgroundColor:backgroundColor];
}

@end


@interface TGMediaGroupCell ()
{
    NSArray *_imageViews;
    NSArray *_borderViews;
    
    UIImageView *_shadowView;
    UIImageView *_iconView;
    
    UILabel *_nameLabel;
    UILabel *_countLabel;
    
    UIImageView *_disclosureIconView;
}
@end

@implementation TGMediaGroupCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = TGSelectionColor();
        
        static UIImage *shadowImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 20.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGColorRef colors[2] =
            {
                CGColorRetain(UIColorRGBA(0x000000, 0.0f).CGColor),
                CGColorRetain(UIColorRGBA(0x000000, 0.8f).CGColor)
            };
            
            CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
            CGFloat locations[2] = { 0.0f, 1.0f };
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
            
            CFRelease(colorsArray);
            CFRelease(colors[0]);
            CFRelease(colors[1]);
            
            CGColorSpaceRelease(colorSpace);
            
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, 20.0f), 0);
            
            CFRelease(gradient);
            
            shadowImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        TGImageView *imageView2 = [[TGMediaGroupImageView alloc] initWithFrame:CGRectMake(12.0f, 7.0f, 61.0f, 61.0f)];
        imageView2.backgroundColor = UIColorRGB(0xefeff4);
        imageView2.clipsToBounds = true;
        imageView2.contentMode = UIViewContentModeScaleAspectFill;
        imageView2.tag = 102;
        [self.contentView addSubview:imageView2];
        
        TGImageView *imageView1 = [[TGMediaGroupImageView alloc] initWithFrame:CGRectMake(10.0f, 9.0f, 65.0f, 65.0f)];
        imageView1.backgroundColor = UIColorRGB(0xefeff4);
        imageView1.clipsToBounds = true;
        imageView1.contentMode = UIViewContentModeScaleAspectFill;
        imageView1.tag = 101;
        [self.contentView addSubview:imageView1];
        
        TGImageView *imageView0 = [[TGMediaGroupImageView alloc] initWithFrame:CGRectMake(8.0f, 11.0f, 69.0f, 69.0f)];
        imageView0.backgroundColor = UIColorRGB(0xefeff4);
        imageView0.clipsToBounds = true;
        imageView0.contentMode = UIViewContentModeScaleAspectFill;
        imageView0.tag = 100;
        [self.contentView addSubview:imageView0];
        
        _imageViews = @[ imageView0, imageView1, imageView2 ];
        for (TGImageView *view in _imageViews)
            [self _addBorderViewForImageView:view];
        
        _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(imageView0.frame.origin.x, imageView0.frame.origin.y + imageView0.frame.size.height - 20, imageView0.frame.size.width, 20)];
        _shadowView.image = shadowImage;
        [self.contentView addSubview:_shadowView];
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 59, 19, 19)];
        _iconView.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:_iconView];
        
        if (@available(iOS 11.0, *)) {
            _shadowView.accessibilityIgnoresInvertColors = true;
            _iconView.accessibilityIgnoresInvertColors = true;
        }
        
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(96, 24, 0, 0)];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.contentMode = UIViewContentModeLeft;
        _nameLabel.font = TGSystemFontOfSize(17);
        _nameLabel.textColor = [UIColor blackColor];
        [self.contentView addSubview:_nameLabel];
        
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(96, 49, 0, 0)];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.contentMode = UIViewContentModeLeft;
        _countLabel.font = TGSystemFontOfSize(13);
        _countLabel.textColor = [UIColor blackColor];
        [self.contentView addSubview:_countLabel];
        
        UIImageView *disclosureIndicator = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"ModernListsDisclosureIndicator")];
        disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        disclosureIndicator.frame = CGRectOffset(disclosureIndicator.frame, self.contentView.frame.size.width - disclosureIndicator.frame.size.width - 15, 37);
        [self.contentView addSubview:disclosureIndicator];
    }
    return self;
}

- (void)setPallete:(TGMediaAssetsPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
        
    _nameLabel.textColor = pallete.textColor;
    _countLabel.textColor = pallete.textColor;
    
    for (TGImageView *view in _imageViews)
    {
        view.backgroundColor = nil;
    }
    
    for (UIView *view in _borderViews)
    {
        view.backgroundColor = self.backgroundColor;
    }
}

- (void)_addBorderViewForImageView:(TGImageView *)imageView
{
    static UIImage *borderImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
        
        borderImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    CGFloat thickness = 1.0f - TGRetinaPixel;
    CGRect rect = imageView.frame;
    
    UIImageView *borderView = [[UIImageView alloc] initWithFrame:CGRectMake(rect.origin.x - thickness, rect.origin.y - thickness, rect.size.width + thickness * 2, rect.size.height + thickness * 2)];
    borderView.backgroundColor = [UIColor whiteColor];
    borderView.image = borderImage;
    [imageView.superview insertSubview:borderView belowSubview:imageView];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    for (TGImageView *imageView in _imageViews)
        [imageView reset];
}

- (void)configureThumbnailsWithAssets:(NSArray *)assets
{
    if (assets.count > 0)
    {
        for (NSUInteger i = 0; i < _imageViews.count; i++)
        {
            TGImageView *imageView = _imageViews[i];
            UIView *borderView = _borderViews[i];
            
            if (i < assets.count)
            {
                imageView.hidden = false;
                borderView.hidden = false;
                
                [imageView setSignal:[TGMediaAssetImageSignals imageForAsset:assets[i]
                                                                   imageType:TGMediaAssetImageTypeThumbnail
                                                                        size:CGSizeMake(138, 138)]];
                
                if (@available(iOS 11.0, *)) {
                    imageView.accessibilityIgnoresInvertColors = true;
                }
            }
            else
            {
                imageView.hidden = true;
                borderView.hidden = true;
                
                [imageView reset];
                
                if (@available(iOS 11.0, *)) {
                    imageView.accessibilityIgnoresInvertColors = false;
                }
            }
        }
    }
    else
    {
        for (NSUInteger i = 0; i < _imageViews.count; i++)
        {
            TGImageView *imageView = _imageViews[i];
            UIView *borderView = _borderViews[i];
            
            imageView.hidden = false;
            borderView.hidden = false;
            
            [imageView reset];
            
            if (@available(iOS 11.0, *)) {
                imageView.accessibilityIgnoresInvertColors = false;
            }
        }
        
        [(TGImageView *)_imageViews.firstObject setImage:TGComponentsImageNamed(@"ModernMediaEmptyAlbumIcon")];
    }
}

- (void)configureForAssetGroup:(TGMediaAssetGroup *)assetGroup
{
    _assetGroup = assetGroup;
    
    _nameLabel.text = assetGroup.title;
    if (assetGroup.assetCount == -1)
        _countLabel.text = @"";
    else
        _countLabel.text = [[NSString alloc] initWithFormat:@"%ld", (long)assetGroup.assetCount];
    [self setNeedsLayout];
    
    bool hideThumbnail = false;
    UIImage *iconImage = nil;
    switch (assetGroup.subtype)
    {
        case TGMediaAssetGroupSubtypeFavorites:
            iconImage = TGComponentsImageNamed(@"MediaGroupFavorites");
            break;
            
        case TGMediaAssetGroupSubtypePanoramas:
            iconImage = TGComponentsImageNamed(@"MediaGroupPanoramas");
            break;
            
        case TGMediaAssetGroupSubtypeVideos:
            iconImage = TGComponentsImageNamed(@"MediaGroupVideo");
            break;
            
        case TGMediaAssetGroupSubtypeBursts:
            iconImage = TGComponentsImageNamed(@"MediaGroupBurst");
            break;
            
        case TGMediaAssetGroupSubtypeSlomo:
            iconImage = TGComponentsImageNamed(@"MediaGroupSlomo");
            break;
            
        case TGMediaAssetGroupSubtypeTimelapses:
            iconImage = TGComponentsImageNamed(@"MediaGroupTimelapse");
            break;
            
        case TGMediaAssetGroupSubtypeScreenshots:
            iconImage = TGComponentsImageNamed(@"MediaGroupScreenshots");
            break;
            
        case TGMediaAssetGroupSubtypeSelfPortraits:
            iconImage = TGComponentsImageNamed(@"MediaGroupSelfPortraits");
            break;
            
        case TGMediaAssetGroupSubtypeHidden:
            hideThumbnail = true;
        default:
            break;
    }
    
    [self configureThumbnailsWithAssets:hideThumbnail ? @[] : [assetGroup latestAssets]];
    
    _iconView.image = iconImage;
    _iconView.hidden = (iconImage == nil);
    _shadowView.hidden = _iconView.hidden;
}

- (void)configureForMomentList:(TGMediaAssetMomentList *)momentList
{
    _nameLabel.text = TGLocalized(@"Moments");
    _countLabel.text = @"";
    [self setNeedsLayout];
    
    [self configureThumbnailsWithAssets:[momentList latestAssets]];
    
    _iconView.image = nil;
    _iconView.hidden = true;
    _shadowView.hidden = true;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat y = 24;
    if (_countLabel.text.length == 0)
        y = 33;
        
    CGSize titleSize = [_nameLabel sizeThatFits:CGSizeMake(self.contentView.frame.size.width - _nameLabel.frame.origin.x - 20, _nameLabel.frame.size.height)];
    _nameLabel.frame = CGRectMake(_nameLabel.frame.origin.x, y, ceil(titleSize.width), ceil(titleSize.height));

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGSize countSize = [_countLabel.text sizeWithFont:_countLabel.font];
#pragma clang diagnostic pop
    _countLabel.frame = (CGRect){ _countLabel.frame.origin, { ceil(countSize.width), ceil(countSize.height) } };
}

@end
