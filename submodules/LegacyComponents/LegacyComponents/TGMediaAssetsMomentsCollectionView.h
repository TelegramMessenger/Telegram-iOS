#import <UIKit/UIKit.h>

@class TGMediaAssetsMomentsSectionHeader;
@class TGMediaAssetsMomentsSectionHeaderView;

@protocol TGMediaAssetsMomentsCollectionViewDelegate <UICollectionViewDelegateFlowLayout>

- (void)collectionView:(UICollectionView *)collectionView setupSectionHeaderView:(TGMediaAssetsMomentsSectionHeaderView *)sectionHeaderView forSectionHeader:(TGMediaAssetsMomentsSectionHeader *)sectionHeader;

@end

@interface TGMediaAssetsMomentsCollectionView : UICollectionView

@end
