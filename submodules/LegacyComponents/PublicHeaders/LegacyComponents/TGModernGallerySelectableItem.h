#import <LegacyComponents/TGModernGalleryItem.h>

@protocol TGMediaSelectableItem;
@class TGMediaSelectionContext;

@protocol TGModernGallerySelectableItem <TGModernGalleryItem>

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;

- (id<TGMediaSelectableItem>)selectableMediaItem;
- (NSString *)uniqueId;

@end
