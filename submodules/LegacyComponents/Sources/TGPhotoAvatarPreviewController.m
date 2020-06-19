#import "TGPhotoAvatarPreviewController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"

#import "PGPhotoEditor.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>

#import "TGPhotoEditorController.h"
#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoEditorSparseView.h"

#import "TGMediaPickerGalleryVideoScrubber.h"

const CGFloat TGPhotoAvatarPreviewPanelSize = 96.0f;
const CGFloat TGPhotoAvatarPreviewLandscapePanelSize = TGPhotoAvatarPreviewPanelSize + 40.0f;

@interface TGPhotoAvatarPreviewController () <TGMediaPickerGalleryVideoScrubberDataSource, TGMediaPickerGalleryVideoScrubberDelegate>
{
    bool _appeared;
    
    TGPhotoEditorSparseView *_wrapperView;
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    UIView *_portraitWrapperBackgroundView;
    UIView *_landscapeWrapperBackgroundView;
        
    UIView *_videoAreaView;
    UIView *_flashView;
    UIView *_portraitToolControlView;
    UIView *_landscapeToolControlView;
    UIImageView *_areaMaskView;
    CGFloat _currentDiameter;
    
    TGMediaPickerGalleryVideoScrubber *_scrubberView;
    UILabel *_coverLabel;
    bool _wasPlayingBeforeScrubbing;
    bool _requestingThumbnails;
    SMetaDisposable *_thumbnailsDisposable;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoAvatarPreviewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _thumbnailsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_thumbnailsDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.view addSubview:_previewView];
    
    if (self.item.isVideo) {
        _wrapperView = [[TGPhotoEditorSparseView alloc] initWithFrame:CGRectZero];
        [self.view addSubview:_wrapperView];
            
        _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        _portraitToolsWrapperView.alpha = 0.0f;
        [_wrapperView addSubview:_portraitToolsWrapperView];
        
        _portraitWrapperBackgroundView = [[UIView alloc] initWithFrame:_portraitToolsWrapperView.bounds];
        _portraitWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _portraitWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _portraitWrapperBackgroundView.userInteractionEnabled = false;
        [_portraitToolsWrapperView addSubview:_portraitWrapperBackgroundView];

        _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        _landscapeToolsWrapperView.alpha = 0.0f;
        [_wrapperView addSubview:_landscapeToolsWrapperView];
        
        _landscapeWrapperBackgroundView = [[UIView alloc] initWithFrame:_landscapeToolsWrapperView.bounds];
        _landscapeWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _landscapeWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _landscapeWrapperBackgroundView.userInteractionEnabled = false;
        [_landscapeToolsWrapperView addSubview:_landscapeWrapperBackgroundView];
        
        _videoAreaView = [[UIView alloc] init];
        [self.view insertSubview:_videoAreaView belowSubview:_wrapperView];
    }
    
    _flashView = [[UIView alloc] init];
    _flashView.alpha = 0.0;
    _flashView.backgroundColor = [UIColor whiteColor];
    _flashView.userInteractionEnabled = false;
    [_videoAreaView addSubview:_flashView];
    
    _areaMaskView = [[UIImageView alloc] init];
    _areaMaskView.alpha = 0.0f;
    [self.view insertSubview:_areaMaskView aboveSubview:_videoAreaView];
    
    _scrubberView = [[TGMediaPickerGalleryVideoScrubber alloc] initWithFrame:CGRectMake(0.0f, 0.0, _portraitToolsWrapperView.frame.size.width, 68.0f)];
    _scrubberView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _scrubberView.dataSource = self;
    _scrubberView.delegate = self;
    [_portraitToolsWrapperView addSubview:_scrubberView];
    
    _coverLabel = [[UILabel alloc] init];
    _coverLabel.alpha = 0.7f;
    _coverLabel.backgroundColor = [UIColor clearColor];
    _coverLabel.font = TGSystemFontOfSize(14.0f);
    _coverLabel.textColor = [UIColor whiteColor];
    _coverLabel.text = TGLocalized(@"PhotoEditor.SelectCoverFrame");
    [_coverLabel sizeToFit];
    [_portraitToolsWrapperView addSubview:_coverLabel];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self transitionIn];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _scrubberView.allowsTrimming = true;
    _scrubberView.disableZoom = true;
    _scrubberView.disableTimeDisplay = true;
    _scrubberView.trimStartValue = 0.0;
    _scrubberView.trimEndValue = self.item.originalDuration;
    [_scrubberView reloadData];
    [_scrubberView resetToStart];
}

