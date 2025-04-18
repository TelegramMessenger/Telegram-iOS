#import <UIKit/UIKit.h>

@class SSignal;
@class TGMediaPickerGallerySelectedItemsModel;
@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@interface TGMediaPickerPhotoStripView : UIView

@property (nonatomic, weak) TGMediaPickerGallerySelectedItemsModel *selectedItemsModel;
@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly) bool isAnimating;

@property (nonatomic, assign) bool removable;

@property (nonatomic, copy) void (^itemSelected)(NSInteger index);
@property (nonatomic, copy) void (^itemRemoved)(NSInteger index);
@property (nonatomic, copy) SSignal *(^thumbnailSignalForItem)(id item);

- (bool)isInternalHidden;
- (void)setHidden:(bool)hidden animated:(bool)animated;

- (void)reloadData;
- (void)insertItemAtIndex:(NSInteger)index;
- (void)deleteItemAtIndex:(NSInteger)index;

@end
