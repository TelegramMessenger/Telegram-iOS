#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class TGPhotoEntitiesContainerView;
@class PGPhotoEditorView;
@class TGMediaPickerGalleryVideoScrubber;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

@property (nonatomic, assign) bool switching;
@property (nonatomic, assign) bool skipTransitionIn;
@property (nonatomic, assign) bool fromCamera;

@property (nonatomic, copy) void (^croppingChanged)(void);
@property (nonatomic, copy) void (^togglePlayback)(void);

@property (nonatomic, weak) UIView *dotImageView;
@property (nonatomic, weak) UIView *dotMarkerView;
@property (nonatomic, weak) PGPhotoEditorView *fullPreviewView;
@property (nonatomic, weak) UIImageView *fullPaintingView;
@property (nonatomic, weak) TGPhotoEntitiesContainerView *fullEntitiesView;
@property (nonatomic, weak) TGMediaPickerGalleryVideoScrubber *scrubberView;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (void)setImage:(UIImage *)image;
- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;

- (void)beginScrubbing:(bool)flash;
- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion;

- (void)_finishedTransitionIn;

@end
