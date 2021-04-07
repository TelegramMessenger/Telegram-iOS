#import "TGClipboardGalleryPhotoItem.h"
#import "TGClipboardGalleryPhotoItemView.h"

#import "LegacyComponentsInternal.h"

#import "UIImage+TGMediaEditableItem.h"

@implementation TGClipboardGalleryPhotoItem

@synthesize selectionContext;
@synthesize editingContext;
@synthesize stickersContext;

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
    }
    return self;
}

- (NSString *)uniqueId
{
    return self.image.uniqueIdentifier;
}

- (id<TGMediaSelectableItem>)selectableMediaItem
{
    return self.image;
}

- (id<TGMediaEditableItem>)editableMediaItem
{
    return self.image;
}

- (TGPhotoEditorTab)toolbarTabs
{
    return TGPhotoEditorCropTab | TGPhotoEditorToolsTab | TGPhotoEditorPaintTab;
}


- (Class)viewClass
{
    return [TGClipboardGalleryPhotoItemView class];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGClipboardGalleryPhotoItem class]] && TGObjectCompare(_image, ((TGClipboardGalleryPhotoItem *)object)->_image);
}


@end
