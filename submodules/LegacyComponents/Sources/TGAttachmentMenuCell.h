#import <UIKit/UIKit.h>

@class TGMenuSheetPallete;

@interface TGAttachmentMenuCell : UICollectionViewCell
{
    UIImageView *_cornersView;
}

@property (nonatomic, strong) TGMenuSheetPallete *pallete;

@end

extern const CGFloat TGAttachmentMenuCellCornerRadius;
