#import <UIKit/UIKit.h>

@class PGPhotoFilter;

@interface TGPhotoFilterCell : UICollectionViewCell

@property (nonatomic, readonly) NSString *filterIdentifier;

- (void)setPhotoFilter:(PGPhotoFilter *)photoFilter;
- (void)setFilterSelected:(BOOL)selected;

- (void)setImage:(UIImage *)image;
- (void)setImage:(UIImage *)image animated:(bool)animated;

+ (CGFloat)filterCellWidth;

@end

extern NSString * const TGPhotoFilterCellKind;