- (BOOL)shouldAutorotate
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared;
}

#pragma mark - Transition

- (void)transitionIn
{
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
    }];
    
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
            
        default:
        {
            _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
    }
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))completion
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.touchedUp = nil;
    previewView.touchedDown = nil;
    previewView.tapped = nil;
    previewView.interactionEnded = nil;
    
    [_videoAreaView.superview bringSubviewToFront:_videoAreaView];

    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        default:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f);
            } completion:nil];
        }
            break;
    }
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        _videoAreaView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    [previewView prepareForTransitionOut];
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    
    if (saving && CGRectIsNull(targetFrame) && parentView != nil)
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = previewView.frame;
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2, (self.view.frame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    }
    
    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    
    NSMutableArray *animations = [NSMutableArray arrayWithArray:@[ previewAnimation, previewAlphaAnimation ]];
    if (snapshotAnimation != nil)
        [animations addObject:snapshotAnimation];
    
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
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {
        [self.view insertSubview:transitionView atIndex:0];
    } else {
        [transitionView removeFromSuperview];
    }
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = false;
    [previewView performTransitionInIfNeeded];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    [photoEditor processAnimated:false completion:nil];
}

- (void)prepareForCustomTransitionOut
{
    _previewView.hidden = true;
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
    } completion:nil];
}

- (CGRect)transitionOutReferenceFrame
{
    TGPhotoEditorPreviewView *previewView = _previewView;
    return previewView.frame;
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
    return [self snapshotView];
//    return TGPaintCombineCroppedImages(self.photoEditor.currentResultImage, self.photoEditor.paintingData.image, true, self.photoEditor.originalSize, self.photoEditor.cropRect, self.photoEditor.cropOrientation, self.photoEditor.cropRotation, self.photoEditor.cropMirrored);
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0 hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return sourceFrame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0 hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGRect frame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    return frame;
}

- (void)updateToolViews
{
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([self inFormSheet] || TGIsPad())
    {
        _landscapeToolsWrapperView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoAvatarPreviewPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    CGFloat panelSize = UIInterfaceOrientationIsPortrait(orientation) ? TGPhotoAvatarPreviewPanelSize : TGPhotoAvatarPreviewLandscapePanelSize;
//    if (_portraitToolControlView != nil)
//        panelSize = TGPhotoEditorPanelSize;
    
    CGFloat panelToolbarPortraitSize = panelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = panelSize + TGPhotoEditorToolbarSize;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
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
                _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
//                _landscapeCollectionView.frame = CGRectMake(panelToolbarLandscapeSize - panelSize, 0, panelSize, _landscapeCollectionView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
//            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, _landscapeCollectionView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
//            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
//                _landscapeCollectionView.frame = CGRectMake(0, 0, panelSize, _landscapeCollectionView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
//            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, _landscapeCollectionView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.top, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
//            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _portraitToolControlView.frame = CGRectMake(0, 0, referenceSize.width, panelSize);
            }];
             
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - TGPhotoAvatarPreviewPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
//            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, panelSize, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _scrubberView.frame = CGRectMake(0.0, 0.0, _portraitToolsWrapperView.frame.size.width, _scrubberView.frame.size.height);
            _coverLabel.frame = CGRectMake(floor((_portraitToolsWrapperView.frame.size.width - _coverLabel.frame.size.width) / 2.0), CGRectGetMaxY(_scrubberView.frame) + 6.0, _coverLabel.frame.size.width, _coverLabel.frame.size.height);
//            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
        }
            break;
    }
}

- (void)updatePreviewView
{
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([self inFormSheet] || TGIsPad())
        orientation = UIInterfaceOrientationPortrait;
    
    CGSize referenceSize = [self referenceViewSize];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view)
        return;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0 hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    [UIView performWithoutAnimation:^
    {
        _videoAreaView.frame = _previewView.frame;
        _flashView.frame = _videoAreaView.bounds;
        _areaMaskView.frame = _previewView.frame;
        
        [self updateCircleImage];
    }];
}

