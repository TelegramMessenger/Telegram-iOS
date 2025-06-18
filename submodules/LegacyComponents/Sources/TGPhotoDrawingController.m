#import <LegacyComponents/LegacyComponents.h>
#import "TGPhotoDrawingController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UIImage+TG.h>

#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>
#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGMenuView.h>
#import <LegacyComponents/TGModernButton.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPaintingData.h>

#import "TGPaintingWrapperView.h"
#import <LegacyComponents/TGPhotoEditorSparseView.h>

#import "PGPhotoEditor.h"
#import "TGPhotoEditorPreviewView.h"

#import <LegacyComponents/TGPhotoPaintStickersContext.h>

const CGFloat TGPhotoPaintTopPanelSize = 44.0f;
const CGFloat TGPhotoPaintBottomPanelSize = 79.0f;
const CGSize TGPhotoPaintingLightMaxSize = { 1280.0f, 1280.0f };
const CGSize TGPhotoPaintingMaxSize = { 1920.0f, 1920.0f };

@interface TGPhotoDrawingController () <UIScrollViewDelegate, UIGestureRecognizerDelegate>
{
    id<LegacyComponentsContext> _context;
    id<TGPhotoPaintStickersContext> _stickersContext;
    id<TGPhotoDrawingAdapter> _drawingAdapter;
    
    TGModernGalleryZoomableScrollView *_scrollView;
    UIView *_scrollContentView;
    UIView *_scrollContainerView;
    
    TGPaintingWrapperView *_paintingWrapperView;
    UIView<TGPhotoDrawingView> *_drawingView;
    
    UIPanGestureRecognizer *_entityPanGestureRecognizer;
    UIPinchGestureRecognizer *_entityPinchGestureRecognizer;
    UIRotationGestureRecognizer *_entityRotationGestureRecognizer;
    
    UIView *_entitiesOutsideContainerView;
    UIView *_entitiesWrapperView;
    UIView<TGPhotoDrawingEntitiesView> *_entitiesView;
    
    UIView *_selectionContainerView;
    
    TGPhotoEditorSparseView *_interfaceWrapperView;
    UIViewController<TGPhotoDrawingInterfaceController> *_interfaceController;
    
    CGSize _previousSize;
    CGFloat _keyboardHeight;
    TGObserverProxy *_keyboardWillChangeFrameProxy;
    
    bool _skipEntitiesSetup;
    bool _entitiesReady;
    
    TGPaintingData *_resultData;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoDrawingController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView entitiesView:(UIView<TGPhotoDrawingEntitiesView> *)entitiesView stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext isAvatar:(bool)isAvatar
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _stickersContext = stickersContext;
        
        if (entitiesView != nil) {
            _skipEntitiesSetup = true;
            entitiesView.userInteractionEnabled = true;
        }
        
        CGSize size = TGScaleToSize(photoEditor.originalSize, [TGPhotoDrawingController maximumPaintingSize]);
        _drawingAdapter = [_stickersContext drawingAdapter:size originalSize:photoEditor.originalSize isVideo:photoEditor.forVideo isAvatar:isAvatar entitiesView:entitiesView];
        _interfaceController = (UIViewController<TGPhotoDrawingInterfaceController> *)_drawingAdapter.interfaceController;
        
        __weak TGPhotoDrawingController *weakSelf = self;
        _interfaceController.requestDismiss = ^{
            __strong TGPhotoDrawingController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf.requestDismiss();
        };
        _interfaceController.requestApply = ^{
            __strong TGPhotoDrawingController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf.requestApply();
        };
        _interfaceController.getCurrentImage = ^UIImage *{
            __strong TGPhotoDrawingController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            return [strongSelf.photoEditor currentResultImage];
        };
        _interfaceController.updateVideoPlayback = ^(bool play) {
            __strong TGPhotoDrawingController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf.controlVideoPlayback(play);
        };
                        
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _keyboardWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification];
    }
    return self;
}

