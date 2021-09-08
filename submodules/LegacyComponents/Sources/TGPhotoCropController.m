#import "TGPhotoCropController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGImageBlur.h>
#import <LegacyComponents/TGPaintUtils.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import "TGPhotoEditorInterfaceAssets.h"

#import "PGPhotoEditor.h"

#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/PGCameraShotMetadata.h>
#import <LegacyComponents/TGPaintingData.h>

#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoCropView.h"
#import "TGModernButton.h"

#import "TGMenuSheetController.h"

const CGFloat TGPhotoCropButtonsWrapperSize = 61.0f;
const CGSize TGPhotoCropAreaInsetSize = { 9, 9 };

NSString * const TGPhotoCropOriginalAspectRatio = @"original";

@interface TGPhotoCropController ()
{
    bool _forVideo;
    
    UIView *_wrapperView;
    
    CGFloat _autoRotationAngle;
    
    UIView *_buttonsWrapperView;
    TGModernButton *_resetButton;

    TGPhotoCropView *_cropView;
    
    UIImage *_screenImage;
    
    UIView *_snapshotView;
    UIImage *_snapshotImage;
    
    bool _appeared;
    UIImage *_imagePendingLoad;
    
    CGRect _transitionOutFrame;
    UIView *_transitionOutView;
    
    CGFloat _resetButtonWidth;
    
    dispatch_semaphore_t _waitSemaphore;
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoCropController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView metadata:(PGCameraShotMetadata *)metadata forVideo:(bool)forVideo
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        _forVideo = forVideo;
        
        if (ABS(metadata.deviceAngle) > FLT_EPSILON)
            _autoRotationAngle = metadata.deviceAngle;
        
        _waitSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    __weak TGPhotoCropController *weakSelf = self;
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoCropController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
    };
    
    _wrapperView = [[UIView alloc] initWithFrame:self.view.bounds];
    _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_wrapperView];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    _cropView = [[TGPhotoCropView alloc] initWithOriginalSize:photoEditor.originalSize hasArbitraryRotation:!_forVideo];
    [_cropView setCropRect:photoEditor.cropRect];
    [_cropView setCropOrientation:photoEditor.cropOrientation];
    [_cropView setRotation:photoEditor.cropRotation];
    [_cropView setMirrored:photoEditor.cropMirrored];
    _cropView.interactionBegan = ^
    {
        __strong TGPhotoCropController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setAutoButtonHidden:true];
    };
    _cropView.croppingChanged = ^
    {
        __strong TGPhotoCropController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf _updateEditorValues];
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        if (!photoEditor.hasDefaultCropping || photoEditor.cropLockedAspectRatio > FLT_EPSILON)
            [strongSelf setAutoButtonHidden:true];
        
        if (strongSelf.valuesChanged != nil)
            strongSelf.valuesChanged();
    };
    if (_snapshotView != nil)
    {
        [_cropView setSnapshotView:_snapshotView];
        _snapshotView = nil;
    }
    else if (_snapshotImage != nil)
    {
        [_cropView setSnapshotImage:_snapshotImage];
        _snapshotImage = nil;
    }
    _cropView.interactionEnded = interactionEnded;
    [_wrapperView addSubview:_cropView];
    
    [_cropView setPaintingImage:_photoEditor.paintingData.image];
    
    _buttonsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_buttonsWrapperView];
    
    NSString *resetButtonTitle = TGLocalized(@"PhotoEditor.CropReset");
    _resetButton = [[TGModernButton alloc] init];
    _resetButton.exclusiveTouch = true;
    _resetButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
    _resetButton.titleLabel.font = [TGFont systemFontOfSize:13];
    [_resetButton addTarget:self action:@selector(resetButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_resetButton setTitle:resetButtonTitle forState:UIControlStateNormal];
    [_resetButton setTitleColor:[UIColor whiteColor]];
    [_resetButton sizeToFit];
    _resetButton.frame = CGRectMake(0, 0, _resetButton.frame.size.width, 24);
    [_buttonsWrapperView addSubview:_resetButton];
    
    _resetButtonWidth = CGCeil([resetButtonTitle sizeWithAttributes:@{ NSFontAttributeName:TGSystemFontOfSize(13) }].width);
    
    if (photoEditor.cropLockedAspectRatio > FLT_EPSILON)
    {
        [_cropView setLockedAspectRatio:photoEditor.cropLockedAspectRatio performResize:false animated:false];
    }
    else if ([photoEditor hasDefaultCropping] && ABS(_autoRotationAngle) > FLT_EPSILON)
    {
        _resetButton.selected = true;
        [_resetButton setTitle:TGLocalized(@"PhotoEditor.CropAuto") forState:UIControlStateNormal];
    }
    
    [self _updateTabs];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self transitionIn];
}

