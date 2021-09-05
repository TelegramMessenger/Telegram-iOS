#import "TGPhotoToolsController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"
#import "TGPhotoEditorCollectionView.h"
#import "TGPhotoToolCell.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import "UICollectionView+Utils.h"
#import <LegacyComponents/TGPaintUtils.h>

#import "PGPhotoEditor.h"
#import "PGPhotoTool.h"
#import "PGBlurTool.h"
#import "PGCurvesTool.h"
#import "PGTintTool.h"
#import <LegacyComponents/TGPaintingData.h>

#import "TGPhotoEditorController.h"
#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoEditorHUDView.h"
#import "TGPhotoEditorSparseView.h"
#import "TGPhotoEntitiesContainerView.h"

#import "TGPhotoPaintController.h"

const CGFloat TGPhotoEditorToolsPanelSize = 180.0f;
const CGFloat TGPhotoEditorToolsLandscapePanelSize = TGPhotoEditorToolsPanelSize + 40.0f;

@interface TGPhotoToolsController () <TGPhotoEditorCollectionViewToolsDataSource>
{
    NSValue *_contentOffsetAfterRotation;
    bool _appeared;
    bool _scheduledTransitionIn;
    CGFloat _cellWidth;
    int _entitiesReady;
    
    NSArray *_allTools;
    NSArray *_simpleTools;
    
    TGPhotoEditorSparseView *_wrapperView;
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    UIView *_portraitWrapperBackgroundView;
    UIView *_landscapeWrapperBackgroundView;
    TGPhotoEditorCollectionView *_portraitCollectionView;
    TGPhotoEditorCollectionView *_landscapeCollectionView;
    TGPhotoEditorHUDView *_hudView;
    TGPhotoEntitiesContainerView *_entitiesView;
    
    void (^_changeBlock)(PGPhotoTool *, id, bool);
    void (^_interactionBegan)(void);
    void (^_interactionEnded)(void);
    
    bool _preview;
    TGPhotoEditorTab _currentTab;
    
    UIView *_entitiesWrapperView;
    
    UIView <TGPhotoEditorToolView> *_toolAreaView;
    UIView <TGPhotoEditorToolView> *_portraitToolControlView;
    UIView <TGPhotoEditorToolView> *_landscapeToolControlView;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoToolsController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView entitiesView:(TGPhotoEntitiesContainerView *)entitiesView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        _entitiesView = entitiesView;

         __weak TGPhotoToolsController *weakSelf = self;
        _changeBlock = ^(PGPhotoTool *tool, __unused id newValue, bool animated)
        {
            __strong TGPhotoToolsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            PGPhotoEditor *photoEditor = strongSelf.photoEditor;
            [photoEditor processAnimated:false completion:nil];
            
            if (animated)
                [strongSelf showHUDForTool:nil];
            else if (tool.isSimple)
                [strongSelf showHUDForTool:tool];
        };
        
        _currentTab = TGPhotoEditorToolsTab;
    }
    return self;
}

- (void)dealloc
{
    _portraitCollectionView.toolsDataSource = nil;
    _landscapeCollectionView.toolsDataSource = nil;
}

