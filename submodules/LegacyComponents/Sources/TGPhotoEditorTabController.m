#import "TGPhotoEditorTabController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGPhotoEditorController.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoToolbarView.h"

#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/JNWSpringAnimation.h>

const CGFloat TGPhotoEditorPanelSize = 115.0f;
const CGFloat TGPhotoEditorToolbarSize = 49.0f;

@interface TGPhotoEditorTabController ()
{
    bool _noTransitionView;
    CGRect _transitionInReferenceFrame;
    UIView *_transitionInReferenceView;
    UIView *_transitionInParentView;
    CGRect _transitionTargetFrame;
}
@end

@implementation TGPhotoEditorTabController

- (void)handleTabAction:(TGPhotoEditorTab)__unused tab
{
}

- (BOOL)prefersStatusBarHidden
{
    if ([self inFormSheet])
        return false;
    
    return true;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.beginTransitionIn != nil)
    {
        bool noTransitionView = false;
        CGRect referenceFrame = CGRectZero;
        UIView *parentView = nil;
        UIView *referenceView = self.beginTransitionIn(&referenceFrame, &parentView, &noTransitionView);
        
        [self prepareTransitionInWithReferenceView:referenceView referenceFrame:referenceFrame parentView:parentView noTransitionView:noTransitionView];
        self.beginTransitionIn = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_transitionInPending)
    {
        _transitionInPending = false;
        [self animateTransitionIn];
    }
}

- (bool)hasOnScreenNavigation {
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    return hasOnScreenNavigation;
}

- (UIInterfaceOrientation)effectiveOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self effectiveOrientation:self.interfaceOrientation];
#pragma clang diagnostic pop
}

- (UIInterfaceOrientation)effectiveOrientation:(UIInterfaceOrientation)orientation {
    bool isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if ([self inFormSheet] || isPad)
        orientation = UIInterfaceOrientationPortrait;
    return orientation;
}

- (void)transitionInWithDuration:(CGFloat)__unused duration
{
    
}

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)parentView noTransitionView:(bool)noTransitionView
{
    _dismissing = false;
    
    CGRect targetFrame = [self _targetFrameForTransitionInFromFrame:referenceFrame];
    
    if (_CGRectEqualToRectWithEpsilon(targetFrame, referenceFrame, FLT_EPSILON))
    {
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
        
        [self _finishedTransitionInWithView:nil];
        
        return;
    }
    
    _transitionInPending = true;
    
    _noTransitionView = noTransitionView;
    if (noTransitionView)
        return;
    
    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    UIView *transitionViewSuperview = nil;
    UIImage *transitionImage = nil;
    if ([referenceView isKindOfClass:[UIImageView class]] && referenceView.subviews.count == 0)
        transitionImage = ((UIImageView *)referenceView).image;
    
    if (transitionImage != nil)
    {
        _transitionView = [[UIImageView alloc] initWithImage:transitionImage];
        _transitionView.clipsToBounds = true;
        _transitionView.contentMode = UIViewContentModeScaleAspectFill;
        transitionViewSuperview = parentView;
    }
    else
    {
        if (![referenceView isKindOfClass:[TGPhotoEditorPreviewView class]])
            _transitionView = [referenceView snapshotViewAfterScreenUpdates:false];
        if (_transitionView == nil) {
            _transitionView = referenceView;
        }
        transitionViewSuperview = parentView;
    }
    
    
    _transitionView.hidden = false;
    _transitionView.frame = referenceFrame;
    _transitionTargetFrame = [self _targetFrameForTransitionInFromFrame:referenceFrame];
    [transitionViewSuperview addSubview:_transitionView];
}

- (void)animateTransitionIn
{    
    if (_noTransitionView)
        return;
    
    _transitionInProgress = true;
    
    CGAffineTransform initialTransform = _transitionView.transform;
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews animations:^
    {
        if (_animateScale) {
            CGFloat scale = _transitionTargetFrame.size.width / _transitionView.frame.size.width;
            _transitionView.center = CGPointMake(CGRectGetMidX(_transitionTargetFrame), CGRectGetMidY(_transitionTargetFrame));
            _transitionView.transform = CGAffineTransformScale(initialTransform, scale, scale);
        } else {
            _transitionView.frame = _transitionTargetFrame;
        }
    } completion:^(BOOL finished) {
        _transitionInProgress = false;
             
         UIView *transitionView = _transitionView;
         _transitionView = nil;
         
        if (_animateScale) {
            _transitionView.transform = initialTransform;
            _transitionView.frame = _transitionTargetFrame;
        }
        
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
         
        [self _finishedTransitionInWithView:transitionView];
    }];
}

- (void)prepareForCustomTransitionOut
{
    
}

