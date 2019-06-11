#import "TGPhotoAvatarCropController.h"

#import "LegacyComponentsInternal.h"

#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "PGPhotoEditor.h"
#import "TGPhotoEditorPreviewView.h"

#import "TGPhotoAvatarCropView.h"
#import <LegacyComponents/TGModernButton.h>

#import "TGPhotoPaintController.h"

const CGFloat TGPhotoAvatarCropButtonsWrapperSize = 61.0f;

@interface TGPhotoAvatarCropController ()
{
    UIView *_wrapperView;
    
    UIView *_buttonsWrapperView;
    TGModernButton *_rotateButton;
    TGModernButton *_mirrorButton;
    TGModernButton *_resetButton;
    
    TGPhotoAvatarCropView *_cropView;
    UIView *_snapshotView;
    UIImage *_snapshotImage;
    
    bool _appeared;
    UIImage *_imagePendingLoad;
    
    dispatch_semaphore_t _waitSemaphore;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoAvatarCropController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _waitSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    __weak TGPhotoAvatarCropController *weakSelf = self;
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoAvatarCropController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
    };
    
    _wrapperView = [[UIView alloc] initWithFrame:self.view.bounds];
    _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_wrapperView];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    _cropView = [[TGPhotoAvatarCropView alloc] initWithOriginalSize:photoEditor.originalSize screenSize:[self referenceViewSize]];
    [_cropView setCropRect:photoEditor.cropRect];
    [_cropView setCropOrientation:photoEditor.cropOrientation];
    [_cropView setCropMirrored:photoEditor.cropMirrored];
    _cropView.croppingChanged = ^
    {
        __strong TGPhotoAvatarCropController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        photoEditor.cropRect = strongSelf->_cropView.cropRect;
        photoEditor.cropOrientation = strongSelf->_cropView.cropOrientation;
        photoEditor.cropMirrored = strongSelf->_cropView.cropMirrored;
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
    
    _buttonsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_buttonsWrapperView];
    
    _rotateButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    _rotateButton.exclusiveTouch = true;
    _rotateButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
    [_rotateButton addTarget:self action:@selector(rotate) forControlEvents:UIControlEventTouchUpInside];
    [_rotateButton setImage:TGComponentsImageNamed(@"PhotoEditorRotateIcon") forState:UIControlStateNormal];
    [_buttonsWrapperView addSubview:_rotateButton];
    
    _mirrorButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    _mirrorButton.exclusiveTouch = true;
    _mirrorButton.imageEdgeInsets = UIEdgeInsetsMake(4.0f, 0.0f, 0.0f, 0.0f);
    _mirrorButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
    [_mirrorButton addTarget:self action:@selector(mirror) forControlEvents:UIControlEventTouchUpInside];
    [_mirrorButton setImage:TGComponentsImageNamed(@"PhotoEditorMirrorIcon") forState:UIControlStateNormal];
    [_buttonsWrapperView addSubview:_mirrorButton];
    
    _resetButton = [[TGModernButton alloc] init];
    _resetButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 8.0f, 0.0f, 8.0f);
    _resetButton.exclusiveTouch = true;
    _resetButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
    _resetButton.titleLabel.font = [TGFont systemFontOfSize:13];
    [_resetButton addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
    [_resetButton setTitle:TGLocalized(@"PhotoEditor.CropReset") forState:UIControlStateNormal];
    [_resetButton setTitleColor:[UIColor whiteColor]];
    [_resetButton sizeToFit];
    _resetButton.frame = CGRectMake(0, 0, _resetButton.frame.size.width, 24);
    [_buttonsWrapperView addSubview:_resetButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_appeared)
        return;
    
    if (self.initialAppearance && self.skipTransitionIn)
    {
        [self _finishedTransitionInWithView:nil];
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
    }
    else
    {
        [self transitionIn];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _appeared = true;
    
    if (_imagePendingLoad != nil)
        [_cropView setImage:_imagePendingLoad];
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
    [_cropView _replaceSnapshotImage:snapshotImage];
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    _snapshotView = snapshotView;
}

#pragma mark - Transition

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)parentView noTransitionView:(bool)noTransitionView
{
    [super prepareTransitionInWithReferenceView:referenceView referenceFrame:referenceFrame parentView:parentView noTransitionView:noTransitionView];
    [self.view insertSubview:_transitionView belowSubview:_wrapperView];
}

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
    [transitionView removeFromSuperview];
    
    _buttonsWrapperView.alpha = 1.0f;
    [_cropView transitionInFinishedFromCamera:(self.fromCamera && self.initialAppearance)];
}