- (void)dealloc {
    [_context unlockPortrait];
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    _scrollView = [[TGModernGalleryZoomableScrollView alloc] initWithFrame:self.view.bounds hasDoubleTap:false];
    if (@available(iOS 11.0, *)) {
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.showsVerticalScrollIndicator = false;
    [self.view addSubview:_scrollView];
    
    _scrollContentView = [[UIView alloc] initWithFrame:self.view.bounds];
    [_scrollView addSubview:_scrollContentView];
  
    _scrollContainerView = _drawingAdapter.contentWrapperView;
    _scrollContainerView.clipsToBounds = true;
//    [_scrollContainerView addTarget:self action:@selector(containerPressed) forControlEvents:UIControlEventTouchUpInside];
    [_scrollContentView addSubview:_scrollContainerView];
    
    _entityPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _entityPanGestureRecognizer.delegate = self;
    _entityPanGestureRecognizer.minimumNumberOfTouches = 1;
    _entityPanGestureRecognizer.maximumNumberOfTouches = 2;
    [_scrollContentView addGestureRecognizer:_entityPanGestureRecognizer];
    
    _entityPinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _entityPinchGestureRecognizer.delegate = self;
    [_scrollContentView addGestureRecognizer:_entityPinchGestureRecognizer];
    
    _entityRotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotate:)];
    _entityRotationGestureRecognizer.delegate = self;
    [_scrollContentView addGestureRecognizer:_entityRotationGestureRecognizer];
            
    __weak TGPhotoDrawingController *weakSelf = self;
    _paintingWrapperView = [[TGPaintingWrapperView alloc] init];
    _paintingWrapperView.clipsToBounds = true;
    _paintingWrapperView.shouldReceiveTouch = ^bool
    {
        __strong TGPhotoDrawingController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return true;
    };
    [_scrollContainerView addSubview:_paintingWrapperView];
    
    _entitiesOutsideContainerView = [[TGPhotoEditorSparseView alloc] init];
    _entitiesOutsideContainerView.clipsToBounds = true;
    [_scrollContainerView addSubview:_entitiesOutsideContainerView];
    
    _entitiesWrapperView = [[TGPhotoEditorSparseView alloc] init];
    [_entitiesOutsideContainerView addSubview:_entitiesWrapperView];
    
    if (_entitiesView == nil) {
        _entitiesView = (UIView<TGPhotoDrawingEntitiesView> *)[_drawingAdapter drawingEntitiesView];
    }
    if (!_skipEntitiesSetup) {
        [_entitiesWrapperView addSubview:_entitiesView];
    }
    
    _selectionContainerView = [_drawingAdapter selectionContainerView];
    _selectionContainerView.clipsToBounds = false;
    [_scrollContainerView addSubview:_selectionContainerView];
    
    _interfaceWrapperView = [[TGPhotoEditorSparseView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_interfaceWrapperView];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.userInteractionEnabled = false;
    previewView.hidden = true;
        
    [_interfaceWrapperView addSubview:_interfaceController.view];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)setupCanvas
{
    __weak TGPhotoDrawingController *weakSelf = self;
    if (_drawingView == nil) {
        _drawingView = (UIView<TGPhotoDrawingView> *)_drawingAdapter.drawingView;
        _drawingView.zoomOut = ^{
            __strong TGPhotoDrawingController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_scrollView setZoomScale:strongSelf->_scrollView.normalZoomScale animated:true];
        };
        [_paintingWrapperView addSubview:_drawingView];
        
        [_drawingView setupWithDrawingData:_photoEditor.paintingData.drawingData storeAsClear:false];
    }
    
    _entitiesView.hasSelectionChanged = ^(bool hasSelection) {
        __strong TGPhotoDrawingController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_scrollView.pinchGestureRecognizer.enabled = !hasSelection;
    };
    
    _entitiesView.getEntityCenterPosition = ^CGPoint {
        __strong TGPhotoDrawingController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return CGPointZero;
        
        return [strongSelf entityCenterPoint];
    };
    
    _entitiesView.getEntityInitialRotation = ^CGFloat {
        __strong TGPhotoDrawingController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return 0.0f;
        
        return [strongSelf entityInitialRotation];
    };
    
    _entitiesView.getEntityAdditionalScale = ^CGFloat {
        __strong TGPhotoDrawingController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return 1.0f;
        
        return strongSelf->_photoEditor.cropRect.size.width / strongSelf->_photoEditor.originalSize.width;
    };
    
    [self.view setNeedsLayout];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    PGPhotoEditor *photoEditor = _photoEditor;
    if (!_skipEntitiesSetup) {
        [_entitiesView setupWithEntitiesData:photoEditor.paintingData.entitiesData];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self transitionIn];
}

