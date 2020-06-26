#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class TGMediaPickerGalleryVideoScrubber;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView scrubberView:(TGMediaPickerGalleryVideoScrubber *)scrubberView;

- (void)beginScrubbing;
- (void)endScrubbing:(bool (^)(void))completion;
- (void)setPlayButtonHidden:(bool)hidden animated:(bool)animated;

@end
