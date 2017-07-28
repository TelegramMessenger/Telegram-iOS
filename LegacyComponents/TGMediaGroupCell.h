#import <UIKit/UIKit.h>

@class TGMediaAssetGroup;
@class TGMediaAssetMomentList;

@interface TGMediaGroupCell : UITableViewCell

@property (nonatomic, readonly) TGMediaAssetGroup *assetGroup;

- (void)configureForAssetGroup:(TGMediaAssetGroup *)assetGroup;
- (void)configureForMomentList:(TGMediaAssetMomentList *)momentList;

@end

extern NSString *const TGMediaGroupCellKind;
extern const CGFloat TGMediaGroupCellHeight;
