#import <UIKit/UIKit.h>

@class TGMediaAssetGroup;
@class TGMediaAssetMomentList;
@class TGMediaAssetsPallete;

@interface TGMediaGroupCell : UITableViewCell

@property (nonatomic, readonly) TGMediaAssetGroup *assetGroup;
@property (nonatomic, strong) TGMediaAssetsPallete *pallete;

- (void)configureForAssetGroup:(TGMediaAssetGroup *)assetGroup;
- (void)configureForMomentList:(TGMediaAssetMomentList *)momentList;

@end

extern NSString *const TGMediaGroupCellKind;
extern const CGFloat TGMediaGroupCellHeight;
