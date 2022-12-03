#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoDrawingController : TGPhotoEditorTabController

@property (nonatomic, copy) void (^requestDismiss)(void);
@property (nonatomic, copy) void (^requestApply)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView entitiesView:(TGPhotoEntitiesContainerView *)entitiesView stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext;

- (TGPaintingData *)paintingData;

@end
