#import <UIKit/UIKit.h>

@class SSignal;
@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@protocol TGMediaSelectableItem;

@interface TGMediaPickerPhotoStripCell : UICollectionViewCell

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;
@property (nonatomic, copy) void (^itemSelected)(id<TGMediaSelectableItem> item, bool selected, id sender);
@property (nonatomic, copy) void (^itemRemoved)(void);

- (void)setItem:(NSObject *)item signal:(SSignal *)signal removable:(bool)removable;

@end

extern NSString *const TGMediaPickerPhotoStripCellKind;