- (void)updateCircleImage
{
    CGFloat diameter = _areaMaskView.frame.size.width;
 
    if (fabs(diameter - _currentDiameter) < DBL_EPSILON)
        return;
    
    _currentDiameter = diameter;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets cropTransparentOverlayColor].CGColor);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, diameter, diameter)];
    [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, diameter, diameter)]];
    path.usesEvenOddFillRule = true;
    [path fill];
    
    UIImage *areaMaskImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _areaMaskView.image = areaMaskImage;
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet] || TGIsPad())
        orientation = UIInterfaceOrientationPortrait;
    
    if (!_dismissing)
        [self updateToolViews];

    dispatch_async(dispatch_get_main_queue(), ^{
       [_scrubberView reloadThumbnails];
    });
        
    [self updatePreviewView];
}

- (TGPhotoEditorTab)availableTabs
{
    return TGPhotoEditorPaintTab | TGPhotoEditorToolsTab;
}

- (TGPhotoEditorTab)activeTab
{
    return TGPhotoEditorCropTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    bool hasSimpleValue = false;
    bool hasBlur = false;
    bool hasCurves = false;
    bool hasTint = false;
    
//    for (PGPhotoTool *tool in _allTools)
//    {
//        if (tool.isSimple)
//        {
//            if (tool.stringValue != nil)
//                hasSimpleValue = true;
//        }
//        else if ([tool isKindOfClass:[PGBlurTool class]] && tool.stringValue != nil)
//        {
//            hasBlur = true;
//        }
//        else if ([tool isKindOfClass:[PGCurvesTool class]] && tool.stringValue != nil)
//        {
//            hasCurves = true;
//        }
//        else if ([tool isKindOfClass:[PGTintTool class]] && tool.stringValue != nil)
//        {
//            hasTint = true;
//        }
//    }
//
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    
    if (hasSimpleValue)
        tabs |= TGPhotoEditorToolsTab;
    if (hasBlur)
        tabs |= TGPhotoEditorBlurTab;
    if (hasCurves)
        tabs |= TGPhotoEditorCurvesTab;
    if (hasTint)
        tabs |= TGPhotoEditorTintTab;
    
    return tabs;
}

- (void)setPlayButtonHidden:(bool)hidden animated:(bool)animated
{
//    if (animated)
//    {
//        _actionButton.hidden = false;
//        [UIView animateWithDuration:0.15f animations:^
//        {
//            _actionButton.alpha = hidden ? 0.0f : 1.0f;
//        } completion:^(BOOL finished)
//        {
//            if (finished)
//                _actionButton.hidden = hidden;
//        }];
//    }
//    else
//    {
//        _actionButton.alpha = hidden ? 0.0f : 1.0f;
//        _actionButton.hidden = hidden;
//    }
}

#pragma mark - Video Scrubber Data Source & Delegate

#pragma mark Scrubbing

- (NSTimeInterval)videoScrubberDuration:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    return self.item.originalDuration;
}

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    if (CGSizeEqualToSize(self.item.originalSize, CGSizeZero))
        return 1.0f;
    
    return self.item.originalSize.width / self.item.originalSize.height;
}

- (void)videoScrubberDidBeginScrubbing:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    _wasPlayingBeforeScrubbing = true;
    self.controlVideoPlayback(false);
    
    _scrubberView.dotValue = 0.0;
    
    _coverLabel.alpha = 1.0f;
    
    [self setPlayButtonHidden:true animated:false];
    
    [UIView animateWithDuration:0.2 animations:^{
        _areaMaskView.alpha = 1.0f;
    }];
}

- (void)videoScrubberDidEndScrubbing:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    [UIView animateWithDuration:0.12 animations:^{
        _flashView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            _flashView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            TGDispatchAfter(1.0, dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.2 animations:^{
                    _areaMaskView.alpha = 0.0f;
                    _coverLabel.alpha = 0.7f;
                }];
            
                self.controlVideoPlayback(true);
            });
        }];
    }];
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber valueDidChange:(NSTimeInterval)position
{
    self.controlVideoSeek(position);
}

#pragma mark Trimming

- (bool)hasTrimming
{
    return _scrubberView.hasTrimming;
}

- (CMTimeRange)trimRange
{
    return CMTimeRangeMake(CMTimeMakeWithSeconds(_scrubberView.trimStartValue , NSEC_PER_SEC), CMTimeMakeWithSeconds((_scrubberView.trimEndValue - _scrubberView.trimStartValue), NSEC_PER_SEC));
}

- (void)videoScrubberDidBeginEditing:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    self.controlVideoPlayback(false);
    
    [self setPlayButtonHidden:true animated:false];
}