- (void)layoutEntitiesView {
    if (_entitiesReady < 2 || _dismissing)
        return;
    
    _entitiesWrapperView.transform = CGAffineTransformIdentity;
    _entitiesWrapperView.frame = CGRectMake(0.0, 0.0, _entitiesView.frame.size.width, _entitiesView.frame.size.height);
    [_entitiesWrapperView addSubview:_entitiesView];
    
    CGFloat paintingScale = _entitiesView.frame.size.width / _photoEditor.originalSize.width;
    _entitiesView.frame = CGRectMake(-_photoEditor.cropRect.origin.x * paintingScale, -_photoEditor.cropRect.origin.y * paintingScale, _entitiesView.frame.size.width, _entitiesView.frame.size.height);
    
    CGFloat cropScale = 1.0;
    if (_photoEditor.originalSize.width > _photoEditor.originalSize.height) {
        cropScale = _photoEditor.originalSize.height / _photoEditor.cropRect.size.height;
    } else {
        cropScale = _photoEditor.originalSize.width / _photoEditor.cropRect.size.width;
    }
    
    CGFloat scale = _previewView.frame.size.width / _entitiesView.frame.size.width;
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(_photoEditor.cropOrientation));
    _entitiesWrapperView.transform = CGAffineTransformScale(rotationTransform, scale * cropScale, scale * cropScale);
    _entitiesWrapperView.frame = [_previewView convertRect:_previewView.bounds toView:_entitiesWrapperView.superview];
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    TGPhotoEditorController *editorController = (TGPhotoEditorController *)self.parentViewController;
    NSArray *faces;
    if ([editorController isKindOfClass:[TGPhotoEditorController class]]) {
        faces = editorController.faces;
    }
    
    NSMutableArray *tools = [[NSMutableArray alloc] init];
    NSMutableArray *simpleTools = [[NSMutableArray alloc] init];
    for (PGPhotoTool *tool in self.photoEditor.tools)
    {
        if (tool.requiresFaces && faces.count < 1) {
            continue;
        }
        if (!tool.isHidden)
        {
            [tools addObject:tool];
            if (tool.isSimple)
                [simpleTools addObject:tool];
        }
    }
    _allTools = tools;
    _simpleTools = simpleTools;
    
    __weak TGPhotoToolsController *weakSelf = self;
    _interactionBegan = ^
    {
        __strong TGPhotoToolsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setPanelHidden:true animated:false];
    };
    _interactionEnded = ^
    {
        __strong TGPhotoToolsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
        
        [strongSelf setPanelHidden:false animated:true];
        [strongSelf->_hudView setText:nil];
    };
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = true;
    previewView.interactionEnded = _interactionEnded;
    
    bool forVideo = _photoEditor.forVideo;
    previewView.touchedUp = ^
    {
        __strong TGPhotoToolsController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf->_hudView setText:nil];
            
            strongSelf->_photoEditor.disableAll = false;
            if (!forVideo) {
                [strongSelf->_photoEditor processAnimated:false completion:nil];
            }
        }
    };
    previewView.touchedDown = ^
    {
        __strong TGPhotoToolsController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf->_hudView setText:TGLocalized(@"PhotoEditor.Original")];
            
            strongSelf->_photoEditor.disableAll = true;
            if (!forVideo) {
                [strongSelf->_photoEditor processAnimated:false completion:nil];
            }
        }
    };
    previewView.tapped = ^{
        __strong TGPhotoToolsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf setPreview:!strongSelf->_preview animated:true];
    };
    previewView.customTouchDownHandling = true;
    [self.view addSubview:_previewView];
    
    _wrapperView = [[TGPhotoEditorSparseView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    _entitiesWrapperView = [[UIView alloc] init];
    _entitiesWrapperView.userInteractionEnabled = false;
    [_wrapperView addSubview:_entitiesWrapperView];
    
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
    
    CGFloat maxTitleWidth = 0.0f;
    for (PGPhotoTool *tool in _simpleTools)
    {
        NSString *title = tool.title;
        CGFloat width = 0.0f;
        width = CGCeil([title sizeWithAttributes:@{ NSFontAttributeName:[TGPhotoEditorInterfaceAssets editorItemTitleFont] }].width);
        
        if (width > maxTitleWidth)
            maxTitleWidth = width;
    }
    maxTitleWidth = MAX(64, maxTitleWidth);
    
    CGSize referenceSize = [self referenceViewSize];
    CGFloat collectionViewSize = MIN(referenceSize.width, referenceSize.height);
    _portraitCollectionView = [[TGPhotoEditorCollectionView alloc] initWithLandscape:false nameWidth:maxTitleWidth];
    _portraitCollectionView.backgroundColor = [UIColor clearColor];
    _portraitCollectionView.contentInset = UIEdgeInsetsMake(8, 10, 16, 10);
    _portraitCollectionView.frame = CGRectMake(0, 0, collectionViewSize, TGPhotoEditorToolsPanelSize);
    _portraitCollectionView.toolsDataSource = self;
    _portraitCollectionView.interactionBegan = _interactionBegan;
    _portraitCollectionView.interactionEnded = _interactionEnded;
    [_portraitToolsWrapperView addSubview:_portraitCollectionView];
    
    if (!TGIsPad())
    {
        _landscapeCollectionView = [[TGPhotoEditorCollectionView alloc] initWithLandscape:true nameWidth:maxTitleWidth];
        _landscapeCollectionView.backgroundColor = [UIColor clearColor];
        _landscapeCollectionView.contentInset = UIEdgeInsetsMake(10, 10, 10, 10);
        _landscapeCollectionView.frame = CGRectMake(0, 0, TGPhotoEditorToolsPanelSize, collectionViewSize);
        _landscapeCollectionView.minimumLineSpacing = 12;
        _landscapeCollectionView.toolsDataSource = self;
        _landscapeCollectionView.interactionBegan = _interactionBegan;
        _landscapeCollectionView.interactionEnded = _interactionEnded;
        [_landscapeToolsWrapperView addSubview:_landscapeCollectionView];
    }
    
    _hudView = [[TGPhotoEditorHUDView alloc] init];
    [self.view addSubview:_hudView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self transitionIn];
}

- (BOOL)shouldAutorotate
{
    bool toolTracking = _toolAreaView.isTracking || _portraitToolControlView.isTracking || _landscapeToolControlView.isTracking;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && !_portraitCollectionView.hasAnyTracking && !_landscapeCollectionView.hasAnyTracking && !toolTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared;
}

- (void)setPanelHidden:(bool)hidden animated:(bool)animated
{
    void (^block)(void) = ^
    {
        CGFloat alpha = hidden ? 0.0f : 1.0f;
        
        _portraitWrapperBackgroundView.alpha = alpha;
        _landscapeWrapperBackgroundView.alpha = alpha;
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.15 animations:block];
    }
    else
    {
        block();
    }
}

