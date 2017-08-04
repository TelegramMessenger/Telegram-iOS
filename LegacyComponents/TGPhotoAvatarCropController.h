#import "TGPhotoEditorTabController.h"

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@interface TGPhotoAvatarCropController : TGPhotoEditorTabController

@property (nonatomic, readonly) UIView *transitionParentView;

@property (nonatomic, assign) bool switching;
@property (nonatomic, assign) bool skipTransitionIn;
@property (nonatomic, assign) bool fromCamera;

@property (nonatomic, copy) void (^finishedPhotoProcessing)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (void)setImage:(UIImage *)image;
- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;

- (void)_finishedTransitionIn;

@end
