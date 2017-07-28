#import <UIKit/UIKit.h>

@class TGModernMediaListItemContentView;

@interface TGModernMediaListItemView : UICollectionViewCell

@property (nonatomic, copy) void (^recycleItemContentView)(TGModernMediaListItemContentView *);

@property (nonatomic, strong) TGModernMediaListItemContentView *itemContentView;

- (TGModernMediaListItemContentView *)_takeItemContentView;

@end
