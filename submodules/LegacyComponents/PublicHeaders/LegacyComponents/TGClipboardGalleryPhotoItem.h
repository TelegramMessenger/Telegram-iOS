#import <LegacyComponents/TGModernGallerySelectableItem.h>
#import <LegacyComponents/TGModernGalleryEditableItem.h>

@interface TGClipboardGalleryPhotoItem : NSObject <TGModernGallerySelectableItem, TGModernGalleryEditableItem>

@property (nonatomic, strong) UIImage *image;

- (instancetype)initWithImage:(UIImage *)image;

@end
