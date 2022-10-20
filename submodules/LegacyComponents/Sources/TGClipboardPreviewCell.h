#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGImageView.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@interface TGClipboardPreviewCell : UICollectionViewCell

@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) TGImageView *imageView;

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;

- (void)setCornersImage:(UIImage *)cornersImage;

- (void)setImage:(UIImage *)image signal:(SSignal *)signal hasCheck:(bool)hasCheck;
- (void)setHidden:(bool)hidden animated:(bool)animated;

@end

extern NSString *const TGClipboardPreviewCellIdentifier;