- (void)containerPressed {
    [_entitiesView clearSelection];
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer {
    [_entitiesView handlePan:gestureRecognizer];
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    [_entitiesView handlePinch:gestureRecognizer];
}

- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [_entitiesView handleRotate:gestureRecognizer];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    if (gestureRecognizer == _entityPinchGestureRecognizer && !_entitiesView.hasSelection) {
        return false;
    }
    if (_entitiesView.isEditingText) {
        return false;
    }
    return !_drawingView.isTracking;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

#pragma mark - Tab Bar

- (TGPhotoEditorTab)availableTabs
{
    return 0;
}

- (TGPhotoEditorTab)activeTab
{
    return 0;
}

#pragma mark - Undo & Redo


- (TGPaintingData *)_prepareResultData
{
    TGPaintingData *resultData = _resultData;
    if (_resultData == nil) {
        resultData = [_interfaceController generateResultData];
        _resultData = resultData;
    }
    return resultData;
}

- (UIImage *)image
{
    TGPaintingData *paintingData = [self _prepareResultData];
    return paintingData.image;
}

- (TGPaintingData *)paintingData
{
    return [self _prepareResultData];
}

#pragma mark - Scroll View

- (CGSize)fittedContentSize
{
    return [TGPhotoDrawingController fittedContentSize:_photoEditor.cropRect orientation:_photoEditor.cropOrientation originalSize:_photoEditor.originalSize];
}

+ (CGSize)fittedContentSize:(CGRect)cropRect orientation:(UIImageOrientation)orientation originalSize:(CGSize)originalSize {
    CGSize fittedOriginalSize = TGScaleToSize(originalSize, [TGPhotoDrawingController maximumPaintingSize]);
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    
    CGSize size = CGSizeMake(cropRect.size.width * scale, cropRect.size.height * scale);
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
        size = CGSizeMake(size.height, size.width);

    return CGSizeMake(floor(size.width), floor(size.height));
}

- (CGRect)fittedCropRect:(bool)originalSize
{
    return [TGPhotoDrawingController fittedCropRect:_photoEditor.cropRect originalSize:_photoEditor.originalSize keepOriginalSize:originalSize];
}

+ (CGRect)fittedCropRect:(CGRect)cropRect originalSize:(CGSize)originalSize keepOriginalSize:(bool)keepOriginalSize {
    CGSize fittedOriginalSize = TGScaleToSize(originalSize, [TGPhotoDrawingController maximumPaintingSize]);
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    
    CGSize size = fittedOriginalSize;
    if (!keepOriginalSize)
        size = CGSizeMake(cropRect.size.width * scale, cropRect.size.height * scale);
    
    return CGRectMake(-cropRect.origin.x * scale, -cropRect.origin.y * scale, size.width, size.height);
}

- (CGPoint)fittedCropCenterScale:(CGFloat)scale
{
    return [TGPhotoDrawingController fittedCropRect:_photoEditor.cropRect centerScale:scale];
}

+ (CGPoint)fittedCropRect:(CGRect)cropRect centerScale:(CGFloat)scale
{
    CGSize size = CGSizeMake(cropRect.size.width * scale, cropRect.size.height * scale);
    CGRect rect = CGRectMake(cropRect.origin.x * scale, cropRect.origin.y * scale, size.width, size.height);
    
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

- (void)resetScrollView
{
    CGSize fittedContentSize = [self fittedContentSize];
    CGRect fittedCropRect = [self fittedCropRect:false];
    _entitiesWrapperView.frame = CGRectMake(0.0f, 0.0f, fittedContentSize.width, fittedContentSize.height);
    
    CGFloat scale = _entitiesOutsideContainerView.bounds.size.width / fittedCropRect.size.width;
    _entitiesWrapperView.transform = CGAffineTransformMakeScale(scale, scale);
    _entitiesWrapperView.frame = CGRectMake(0.0f, 0.0f, _entitiesOutsideContainerView.bounds.size.width, _entitiesOutsideContainerView.bounds.size.height);
    
    CGSize contentSize = [self contentSize];
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 1.0f;
    _scrollView.normalZoomScale = 1.0f;
    _scrollView.zoomScale = 1.0f;
    _scrollView.contentSize = contentSize;
    [self contentView].frame = CGRectMake(0.0f, 0.0f, contentSize.width, contentSize.height);
    
    [self adjustZoom];
    _scrollView.zoomScale = _scrollView.normalZoomScale;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view
{
}

- (void)scrollViewDidZoom:(UIScrollView *)__unused scrollView
{
    [self adjustZoom];
    [_entitiesView onZoom];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view atScale:(CGFloat)__unused scale
{
    [self adjustZoom];
        
    if (_scrollView.zoomScale < _scrollView.normalZoomScale - FLT_EPSILON)
    {
        [TGHacks setAnimationDurationFactor:0.5f];
        [_scrollView setZoomScale:_scrollView.normalZoomScale animated:true];
        [TGHacks setAnimationDurationFactor:1.0f];
    }
}

- (UIView *)contentView
{
    return _scrollContentView;
}

- (CGSize)contentSize
{
    return _scrollView.frame.size;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)__unused scrollView
{
    return [self contentView];
}

- (void)adjustZoom
{
    CGSize contentSize = [self contentSize];
    CGSize boundsSize = _scrollView.frame.size;
    if (contentSize.width < FLT_EPSILON || contentSize.height < FLT_EPSILON || boundsSize.width < FLT_EPSILON || boundsSize.height < FLT_EPSILON)
        return;
    
    CGFloat scaleWidth = boundsSize.width / contentSize.width;
    CGFloat scaleHeight = boundsSize.height / contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    CGFloat maxScale = MAX(scaleWidth, scaleHeight);
    maxScale = MAX(maxScale, minScale * 3.0f);
    
    if (ABS(maxScale - minScale) < 0.01f)
        maxScale = minScale;

    _scrollView.contentInset = UIEdgeInsetsZero;
    
    if (_scrollView.minimumZoomScale != 0.05f)
        _scrollView.minimumZoomScale = 0.05f;
    if (_scrollView.normalZoomScale != minScale)
        _scrollView.normalZoomScale = minScale;
    if (_scrollView.maximumZoomScale != maxScale)
        _scrollView.maximumZoomScale = maxScale;

    CGRect contentFrame = [self contentView].frame;
    
    if (boundsSize.width > contentFrame.size.width)
        contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0f;
    else
        contentFrame.origin.x = 0;
    
    if (boundsSize.height > contentFrame.size.height)
        contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0f;
    else
        contentFrame.origin.y = 0;
    
    [self contentView].frame = contentFrame;
    
    _scrollView.scrollEnabled = ABS(_scrollView.zoomScale - _scrollView.normalZoomScale) > FLT_EPSILON;
    
    [_drawingView updateZoomScale:_scrollView.zoomScale];
}

#pragma mark - Transitions

- (void)transitionIn {
    [_context lockPortrait];
    [_context disableInteractiveKeyboardGesture];
//    if (self.presentedForAvatarCreation) {
//        _drawingView.hidden = true;
//    }
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGRect frame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame.origin.x -= TGPhotoPaintTopPanelSize;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame.origin.x += TGPhotoPaintTopPanelSize;
            break;
            
        default:
            frame.origin.y += TGPhotoPaintTopPanelSize;
            break;
    }
    
    return frame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    CGRect containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {

    } else {
        [transitionView removeFromSuperview];
    }
    
    [self setupCanvas];
    _entitiesView.hidden = false;
        
    TGPhotoEditorPreviewView *previewView = _previewView;
    [previewView setPaintingHidden:true];
    previewView.hidden = false;
    [_scrollContainerView insertSubview:previewView belowSubview:_paintingWrapperView];
    [self updateContentViewLayout];
    [previewView performTransitionInIfNeeded];
    
    CGRect rect = [self fittedCropRect:true];
    _entitiesView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    _entitiesView.transform = CGAffineTransformMakeRotation(_photoEditor.cropRotation);
    
    CGSize fittedOriginalSize = TGScaleToSize(_photoEditor.originalSize, [TGPhotoDrawingController maximumPaintingSize]);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, _photoEditor.cropRotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    CGPoint offset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterScale:scale]);
    
    CGPoint boundsCenter = TGPaintCenterOfRect(_entitiesWrapperView.bounds);
    _entitiesView.center = TGPaintAddPoints(boundsCenter, offset);
    
    if (!_skipEntitiesSetup || _entitiesReady) {
        [_entitiesWrapperView addSubview:_entitiesView];
    }
    _entitiesReady = true;
    [self resetScrollView];
}

- (void)prepareForCustomTransitionOut
{
    _previewView.hidden = true;
    _drawingView.hidden = true;
    _entitiesOutsideContainerView.hidden = true;
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))completion
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.interactionEnded = nil;
    
    [_interfaceController animateOut:^{
        if (completion != nil)
            completion();
    }];
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    CGRect containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    return CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
        