- (BOOL)shouldAutorotate
{
    return (!_cropView.isTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared && !_cropView.isTracking && !_cropView.isAnimating;
}

#pragma mark -

- (void)setAutorotationAngle:(CGFloat)autorotationAngle
{
    if (fabs(autorotationAngle) < TGDegreesToRadians(5.0f))
        return;
    
    _autoRotationAngle = autorotationAngle;
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    if ([photoEditor hasDefaultCropping] && fabs(_autoRotationAngle) > FLT_EPSILON && photoEditor.cropLockedAspectRatio < FLT_EPSILON)
    {
        _resetButton.selected = true;
        [_resetButton setTitle:TGLocalized(@"PhotoEditor.CropAuto") forState:UIControlStateNormal];
    }
}

- (void)setImage:(UIImage *)image
{
    if (_dismissing && !_switching)
        return;
    
    if (_waitSemaphore != nil)
        dispatch_semaphore_signal(_waitSemaphore);
    
    if (!_appeared)
    {
        _imagePendingLoad = image;
        return;
    }
    
    [_cropView setImage:image];
}

- (void)setSnapshotImage:(UIImage *)snapshotImage
{
    _snapshotImage = snapshotImage;
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    _snapshotView = snapshotView;
}

- (void)_updateEditorValues
{
    PGPhotoEditor *photoEditor = self.photoEditor;
    photoEditor.cropRect = _cropView.cropRect;
    photoEditor.cropRotation = _cropView.rotation;
    photoEditor.cropLockedAspectRatio = _cropView.lockedAspectRatio;
    photoEditor.cropOrientation = _cropView.cropOrientation;
    photoEditor.cropMirrored = _cropView.mirrored;
}

#pragma mark - Transition

- (void)transitionIn
{
    _buttonsWrapperView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _buttonsWrapperView.alpha = 1.0f;
    }];
    
    [_cropView animateTransitionIn];
}