- (void)showHUDForTool:(PGPhotoTool *)tool
{
    if (tool == nil)
    {
        [_hudView setText:nil];
        return;
    }
    
    [_hudView setTitle:tool.title value:[tool stringValue:true]];
}

#pragma mark - Transition

- (void)transitionIn
{
    if (_portraitToolsWrapperView.frame.size.height < FLT_EPSILON) {
        _scheduledTransitionIn = true;
        return;
    }
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
    }];
    
    switch (self.effectiveOrientation)
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

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion
{
    if (switching) {
        _dismissing = true;
    }
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.touchedUp = nil;
    previewView.touchedDown = nil;
    previewView.tapped = nil;
    previewView.interactionEnded = nil;
    
    [_toolAreaView.superview bringSubviewToFront:_toolAreaView];

    switch (self.effectiveOrientation)
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
        _toolAreaView.alpha = 0.0f;
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
        
    _entitiesReady++;
    [self layoutEntitiesView];
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
    return TGPaintCombineCroppedImages(self.photoEditor.currentResultImage, self.photoEditor.paintingData.image, true, self.photoEditor.originalSize, self.photoEditor.cropRect, self.photoEditor.cropOrientation, self.photoEditor.cropRotation, self.photoEditor.cropMirrored);
}

#pragma mark - 

