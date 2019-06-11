#import "TGPhotoEditorItemController.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "PGPhotoEditor.h"
#import "PGPhotoEditorItem.h"
#import "PGPhotoFilter.h"
#import "PGPhotoTool.h"

#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoEditorToolButtonsView.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"

@interface TGPhotoEditorItemController () <TGViewControllerNavigationBarAppearance>
{
    id<PGPhotoEditorItem> _editorItem;
    
    UIView *_wrapperView;
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    
    UIView <TGPhotoEditorToolView> *_toolAreaView;
    UIView <TGPhotoEditorToolView> *_portraitToolControlView;
    UIView <TGPhotoEditorToolView> *_landscapeToolControlView;
    
    TGPhotoEditorToolButtonsView *_portraitButtonsView;
    TGPhotoEditorToolButtonsView *_landscapeButtonsView;
    
    UIView *_initialPreviewSuperview;
    bool _dismissing;
    bool _animating;
    
    bool _enhanceInitialAppearance;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoEditorItemController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context editorItem:(id<PGPhotoEditorItem>)editorItem photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _editorItem = editorItem;
        _editorItem.beingEdited = true;
        _editorItem.tempValue = [_editorItem.value copy];
        
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _initialPreviewSuperview = previewView.superview;
    }
    return self;
}

- (void)dealloc
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.touchedDown = nil;
    previewView.touchedUp = nil;
}

- (void)loadView
{
    [super loadView];
    
    __weak TGPhotoEditorItemController *weakSelf = self;
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
    };
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    _wrapperView.alpha = 0.0f;
    _wrapperView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_wrapperView];
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    if (previewView != nil)
        [self attachPreviewView:previewView];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    
    _toolAreaView = [_editorItem itemAreaViewWithChangeBlock:^(id __unused newValue)
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_portraitToolControlView setValue:newValue];
        [strongSelf->_landscapeToolControlView setValue:newValue];
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        [photoEditor processAnimated:false completion:nil];
    }];
    _toolAreaView.interactionEnded = interactionEnded;
    
    if (_toolAreaView != nil)
        [self.view addSubview:_toolAreaView];
    
    _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_portraitToolsWrapperView];
    
    _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_landscapeToolsWrapperView];
    
    _portraitToolControlView = [_editorItem itemControlViewWithChangeBlock:^(id newValue, bool animated)
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_toolAreaView setValue:newValue];
        [strongSelf->_landscapeToolControlView setValue:newValue];
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        [photoEditor processAnimated:animated completion:nil];
    }];
    _portraitToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
    _portraitToolControlView.clipsToBounds = true;
    _portraitToolControlView.interactionEnded = interactionEnded;
    _portraitToolControlView.layer.rasterizationScale = TGScreenScaling();
    _portraitToolControlView.isLandscape = false;
    
    if ([_portraitToolControlView respondsToSelector:@selector(setHistogramSignal:)])
        [_portraitToolControlView setHistogramSignal:photoEditor.histogramSignal];
    
    [_portraitToolsWrapperView addSubview:_portraitToolControlView];
    
    _landscapeToolControlView = [_editorItem itemControlViewWithChangeBlock:^(id newValue, bool animated)
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_toolAreaView setValue:newValue];
        [strongSelf->_portraitToolControlView setValue:newValue];
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        [photoEditor processAnimated:animated completion:nil];
    }];
    _landscapeToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
    _landscapeToolControlView.clipsToBounds = true;
    _landscapeToolControlView.interactionEnded = interactionEnded;
    _landscapeToolControlView.layer.rasterizationScale = TGScreenScaling();
    _landscapeToolControlView.isLandscape = true;
    _landscapeToolControlView.toolbarLandscapeSize = self.toolbarLandscapeSize;
    
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)
    {
        if ([_landscapeToolControlView respondsToSelector:@selector(setHistogramSignal:)])
            [_landscapeToolControlView setHistogramSignal:photoEditor.histogramSignal];
        
        [_landscapeToolsWrapperView addSubview:_landscapeToolControlView];
    }
    
    void(^cancelPressed)(void) = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_toolAreaView.isTracking || strongSelf->_portraitToolControlView.isTracking || strongSelf->_landscapeToolControlView.isTracking || strongSelf->_animating)
            return;
        
        
        if (![strongSelf->_portraitToolControlView buttonPressed:true])
            return;
        
        strongSelf->_editorItem.beingEdited = false;
        strongSelf->_editorItem.tempValue = nil;
        
        [strongSelf transitionOutWithCompletion:^
        {
            [strongSelf removeFromParentViewController];
            [strongSelf.view removeFromSuperview];
        }];
        
        PGPhotoEditor *photoEditor = strongSelf.photoEditor;
        [photoEditor processAnimated:false completion:nil];
    };
    
    void(^confirmPressed)(void) = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_toolAreaView.isTracking || strongSelf->_portraitToolControlView.isTracking || strongSelf->_landscapeToolControlView.isTracking || strongSelf->_animating)
            return;
        
        if (![strongSelf->_portraitToolControlView buttonPressed:false])
            return;
        
        id value = strongSelf->_editorItem.tempValue;
        if ([value conformsToProtocol:@protocol(PGCustomToolValue)])
            value = [(id<PGCustomToolValue>)value cleanValue];
        
        strongSelf->_editorItem.value = value;
        strongSelf->_editorItem.beingEdited = false;
        strongSelf->_editorItem.tempValue = nil;
        
        if (strongSelf.editorItemUpdated != nil)
            strongSelf.editorItemUpdated();
        
        [strongSelf transitionOutWithCompletion:^
        {
            [strongSelf removeFromParentViewController];
            [strongSelf.view removeFromSuperview];
        }];
    };
    
    NSString *cancelButton = TGLocalized(@"Common.Cancel");
    if (self.initialAppearance)
        cancelButton = TGLocalized(@"PhotoEditor.Skip");
    NSString *doneButton = TGLocalized(@"PhotoEditor.Set");
    
    _portraitButtonsView = [[TGPhotoEditorToolButtonsView alloc] initWithCancelButton:cancelButton doneButton:doneButton];
    _portraitButtonsView.cancelPressed = cancelPressed;
    _portraitButtonsView.confirmPressed = confirmPressed;
    [_portraitToolsWrapperView addSubview:_portraitButtonsView];
    
    _landscapeButtonsView = [[TGPhotoEditorToolButtonsView alloc] initWithCancelButton:cancelButton doneButton:doneButton];
    _landscapeButtonsView.cancelPressed = cancelPressed;
    _landscapeButtonsView.confirmPressed = confirmPressed;
    [_landscapeToolsWrapperView addSubview:_landscapeButtonsView];
}

