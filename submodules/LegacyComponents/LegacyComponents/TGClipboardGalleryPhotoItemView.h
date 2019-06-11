#import <LegacyComponents/LegacyComponents.h>
#import "TGModernGalleryEditableItemView.h"
#import "TGModernGalleryImageItemImageView.h"

@interface TGClipboardGalleryPhotoItemView : TGModernGalleryZoomableItemView <TGModernGalleryEditableItemView>

@property (nonatomic) CGSize imageSize;

@property (nonatomic, strong) TGModernGalleryImageItemImageView *imageView;

@end
