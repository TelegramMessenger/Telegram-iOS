#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@class TGPaintingData;
@class TGStickerMaskDescription;

@protocol TGPhotoPaintEntityRenderer <NSObject>

- (void)entitiesForTime:(CMTime)time fps:(NSInteger)fps size:(CGSize)size completion:(void(^)(NSArray<CIImage *> *))completion;

@end

@protocol TGPhotoSolidRoundedButtonView <NSObject>

- (void)updateWidth:(CGFloat)width;

@end

@protocol TGPhotoPaintStickerRenderView <NSObject>

@property (nonatomic, copy) void(^started)(double);

- (void)setIsVisible:(bool)isVisible;
- (void)seekTo:(double)timestamp;
- (void)play;
- (void)pause;
- (void)resetToStart;

- (void)playFromFrame:(NSInteger)frameIndex;
- (void)copyStickerView:(NSObject<TGPhotoPaintStickerRenderView> *)view;

- (int64_t)documentId;
- (UIImage *)image;

@end

@protocol TGPhotoPaintStickersScreen <NSObject>

@property (nonatomic, copy) void(^screenDidAppear)(void);
@property (nonatomic, copy) void(^screenWillDisappear)(void);

- (void)restore;
- (void)invalidate;

@end

@protocol TGCaptionPanelView <NSObject>

@property (nonatomic, readonly) UIView *view;

- (NSAttributedString *)caption;
- (void)setCaption:(NSAttributedString *)caption;
- (void)dismissInput;

@property (nonatomic, copy) void(^sendPressed)(NSAttributedString *string);
@property (nonatomic, copy) void(^focusUpdated)(BOOL focused);
@property (nonatomic, copy) void(^heightUpdated)(BOOL animated);

- (CGFloat)updateLayoutSize:(CGSize)size sideInset:(CGFloat)sideInset;
- (CGFloat)baseHeight;

@end


@protocol TGPhotoDrawingView <NSObject>

@property (nonatomic, readonly) BOOL isTracking;

@property (nonatomic, copy) void(^zoomOut)(void);

- (void)updateZoomScale:(CGFloat)scale;

- (void)setupWithDrawingData:(NSData *)drawingData;

@end

@protocol TGPhotoDrawingEntitiesView <NSObject>

@property (nonatomic, copy) CGPoint (^getEntityCenterPosition)(void);
@property (nonatomic, copy) CGFloat (^getEntityInitialRotation)(void);

@property (nonatomic, copy) void(^hasSelectionChanged)(bool);
@property (nonatomic, readonly) BOOL hasSelection;

- (void)play;
- (void)pause;
- (void)seekTo:(double)timestamp;
- (void)resetToStart;
- (void)updateVisibility:(BOOL)visibility;
- (void)clearSelection;
- (void)onZoom;

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer;
- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer;

- (void)setupWithEntitiesData:(NSData *)entitiesData;

@end

@protocol TGPhotoDrawingInterfaceController <NSObject>

@property (nonatomic, copy) void(^requestDismiss)(void);
@property (nonatomic, copy) void(^requestApply)(void);
@property (nonatomic, copy) UIImage *(^getCurrentImage)(void);
@property (nonatomic, copy) void(^updateVideoPlayback)(bool);

- (TGPaintingData *)generateResultData;
- (void)animateOut:(void(^)(void))completion;

- (void)adapterContainerLayoutUpdatedSize:(CGSize)size
                          intrinsicInsets:(UIEdgeInsets)intrinsicInsets
                               safeInsets:(UIEdgeInsets)safeInsets
                          statusBarHeight:(CGFloat)statusBarHeight
                              inputHeight:(CGFloat)inputHeight
                              orientation:(UIInterfaceOrientation)orientation
                                 animated:(BOOL)animated;

@end


@protocol TGPhotoDrawingAdapter <NSObject>

@property (nonatomic, readonly) id<TGPhotoDrawingView> drawingView;
@property (nonatomic, readonly) id<TGPhotoDrawingEntitiesView> drawingEntitiesView;
@property (nonatomic, readonly) UIView * selectionContainerView;
@property (nonatomic, readonly) UIView * contentWrapperView;
@property (nonatomic, readonly) id<TGPhotoDrawingInterfaceController> interfaceController;

@end


@protocol TGPhotoPaintStickersContext <NSObject>

- (int64_t)documentIdForDocument:(id)document;
- (TGStickerMaskDescription *)maskDescriptionForDocument:(id)document;

- (UIView<TGPhotoPaintStickerRenderView> *)stickerViewForDocument:(id)document;

@property (nonatomic, copy) id<TGPhotoPaintStickersScreen>(^presentStickersController)(void(^)(id, bool, UIView *, CGRect));

@property (nonatomic, copy) id<TGCaptionPanelView>(^captionPanelView)(void);


- (UIView<TGPhotoSolidRoundedButtonView> *)solidRoundedButton:(NSString *)title action:(void(^)(void))action;
- (id<TGPhotoDrawingAdapter>)drawingAdapter:(CGSize)size originalSize:(CGSize)originalSize isVideo:(bool)isVideo isAvatar:(bool)isAvatar;

- (UIView<TGPhotoDrawingEntitiesView> *)drawingEntitiesViewWithSize:(CGSize)size;

@end