- (void)attachPreviewView:(TGPhotoEditorPreviewView *)previewView
{
    self.previewView = previewView;
    _initialPreviewSuperview = previewView.superview;
    [self.view insertSubview:previewView aboveSubview:_wrapperView];
    
    __weak TGPhotoEditorItemController *weakSelf = self;
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
    };
    
    previewView.touchedDown = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_editorItem.beingEdited = false;
        
        PGPhotoEditor *photoEditor = strongSelf->_photoEditor;
        [photoEditor processAnimated:false completion:nil];
    };
    
    previewView.touchedUp = ^
    {
        __strong TGPhotoEditorItemController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_editorItem.beingEdited = true;
        
        PGPhotoEditor *photoEditor = strongSelf->_photoEditor;
        [photoEditor processAnimated:false completion:nil];
    };
    previewView.interactionEnded = interactionEnded;
    
    if (!_enhanceInitialAppearance)
        return;
    
    [_editorItem setTempValue:@(50)];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    if (photoEditor.readyForProcessing && !self.skipProcessingOnCompletion)
    {
        [photoEditor processAnimated:false completion:^
        {
            TGDispatchOnMainThread(^
            {
                TGPhotoEditorPreviewView *previewView = self.previewView;
                [previewView performTransitionInWithCompletion:nil];
            });
        }];
    }
    else
    {
        if (self.finishedCombinedTransition != nil)
            self.finishedCombinedTransition();
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self transitionIn];
}

- (BOOL)shouldAutorotate
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && !(_toolAreaView != nil && _toolAreaView.isTracking) && !_portraitToolControlView.isTracking && !_landscapeToolControlView.isTracking && [super shouldAutorotate]);
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