//    [_entitySelectionView removeFromSuperview];
//    _entitySelectionView = nil;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    [previewView prepareForTransitionOut];
    
    UIInterfaceOrientation orientation = self.effectiveOrientation;
    CGRect containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGRect referenceFrame = CGRectMake(0, 0, self.photoEditor.rotatedCropSize.width, self.photoEditor.rotatedCropSize.height);
    CGRect rect = CGRectOffset([self transitionOutSourceFrameForReferenceFrame:referenceFrame orientation:orientation], -containerFrame.origin.x, -containerFrame.origin.y);
    previewView.frame = rect;
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    NSMutableArray *animations = [[NSMutableArray alloc] init];
    
    if (saving && CGRectIsNull(targetFrame) && parentView != nil)
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = [_scrollContainerView convertRect:previewView.frame toView:parentView];
        
        UIView *canvasSnapshotView = [_paintingWrapperView resizableSnapshotViewFromRect:[_paintingWrapperView convertRect:previewView.bounds fromView:previewView] afterScreenUpdates:false withCapInsets:UIEdgeInsetsZero];
        canvasSnapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        canvasSnapshotView.transform = _entitiesOutsideContainerView.transform;
        canvasSnapshotView.frame = snapshotView.bounds;
        [snapshotView addSubview:canvasSnapshotView];
        
        UIView *entitiesSnapshotView = [_entitiesWrapperView resizableSnapshotViewFromRect:[_entitiesWrapperView convertRect:previewView.bounds fromView:previewView] afterScreenUpdates:false withCapInsets:UIEdgeInsetsZero];
        entitiesSnapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        entitiesSnapshotView.transform = _entitiesOutsideContainerView.transform;
        entitiesSnapshotView.frame = snapshotView.bounds;
        [snapshotView addSubview:entitiesSnapshotView];
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2, (self.view.frame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
        [animations addObject:snapshotAnimation];
    }
    
    targetFrame = CGRectOffset(targetFrame, -containerFrame.origin.x, -containerFrame.origin.y);
    CGPoint targetCenter = TGPaintCenterOfRect(targetFrame);
    
    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    [animations addObject:previewAnimation];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    [animations addObject:previewAnimation];
    
    POPSpringAnimation *entitiesAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewCenter];
    entitiesAnimation.fromValue = [NSValue valueWithCGPoint:_entitiesOutsideContainerView.center];
    entitiesAnimation.toValue = [NSValue valueWithCGPoint:targetCenter];
    [animations addObject:entitiesAnimation];
    
    CGFloat targetEntitiesScale = targetFrame.size.width / _entitiesOutsideContainerView.frame.size.width;
    POPSpringAnimation *entitiesScaleAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewScaleXY];
    entitiesScaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    entitiesScaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetEntitiesScale, targetEntitiesScale)];
    [animations addObject:entitiesScaleAnimation];
    
    POPSpringAnimation *entitiesAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    entitiesAlphaAnimation.fromValue = @(_drawingView.alpha);
    entitiesAlphaAnimation.toValue = @(0.0f);
    [animations addObject:entitiesAlphaAnimation];
    
    POPSpringAnimation *paintingAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewCenter];
    paintingAnimation.fromValue = [NSValue valueWithCGPoint:_paintingWrapperView.center];
    paintingAnimation.toValue = [NSValue valueWithCGPoint:targetCenter];
    [animations addObject:paintingAnimation];
    
    CGFloat targetPaintingScale = targetFrame.size.width / _paintingWrapperView.frame.size.width;
    POPSpringAnimation *paintingScaleAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewScaleXY];
    paintingScaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    paintingScaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetPaintingScale, targetPaintingScale)];
    [animations addObject:paintingScaleAnimation];

    POPSpringAnimation *paintingAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    paintingAlphaAnimation.fromValue = @(_paintingWrapperView.alpha);
    paintingAlphaAnimation.toValue = @(0.0f);
    [animations addObject:paintingAlphaAnimation];
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [snapshotView removeFromSuperview];
        
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:animations];
    
    if (snapshotAnimation != nil)
        [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAlphaAnimation forKey:@"alpha"];
    
    [_entitiesOutsideContainerView pop_addAnimation:entitiesAnimation forKey:@"frame"];
    [_entitiesOutsideContainerView pop_addAnimation:entitiesScaleAnimation forKey:@"scale"];
    [_entitiesOutsideContainerView pop_addAnimation:entitiesAlphaAnimation forKey:@"alpha"];
    
    [_paintingWrapperView pop_addAnimation:paintingAnimation forKey:@"frame"];
    [_paintingWrapperView pop_addAnimation:paintingScaleAnimation forKey:@"scale"];
    [_paintingWrapperView pop_addAnimation:paintingAlphaAnimation forKey:@"alpha"];
    
    if (saving)
    {
        _entitiesOutsideContainerView.hidden = true;
        _paintingWrapperView.hidden = true;
        previewView.hidden = true;
    }
}

