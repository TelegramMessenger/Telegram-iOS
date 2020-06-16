#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;

@interface TGPhotoAvatarPreviewController : TGPhotoEditorTabController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (void)setScrubberPosition:(NSTimeInterval)position reset:(bool)reset;
- (void)setScrubberPlaying:(bool)value;

@end