- (void)_applyDefaultEnhanceIfNeeded
{
    if (_dismissing || fabsf([_editorItem.displayValue floatValue]) > FLT_EPSILON)
        return;
    
    _animating = true;
    
    POPBasicAnimation *animation = [POPBasicAnimation animation];
    POPAnimatableProperty *valueProperty = [POPAnimatableProperty propertyWithName:@"org.telegram.enhanceValue" initializer:^(POPMutableAnimatableProperty *prop)
    {
        prop.readBlock = ^(TGPhotoEditorItemController *obj, CGFloat values[])
        {
            values[0] = [[obj->_portraitToolControlView value] floatValue];
        };
        prop.writeBlock = ^(TGPhotoEditorItemController *obj, const CGFloat values[])
        {
            [obj->_portraitToolControlView setValue:@(values[0])];
            [obj->_landscapeToolControlView setValue:@(values[0])];
        };
    }];
    animation.property = valueProperty;
    animation.fromValue = @(0);
    animation.toValue = @(50.0f);
    animation.duration = 0.3f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
    {
        _animating = false;
        
        if (_enhanceInitialAppearance)
            return;
        
        [_editorItem setTempValue:@(50)];
        
        PGPhotoEditor *photoEditor = self.photoEditor;
        [photoEditor processAnimated:true completion:nil];
    };
    [self pop_addAnimation:animation forKey:@"enhanceValue"];
}

#pragma mark - Transition

- (void)prepareForCombinedAppearance
{
    _enhanceInitialAppearance = true;
    
    _wrapperView.backgroundColor = [UIColor clearColor];
    _portraitToolControlView.backgroundColor = [UIColor clearColor];
    _landscapeToolControlView.backgroundColor = [UIColor clearColor];
}

- (void)finishedCombinedAppearance
{
    _wrapperView.backgroundColor = [UIColor blackColor];
    _portraitToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
    _landscapeToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
}

- (void)transitionIn
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        _portraitToolControlView.layer.shouldRasterize = true;
    else
        _landscapeToolControlView.layer.shouldRasterize = true;
    
    CGRect targetFrame;
    CGRect toolTargetFrame;
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            targetFrame = _landscapeButtonsView.frame;
            _landscapeButtonsView.frame = CGRectOffset(_landscapeButtonsView.frame, -_landscapeButtonsView.frame.size.width, 0);
            toolTargetFrame = _landscapeToolsWrapperView.frame;
            _landscapeToolsWrapperView.frame = CGRectOffset(_landscapeToolsWrapperView.frame, -_landscapeToolsWrapperView.frame.size.width / 2 - 20, 0);
        }
            break;
        case UIInterfaceOrientationLandscapeRight:
        {
            targetFrame = _landscapeButtonsView.frame;
            _landscapeButtonsView.frame = CGRectOffset(_landscapeButtonsView.frame, _landscapeButtonsView.frame.size.width, 0);
            toolTargetFrame = _landscapeToolsWrapperView.frame;
            _landscapeToolsWrapperView.frame = CGRectOffset(_landscapeToolsWrapperView.frame, _landscapeToolsWrapperView.frame.size.width / 2 + 20, 0);
        }
            break;
            
        default:
        {
            targetFrame = _portraitButtonsView.frame;
            _portraitButtonsView.frame = CGRectOffset(_portraitButtonsView.frame, 0, _portraitButtonsView.frame.size.height);
            toolTargetFrame = _portraitToolsWrapperView.frame;
            _portraitToolsWrapperView.frame = CGRectOffset(_portraitToolsWrapperView.frame, 0, _portraitToolsWrapperView.frame.size.height / 2 + 20);
        }
            break;
    }
    
    void (^animationBlock)(void) = ^
    {
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
            _portraitButtonsView.frame = targetFrame;
            _portraitToolsWrapperView.frame = toolTargetFrame;
        }
        else {
            _landscapeButtonsView.frame = targetFrame;
            _landscapeToolsWrapperView.frame = toolTargetFrame;
        }
    };
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _wrapperView.alpha = 1.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _portraitToolControlView.layer.shouldRasterize = false;
            _landscapeToolControlView.layer.shouldRasterize = false;
        }
    }];
    
    if ([_editorItem.identifier isEqualToString:@"enhance"])
        [self _applyDefaultEnhanceIfNeeded];
    
    if (iosMajorVersion() >= 7)
        [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:nil];
    else
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:nil];
    
    if (self.beginTransitionIn != nil)
        self.beginTransitionIn();
}