- (void)_finishedTransitionIn
{
    [_cropView animateTransitionIn];
    [_cropView transitionInFinishedFromCamera:true];
}

- (void)prepareForCustomTransitionOut
{
    [_cropView hideImageForCustomTransition];
    [_cropView animateTransitionOutSwitching:false];
    [UIView animateWithDuration:0.3f animations:^
    {
     _buttonsWrapperView.alpha = 0.0f;
    } completion:nil];
}

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion
{
    _dismissing = true;
    
    [_cropView animateTransitionOutSwitching:switching];
        
    if (switching)
    {
        _switching = true;
        
        TGPhotoEditorPreviewView *previewView = self.previewView;
        [previewView performTransitionToCropAnimated:false];
        [previewView setSnapshotView:[_cropView cropSnapshotView]];
        
        PGPhotoEditor *photoEditor = self.photoEditor;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            if (dispatch_semaphore_wait(_waitSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC))))
            {
                TGLegacyLog(@"Photo crop on switching failed");
                return;
            }
            
            UIImage *croppedImage = [_cropView croppedImageWithMaxSize:TGPhotoEditorScreenImageMaxSize()];
            [photoEditor setImage:croppedImage forCropRect:_cropView.cropRect cropRotation:0.0f cropOrientation:_cropView.cropOrientation cropMirrored:_cropView.cropMirrored fullSize:false];
            
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
        
        UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
        if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            orientation = UIInterfaceOrientationPortrait;
        
        bool hasOnScreenNavigation = false;
        if (iosMajorVersion() >= 11)
            hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
        
        CGRect cropRectFrame = [_cropView cropRectFrameForView:self.view];
        CGSize referenceSize = [self referenceViewSizeForOrientation:orientation];
        CGRect referenceBounds = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
        CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:referenceBounds toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
        
        if (self.switchingToTab == TGPhotoEditorPaintTab)
        {
            containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:referenceBounds toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
        }
        
        CGSize fittedSize = TGScaleToSize(cropRectFrame.size, containerFrame.size);
        CGRect targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                        containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                        fittedSize.width,
                                        fittedSize.height);
        
        UIView *snapshotView = [_cropView cropSnapshotView];
        snapshotView.alpha = 0.0f;
        snapshotView.frame = cropRectFrame;
        [self.view addSubview:snapshotView];

        CGRect targetCropViewFrame = [self.view convertRect:targetFrame toView:_wrapperView];
        
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews animations:^
        {
            snapshotView.frame = targetFrame;
            snapshotView.alpha = 1.0f;
            _cropView.frame = targetCropViewFrame;
            [_cropView invalidateCropRect];
        } completion:^(__unused BOOL finished)
        {
            if (self.finishedTransitionOut != nil)
                self.finishedTransitionOut();
        }];
    }
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _buttonsWrapperView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (void)transitionOutSaving:(bool)__unused saving completion:(void (^)(void))completion
{
    CGRect referenceFrame = [_cropView contentFrameForView:self.view];
    
    CGSize referenceSize = [self referenceViewSize];
    
    UIImageView *snapshotView = [[UIImageView alloc] initWithImage:_cropView.image];
    snapshotView.frame = [_wrapperView convertRect:referenceFrame fromView:nil];
    snapshotView.alpha = 0.0f;
    [_wrapperView insertSubview:snapshotView belowSubview:_cropView];
    
    [self transitionOutSwitching:false completion:nil];

    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent))
    {        
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            referenceFrame = CGRectMake(referenceSize.height - referenceFrame.size.height - referenceFrame.origin.y,
                                        referenceSize.width - referenceFrame.size.width - referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            referenceFrame = CGRectMake(referenceFrame.origin.y,
                                        referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
    }
    
    UIView *referenceView = nil;
    UIView *parentView = nil;
    if (self.beginTransitionOut != nil)
        referenceView = self.beginTransitionOut(&referenceFrame, &parentView);
    
    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent))
    {
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            referenceFrame = CGRectMake(referenceSize.width - referenceFrame.size.height - referenceFrame.origin.y,
                                        referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            referenceFrame = CGRectMake(referenceFrame.origin.y,
                                        referenceSize.height - referenceFrame.size.width - referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
    }
    
    POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    animation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
    animation.toValue = [NSValue valueWithCGRect:[_wrapperView convertRect:referenceFrame fromView:nil]];
    
    POPSpringAnimation *alphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    alphaAnimation.fromValue = @(snapshotView.alpha);
    alphaAnimation.toValue = @(0.0f);
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [snapshotView removeFromSuperview];
         
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:@[ animation, alphaAnimation ]];
    
    [snapshotView pop_addAnimation:animation forKey:@"frame"];
    [snapshotView pop_addAnimation:alphaAnimation forKey:@"alpha"];
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;

    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0.0f hasOnScreenNavigation:hasOnScreenNavigation];

    CGRect targetFrame = CGRectZero;
    
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    if (self.initialAppearance && (self.fromCamera || !self.skipTransitionIn))
    {
        CGSize referenceSize = fromFrame.size;
        if ([_transitionView isKindOfClass:[UIImageView class]])
            referenceSize = ((UIImageView *)_transitionView).image.size;
        
        CGSize fittedSize = TGScaleToFill(referenceSize, CGSizeMake(diameter, diameter));

        targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                 containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                 fittedSize.width, fittedSize.height);
    }
    else
    {
        targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - diameter) / 2,
                                 containerFrame.origin.y + (containerFrame.size.height - diameter) / 2,
                                 diameter, diameter);
    }

    return targetFrame;
}

