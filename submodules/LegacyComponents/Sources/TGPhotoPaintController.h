#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoPaintController : TGPhotoEditorTabController

@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (TGPaintingData *)paintingData;

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation;

@end

extern const CGFloat TGPhotoPaintTopPanelSize;
extern const CGFloat TGPhotoPaintBottomPanelSize;