- (void)setActiveTool:(PGPhotoTool *)tool
{
    UIView *previousAreaView = _toolAreaView;
    UIView *previousPortaitControlView = _portraitToolControlView;
    UIView *previousLandscapeControlView = _landscapeToolControlView;
    
    _toolAreaView = nil;
    _portraitToolControlView = nil;
    _landscapeToolControlView = nil;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        previousAreaView.alpha = 0.0f;
        previousPortaitControlView.alpha = 0.0f;
        previousLandscapeControlView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [previousAreaView removeFromSuperview];
        [previousPortaitControlView removeFromSuperview];
        [previousLandscapeControlView removeFromSuperview];
    }];
    
    if (tool == nil)
    {
        _portraitCollectionView.userInteractionEnabled = true;
        _landscapeCollectionView.userInteractionEnabled = true;
        
        [UIView animateWithDuration:0.25 animations:^
        {
            _portraitCollectionView.alpha = 1.0f;
            _landscapeCollectionView.alpha = 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _portraitCollectionView.userInteractionEnabled = true;
                _landscapeCollectionView.userInteractionEnabled = true;
            }
        }];
    }
    else
    {
        __weak TGPhotoToolsController *weakSelf = self;
        _toolAreaView = [tool itemAreaViewWithChangeBlock:^(id __unused newValue)
        {
            __strong TGPhotoToolsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_portraitToolControlView setValue:newValue];
            [strongSelf->_landscapeToolControlView setValue:newValue];
            
            PGPhotoEditor *photoEditor = strongSelf.photoEditor;
            [photoEditor processAnimated:false completion:nil];
        } explicit:true];
        _toolAreaView.interactionEnded = _interactionEnded;
        
        if (_toolAreaView != nil)
            [self.view insertSubview:_toolAreaView belowSubview:_wrapperView];
        
        _portraitToolControlView = [tool itemControlViewWithChangeBlock:^(id newValue, bool animated)
        {
            __strong TGPhotoToolsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_toolAreaView setValue:newValue];
            [strongSelf->_landscapeToolControlView setValue:newValue];
            
            PGPhotoEditor *photoEditor = strongSelf.photoEditor;
            [photoEditor processAnimated:animated completion:nil];
        } explicit:true nameWidth:0.0f];
        _portraitToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
        _portraitToolControlView.clipsToBounds = true;
        _portraitToolControlView.interactionEnded = _interactionEnded;
        _portraitToolControlView.layer.rasterizationScale = TGScreenScaling();
        _portraitToolControlView.isLandscape = false;
        
        if ([_portraitToolControlView respondsToSelector:@selector(setHistogramSignal:)])
            [_portraitToolControlView setHistogramSignal:_photoEditor.histogramSignal];
        
        [_portraitToolsWrapperView addSubview:_portraitToolControlView];
        
        _landscapeToolControlView = [tool itemControlViewWithChangeBlock:^(id newValue, bool animated)
        {
            __strong TGPhotoToolsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_toolAreaView setValue:newValue];
            [strongSelf->_portraitToolControlView setValue:newValue];
            
            PGPhotoEditor *photoEditor = strongSelf.photoEditor;
            [photoEditor processAnimated:animated completion:nil];
        } explicit:true nameWidth:0.0f];
        _landscapeToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
        _landscapeToolControlView.clipsToBounds = true;
        _landscapeToolControlView.interactionEnded = _interactionEnded;
        _landscapeToolControlView.layer.rasterizationScale = TGScreenScaling();
        _landscapeToolControlView.isLandscape = true;
        _landscapeToolControlView.toolbarLandscapeSize = self.toolbarLandscapeSize;
        
        if (!TGIsPad())
        {
            if ([_landscapeToolControlView respondsToSelector:@selector(setHistogramSignal:)])
                [_landscapeToolControlView setHistogramSignal:_photoEditor.histogramSignal];
            
            [_landscapeToolsWrapperView addSubview:_landscapeToolControlView];
        }
        
        _toolAreaView.alpha = 0.0f;
        _portraitToolControlView.alpha = 0.0f;
        _landscapeToolControlView.alpha = 0.0f;
        
        [UIView animateWithDuration:0.25 animations:^
        {
            _toolAreaView.alpha = 1.0f;
            _portraitToolControlView.alpha = 1.0f;
            _landscapeToolControlView.alpha = 1.0f;
            
            _portraitCollectionView.alpha = 0.0f;
            _landscapeCollectionView.alpha = 0.0f;
        } completion:nil];
        
        [UIView animateWithDuration:0.2 animations:^
        {
            _portraitCollectionView.alpha = 0.0f;
            _landscapeCollectionView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _portraitCollectionView.userInteractionEnabled = false;
                _landscapeCollectionView.userInteractionEnabled = false;
            }
        }];
    }
    
    [UIView animateWithDuration:0.25 delay:0.0 options:7 << 16 animations:^
    {
        [self updateToolViews];
    } completion:nil];
}

