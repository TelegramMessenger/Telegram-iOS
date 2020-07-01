#import <UIKit/UIKit.h>

@interface TGMediaPickerGalleryVideoScrubberThumbnailView : UIView

@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, assign) UIImageOrientation cropOrientation;
@property (nonatomic, assign) bool cropMirrored;

@property (nonatomic, strong) UIImage *image;
- (void)setImage:(UIImage *)image animated:(bool)animated;

- (instancetype)initWithImage:(UIImage *)image originalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation cropMirrored:(bool)cropMirrored;

- (void)updateCropping;
- (void)updateCropping:(bool)animated;

@end