- (void)animateTransitionIn
{
    if ([_transitionView isKindOfClass:[TGPhotoEditorPreviewView class]])
        [(TGPhotoEditorPreviewView *)_transitionView performTransitionToCropAnimated:true];
    
    [super animateTransitionIn];
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    
    if (_imagePendingLoad != nil)
        [_cropView setImage:_imagePendingLoad];
    [transitionView removeFromSuperview];
    
    [_cropView transitionInFinishedAnimated:false completion:nil];
}

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion
{
    _dismissing = true;
    
    if (switching)
    {
        _switching = true;
        
        TGPhotoEditorPreviewView *previewView = self.previewView;
        [previewView performTransitionToCropAnimated:false];
        [previewView setSnapshotView:[_cropView cropSnapshotView]];
        
        [_cropView performConfirmAnimated:false updateInterface:false];
        
        if (!_forVideo)
        {
            PGPhotoEditor *photoEditor = self.photoEditor;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
            {
                if (dispatch_semaphore_wait(_waitSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC))))
                {
                    TGLegacyLog(@"Photo crop on switching failed");
                    return;
                }
                
                UIImage *croppedImage = [_cropView croppedImageWithMaxSize:TGPhotoEditorScreenImageMaxSize()];
                [photoEditor setImage:croppedImage forCropRect:_cropView.cropRect cropRotation:_cropView.rotation cropOrientation:_cropView.cropOrientation cropMirrored:_cropView.mirrored fullSize:false];
                
                [photoEditor processAnimated:false completion:^
                {
                    TGDispatchOnMainThread(^
                    {
                        [previewView setSnapshotImage:croppedImage];
                        
                        if (!previewView.hidden)
                            [previewView performTransitionInWithCompletion:nil];
                        else
                            [previewView setNeedsTransitionIn];
                    });
                }];
                
                if (self.finishedPhotoProcessing != nil)
                    self.finishedPhotoProcessing();
            });
        }
    }
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _buttonsWrapperView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
    
    [_cropView animateTransitionOut];
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    CGRect containerFrame = [TGPhotoCropController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation hasArbitraryRotation:_cropView.hasArbitraryRotation hasOnScreenNavigation:hasOnScreenNavigation];
    containerFrame = CGRectInset(containerFrame, TGPhotoCropAreaInsetSize.width, TGPhotoCropAreaInsetSize.height);
    
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                fittedSize.width,
                                fittedSize.height);
    
    return toFrame;
}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    UIView *snapshotView = nil;
    CGRect sourceFrame = CGRectZero;
    
    if (_transitionOutView != nil)
    {
        snapshotView = _transitionOutView;
        sourceFrame = _transitionOutFrame;
    }
    else
    {
        snapshotView = [_cropView cropSnapshotView];
        sourceFrame = [_cropView cropRectFrameForView:self.view];
    }

    snapshotView.frame = sourceFrame;
    
    if (snapshotView.superview != self.view)
        [self.view addSubview:snapshotView];
    
    [self transitionOutSwitching:false completion:nil];
    
    CGRect referenceFrame = CGRectZero;
    UIView *referenceView = nil;
    UIView *parentView = nil;
    
    if (self.beginTransitionOut != nil)
        referenceView = self.beginTransitionOut(&referenceFrame, &parentView);
    
    UIView *toTransitionView = nil;
    CGRect targetFrame = CGRectZero;
    
    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    UIView *backgroundSuperview = parentView;
    UIView *transitionBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, backgroundSuperview.frame.size.width, backgroundSuperview.frame.size.height)];
    transitionBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
    [backgroundSuperview addSubview:transitionBackgroundView];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        transitionBackgroundView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [transitionBackgroundView removeFromSuperview];
    }];
    
    if (saving)
    {
        CGSize fittedSize = TGScaleToSize(snapshotView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2,
                                 (self.view.frame.size.height - fittedSize.height) / 2,
                                 fittedSize.width,
                                 fittedSize.height);
        
        UIImage *transitionImage = nil;
        if ([referenceView isKindOfClass:[UIImageView class]])
            transitionImage = ((UIImageView *)referenceView).image;
        
        if (transitionImage != nil)
            toTransitionView = [[UIImageView alloc] initWithImage:transitionImage];
        else
            toTransitionView = [snapshotView snapshotViewAfterScreenUpdates:false];
        
        toTransitionView.frame = snapshotView.frame;
    }
    else
    {  
        UIImage *transitionImage = nil;
        if ([referenceView isKindOfClass:[UIImageView class]])
            transitionImage = ((UIImageView *)referenceView).image;
        
        if (transitionImage != nil)
            toTransitionView = [[UIImageView alloc] initWithImage:transitionImage];
        else
            toTransitionView = [referenceView snapshotViewAfterScreenUpdates:false];
        
        targetFrame = referenceFrame;
        toTransitionView.frame = snapshotView.frame;
    }
    
    [parentView addSubview:toTransitionView];
    
    POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    animation.fromValue = [NSValue valueWithCGRect:toTransitionView.frame];
    animation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
    snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *snapshotAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    snapshotAlphaAnimation.fromValue = @([snapshotView alpha]);
    snapshotAlphaAnimation.toValue = @(0.0f);
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [toTransitionView removeFromSuperview];
        [snapshotView removeFromSuperview];
         
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:@[ animation, snapshotAnimation, snapshotAlphaAnimation ]];
    
    [toTransitionView pop_addAnimation:animation forKey:@"frame"];
    [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    [snapshotView pop_addAnimation:snapshotAlphaAnimation forKey:@"alpha"];
}

- (CGRect)transitionOutReferenceFrame
{
    return [_cropView cropRectFrameForView:self.view];
}

- (UIView *)transitionOutReferenceView
{
    return [_cropView cropSnapshotView];
}

