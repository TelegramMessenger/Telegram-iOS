#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@class TGPaintingData;
@class TGStickerMaskDescription;

@protocol TGPhotoPaintEntityRenderer <NSObject>

- (void)entitiesForTime:(CMTime)time fps:(NSInteger)fps size:(CGSize)size completion:(void(^_Nonnull)(NSArray<CIImage *> * _Nonnull))completion;

@end

@protocol TGPhotoSolidRoundedButtonView <NSObject>

- (void)updateWidth:(CGFloat)width;

@end

@protocol TGPhotoSendStarsButtonView <NSObject>

- (void)updateFrame:(CGRect)frame;
- (CGSize)updateCount:(int64_t)count;

@end


@protocol TGCaptionPanelView <NSObject>

@property (nonatomic, readonly) UIView * _Nonnull view;

- (void)setTimeout:(int32_t)timeout isVideo:(bool)isVideo isCaptionAbove:(bool)isCaptionAbove;

- (NSAttributedString * _Nonnull)caption;
- (void)setCaption:(NSAttributedString * _Nullable)caption;
- (bool)dismissInput;

- (void)animateView:(UIView * _Nonnull)view frame:(CGRect)frame;

- (void)onAnimateOut;

@property (nonatomic, copy) void(^ _Nullable sendPressed)(NSAttributedString * _Nullable string);
@property (nonatomic, copy) void(^ _Nullable focusUpdated)(BOOL focused);
@property (nonatomic, copy) void(^ _Nullable heightUpdated)(BOOL animated);
@property (nonatomic, copy) void(^ _Nullable timerUpdated)(NSNumber * _Nullable value);
@property (nonatomic, copy) void(^ _Nullable captionIsAboveUpdated)(BOOL value);

- (CGFloat)updateLayoutSize:(CGSize)size keyboardHeight:(CGFloat)keyboardHeight sideInset:(CGFloat)sideInset animated:(bool)animated;
- (CGFloat)baseHeight;

@end


@protocol TGPhotoDrawingView <NSObject>

@property (nonatomic, readonly) BOOL isTracking;
@property (nonatomic, assign) CGSize screenSize;

@property (nonatomic, copy) void(^ _Nonnull zoomOut)(void);

- (void)updateZoomScale:(CGFloat)scale;

- (void)setupWithDrawingData:(NSData * _Nullable)drawingData storeAsClear:(BOOL)storeAsClear;

@end

@protocol TGPhotoDrawingEntitiesView <NSObject>

@property (nonatomic, copy) CGPoint (^ _Nonnull getEntityCenterPosition)(void);
@property (nonatomic, copy) CGFloat (^ _Nonnull getEntityInitialRotation)(void);
@property (nonatomic, copy) CGFloat (^ _Nonnull getEntityAdditionalScale)(void);

@property (nonatomic, copy) void(^ _Nonnull hasSelectionChanged)(bool);
@property (nonatomic, readonly) BOOL hasSelection;
@property (nonatomic, readonly) BOOL isEditingText;

- (void)play;
- (void)pause;
- (void)seekTo:(double)timestamp;
- (void)resetToStart;
- (void)updateVisibility:(BOOL)visibility;
- (void)clearSelection;
- (void)onZoom;

- (void)handlePan:(UIPanGestureRecognizer * _Nonnull)gestureRecognizer;
- (void)handlePinch:(UIPinchGestureRecognizer * _Nonnull)gestureRecognizer;
- (void)handleRotate:(UIRotationGestureRecognizer * _Nonnull)gestureRecognizer;

- (void)setupWithEntitiesData:(NSData * _Nullable)entitiesData;

@end

@protocol TGPhotoDrawingInterfaceController <NSObject>

@property (nonatomic, copy) void(^ _Nonnull requestDismiss)(void);
@property (nonatomic, copy) void(^ _Nonnull requestApply)(void);
@property (nonatomic, copy) UIImage * _Nullable(^ _Nonnull getCurrentImage)(void);
@property (nonatomic, copy) void(^ _Nonnull updateVideoPlayback)(bool);

- (TGPaintingData * _Nullable)generateResultData;
- (void)animateOut:(void(^_Nonnull)(void))completion;

- (void)adapterContainerLayoutUpdatedSize:(CGSize)size
                          intrinsicInsets:(UIEdgeInsets)intrinsicInsets
                               safeInsets:(UIEdgeInsets)safeInsets
                          statusBarHeight:(CGFloat)statusBarHeight
                              inputHeight:(CGFloat)inputHeight
                              orientation:(UIInterfaceOrientation)orientation
                                isRegular:(bool)isRegular
                                 animated:(BOOL)animated;

@end


@protocol TGPhotoDrawingAdapter <NSObject>

@property (nonatomic, readonly) id<TGPhotoDrawingView> _Nonnull drawingView;
@property (nonatomic, readonly) id<TGPhotoDrawingEntitiesView> _Nonnull drawingEntitiesView;
@property (nonatomic, readonly) UIView * _Nonnull selectionContainerView;
@property (nonatomic, readonly) UIView * _Nonnull contentWrapperView;
@property (nonatomic, readonly) id<TGPhotoDrawingInterfaceController> _Nonnull interfaceController;

@end


@protocol TGPhotoPaintStickersContext <NSObject>

@property (nonatomic, copy) id<TGCaptionPanelView> _Nullable(^ _Nullable captionPanelView)(void);

@property (nonatomic, copy) void (^ _Nullable editCover)(CGSize dimensions, void(^_Nonnull completion)(UIImage * _Nonnull));

- (UIView<TGPhotoSendStarsButtonView> *_Nonnull)sendStarsButtonAction:(void(^_Nonnull)(void))action;
- (UIView<TGPhotoSolidRoundedButtonView> *_Nonnull)solidRoundedButton:(NSString *_Nonnull)title action:(void(^_Nonnull)(void))action;
- (id<TGPhotoDrawingAdapter> _Nonnull)drawingAdapter:(CGSize)size originalSize:(CGSize)originalSize isVideo:(bool)isVideo isAvatar:(bool)isAvatar entitiesView:(UIView<TGPhotoDrawingEntitiesView> * _Nullable)entitiesView;

- (UIView<TGPhotoDrawingEntitiesView> * _Nonnull)drawingEntitiesViewWithSize:(CGSize)size;

@end