- (CGRect)transitionOutReferenceFrame
{
    TGPhotoEditorPreviewView *previewView = _previewView;
    return [previewView convertRect:previewView.bounds toView:self.view];
}

- (UIView *)transitionOutReferenceView
{
    return _previewView;
}

- (UIView *)snapshotView
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return [previewView originalSnapshotView];
}

- (id)currentResultRepresentation
{
    return TGPaintCombineCroppedImages(self.photoEditor.currentResultImage, [self image], true, _photoEditor.originalSize, _photoEditor.cropRect, _photoEditor.cropOrientation, _photoEditor.cropRotation, false);
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
 
    [self updateLayout:toInterfaceOrientation];
}

- (void)updateContentViewLayout
{
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(_photoEditor.cropOrientation));
    _entitiesOutsideContainerView.transform = rotationTransform;
    _entitiesOutsideContainerView.frame = self.previewView.frame;
    [self resetScrollView];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    UIView *parentView = self.view;
    
    NSTimeInterval duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] == nil ? 0.3 : [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    int curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect screenKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [parentView convertRect:screenKeyboardFrame fromView:nil];
    
    CGFloat keyboardHeight = (keyboardFrame.size.height <= FLT_EPSILON || keyboardFrame.size.width <= FLT_EPSILON) ? 0.0f : (parentView.frame.size.height - keyboardFrame.origin.y);
    keyboardHeight = MAX(keyboardHeight, 0.0f);
    
    _keyboardHeight = keyboardHeight;
    
    CGSize referenceSize = [self referenceViewSize];
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoPaintBottomPanelSize;
    
    CGRect containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    
    CGFloat topInset = [self controllerStatusBarHeight] + 31.0;
    CGFloat visibleArea = self.view.frame.size.height - _keyboardHeight - topInset;
    CGFloat yCenter = visibleArea / 2.0f;
    CGFloat offset = yCenter - _previewView.center.y - containerFrame.origin.y + topInset;
    CGFloat offsetHeight = _keyboardHeight > FLT_EPSILON ? offset : 0.0f;
    
    [UIView animateWithDuration:duration delay:0.0 options:curve animations:^
    {
        _interfaceWrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, _interfaceWrapperView.frame.size.width, _interfaceWrapperView.frame.size.height);
        _scrollContainerView.frame = CGRectMake(containerFrame.origin.x, containerFrame.origin.y + offsetHeight, containerFrame.size.width, containerFrame.size.height);
    } completion:nil];
    
    [self updateInterfaceLayoutAnimated:true];
}

