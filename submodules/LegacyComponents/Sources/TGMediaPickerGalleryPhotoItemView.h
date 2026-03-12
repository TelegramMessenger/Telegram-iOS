#import <LegacyComponents/TGModernGalleryZoomableItemView.h>
#import <LegacyComponents/TGModernGalleryEditableItemView.h>
#import <LegacyComponents/TGModernGalleryImageItemImageView.h>

@interface TGMediaPickerGalleryPhotoItemView : TGModernGalleryZoomableItemView <TGModernGalleryEditableItemView>

@property (nonatomic) CGSize imageSize;

@property (nonatomic, strong) TGModernGalleryImageItemImageView *imageView;

- (void)setLivePhotoMode:(TGMediaLivePhotoMode)mode;
- (void)returnFromEditing;
- (void)toggleSendAsGif;

@end
