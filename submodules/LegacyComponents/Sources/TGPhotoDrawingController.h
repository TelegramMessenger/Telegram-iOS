#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoDrawingController : TGPhotoEditorTabController

@property (nonatomic, copy) void (^requestDismiss)(void);
@property (nonatomic, copy) void (^requestApply)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView entitiesView:(UIView<TGPhotoDrawingEntitiesView> *)entitiesView stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext isAvatar:(bool)isAvatar;

- (TGPaintingData *)paintingData;

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation;

+ (CGSize)fittedContentSize:(CGRect)cropRect orientation:(UIImageOrientation)orientation originalSize:(CGSize)originalSize;
+ (CGRect)fittedCropRect:(CGRect)cropRect originalSize:(CGSize)originalSize keepOriginalSize:(bool)originalSize;
+ (CGPoint)fittedCropRect:(CGRect)cropRect centerScale:(CGFloat)scale;
+ (CGSize)maximumPaintingSize;

@end

extern const CGFloat TGPhotoPaintTopPanelSize;
extern const CGFloat TGPhotoPaintBottomPanelSize;