- (void)updateInterfaceLayoutAnimated:(BOOL)animated {
    if (_interfaceController == nil)
        return;
    
    CGSize size = [self referenceViewSize];
    _interfaceController.view.frame = CGRectMake((_interfaceWrapperView.frame.size.width - size.width) / 2.0, (_interfaceWrapperView.frame.size.height - size.height) / 2.0, size.width, size.height);
    [_interfaceController adapterContainerLayoutUpdatedSize:[self referenceViewSize]
                                            intrinsicInsets:_context.safeAreaInset
                                                 safeInsets:UIEdgeInsetsMake(0.0, _context.safeAreaInset.left, 0.0, _context.safeAreaInset.right)
                                            statusBarHeight:[_context statusBarFrame].size.height
                                                inputHeight:_keyboardHeight
                                                orientation:self.effectiveOrientation
                                                  isRegular:[UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad
                                                   animated:animated];
    
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
        
    CGSize referenceSize = [self referenceViewSize];
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoPaintBottomPanelSize;
    
    bool sizeUpdated = false;
    if (!CGSizeEqualToSize(referenceSize, _previousSize)) {
        sizeUpdated = true;
        _previousSize = referenceSize;
    }
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:self.hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    CGRect containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
                
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    CGRect previewFrame = CGRectMake((containerFrame.size.width - fittedSize.width) / 2, (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    _drawingView.screenSize = fittedSize;
    
    CGFloat topInset = [self controllerStatusBarHeight] + 31.0;
    CGFloat visibleArea = self.view.frame.size.height - _keyboardHeight - topInset;
    CGFloat yCenter = visibleArea / 2.0f;
    CGFloat offset = yCenter - _previewView.center.y - containerFrame.origin.y + topInset;
    CGFloat offsetHeight = _keyboardHeight > FLT_EPSILON ? offset : 0.0f;
    
    _interfaceWrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    [self updateInterfaceLayoutAnimated:false];
    
    if (_dismissing || (previewView.superview != _scrollContainerView && previewView.superview != self.view))
        return;
    
    if (previewView.superview == self.view)
    {
        previewFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    }
    
    UIImageOrientation cropOrientation = _photoEditor.cropOrientation;
    CGRect cropRect = _photoEditor.cropRect;
    CGSize originalSize = _photoEditor.originalSize;
    CGFloat rotation = _photoEditor.cropRotation;
    
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    _entitiesOutsideContainerView.transform = rotationTransform;
    _entitiesOutsideContainerView.frame = previewFrame;
    
    _scrollView.frame = self.view.bounds;
        
    if (sizeUpdated) {
        [self resetScrollView];
    }
    [self adjustZoom];
    
    _paintingWrapperView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    _paintingWrapperView.frame = previewFrame;
    
    CGFloat originalWidth = TGOrientationIsSideward(cropOrientation, NULL) ? previewFrame.size.height : previewFrame.size.width;
    CGFloat ratio = originalWidth / cropRect.size.width;
    CGRect originalFrame = CGRectMake(-cropRect.origin.x * ratio, -cropRect.origin.y * ratio, originalSize.width * ratio, originalSize.height * ratio);
    
    previewView.frame = previewFrame;
    
    if ([self presentedForAvatarCreation]) {
        CGAffineTransform transform = CGAffineTransformMakeRotation(TGRotationForOrientation(photoEditor.cropOrientation));
        if (photoEditor.cropMirrored)
            transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
        previewView.transform = transform;
    }
    
    CGSize fittedOriginalSize = CGSizeMake(originalSize.width * ratio, originalSize.height * ratio);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, rotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    CGPoint centerOffset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterScale:scale]);
    
    _drawingView.transform = CGAffineTransformIdentity;
    _drawingView.frame = originalFrame;
    _drawingView.transform = CGAffineTransformMakeRotation(rotation);
    _drawingView.center = TGPaintAddPoints(TGPaintCenterOfRect(_paintingWrapperView.bounds), centerOffset);
    
    _selectionContainerView.transform = CGAffineTransformRotate(rotationTransform, rotation);
    _selectionContainerView.frame = previewFrame;
    
    _scrollContainerView.frame = CGRectMake(containerFrame.origin.x, containerFrame.origin.y + offsetHeight, containerFrame.size.width, containerFrame.size.height);
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeTop | UIRectEdgeBottom;
}

- (CGPoint)entityCenterPoint
{
    //return [_scrollView convertPoint:TGPaintCenterOfRect(_scrollView.bounds) toView:_entitiesView];
    return [_previewView convertPoint:TGPaintCenterOfRect(_previewView.bounds) toView:_entitiesView];
}

- (CGFloat)entityInitialRotation
{
    return TGCounterRotationForOrientation(_photoEditor.cropOrientation) - _photoEditor.cropRotation;
}

+ (CGSize)maximumPaintingSize
{
    static dispatch_once_t onceToken;
    static CGSize size;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if ((NSInteger)screenSize.height == 480)
            size = TGPhotoPaintingLightMaxSize;
        else
            size = TGPhotoPaintingMaxSize;
    });
    return size;
}

@end