- (void)transitionOutWithCompletion:(void (^)(void))completion
{
    _dismissing = true;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.interactionEnded = nil;
    
    if (self.beginTransitionOut != nil)
        self.beginTransitionOut();
    
    UIView *snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
    snapshotView.frame = previewView.frame;
    [previewView.superview addSubview:snapshotView];
    
    _wrapperView.backgroundColor = [UIColor clearColor];
    
    [_initialPreviewSuperview addSubview:self.previewView];
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        _portraitToolControlView.layer.shouldRasterize = true;
    else
        _landscapeToolControlView.layer.shouldRasterize = true;
    
    [_toolAreaView.superview bringSubviewToFront:_toolAreaView];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _wrapperView.alpha = 0.0f;
        snapshotView.alpha = 0.0f;
        _toolAreaView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (completion != nil)
                completion();
        });
    }];
    
    void (^animationBlock)(void) = ^
    {
        switch (self.interfaceOrientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _landscapeButtonsView.frame = CGRectOffset(_landscapeButtonsView.frame, -_landscapeButtonsView.frame.size.width, 0);
            }
                break;
            case UIInterfaceOrientationLandscapeRight:
            {
                _landscapeButtonsView.frame = CGRectOffset(_landscapeButtonsView.frame, _landscapeButtonsView.frame.size.width, 0);
            }
                break;
                
            default:
            {
                _portraitButtonsView.frame = CGRectOffset(_portraitButtonsView.frame, 0, _portraitButtonsView.frame.size.height);
            }
                break;
        }
    };
    
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    else if ([self.presentingViewController isKindOfClass:[TGNavigationController class]] &&
             [(TGNavigationController *)self.presentingViewController presentationStyle] == TGNavigationControllerPresentationStyleInFormSheet)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    
    if (UIInterfaceOrientationIsPortrait(orientation))
        _landscapeToolsWrapperView.hidden = true;
    else
        _portraitToolsWrapperView.hidden = true;
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:nil];
    }
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    if (_toolAreaView != nil)
    {
        _toolAreaView.alpha = 0.0f;
        
        [UIView animateWithDuration:duration / 2 delay:duration / 2 options:UIViewAnimationOptionCurveLinear animations:^
        {
            _toolAreaView.alpha = 1.0f;
        } completion:nil];
    }
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
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

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    CGSize referenceSize = [self referenceViewSize];
    
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    else if ([self.presentingViewController isKindOfClass:[TGNavigationController class]] &&
             [(TGNavigationController *)self.presentingViewController presentationStyle] == TGNavigationControllerPresentationStyleInFormSheet)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoEditorPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    CGFloat panelToolbarPortraitSize = TGPhotoEditorPanelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = TGPhotoEditorPanelSize + self.toolbarLandscapeSize;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(0, (screenSide - referenceSize.height) / 2, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - TGPhotoEditorPanelSize, 0, TGPhotoEditorPanelSize, _landscapeToolsWrapperView.frame.size.height);
                
                if (!_dismissing)
                    _landscapeButtonsView.frame = CGRectMake(0, 0, [_landscapeButtonsView landscapeSize], referenceSize.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, (screenSide - referenceSize.height) / 2, panelToolbarLandscapeSize, referenceSize.height);
            
            _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - TGPhotoEditorPanelSize, 0, TGPhotoEditorPanelSize, _landscapeToolsWrapperView.frame.size.height);

            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, (screenSide - referenceSize.height) / 2, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeToolControlView.frame = CGRectMake(0, 0, TGPhotoEditorPanelSize, _landscapeToolsWrapperView.frame.size.height);
                
                if (!_dismissing)
                    _landscapeButtonsView.frame = CGRectMake(panelToolbarLandscapeSize - [_landscapeButtonsView landscapeSize], 0, [_landscapeButtonsView landscapeSize], referenceSize.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake((screenSide + referenceSize.width) / 2 - panelToolbarLandscapeSize, (screenSide - referenceSize.height) / 2, panelToolbarLandscapeSize, referenceSize.height);
            
            _landscapeToolControlView.frame = CGRectMake(0, 0, TGPhotoEditorPanelSize, _landscapeToolsWrapperView.frame.size.height);

            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        default:
        {
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - TGPhotoEditorPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, (screenSide - referenceSize.height) / 2, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2 - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            if (!_dismissing)
                _portraitButtonsView.frame = CGRectMake(0, _portraitToolsWrapperView.frame.size.height - TGPhotoEditorToolButtonsViewSize, _portraitToolsWrapperView.frame.size.width, TGPhotoEditorToolButtonsViewSize);
            
            _portraitToolControlView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, _portraitToolsWrapperView.frame.size.height - _portraitButtonsView.frame.size.height);
        }
            break;
    }
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view)
        return;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                   containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                   fittedSize.width,
                                   fittedSize.height);
    
    [UIView performWithoutAnimation:^
    {
        _toolAreaView.frame = CGRectMake(CGRectGetMidX(previewView.frame) - containerFrame.size.width / 2, CGRectGetMidY(previewView.frame) - containerFrame.size.height / 2, containerFrame.size.width, containerFrame.size.height);
        _toolAreaView.actualAreaSize  = previewView.frame.size;
    }];
}

@end
