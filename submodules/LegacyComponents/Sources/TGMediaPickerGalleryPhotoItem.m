#import "TGMediaPickerGalleryPhotoItem.h"
#import "TGMediaPickerGalleryPhotoItemView.h"

#import "TGMediaAsset+TGMediaEditableItem.h"

@implementation TGMediaPickerGalleryPhotoItem

@synthesize selectionContext;
@synthesize editingContext;
@synthesize stickersContext;

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
    return TGPhotoEditorCropTab | TGPhotoEditorToolsTab | TGPhotoEditorPaintTab;
}

- (Class)viewClass
{
    return [TGMediaPickerGalleryPhotoItemView class];
}

@end
