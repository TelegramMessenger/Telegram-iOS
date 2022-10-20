#import "TGModernGalleryImageItemImageView.h"

@interface TGModernGalleryImageItemImageView ()

@end

@implementation TGModernGalleryImageItemImageView

- (void)performProgressUpdate:(CGFloat)progress
{
    [super performProgressUpdate:progress];
    
    if (_progressChanged)
        _progressChanged(progress);
}

- (void)_commitImage:(UIImage *)image partial:(bool)partial loadTime:(NSTimeInterval)loadTime
{
    [super _commitImage:image partial:partial loadTime:loadTime];

    _isPartial = partial;

    bool available = (self.currentImage != nil && self.currentImage.size.width > 1 && self.currentImage.size.height > 1);
    if (_availabilityStateChanged)
        _availabilityStateChanged(available && !partial);
}

- (bool)isAvailableNow
{
    bool available = (self.currentImage != nil && self.currentImage.size.width > 1 && self.currentImage.size.height > 1);
    return available && !_isPartial;
}

@end