- (void)finishCustomTransitionOut
{
    
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))__unused completion
{

}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    [self transitionOutSwitching:false completion:nil];
    
    CGRect referenceFrame = [self transitionOutReferenceFrame];
    UIView *referenceView = nil;
    UIView *parentView = nil;
    
    CGSize referenceSize = [self referenceViewSize];
    
    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent))
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
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
#pragma clang diagnostic pop
    }
    
    if (self.beginTransitionOut != nil)
        referenceView = self.beginTransitionOut(&referenceFrame, &parentView);
    
    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent))
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
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
#pragma clang diagnostic pop
    }
    
    if (saving)
    {
        [self _animatePreviewViewTransitionOutToFrame:CGRectNull saving:saving parentView:parentView completion:^
        {
            if (completion != nil)
                completion();
        }];
    }
    else
    {
        UIView *toTransitionView = nil;
        
        UIImage *transitionImage = nil;
        if ([referenceView isKindOfClass:[UIImageView class]] && referenceView.subviews.count == 0)
            transitionImage = ((UIImageView *)referenceView).image;
        
        if (transitionImage != nil)
        {
            toTransitionView = [[UIImageView alloc] initWithImage:transitionImage];
            toTransitionView.clipsToBounds = true;
            toTransitionView.contentMode = UIViewContentModeScaleAspectFill;
        }
        else
        {
            bool wasHidden = referenceView.isHidden;
            CGRect previousFrame = referenceView.frame;
            referenceView.frame = CGRectOffset(referenceView.frame, -1000.0, 0.0);
            referenceView.hidden = false;
            toTransitionView = [referenceView snapshotViewAfterScreenUpdates:true];
            referenceView.hidden = wasHidden;
            referenceView.frame = previousFrame;
        }
        
        [parentView addSubview:toTransitionView];
        
        if (_noTransitionToSnapshot)
            toTransitionView.alpha = 0.0f;
        
        UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            orientation = UIInterfaceOrientationPortrait;

        CGRect sourceFrame = [self transitionOutSourceFrameForReferenceFrame:referenceView.frame orientation:orientation];
        CGRect targetFrame = referenceFrame;
        toTransitionView.frame = sourceFrame;
        
        NSMutableSet *animations = [NSMutableSet set];
        void (^onAnimationCompletion)(id) = ^(id object)
        {
            [animations removeObject:object];
            
            if (animations.count == 0)
            {
                [toTransitionView removeFromSuperview];
                
                if (completion != nil)
                    completion();
            }
        };
        
        [animations addObject:@1];
        [self _animatePreviewViewTransitionOutToFrame:targetFrame saving:saving parentView:nil completion:^
        {
            onAnimationCompletion(@1);
        }];
        
        [animations addObject:@2];
        POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        if (self.transitionSpeed > FLT_EPSILON)
            animation.springSpeed = self.transitionSpeed;
        animation.fromValue = [NSValue valueWithCGRect:toTransitionView.frame];
        animation.toValue = [NSValue valueWithCGRect:targetFrame];
        animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
        {
            onAnimationCompletion(@2);
        };
        [toTransitionView pop_addAnimation:animation forKey:@"frame"];
    }
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                    containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                    fittedSize.width,
                                    fittedSize.height);
    
    return sourceFrame;
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)__unused toFrame saving:(bool)__unused saving parentView:(UIView *)__unused parentView completion:(void (^)(void))__unused completion
{
    
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.effectiveOrientation;
    
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                fittedSize.width,
                                fittedSize.height);
    
    return toFrame;
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {
        [self.view insertSubview:transitionView atIndex:0];
    } else {
        [transitionView removeFromSuperview];
    }
}

- (bool)inFormSheet
{
    return [(TGViewController *)[self parentViewController] inFormSheet];
}

- (CGSize)referenceViewSize
{
    if (self.parentViewController != nil)
    {
        TGPhotoEditorController *controller = (TGPhotoEditorController *)self.parentViewController;
        return [controller referenceViewSize];
    }

    return CGSizeZero;
}

- (void)animateTransitionOutToRect:(CGRect)__unused fromRect saving:(bool)__unused saving duration:(CGFloat)__unused duration
{
    
}

- (void)prepareTransitionOutSaving:(bool)__unused saving
{
    
}

- (CGRect)transitionOutReferenceFrame
{
    return CGRectZero;
}

- (UIView *)transitionOutReferenceView
{
    return nil;
}

- (UIView *)snapshotView
{
    return nil;
}

- (bool)dismissing
{
    return _dismissing;
}

- (bool)isDismissAllowed
{
    return true;
}

- (id)currentResultRepresentation
{
    return nil;
}

- (void)_updateTabs
{
    if (self.tabsChanged != nil)
        self.tabsChanged();
}

- (TGPhotoEditorTab)activeTab
{
    return TGPhotoEditorNoneTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    return TGPhotoEditorNoneTab;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGFloat panelToolbarPortraitSize = TGPhotoEditorToolbarSize + panelSize;
    CGFloat panelToolbarLandscapeSize = toolbarLandscapeSize + panelSize;
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

+ (TGPhotoEditorTab)highlightedButtonsForEditorValues:(id<TGMediaEditAdjustments>)editorValues forAvatar:(bool)forAvatar
{
    TGPhotoEditorTab highlightedButtons = TGPhotoEditorNoneTab;
    
    if ([editorValues cropAppliedForAvatar:forAvatar])
        highlightedButtons |= TGPhotoEditorCropTab;
    
    if ([editorValues hasPainting])
        highlightedButtons |= TGPhotoEditorPaintTab;
    
    if ([editorValues toolsApplied])
        highlightedButtons |= TGPhotoEditorToolsTab;
    
    return highlightedButtons;
}

- (bool)presentedForAvatarCreation
{
    return _intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent);
}

@end
