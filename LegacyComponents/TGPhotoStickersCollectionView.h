#import <UIKit/UIKit.h>

@class TGPhotoStickersSectionHeader;
@class TGPhotoStickersSectionHeaderView;

@protocol TGPhotoStickersCollectionViewDelegate <UICollectionViewDelegateFlowLayout>

- (void)collectionView:(UICollectionView *)collectionView setupSectionHeaderView:(TGPhotoStickersSectionHeaderView *)sectionHeaderView forSectionHeader:(TGPhotoStickersSectionHeader *)sectionHeader;

@end

@interface TGPhotoStickersCollectionView : UICollectionView

@property (nonatomic, weak) UIView *headersParentView;
@property (nonatomic, strong) UIColor *headerTextColor;

@end