- (void)videoScrubberDidEndEditing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber
{
    [self updatePlayerRange:videoScrubber.trimEndValue];
    
    self.controlVideoSeek(videoScrubber.trimStartValue);
    self.controlVideoPlayback(true);
    
    [self setPlayButtonHidden:false animated:true];
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue
{
    self.controlVideoSeek(startValue);
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue
{
    self.controlVideoSeek(endValue);
}

- (void)updatePlayerRange:(NSTimeInterval)trimEndValue
{
    self.controlVideoEndTime(trimEndValue);
}

#pragma mark Thumbnails

- (NSArray *)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp
{
    if (endTimestamp < startTimestamp)
        return nil;
    
    if (count == 0)
        return nil;

    NSTimeInterval duration = [self videoScrubberDuration:videoScrubber];
    if (endTimestamp > duration)
        endTimestamp = duration;
    
    NSTimeInterval interval = (endTimestamp - startTimestamp) / count;
    
    NSMutableArray *timestamps = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < count; i++)
        [timestamps addObject:@(startTimestamp + i * interval)];
    
    return timestamps;
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)size isSummaryThumbnails:(bool)isSummaryThumbnails
{
    if (timestamps.count == 0)
        return;
    
    id<TGMediaEditAdjustments> adjustments = [self.photoEditor exportAdjustments];
    
    SSignal *thumbnailsSignal = nil;
    if ([self.item isKindOfClass:[TGMediaAsset class]])
        thumbnailsSignal = [TGMediaAssetImageSignals videoThumbnailsForAsset:(TGMediaAsset *)self.item size:size timestamps:timestamps];
    else if ([self.item isKindOfClass:[TGCameraCapturedVideo class]])
        thumbnailsSignal = [((TGCameraCapturedVideo *)self.item).avAsset mapToSignal:^SSignal *(AVAsset *avAsset) {
            return [TGMediaAssetImageSignals videoThumbnailsForAVAsset:avAsset size:size timestamps:timestamps];
        }];

    _requestingThumbnails = true;
    
    __weak TGPhotoAvatarPreviewController *weakSelf = self;
    [_thumbnailsDisposable setDisposable:[[[thumbnailsSignal map:^NSArray *(NSArray *images) {
        if (adjustments.toolsApplied) {
            NSMutableArray *editedImages = [[NSMutableArray alloc] init];
            PGPhotoEditor *editor = [[PGPhotoEditor alloc] initWithOriginalSize:adjustments.originalSize adjustments:adjustments forVideo:false enableStickers:true];
            editor.standalone = true;
            for (UIImage *image in images) {
                [editor setImage:image forCropRect:adjustments.cropRect cropRotation:0.0 cropOrientation:adjustments.cropOrientation cropMirrored:adjustments.cropMirrored fullSize:false];
                UIImage *resultImage = editor.currentResultImage;
                if (resultImage != nil) {
                    [editedImages addObject:resultImage];
                } else {
                    [editedImages addObject:image];
                }
            }
            return editedImages;
        } else {
            return images;
        }
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *images)
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger index, __unused BOOL *stop)
        {
            if (index < timestamps.count)
                [strongSelf->_scrubberView setThumbnailImage:image forTimestamp:[timestamps[index] doubleValue] isSummaryThubmnail:isSummaryThumbnails];
        }];
    } completed:^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_requestingThumbnails = false;
    }]];
}

- (void)videoScrubberDidFinishRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    _requestingThumbnails = false;
    
//    [self setScrubbingPanelHidden:false animated:true];
}

- (void)videoScrubberDidCancelRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    _requestingThumbnails = false;
}

- (CGSize)videoScrubberOriginalSize:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored
{
    id<TGMediaEditAdjustments> adjustments = [self.photoEditor exportAdjustments];
    if (cropRect != NULL)
        *cropRect = (adjustments != nil) ? adjustments.cropRect : CGRectMake(0, 0, self.item.originalSize.width, self.item.originalSize.height);
    
    if (cropOrientation != NULL)
        *cropOrientation = (adjustments != nil) ? adjustments.cropOrientation : UIImageOrientationUp;
    
    if (cropMirrored != NULL)
        *cropMirrored = adjustments.cropMirrored;
    
    return self.item.originalSize;
}

- (void)setScrubberPosition:(NSTimeInterval)position reset:(bool)reset
{
     [_scrubberView setValue:_scrubberView.trimStartValue resetPosition:reset];
}

- (void)setScrubberPlaying:(bool)value
{
    [_scrubberView setIsPlaying:value];
}

- (NSTimeInterval)coverPosition {
    return _scrubberView.dotValue;
}

@end
