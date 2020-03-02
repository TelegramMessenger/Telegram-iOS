#import "TGMediaAssetsVideoCell.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>

#import <LegacyComponents/TGImageView.h>

NSString *const TGMediaAssetsVideoCellKind = @"TGMediaAssetsVideoCellKind";

@interface TGMediaAssetsVideoCell ()
{
    UIImageView *_shadowView;
    UIImageView *_iconView;
    UILabel *_durationLabel;
    
    SMetaDisposable *_adjustmentsDisposable;
}
@end

@implementation TGMediaAssetsVideoCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static UIImage *shadowImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 20.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGColorRef colors[2] = {
                CGColorRetain(UIColorRGBA(0x000000, 0.0f).CGColor),
                CGColorRetain(UIColorRGBA(0x000000, 0.8f).CGColor)
            };
            
            CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
            CGFloat locations[2] = {0.0f, 1.0f};
            
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
        
        _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, frame.size.height - 20, frame.size.width, 20)];
        _shadowView.image = shadowImage;
        [self addSubview:_shadowView];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
        
        _durationLabel = [[UILabel alloc] init];
        _durationLabel.textColor = [UIColor whiteColor];
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.textAlignment = NSTextAlignmentRight;
        _durationLabel.font = TGSystemFontOfSize(12.0f);
        [_durationLabel sizeToFit];
        [self addSubview:_durationLabel];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
        
        if (iosMajorVersion() >= 11)
        {
            _shadowView.accessibilityIgnoresInvertColors = true;
            _iconView.accessibilityIgnoresInvertColors = true;
            _durationLabel.accessibilityIgnoresInvertColors = true;
        }
        
        self.accessibilityLabel = TGLocalized(@"Message.Video");
    }
    return self;
}

- (void)dealloc
{
    [_adjustmentsDisposable dispose];
}

- (void)setItem:(NSObject *)item signal:(SSignal *)signal
{
    [super setItem:item signal:signal];
    
    TGMediaAsset *asset = (TGMediaAsset *)item;
    if (![asset isKindOfClass:[TGMediaAsset class]])
        return;
    
    
    NSString *durationString = nil;
    int duration = (int)ceil(asset.videoDuration);
    if (duration >= 3600)
        durationString = [NSString stringWithFormat:@"%d:%02d:%02d", duration / 3600, duration / 60, duration % 60];
    else
        durationString = [NSString stringWithFormat:@"%d:%02d", duration / 60, duration % 60];
        
    _durationLabel.text = durationString;
    
    if (asset.subtypes & TGMediaAssetSubtypeVideoTimelapse)
        _iconView.image = TGComponentsImageNamed(@"ModernMediaItemTimelapseIcon");
    else if (asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate)
        _iconView.image = TGComponentsImageNamed(@"ModernMediaItemSloMoIcon");
    else
        _iconView.image = TGComponentsImageNamed(@"ModernMediaItemVideoIcon");
    
    SSignal *adjustmentsSignal = [self.editingContext adjustmentsSignalForItem:(id<TGMediaEditableItem>)self.item];
    
    __weak TGMediaAssetsVideoCell *weakSelf = self;
    [_adjustmentsDisposable setDisposable:[adjustmentsSignal startWithNext:^(TGVideoEditAdjustments *next)
    {
        __strong TGMediaAssetsVideoCell *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([next isKindOfClass:[TGVideoEditAdjustments class]])
            [strongSelf _layoutImageForOriginalSize:next.originalSize cropRect:next.cropRect cropOrientation:next.cropOrientation];
        else
            [strongSelf _layoutImageWithoutAdjustments];
    }]];
}