- (CGRect)transitionOutReferenceFrame
{
    return [_cropView cropRectFrameForView:self.view];
}

- (UIView *)transitionOutReferenceView
{
    return [_cropView cropSnapshotView];
}

- (id)currentResultRepresentation
{
    return [_cropView cropSnapshotView];
}

#pragma mark - Actions

- (void)rotate
{
    [_cropView rotate90DegreesCCWAnimated:true];
}

- (void)mirror
{
    [_cropView mirror];
}

- (void)reset
{
    [_cropView resetAnimated:true];
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
        _resetButton.hidden = true;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        [_cropView updateCircleImageWithReferenceSize:referenceSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoEditorPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - self.view.frame.size.height) / 2, (screenSide - self.view.frame.size.width) / 2, (screenSide + self.view.frame.size.height) / 2, (screenSide + self.view.frame.size.width) / 2);
    
    UIEdgeInsets initialScreenEdges = screenEdges;
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.left + self.toolbarLandscapeSize,
                                                       screenEdges.top,
                                                       TGPhotoAvatarCropButtonsWrapperSize,
                                                       referenceSize.height);
                 
                _rotateButton.frame = CGRectMake(25 + 2.0f, 10, _rotateButton.frame.size.width, _rotateButton.frame.size.height);
                _mirrorButton.frame = CGRectMake(25, 60, _mirrorButton.frame.size.width, _mirrorButton.frame.size.height);
                
                _resetButton.transform = CGAffineTransformIdentity;
                [_resetButton sizeToFit];
                _resetButton.frame = CGRectMake(0, 0, _resetButton.frame.size.width, 24);
                
                CGFloat xOrigin = 0;
                if (_resetButton.frame.size.width > _buttonsWrapperView.frame.size.width)
                {
                    _resetButton.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
                    xOrigin = 12;
                }
                
                _resetButton.frame = CGRectMake(_buttonsWrapperView.frame.size.width - _resetButton.frame.size.width - xOrigin,
                                                (_buttonsWrapperView.frame.size.height - _resetButton.frame.size.height) / 2,
                                                _resetButton.frame.size.width,
                                                _resetButton.frame.size.height);
            }];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.right - self.toolbarLandscapeSize - TGPhotoAvatarCropButtonsWrapperSize,
                                                       screenEdges.top,
                                                       TGPhotoAvatarCropButtonsWrapperSize,
                                                       referenceSize.height);
                 
                _rotateButton.frame = CGRectMake(_buttonsWrapperView.frame.size.width - _rotateButton.frame.size.width - 25 + 2.0f, 10, _rotateButton.frame.size.width, _rotateButton.frame.size.height);
                _mirrorButton.frame = CGRectMake(_buttonsWrapperView.frame.size.width - _mirrorButton.frame.size.width - 25, 60, _mirrorButton.frame.size.width, _mirrorButton.frame.size.height);
                
                _resetButton.transform = CGAffineTransformIdentity;
                [_resetButton sizeToFit];
                CGSize resetButtonSize = _resetButton.frame.size;
                CGFloat xOrigin = 0;
                if (resetButtonSize.width > _buttonsWrapperView.frame.size.width)
                {
                    _resetButton.transform = CGAffineTransformMakeRotation((CGFloat)-M_PI_2);
                    xOrigin = 12;
                }
                
                _resetButton.frame = CGRectMake(xOrigin,
                                                (_buttonsWrapperView.frame.size.height - _resetButton.frame.size.height) / 2,
                                                _resetButton.frame.size.width,
                                                _resetButton.frame.size.height);
            }];
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _buttonsWrapperView.frame = CGRectMake(screenEdges.left,
                                                       screenEdges.bottom - TGPhotoEditorToolbarSize - TGPhotoAvatarCropButtonsWrapperSize,
                                                       referenceSize.width,
                                                       TGPhotoAvatarCropButtonsWrapperSize);
                 
                _rotateButton.frame = CGRectMake(10, _buttonsWrapperView.frame.size.height - _rotateButton.frame.size.height - 25 + 2.0f, _rotateButton.frame.size.width, _rotateButton.frame.size.height);
                _mirrorButton.frame = CGRectMake(60, _buttonsWrapperView.frame.size.height - _mirrorButton.frame.size.height - 25, _mirrorButton.frame.size.width, _mirrorButton.frame.size.height);
                
                _resetButton.transform = CGAffineTransformIdentity;
                [_resetButton sizeToFit];
                _resetButton.frame = CGRectMake((_buttonsWrapperView.frame.size.width - _resetButton.frame.size.width) / 2,
                                                10,
                                                _resetButton.frame.size.width,
                                                24);
             }];
        }
            break;
    }
    
    if (_dismissing)
        return;
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0.0f hasOnScreenNavigation:hasOnScreenNavigation];
    containerFrame = CGRectOffset(containerFrame, initialScreenEdges.left, initialScreenEdges.top);
    
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    _cropView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - diameter) / 2,
                                 containerFrame.origin.y + (containerFrame.size.height - diameter) / 2,
                                 diameter,
                                 diameter);
}

- (TGPhotoEditorTab)availableTabs
{
    return iosMajorVersion() >= 7 ? (TGPhotoEditorPaintTab | TGPhotoEditorToolsTab) : TGPhotoEditorNoneTab;
}

@end