- (void)prepareTransitionOutSaving:(bool)saving
{
    if (saving)
    {
        _transitionOutFrame = [_cropView cropRectFrameForView:self.view];
        
        [_cropView performConfirmAnimated:false updateInterface:false];
     
        _transitionOutView = [[UIImageView alloc] initWithImage:[_cropView croppedImageWithMaxSize:CGSizeMake(1280, 1280)]];
        _transitionOutView.frame = _transitionOutFrame;
        
        [self.view addSubview:_transitionOutView];

        _cropView.hidden = true;
        
        [self _updateEditorValues];
    }
}

- (id)currentResultRepresentation
{
    if (_transitionOutView != nil && [_transitionOutView isKindOfClass:[UIImageView class]]) {
        return ((UIImageView *)_transitionOutView).image;
    } else {
        return [_cropView croppedImageWithMaxSize:TGPhotoEditorScreenImageMaxSize()];
    }
}

#pragma mark - Actions

- (UIImageOrientation)cropOrientation
{
    return _cropView.cropOrientation;
}

- (void)rotate
{
    [_cropView rotate90DegreesCCWAnimated:true];
}

- (void)mirror
{
    [_cropView mirror];
    
    [self _updateTabs];
}

- (void)aspectRatioButtonPressed
{
    if (_cropView.isAnimating)
        return;
    
    if (_cropView.isAspectRatioLocked)
    {
        [_cropView unlockAspectRatio];
    }
    else
    {
        [_cropView performConfirmAnimated:true];
        
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.hasSwipeGesture = true;
        __weak TGMenuSheetController *weakController = controller;
        __weak TGPhotoCropController *weakSelf = self;
        
        void (^action)(NSString *) = ^(NSString *ratioString)
        {
            __strong TGPhotoCropController *strongSelf = weakSelf;
            __strong TGMenuSheetController *strongController = weakController;
            if (strongSelf == nil)
                return;
            
            CGFloat aspectRatio = 0.0f;
            if ([ratioString isEqualToString:TGPhotoCropOriginalAspectRatio])
            {
                PGPhotoEditor *photoEditor = strongSelf->_photoEditor;
                aspectRatio = photoEditor.originalSize.height / photoEditor.originalSize.width;
            }
            else
            {
                aspectRatio = [ratioString floatValue];
                if (_cropView.cropOrientation == UIImageOrientationLeft || _cropView.cropOrientation == UIImageOrientationRight)
                    aspectRatio = 1.0f / aspectRatio;
            }
            
            void (^setAspectRatioBlock)(void) = ^
            {
                [strongSelf setAutoButtonHidden:true];
                [strongSelf->_cropView setLockedAspectRatio:aspectRatio performResize:true animated:true];
                
                [strongSelf _updateTabs];
            };
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                setAspectRatioBlock();
            else
                TGDispatchAfter(0.1f, dispatch_get_main_queue(), setAspectRatioBlock);
            
            [strongController dismissAnimated:true];
        };
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"PhotoEditor.CropAspectRatioOriginal") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^{ action(TGPhotoCropOriginalAspectRatio); }]];
        [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"PhotoEditor.CropAspectRatioSquare") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^{ action(@"1.0"); }]];
        
        CGSize croppedImageSize = _cropView.cropRect.size;
        if (_cropView.cropOrientation == UIImageOrientationLeft || _cropView.cropOrientation == UIImageOrientationRight)
            croppedImageSize = CGSizeMake(croppedImageSize.height, croppedImageSize.width);
        
        static NSArray *ratiosDefinitions = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            ratiosDefinitions = @
            [
                @[ @3.0f, @2.0f ],
                @[ @5.0f, @3.0f ],
                @[ @4.0f, @3.0f ],
                @[ @5.0f, @4.0f ],
                @[ @7.0f, @5.0f ],
                @[ @16.0f, @9.0f ]
            ];
        });
        
        for (NSArray *ratioDef in ratiosDefinitions)
        {
            CGFloat widthComponent;
            CGFloat heightComponent;
            CGFloat ratio = 0.0f;
            
            if (croppedImageSize.width >= croppedImageSize.height)
            {
                widthComponent = [ratioDef.firstObject floatValue];
                heightComponent = [ratioDef.lastObject floatValue];
            }
            else
            {
                widthComponent = [ratioDef.lastObject floatValue];
                heightComponent = [ratioDef.firstObject floatValue];
            }
            
            ratio = heightComponent / widthComponent;
            
            [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:[NSString stringWithFormat:@"%d:%d", (int)widthComponent, (int)heightComponent] type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^{ action([NSString stringWithFormat:@"%f", ratio]); }]];
        }
        
        [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController != nil)
                [strongController dismissAnimated:true];
        }]];
        
        [controller setItemViews:items];