- (void)_transformLayoutForOrientation:(UIImageOrientation)orientation originalSize:(CGSize *)inOriginalSize cropRect:(CGRect *)inCropRect
{
    if (inOriginalSize == NULL || inCropRect == NULL)
        return;
    
    CGSize originalSize = *inOriginalSize;
    CGRect cropRect = *inCropRect;
    
    if (orientation == UIImageOrientationLeft)
    {
        cropRect = CGRectMake(cropRect.origin.y, originalSize.width - cropRect.size.width - cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (orientation == UIImageOrientationRight)
    {
        cropRect = CGRectMake(originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (orientation == UIImageOrientationDown)
    {
        cropRect = CGRectMake(originalSize.width - cropRect.size.width - cropRect.origin.x, originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.size.width, cropRect.size.height);
    }
    
    *inOriginalSize = originalSize;
    *inCropRect = cropRect;
}

- (void)_layoutImageForOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation
{
    self.imageView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    
    [self _transformLayoutForOrientation:cropOrientation originalSize:&originalSize cropRect:&cropRect];
    
    CGFloat ratio = (cropRect.size.width > cropRect.size.height) ? self.frame.size.height / cropRect.size.height : self.frame.size.width / cropRect.size.width;
    CGSize fillSize = CGSizeMake(cropRect.size.width * ratio, cropRect.size.height * ratio);
    
    self.imageView.frame = CGRectMake(-cropRect.origin.x * ratio + (self.frame.size.width - fillSize.width) / 2, -cropRect.origin.y * ratio + (self.frame.size.height - fillSize.height) / 2, originalSize.width * ratio, originalSize.height * ratio);
}

- (void)_layoutImageWithoutAdjustments
{
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.frame = self.bounds;
}

- (UIImage *)transitionImage
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, 0.0f);
    
    UIImage *image = self.imageView.image;
    
    CGSize originalSize = CGSizeZero;
    CGRect cropRect = CGRectZero;
    UIImageOrientation cropOrientation = UIImageOrientationUp;
    
    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[self.editingContext adjustmentsForItem:(id<TGMediaEditableItem>)self.item];
    if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
    {
        originalSize = adjustments.originalSize;
        cropRect = adjustments.cropRect;
        cropOrientation = adjustments.cropOrientation;
        
        __block UIImage *editedImage = nil;
        [[self.editingContext thumbnailImageSignalForItem:(id<TGMediaEditableItem>)self.item withUpdates:false synchronous:true] startWithNext:^(UIImage *next)
        {
            editedImage = next;
        }];
        
        if (editedImage != nil)
            image = editedImage;
    }
    
    if (CGRectEqualToRect(cropRect, CGRectZero))
    {
        CGSize fillSize = TGScaleToFillSize(image.size, self.bounds.size);
        [image drawInRect:CGRectMake((self.bounds.size.width - fillSize.width) / 2, (self.bounds.size.height - fillSize.height) / 2, fillSize.width, fillSize.height)];
    }
    else
    {
        CGContextConcatCTM(UIGraphicsGetCurrentContext(), TGVideoCropTransformForOrientation(cropOrientation, self.frame.size, false));
        
        CGFloat ratio = (cropRect.size.width > cropRect.size.height) ? self.frame.size.height / cropRect.size.height : self.frame.size.width / cropRect.size.width;
        CGSize fillSize = CGSizeMake(cropRect.size.width * ratio, cropRect.size.height * ratio);
        
        [image drawInRect:CGRectMake(-cropRect.origin.x * ratio + (self.frame.size.width - fillSize.width) / 2, -cropRect.origin.y * ratio + (self.frame.size.height - fillSize.height) / 2, originalSize.width * ratio, originalSize.height * ratio)];
    }
    
    UIImage *transitionImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return transitionImage;
}

- (void)layoutSubviews
{
    self.checkButton.frame = (CGRect){ { self.frame.size.width - self.checkButton.frame.size.width - 2, 2 }, self.checkButton.frame.size };
    _shadowView.frame = (CGRect){ { 0, self.frame.size.height - _shadowView.frame.size.height }, {self.frame.size.width, _shadowView.frame.size.height } };
    _iconView.frame = CGRectMake(0, self.frame.size.height - 19, 19, 19);
    _durationLabel.frame = (CGRect){ { 5, _shadowView.frame.origin.y }, {self.frame.size.width - 5 - 4, _shadowView.frame.size.height } };
}

@end
