#import "TGMediaPickerPhotoStripCell.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "TGModernButton.h"
#import "TGCheckButtonView.h"
#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "TGMediaPickerGallerySelectedItemsModel.h"
#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGMediaEditingContext.h>

#import <LegacyComponents/TGVideoEditAdjustments.h>

#import "TGCameraCapturedVideo.h"
#import "TGMediaAsset+TGMediaEditableItem.h"

NSString *const TGMediaPickerPhotoStripCellKind = @"PhotoStripCell";

@interface TGMediaPickerPhotoStripDeleteButton : TGModernButton

@end

@interface TGMediaPickerPhotoStripCell ()
{
    TGMediaPickerPhotoStripDeleteButton *_deleteButton;
    TGCheckButtonView *_checkButton;
    UIImageView *_iconView;
    UIImageView *_gradientView;
    UILabel *_label;
    
    NSObject *_item;
    SMetaDisposable *_itemSelectedDisposable;
    bool _isGif;
    
    SMetaDisposable *_adjustmentsDisposable;
}

@property (nonatomic, readonly) TGImageView *imageView;

@end

@implementation TGMediaPickerPhotoStripCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        if (iosMajorVersion() >= 8)
            self.layer.cornerRadius = 4.0f;
        
        _imageView = [[TGImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        
        static dispatch_once_t onceToken;
        static UIImage *gradientImage;
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
            
            gradientImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _gradientView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _gradientView.image = gradientImage;
        _gradientView.hidden = true;
        [self addSubview:_gradientView];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
        
        _label = [[UILabel alloc] init];
        _label.textColor = [UIColor whiteColor];
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentRight;
        _label.font = TGSystemFontOfSize(12.0f);
        [_label sizeToFit];
        [self addSubview:_label];
    }
    return self;
}

- (void)dealloc
{
    [_itemSelectedDisposable dispose];
    [_adjustmentsDisposable dispose];
}

