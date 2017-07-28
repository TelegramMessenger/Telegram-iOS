#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;

@interface TGPhotoToolsController : TGPhotoEditorTabController

- (instancetype)initWithPhotoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (void)updateValues;

@end
