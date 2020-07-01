#import "TGMediaPickerGalleryVideoScrubberThumbnailView.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

@interface TGMediaPickerGalleryVideoScrubberThumbnailView ()
{
    CGSize _originalSize;
    
    UIImageView *_imageView;
    UIView *_stripeView;
}
@end

@implementation TGMediaPickerGalleryVideoScrubberThumbnailView

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.image = image;
        [self addSubview:_imageView];
        
        _stripeView = [[UIView alloc] init];
        _stripeView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
        [self addSubview:_stripeView];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image originalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored
{
    self = [self initWithImage:image];
    if (self != nil)
    {
        _originalSize = originalSize;
        _cropRect = cropRect;
        _cropOrientation = cropOrientation;
        _cropMirrored = cropMirrored;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
        
    [self updateCropping];
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    _imageView.image = image;
}

- (void)setImage:(UIImage *)image animated:(bool)animated
{
    if (animated) {
        UIView *snapshotView = [self snapshotViewAfterScreenUpdates:false];
        [self addSubview:snapshotView];
        
        [self setImage:image];
        
        [UIView animateWithDuration:0.2f animations:^
        {
            snapshotView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    } else {
        [self setImage:image];
    }
}

- (void)updateCropping {
    [self updateCropping:false];
}
    
- (void)updateCropping:(bool)animated {
    if (_imageView.image == nil || _cropRect.size.width < FLT_EPSILON)
        return;
    
    UIView *snapshotView;
    if (animated) {
        snapshotView = [self snapshotViewAfterScreenUpdates:false];
        [self addSubview:snapshotView];
    }
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(TGRotationForOrientation(_cropOrientation));
    if (_cropMirrored)
        transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
    _imageView.transform = transform;
    
    CGRect cropRect = _cropRect;
    CGSize originalSize = _originalSize;
    
    if (_cropOrientation == UIImageOrientationLeft)
    {
        cropRect = CGRectMake(cropRect.origin.y, originalSize.width - cropRect.size.width - cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (_cropOrientation == UIImageOrientationRight)
    {
        cropRect = CGRectMake(originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (_cropOrientation == UIImageOrientationDown)
    {
        cropRect = CGRectMake(originalSize.width - cropRect.size.width - cropRect.origin.x, originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.size.width, cropRect.size.height);
    }
    
    CGFloat ratio = self.bounds.size.width / cropRect.size.width;
    _imageView.frame = CGRectMake(-cropRect.origin.x * ratio, -cropRect.origin.y * ratio, originalSize.width * ratio, originalSize.height * ratio);
    
    CGFloat thickness = 1.0f - TGRetinaPixel;
    _stripeView.frame = CGRectMake(self.bounds.size.width - thickness, 0, thickness, self.bounds.size.height);
    
    if (snapshotView != nil)
    {
        [UIView animateWithDuration:0.2f animations:^
        {
            snapshotView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }
}

@end