#pragma mark - Data Source and Delegate

- (NSInteger)numberOfToolsInCollectionView:(TGPhotoEditorCollectionView *)__unused collectionView
{
    return _simpleTools.count;
}

- (PGPhotoTool *)collectionView:(TGPhotoEditorCollectionView *)__unused collectionView toolAtIndex:(NSInteger)index
{
    return _simpleTools[index];
}

- (void (^)(PGPhotoTool *, id, bool))changeBlockForCollectionView:(TGPhotoEditorCollectionView *)__unused collectionView
{
    return _changeBlock;
}

- (void (^)(void))interactionEndedForCollectionView:(TGPhotoEditorCollectionView *)__unused collectionView
{
    return _interactionEnded;
}

#pragma mark - Layout

- (void)_prepareCollectionViewsForTransitionFromOrientation:(UIInterfaceOrientation)fromOrientation toOrientation:(UIInterfaceOrientation)toOrientation
{
    if ((UIInterfaceOrientationIsLandscape(fromOrientation) && UIInterfaceOrientationIsLandscape(toOrientation)) || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return;
    
    UICollectionView *currentCollectionView = nil;
    UICollectionView *targetCollectionView = nil;
    
    if (UIInterfaceOrientationIsPortrait(fromOrientation))
    {
        currentCollectionView = _portraitCollectionView;
        targetCollectionView = _landscapeCollectionView;
    }
    else
    {
        currentCollectionView = _landscapeCollectionView;
        targetCollectionView = _portraitCollectionView;
    }
    
    bool scrollToEnd = false;
    if (currentCollectionView.contentOffset.y > currentCollectionView.contentSize.height - currentCollectionView.frame.size.height - 2)
        scrollToEnd = true;
    
    CGPoint targetOffset = CGPointZero;
    CGFloat collectionViewSize = MIN(TGScreenSize().width, TGScreenSize().height);
    
    if (!scrollToEnd)
    {
        NSIndexPath *firstVisibleIndexPath = nil;
        
        NSArray *visibleLayoutAttributes = [currentCollectionView.collectionViewLayout layoutAttributesForElementsInRect:currentCollectionView.bounds];
        
        CGFloat firstItemPosition = FLT_MAX;
        for (UICollectionViewLayoutAttributes *layoutAttributes in visibleLayoutAttributes)
        {
            CGFloat position = CGRectOffset(layoutAttributes.frame, 0, -currentCollectionView.bounds.origin.y).origin.y;
            if (position > 0 && position < firstItemPosition)
            {
                firstItemPosition = position;
                firstVisibleIndexPath = layoutAttributes.indexPath;
            }
        }
        
        if (firstVisibleIndexPath == nil)
            return;
    
        UICollectionViewLayoutAttributes *attributes = [targetCollectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForRow:firstVisibleIndexPath.row inSection:0]];
        
        targetOffset = CGPointMake(-targetCollectionView.contentInset.left, MIN(targetCollectionView.contentSize.height + targetCollectionView.contentInset.bottom - collectionViewSize, -targetCollectionView.contentInset.top + attributes.frame.origin.y));
    
    }
    else
    {
        targetOffset = CGPointMake(-targetCollectionView.contentInset.left, targetCollectionView.contentSize.height + targetCollectionView.contentInset.bottom - collectionViewSize);
    }
    
    _contentOffsetAfterRotation = [NSValue valueWithCGPoint:targetOffset];
}

