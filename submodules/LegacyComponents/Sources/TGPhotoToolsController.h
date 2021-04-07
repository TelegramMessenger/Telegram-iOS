#import <LegacyComponents/TGPhotoEditorTabController.h>

@class PGPhotoEditor;
@class PGPhotoTool;
@class TGPhotoEditorPreviewView;
@class TGPhotoEntitiesContainerView;

@interface TGPhotoToolsController : TGPhotoEditorTabController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView entitiesView:(TGPhotoEntitiesContainerView *)entitiesView;

@end
