#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class PGPhotoEditorView;
@class TGMediaPickerGalleryVideoScrubber;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

@property (nonatomic, assign) bool switching;
@property (nonatomic, assign) bool skipTransitionIn;
@property (nonatomic, assign) bool fromCamera;

@property (nonatomic, copy) void (^cancelPressed)(void);
@property (nonatomic, copy) void (^donePressed)(void);

@property (nonatomic, copy) void (^croppingChanged)(void);
@property (nonatomic, copy) void (^togglePlayback)(void);

@property (nonatomic, weak) UIView *dotImageView;
@property (nonatomic, weak) UIView *dotMarkerView;
@property (nonatomic, weak) PGPhotoEditorView *fullPreviewView;
@property (nonatomic, weak) UIImageView *fullPaintingView;
@property (nonatomic, weak) UIView<TGPhotoDrawingEntitiesView> *fullEntitiesView;
@property (nonatomic, weak) TGMediaPickerGalleryVideoScrubber *scrubberView;

@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView isForum:(bool)isForum isSuggestion:(bool)isSuggestion isSuggesting:(bool)isSuggesting senderName:(NSString *)senderName;

- (void)setImage:(UIImage *)image;
- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;

- (void)beginScrubbing:(bool)flash;
- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion;

- (void)_finishedTransitionIn;

@end