- (void)_applyPreparedContentOffset
{
    if (_contentOffsetAfterRotation != nil)
    {
        [UIView performWithoutAnimation:^
        {
            if (UIInterfaceOrientationIsPortrait([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]))
            {
                if (_portraitCollectionView.contentSize.width > _portraitCollectionView.frame.size.width)
                    [_portraitCollectionView setContentOffset:_contentOffsetAfterRotation.CGPointValue];
            }
            else
            {
                if (_landscapeCollectionView.contentSize.height > _landscapeCollectionView.frame.size.height)
                    [_landscapeCollectionView setContentOffset:_contentOffsetAfterRotation.CGPointValue];
            }
        }];
        _contentOffsetAfterRotation = nil;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    if (![self inFormSheet])
        [self _prepareCollectionViewsForTransitionFromOrientation:self.interfaceOrientation toOrientation:toInterfaceOrientation];
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
    
    if (_scheduledTransitionIn) {
        _scheduledTransitionIn = false;
        [self transitionIn];
    }
    
    if (![self inFormSheet])
        [self _applyPreparedContentOffset];
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    CGRect containerFrame = [TGPhotoToolsController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return sourceFrame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    CGRect containerFrame = [TGPhotoToolsController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    return [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
}

- (void)updateToolViews
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIInterfaceOrientation orientation = self.interfaceOrientation;
#pragma clang diagnostic pop
    if ([self inFormSheet] || TGIsPad())
    {
        _landscapeToolsWrapperView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoEditorToolsPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    CGFloat panelSize = UIInterfaceOrientationIsPortrait(orientation) ? TGPhotoEditorToolsPanelSize : TGPhotoEditorToolsLandscapePanelSize;
    if (_portraitToolControlView != nil)
        panelSize = TGPhotoEditorPanelSize;
    
    CGFloat panelToolbarPortraitSize = panelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = panelSize + TGPhotoEditorToolbarSize;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:self.hasOnScreenNavigation];
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
                if (!_preview)
                {
                    _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                }
                _landscapeCollectionView.frame = CGRectMake(panelToolbarLandscapeSize - panelSize, 0, panelSize, _landscapeCollectionView.frame.size.height);
                
                _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - panelSize, 0, panelSize, _landscapeCollectionView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left - (_preview ? panelToolbarLandscapeSize : 0.0f), screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, _landscapeCollectionView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - TGPhotoEditorPanelSize, 0, TGPhotoEditorPanelSize, _landscapeToolsWrapperView.frame.size.height);
            
            _hudView.frame = CGRectMake(_preview ? 0.0f : panelToolbarLandscapeSize, 0.0f, referenceSize.width - (_preview ? 0.0f : panelToolbarLandscapeSize), referenceSize.height);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                if (!_preview)
                {
                    _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                }
                _landscapeCollectionView.frame = CGRectMake(0, 0, panelSize, _landscapeCollectionView.frame.size.height);
                
                _landscapeToolControlView.frame = CGRectMake(0, 0, panelSize, _landscapeCollectionView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize + (_preview ? panelToolbarLandscapeSize : 0.0f), screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, _landscapeCollectionView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.top, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _landscapeToolControlView.frame = CGRectMake(0, 0, panelSize, _landscapeCollectionView.frame.size.height);
            
            _hudView.frame = CGRectMake(0.0f, 0.0f, referenceSize.width - (_preview ? 0.0f : panelToolbarLandscapeSize), referenceSize.height);
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
                x = screenSide - TGPhotoEditorToolsPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            _landscapeCollectionView.frame = CGRectMake(_landscapeCollectionView.frame.origin.x, _landscapeCollectionView.frame.origin.y, panelSize, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize + (_preview ? TGPhotoEditorToolbarSize : 0.0f), referenceSize.width, panelToolbarPortraitSize);
            _portraitCollectionView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, panelSize);
            
            _portraitToolControlView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, TGPhotoEditorPanelSize);
            
            _hudView.frame = CGRectMake(0.0f, safeAreaInset.top, referenceSize.width, referenceSize.height - panelToolbarPortraitSize);
        }
            break;
    }
}

