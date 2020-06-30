#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class TGMediaPickerGalleryVideoScrubber;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

@property (nonatomic, assign) bool switching;
@property (nonatomic, assign) bool skipTransitionIn;
@property (nonatomic, assign) bool fromCamera;

@property (nonatomic, copy) void (^croppingChanged)(void);
@property (nonatomic, copy) void (^togglePlayback)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView scrubberView:(TGMediaPickerGalleryVideoScrubber *)scrubberView dotImageView:(UIView *)dotImageView;

- (void)setImage:(UIImage *)image;
- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;

- (void)beginScrubbing:(bool)flash;
- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion;

- (void)_finishedTransitionIn;

@end