//        controller.sourceRect = ^CGRect
//        {
//            __strong TGPhotoCropController *strongSelf = weakSelf;
//            if (strongSelf != nil)
//                return [strongSelf.view convertRect:strongSelf->_aspectRatioButton.frame fromView:strongSelf->_aspectRatioButton.superview];
//
//            return CGRectZero;
//        };
        [controller presentInViewController:self.parentViewController sourceView:self.view animated:true];
    }
    
    [self _updateTabs];
}

- (void)resetButtonPressed
{
    if (_cropView.isAnimatingRotation)
        return;
    
    bool hasAutorotationAngle = ABS(_autoRotationAngle) > FLT_EPSILON;
    PGPhotoEditor *photoEditor = self.photoEditor;
    
    if ([photoEditor hasDefaultCropping] && photoEditor.cropLockedAspectRatio < FLT_EPSILON && hasAutorotationAngle && _resetButton.selected)
    {
        [_cropView setRotation:_autoRotationAngle animated:true];
        [self setAutoButtonHidden:true];
    }
    else
    {
        [_cropView resetAnimated:true];
        
        if (hasAutorotationAngle)
            [self setAutoButtonHidden:false];
    }
    
    [self _updateTabs];
    
    if (self.cropReset != nil)
        self.cropReset();
}

- (void)setAutoButtonHidden:(bool)hidden
{
    if (hidden)
    {
        _resetButton.selected = false;
        [_resetButton setTitle:TGLocalized(@"PhotoEditor.CropReset") forState:UIControlStateNormal];
    }
    else
    {
        _resetButton.selected = true;
        [_resetButton setTitle:TGLocalized(@"PhotoEditor.CropAuto") forState:UIControlStateNormal];
    }
}