- (void)setPreview:(bool)preview animated:(bool)animated
{
    if (_preview == preview)
        return;
    
    _preview = preview;
    [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
    {
        [self updateToolViews];
        [self updatePreviewView];
    } completion:nil];
    
    [(TGPhotoEditorController *)self.parentViewController setToolbarHidden:preview animated:animated];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _wrapperView.alpha = preview ? 0.0f : 1.0f;
    }];
}

- (void)updatePreviewView
{
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view)
        return;
    
    CGSize referenceSize = [self referenceViewSize];
    CGRect containerFrame = _preview ? CGRectMake(0.0f, 0.0f, referenceSize.width, referenceSize.height) : [TGPhotoToolsController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    
    if ([self presentedForAvatarCreation]) {
        CGAffineTransform transform = CGAffineTransformMakeRotation(TGRotationForOrientation(photoEditor.cropOrientation));
        if (photoEditor.cropMirrored)
            transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
        previewView.transform = transform;
    }
    
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    [UIView performWithoutAnimation:^
    {
        _toolAreaView.frame = CGRectMake(CGRectGetMidX(previewView.frame) - containerFrame.size.width / 2, CGRectGetMidY(previewView.frame) - containerFrame.size.height / 2, containerFrame.size.width, containerFrame.size.height);
        _toolAreaView.actualAreaSize  = previewView.frame.size;
    }];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet] || TGIsPad())
        orientation = UIInterfaceOrientationPortrait;
    
    if (!_dismissing)
        [self updateToolViews];
    
    [_portraitCollectionView.collectionViewLayout invalidateLayout];
    [_landscapeCollectionView.collectionViewLayout invalidateLayout];
    
    [self updatePreviewView];
    [self layoutEntitiesView];
}

- (TGPhotoEditorTab)availableTabs
{
    if (self.photoEditor.forVideo) {
        return TGPhotoEditorToolsTab | TGPhotoEditorTintTab | TGPhotoEditorCurvesTab;
    } else {
        return TGPhotoEditorToolsTab | TGPhotoEditorTintTab | TGPhotoEditorBlurTab | TGPhotoEditorCurvesTab;
    }
}

- (PGPhotoTool *)toolForTab:(TGPhotoEditorTab)tab
{
    if (tab == TGPhotoEditorToolsTab)
        return nil;
    
    for (PGPhotoTool *tool in _allTools)
    {
        if (tab == TGPhotoEditorBlurTab && [tool isKindOfClass:[PGBlurTool class]])
            return tool;
        if (tab == TGPhotoEditorCurvesTab && [tool isKindOfClass:[PGCurvesTool class]])
            return tool;
        if (tab == TGPhotoEditorTintTab && [tool isKindOfClass:[PGTintTool class]])
            return tool;
    }
    
    return nil;
}

- (void)handleTabAction:(TGPhotoEditorTab)tab
{
    if (tab == _currentTab)
        return;
    
    _currentTab = tab;
    PGPhotoTool *tool = [self toolForTab:tab];
    [self setActiveTool:tool];
    [self _updateTabs];
}

- (TGPhotoEditorTab)activeTab
{
    return _currentTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    bool hasSimpleValue = false;
    bool hasBlur = false;
    bool hasCurves = false;
    bool hasTint = false;
    
    for (PGPhotoTool *tool in _allTools)
    {
        if (tool.isSimple)
        {
            if (tool.stringValue != nil)
                hasSimpleValue = true;
        }
        else if ([tool isKindOfClass:[PGBlurTool class]] && tool.stringValue != nil)
        {
            hasBlur = true;
        }
        else if ([tool isKindOfClass:[PGCurvesTool class]] && tool.stringValue != nil)
        {
            hasCurves = true;
        }
        else if ([tool isKindOfClass:[PGTintTool class]] && tool.stringValue != nil)
        {
            hasTint = true;
        }
    }
    
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

@end
