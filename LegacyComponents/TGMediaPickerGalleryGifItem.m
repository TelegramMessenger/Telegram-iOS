#import "TGMediaPickerGalleryGifItem.h"
#import "TGMediaPickerGalleryGifItemView.h"

#import "TGMediaAsset+TGMediaEditableItem.h"

@implementation TGMediaPickerGalleryGifItem

@synthesize selectionContext;
@synthesize editingContext;

- (NSString *)uniqueId
{
    return self.asset.uniqueIdentifier;
}

- (id<TGMediaSelectableItem>)selectableMediaItem
{
    return self.asset;
}

- (id<TGMediaEditableItem>)editableMediaItem
{
    return self.asset;
}

- (TGPhotoEditorTab)toolbarTabs
{
    return TGPhotoEditorNoneTab;
}

- (Class)viewClass
{
    return [TGMediaPickerGalleryGifItemView class];
}

@end