#pragma mark - Layout

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation hasArbitraryRotation:(bool)hasArbitraryRotation hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGFloat panelToolbarPortraitSize = TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = toolbarLandscapeSize;
    
    if (hasArbitraryRotation)
    {
        panelToolbarPortraitSize += TGPhotoEditorPanelSize;
        panelToolbarLandscapeSize += TGPhotoEditorPanelSize;
    }
    else
    {
        panelToolbarPortraitSize += TGPhotoEditorPanelSize - 55;
        panelToolbarLandscapeSize += TGPhotoEditorPanelSize - 55;
    }
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            return CGRectMake(panelToolbarLandscapeSize + safeAreaInset.left, 0, parentViewFrame.size.width - panelToolbarLandscapeSize - safeAreaInset.left - safeAreaInset.right, parentViewFrame.size.height - safeAreaInset.bottom);
            
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(safeAreaInset.left, 0, parentViewFrame.size.width - panelToolbarLandscapeSize - safeAreaInset.left - safeAreaInset.right, parentViewFrame.size.height - safeAreaInset.bottom);
            
        default:
            return CGRectMake(0, safeAreaInset.top, parentViewFrame.size.width, parentViewFrame.size.height - panelToolbarPortraitSize - safeAreaInset.top - safeAreaInset.bottom);
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    UIView *snapshotView = [_buttonsWrapperView snapshotViewAfterScreenUpdates:false];
    snapshotView.frame = _buttonsWrapperView.frame;
    [_wrapperView insertSubview:snapshotView aboveSubview:_buttonsWrapperView];
    
    _buttonsWrapperView.alpha = 0.0f;
    [UIView animateWithDuration:duration animations:^
    {
        _buttonsWrapperView.alpha = 1.0f;
        snapshotView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [snapshotView removeFromSuperview];
    }];
    
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    orientation = [self effectiveOrientation:orientation];
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoEditorPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2 , (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    
    UIEdgeInsets initialScreenEdges = screenEdges;
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    [UIView performWithoutAnimation:^
    {
        switch (orientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.left + self.toolbarLandscapeSize, screenEdges.top, TGPhotoCropButtonsWrapperSize, referenceSize.height);
                                
                _resetButton.transform = CGAffineTransformIdentity;
                _resetButton.frame = CGRectMake(0, 0, _resetButtonWidth, 24);
                
                CGFloat xOrigin = 0.0f;
                if (_resetButton.frame.size.width > _buttonsWrapperView.frame.size.width)
                {
                    _resetButton.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
                    xOrigin = 8.0f;
                }
                
                _resetButton.frame = CGRectMake(_buttonsWrapperView.frame.size.width - _resetButton.frame.size.width - xOrigin, (_buttonsWrapperView.frame.size.height - _resetButton.frame.size.height) / 2.0f, _resetButton.frame.size.width, _resetButton.frame.size.height);
            }
                break;
                
            case UIInterfaceOrientationLandscapeRight:
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.right - self.toolbarLandscapeSize - TGPhotoCropButtonsWrapperSize, screenEdges.top, TGPhotoCropButtonsWrapperSize, referenceSize.height);
                                
                _resetButton.transform = CGAffineTransformIdentity;
                _resetButton.frame = CGRectMake(0, 0, _resetButtonWidth, 24);
                
                CGFloat xOrigin = 0.0f;
                if (_resetButtonWidth > _buttonsWrapperView.frame.size.width)
                {
                    _resetButton.transform = CGAffineTransformMakeRotation((CGFloat)-M_PI_2);
                    xOrigin = 8.0f;
                }
                
                _resetButton.frame = CGRectMake(xOrigin, (_buttonsWrapperView.frame.size.height - _resetButton.frame.size.height) / 2, _resetButton.frame.size.width, _resetButton.frame.size.height);
            }
                break;
                
            default:
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - TGPhotoEditorToolbarSize - TGPhotoCropButtonsWrapperSize, referenceSize.width, TGPhotoCropButtonsWrapperSize);
                
                _resetButton.transform = CGAffineTransformIdentity;
                _resetButton.frame = CGRectMake((_buttonsWrapperView.frame.size.width - _resetButton.frame.size.width) / 2, 20, _resetButtonWidth, 24);
            }
                break;
        }
    }];
        
    CGRect containerFrame = [TGPhotoCropController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation hasArbitraryRotation:_cropView.hasArbitraryRotation hasOnScreenNavigation:hasOnScreenNavigation];
    containerFrame = CGRectOffset(containerFrame, initialScreenEdges.left, initialScreenEdges.top);
    _cropView.interfaceOrientation = orientation;
    _cropView.frame = CGRectInset(containerFrame, TGPhotoCropAreaInsetSize.width, TGPhotoCropAreaInsetSize.height);
    
    [UIView performWithoutAnimation:^
    {
        [_cropView _layoutRotationView];
    }];
}

- (TGPhotoEditorTab)availableTabs
{
    return TGPhotoEditorRotateTab | TGPhotoEditorMirrorTab | TGPhotoEditorAspectRatioTab;
}

- (void)handleTabAction:(TGPhotoEditorTab)tab
{
    switch (tab)
    {
        case TGPhotoEditorRotateTab:
        {
            [self rotate];
        }
            break;
            
        case TGPhotoEditorMirrorTab:
        {
            [self mirror];
        }
            break;
            
        case TGPhotoEditorAspectRatioTab:
        {
            [self aspectRatioButtonPressed];
        }
            break;
            
        default:
            break;
    }
}

- (TGPhotoEditorTab)highlightedTabs
{
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    
    if (_cropView.mirrored)
        tabs |= TGPhotoEditorMirrorTab;
    if (_cropView.lockedAspectRatio > FLT_EPSILON)
        tabs |= TGPhotoEditorAspectRatioTab;
    
    return tabs;

}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeTop | UIRectEdgeBottom;
}

@end
