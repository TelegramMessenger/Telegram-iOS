#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class TGMediaPickerGalleryVideoScrubber;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView scrubberView:(TGMediaPickerGalleryVideoScrubber *)scrubberView dotImageView:(UIImageView *)dotImageView;

- (void)beginScrubbing:(bool)flash;
- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion;

@end
