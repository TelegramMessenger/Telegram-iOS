#import <LegacyComponents/TGModernGalleryImageItem.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@interface TGMediaPickerGalleryItem : NSObject <TGModernGalleryItem>

@property (nonatomic, strong) id<TGMediaEditableItem, TGMediaSelectableItem> asset;
@property (nonatomic, strong) UIImage *immediateThumbnailImage;
@property (nonatomic, assign) bool asFile;

- (instancetype)initWithAsset:(id<TGMediaEditableItem, TGMediaSelectableItem>)asset;

@end
