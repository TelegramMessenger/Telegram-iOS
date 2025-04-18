#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/TGVideoEditAdjustments.h>

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;
@class TGPhotoEditorController;

@interface TGPhotoQualityController : TGPhotoEditorTabController

@property (nonatomic, readonly) TGMediaVideoConversionPreset preset;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

@end