- (void)setItem:(NSObject *)item signal:(SSignal *)signal removable:(bool)removable
{
    _item = item;
    
    [_adjustmentsDisposable setDisposable:nil];
    
    if (removable)
    {
        if (_deleteButton == nil)
        {
            _deleteButton = [[TGMediaPickerPhotoStripDeleteButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
            [_deleteButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_deleteButton];
        }
    }
    else
    {
        if (self.selectionContext != nil)
        {
            if (_checkButton == nil)
            {
                _checkButton = [[TGCheckButtonView alloc] initWithStyle:TGCheckButtonStyleMedia];
                [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                [self addSubview:_checkButton];
            }
            
            if (_itemSelectedDisposable == nil)
                _itemSelectedDisposable = [[SMetaDisposable alloc] init];
            
            [self setChecked:[self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)item] animated:false];
            __weak TGMediaPickerPhotoStripCell *weakSelf = self;
            [_itemSelectedDisposable setDisposable:[[self.selectionContext itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item] startWithNext:^(TGMediaSelectionChange *next)
            {
                __strong TGMediaPickerPhotoStripCell *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (![next.sender isKindOfClass:[TGMediaPickerGallerySelectedItemsModel class]])
                    [strongSelf setChecked:next.selected animated:next.animated];
            }]];
        }
    }
    
    if (_item == nil)
    {
        [_imageView reset];
        return;
    }
    
    [_imageView setSignal:signal];
    
    if ([item isKindOfClass:[TGCameraCapturedVideo class]])
    {
        TGCameraCapturedVideo *video = (TGCameraCapturedVideo *)item;
        _gradientView.hidden = false;
        _label.text = [NSString stringWithFormat:@"%d:%02d", (int)ceil(video.videoDuration) / 60, (int)ceil(video.videoDuration) % 60];
        _iconView.image = TGComponentsImageNamed(@"ModernMediaItemVideoIcon");
        
        if (self.editingContext != nil)
        {
            SSignal *adjustmentsSignal = [self.editingContext adjustmentsSignalForItem:video];
            
            __weak TGMediaPickerPhotoStripCell *weakSelf = self;
            [_adjustmentsDisposable setDisposable:[adjustmentsSignal startWithNext:^(TGVideoEditAdjustments *next)
            {
                __strong TGMediaPickerPhotoStripCell *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if ([next isKindOfClass:[TGVideoEditAdjustments class]])
                    [strongSelf _layoutImageForOriginalSize:next.originalSize cropRect:next.cropRect cropOrientation:next.cropOrientation];
                else
                    [strongSelf _layoutImageWithoutAdjustments];
            }]];
        }
        return;
    }
    
    TGMediaAsset *asset = (TGMediaAsset *)item;
    if (![asset isKindOfClass:[TGMediaAsset class]])
        return;
    
    _isGif = false;
    
    switch (asset.type)
    {
        case TGMediaAssetVideoType:
        {
            _gradientView.hidden = false;
            _label.text = [NSString stringWithFormat:@"%d:%02d", (int)ceil(asset.videoDuration) / 60, (int)ceil(asset.videoDuration) % 60];
            
            if (asset.subtypes & TGMediaAssetSubtypeVideoTimelapse)
                _iconView.image = TGComponentsImageNamed(@"ModernMediaItemTimelapseIcon");
            else if (asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate)
                _iconView.image = TGComponentsImageNamed(@"ModernMediaItemSloMoIcon");
            else
                _iconView.image = TGComponentsImageNamed(@"ModernMediaItemVideoIcon");
            
            if (self.editingContext != nil)
            {
                SSignal *adjustmentsSignal = [self.editingContext adjustmentsSignalForItem:asset];
                
                __weak TGMediaPickerPhotoStripCell *weakSelf = self;
                [_adjustmentsDisposable setDisposable:[adjustmentsSignal startWithNext:^(TGVideoEditAdjustments *next)
                {
                    __strong TGMediaPickerPhotoStripCell *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if ([next isKindOfClass:[TGVideoEditAdjustments class]])
                        [strongSelf _layoutImageForOriginalSize:next.originalSize cropRect:next.cropRect cropOrientation:next.cropOrientation];
                    else
                        [strongSelf _layoutImageWithoutAdjustments];
                }]];
            }
        }
            break;
            
        case TGMediaAssetGifType:
        {
            _gradientView.hidden = false;
            _label.text = @"GIF";
            _iconView.image = nil;
            _isGif = true;
        }
            break;
            
        default:
        {
            _gradientView.hidden = true;
            _label.text = nil;
            _iconView.image = nil;
        }
            break;
    }
}

- (void)deleteButtonPressed
{
    if (self.itemRemoved != nil)
        self.itemRemoved();
}

- (void)checkButtonPressed
{
    [_checkButton setSelected:!_checkButton.selected animated:true];
    
    if (self.itemSelected != nil)
        self.itemSelected((id<TGMediaSelectableItem>)_item, _checkButton.selected, _checkButton);
}

- (void)setChecked:(bool)checked animated:(bool)animated
{
    [_checkButton setSelected:checked animated:animated];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_imageView reset];
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_checkButton != nil)
        _checkButton.frame = CGRectMake(self.bounds.size.width - _checkButton.frame.size.width, 0, _checkButton.frame.size.width, _checkButton.frame.size.height);

    if (_deleteButton != nil)
        _deleteButton.frame = CGRectMake(self.bounds.size.width - _deleteButton.frame.size.width, 0, _deleteButton.frame.size.width, _deleteButton.frame.size.height);
    
    if (!_gradientView.hidden)
        _gradientView.frame = CGRectMake(0, self.frame.size.height - 20.0f, self.frame.size.width, 20.0f);
    
    _iconView.frame = CGRectMake(0, self.frame.size.height - 19, 19, 19);
    
    [_label sizeToFit];
    CGSize durationSize = CGSizeMake(ceil(_label.frame.size.width), ceil(_label.frame.size.height));
    CGFloat x = _isGif ? 4 : self.frame.size.width - durationSize.width - 4;
    _label.frame = CGRectMake(x, self.frame.size.height - durationSize.height - 2, durationSize.width, durationSize.height);
}

@end


@implementation TGMediaPickerPhotoStripDeleteButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static dispatch_once_t onceToken;
        static UIImage *image;
        dispatch_once(&onceToken, ^
        {
            CGFloat insideInset = 4.0f;
            CGSize size = CGSizeMake(32.0f, 32.0f);

            CGRect rect = CGRectMake(0, 0, size.width, size.height);
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.7f).CGColor);
            CGContextFillEllipseInRect(context, CGRectInset(rect, insideInset + 0.5f, insideInset + 0.5f));
            
            CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.22f].CGColor);
            CGContextSetLineWidth(context, 1.5f);
            CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + 0.5f, insideInset + 0.5f));
            
            UIImage *icon = TGComponentsImageNamed(@"CameraDeleteIcon.png");
            [icon drawAtPoint:CGPointMake((size.width - icon.size.width) / 2.0f, (size.height - icon.size.height) / 2.0f)];
            
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        [self setImage:image forState:UIControlStateNormal];
        
        self.adjustsImageWhenHighlighted = false;
    }
    return self;
}

@end
