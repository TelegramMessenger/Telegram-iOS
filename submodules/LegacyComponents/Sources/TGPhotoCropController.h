#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class PGCameraShotMetadata;
@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@interface TGPhotoCropController : TGPhotoEditorTabController

@property (nonatomic, readonly) bool switching;
@property (nonatomic, readonly) UIImageOrientation cropOrientation;

@property (nonatomic, copy) void (^finishedPhotoProcessing)(void);
@property (nonatomic, copy) void (^cropReset)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView metadata:(PGCameraShotMetadata *)metadata forVideo:(bool)forVideo;

- (void)setAutorotationAngle:(CGFloat)autorotationAngle;

- (void)rotate;
- (void)mirror;
- (void)aspectRatioButtonPressed;

- (void)setImage:(UIImage *)image;
- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;

@end
