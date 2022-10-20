#import "TGModernGalleryController.h"

#import "LegacyComponentsInternal.h"
#import "TGHacks.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGModernGalleryView.h>

#import <LegacyComponents/TGModernGalleryItem.h>
#import <LegacyComponents/TGModernGalleryScrollView.h>
#import <LegacyComponents/TGModernGalleryItemView.h>
#import <LegacyComponents/TGModernGalleryTransitionView.h>

#import <LegacyComponents/TGModernGalleryImageItemContainerView.h>

#import <LegacyComponents/TGModernGalleryContainerView.h>
#import <LegacyComponents/TGModernGalleryInterfaceView.h>
#import <LegacyComponents/TGModernGalleryDefaultInterfaceView.h>

#import <LegacyComponents/TGModernGalleryModel.h>

#import <objc/runtime.h>

#import <LegacyComponents/JNWSpringAnimation.h>

#import <LegacyComponents/TGKeyCommandController.h>

#define TGModernGalleryItemPadding 20.0f

@interface TGModernGalleryController () <UIScrollViewDelegate, TGModernGalleryScrollViewDelegate, TGModernGalleryItemViewDelegate, TGKeyCommandResponder>
{
    NSMutableDictionary *_reusableItemViewsByIdentifier;
    NSMutableArray *_visibleItemViews;
    bool _preloadVisibleItemViews;
    
    TGModernGalleryView *_view;
    UIView<TGModernGalleryDefaultHeaderView> *_defaultHeaderView;
    UIView<TGModernGalleryDefaultFooterView> *_defaultFooterView;
    
    NSUInteger _lastReportedFocusedIndex;
    bool _synchronousBoundsChange;
    bool _reloadingItems;
    bool _isBeingDismissed;
    
    UIStatusBarStyle _statusBarStyle;
    id<SDisposable> _transitionInDisposable;
    
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGModernGalleryController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        
        self.automaticallyManageScrollViewInsets = false;
        self.autoManageStatusBarBackground = false;
        _lastReportedFocusedIndex = NSNotFound;
        _statusBarStyle = UIStatusBarStyleLightContent;
        _animateTransition = true;
        _showInterface = true;
        _adjustsStatusBarVisibility = true;
        _defaultStatusBarStyle = UIStatusBarStyleDefault;
        _shouldAnimateStatusBarStyleTransition = true;
        
        if ([context respondsToSelector:@selector(prefersLightStatusBar)])
            _defaultStatusBarStyle = [context prefersLightStatusBar] ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
    }
    return self;
}

- (void)dealloc
{
    _view.scrollView.delegate = nil;
    _view.scrollView.scrollDelegate = nil;
    [_transitionInDisposable dispose];
}

- (void)dismiss
{
    [super dismiss];
    
    if (_completedTransitionOut)
        _completedTransitionOut();
}

- (BOOL)prefersStatusBarHidden
{
    return true;
    
    /*if (!TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]))
        return true;
    
    if (self.childViewControllers.count > 0)
        return [self.childViewControllers.lastObject prefersStatusBarHidden];
    
    return [super prefersStatusBarHidden];*/
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    if (self.childViewControllers.count > 0)
        return [self.childViewControllers.lastObject preferredScreenEdgesDeferringSystemGestures];
    
    return [super preferredScreenEdgesDeferringSystemGestures];
}

- (bool)prefersHomeIndicatorAutoHidden
{
    return [_view isInterfaceHidden];
}

- (void)complexDismiss
{
    if (_completedTransitionOut != nil)
        _completedTransitionOut();
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [super dismiss];
    });
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return _statusBarStyle;
}

- (BOOL)shouldAutorotate
{
    return [super shouldAutorotate] && (_view == nil || [_view shouldAutorotate]) && ([_model _shouldAutorotate]);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    if ([_view.interfaceView respondsToSelector:@selector(willRotateToInterfaceOrientation:duration:)])
        [_view.interfaceView willRotateToInterfaceOrientation:interfaceOrientation duration:duration];
}

- (void)dismissWhenReady {
    [self dismissWhenReadyAnimated:false];
}

- (void)dismissWhenReadyAnimated:(bool)animated {
    [self dismissWhenReadyAnimated:animated force:false];
}

- (void)dismissWhenReadyAnimated:(bool)animated force:(bool)force
{
    if (animated) {
        id<TGModernGalleryItem> focusItem = nil;
        if ([self currentItemIndex] < self.model.items.count)
            focusItem = self.model.items[[self currentItemIndex]];
        
        TGModernGalleryItemView *currentItemView = nil;
        for (TGModernGalleryItemView *itemView in self->_visibleItemViews)
        {
            if ([itemView.item isEqual:focusItem])
            {
                currentItemView = itemView;
                break;
            }
        }
        
        if (currentItemView == nil || [currentItemView dismissControllerNowOrSchedule] || force) {
            [_view simpleTransitionOutWithVelocity:0.0f completion:^
            {
                [self dismiss];
            }];
        }
    } else {
        [self dismiss];
    }
}

- (UIView *)transitionView {
    id<TGModernGalleryItem> focusItem = nil;
    if ([self currentItemIndex] < self.model.items.count)
        focusItem = self.model.items[[self currentItemIndex]];
    
    for (TGModernGalleryItemView *itemView in self->_visibleItemViews)
    {
        if ([itemView.item isEqual:focusItem])
        {
            TGDispatchAfter(0.1, dispatch_get_main_queue(), ^{
                itemView.alpha = 0.01;
            });
            UIView *contentView = [itemView transitionContentView];
            UIView *snapshotView = [contentView snapshotViewAfterScreenUpdates:true];
            snapshotView.frame = [contentView convertRect:contentView.bounds toView:nil];
            return snapshotView;
        }
    }
    
    return nil;
}

- (bool)isFullyOpaque
{
    CGFloat alpha = 0.0f;
    [_view.backgroundColor getWhite:NULL alpha:&alpha];
    return alpha >= 1.0f - FLT_EPSILON;
}

- (void)setModel:(TGModernGalleryModel *)model
{
    if (_model != model)
    {
        _model = model;
        
        __weak TGModernGalleryController *weakSelf = self;
        _model.itemsUpdated = ^(id<TGModernGalleryItem> item)
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            if (strongSelf != nil && !strongSelf->_isBeingDismissed)
                [strongSelf reloadDataAtItem:item synchronously:false];
        };
        
        _model.focusOnItem = ^(id<TGModernGalleryItem> item, bool synchronously)
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            NSUInteger index = [strongSelf.model.items indexOfObject:item];
            [strongSelf setCurrentItemIndex:index == NSNotFound ? 0 : index synchronously:synchronously];
        };
        
        _model.actionSheetView = ^
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            return strongSelf.view;
        };
        
        _model.viewControllerForModalPresentation = ^
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            return strongSelf;
        };
        
        _model.visibleItems = ^NSArray *()
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            return [strongSelf visibleItems];
        };
        
        _model.dismiss = ^(bool animated, bool asModal)
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_isBeingDismissed = true;
                
                if (asModal)
                {
                    strongSelf->_statusBarStyle = strongSelf->_defaultStatusBarStyle;
                    strongSelf.view.hidden = true;
                    
                    if (strongSelf.completedTransitionOut)
                        strongSelf.completedTransitionOut();
                    
                    [strongSelf dismissViewControllerAnimated:true completion:^
                    {
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            [strongSelf dismiss];
                        });
                    }];
                }
                else
                {
                    if (animated)
                    {
                        if (iosMajorVersion() >= 7 && strongSelf.shouldAnimateStatusBarStyleTransition)
                        {
                            [strongSelf animateStatusBarTransition:0.2];
                            strongSelf->_statusBarStyle = strongSelf->_defaultStatusBarStyle;
                            [strongSelf setNeedsStatusBarAppearanceUpdate];
                        }
                        
                        if (strongSelf.adjustsStatusBarVisibility)
                        {
                            [UIView animateWithDuration:0.2 animations:^
                            {
                                //[strongSelf->_context setApplicationStatusBarAlpha:1.0f];
                            }];
                        }
                        
                        [strongSelf->_view simpleTransitionOutWithVelocity:0.0f completion:^
                        {
                            [strongSelf dismiss];
                        }];
                    }
                    else
                    {
                        if (iosMajorVersion() >= 7)
                        {
                            strongSelf->_statusBarStyle = strongSelf->_defaultStatusBarStyle;
                            [strongSelf setNeedsStatusBarAppearanceUpdate];
                        }
                        
                        [strongSelf dismiss];
                    }
                }
            }
        };
        
        _model.dismissWhenReady = ^(bool animated)
        {
            __strong TGModernGalleryController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                [strongSelf dismissWhenReadyAnimated:animated];
            }
        };
        
        [self reloadDataAtItem:_model.focusItem synchronously:false];
    }
}

- (void)itemViewIsReadyForScheduledDismiss:(TGModernGalleryItemView *)__unused itemView
{
    [self dismissWhenReadyAnimated:true force:true];
}

- (void)itemViewDidRequestInterfaceShowHide:(TGModernGalleryItemView *)__unused itemView
{
    [_view showHideInterface];
    
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
}

- (void)itemViewDidRequestGalleryDismissal:(TGModernGalleryItemView *)__unused itemView animated:(bool)animated
{
    if (_completedTransitionOut)
        _completedTransitionOut();
    
    void (^block)(void) = ^
    {
        [super dismiss];
    };
    
    _view.userInteractionEnabled = false;
    
    if (animated)
        [_view fadeOutWithDuration:0.3 completion:block];
    else
        block();
}

- (UIView *)itemViewDidRequestInterfaceView:(TGModernGalleryItemView *)__unused itemView
{
    return _view.interfaceView;
}

- (TGViewController *)parentControllerForPresentation {
    return self;
}

- (UIView *)overlayContainerView {
    return _view.overlayContainerView;
}

- (TGModernGalleryItemView *)dequeueViewForItem:(id<TGModernGalleryItem>)item
{
    if (item == nil || [item viewClass] == nil)
        return nil;
    
    NSString *identifier = NSStringFromClass([item viewClass]);
    NSMutableArray *views = _reusableItemViewsByIdentifier[identifier];
    if (views == nil)
    {
        views = [[NSMutableArray alloc] init];
        _reusableItemViewsByIdentifier[identifier] = views;
    }
    
    if (views.count == 0)
    {
        Class itemClass = [item viewClass];
        TGModernGalleryItemView *itemView = [[itemClass alloc] init];
        itemView.delegate = self;
        itemView.defaultFooterView = _defaultFooterView;
        itemView.defaultFooterAccessoryLeftView = [_model createDefaultLeftAccessoryView];
        itemView.defaultFooterAccessoryRightView = [_model createDefaultRightAccessoryView];
        
        return itemView;
    }

    TGModernGalleryItemView *itemView = [views lastObject];
    [views removeLastObject];
    
    itemView.delegate = self;
    [itemView prepareForReuse];
    return itemView;
}

- (void)enqueueView:(TGModernGalleryItemView *)itemView
{
    if (itemView == nil)
        return;
    
    itemView.delegate = nil;
    [itemView prepareForRecycle];
    
    NSString *identifier = NSStringFromClass([itemView class]);
    if (identifier != nil)
    {
        NSMutableArray *views = _reusableItemViewsByIdentifier[identifier];
        if (views == nil)
        {
            views = [[NSMutableArray alloc] init];
            _reusableItemViewsByIdentifier[identifier] = views;
        }
        [views addObject:itemView];
    }
}

- (NSArray *)visibleItemViews
{
    return _visibleItemViews;
}

- (TGModernGalleryItemView *)itemViewForItem:(id<TGModernGalleryItem>)item
{
    for (TGModernGalleryItemView *itemView in self->_visibleItemViews)
    {
        if ([itemView.item isEqual:item])
        {
            return itemView;
        }
    }

    return nil;
}

- (void)setShowInterface:(bool)showInterface
{
    _showInterface = showInterface;
    
    //_view.userInteractionEnabled = showInterface;
    
    _statusBarStyle = _showInterface ? UIStatusBarStyleLightContent : _defaultStatusBarStyle;
}

- (void)loadView
{
    [super loadView];
    object_setClass(self.view, [TGModernGalleryContainerView class]);
    
    self.view.frame = (CGRect){self.view.frame.origin, [_context fullscreenBounds].size};
    
    _reusableItemViewsByIdentifier = [[NSMutableDictionary alloc] init];
    _visibleItemViews = [[NSMutableArray alloc] init];
    
    UIView<TGModernGalleryInterfaceView> *interfaceView = [_model createInterfaceView];
    if (interfaceView == nil)
        interfaceView = [[TGModernGalleryDefaultInterfaceView alloc] initWithFrame:CGRectZero];
    interfaceView.safeAreaInset = [self calculatedSafeAreaInset];
    
    CGSize previewSize = CGSizeZero;
    if (_previewMode)
        previewSize = self.preferredContentSize;
    
    __weak TGModernGalleryController *weakSelf = self;
    _view = [[TGModernGalleryView alloc] initWithFrame:self.view.bounds context:_context itemPadding:TGModernGalleryItemPadding interfaceView:interfaceView previewMode:_previewMode previewSize:previewSize];
    _view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_view.interfaceView setController:^UIViewController *(void)
    {
        __strong TGModernGalleryController *strongSelf = weakSelf;
        return strongSelf;
    }];
    [self.view addSubview:_view];
    
    _defaultHeaderView = [_model createDefaultHeaderView];
    if (_defaultHeaderView != nil)
        [_view addItemHeaderView:_defaultHeaderView];
    
    _defaultFooterView = [_model createDefaultFooterView];
    if (_defaultFooterView != nil)
    {
        if ([_defaultFooterView respondsToSelector:@selector(setSafeAreaInset:)])
            [_defaultFooterView setSafeAreaInset:[self calculatedSafeAreaInset]];
        [_view addItemFooterView:_defaultFooterView];
    }
    
    _view.scrollView.scrollDelegate = self;
    _view.scrollView.delegate = self;
    
    _view.userInteractionEnabled = _showInterface;
    
    _view.transitionOut = ^bool (CGFloat velocity)
    {
        __strong TGModernGalleryController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_isBeingDismissed = true;
            
            id<TGModernGalleryItem> focusItem = nil;
            if ([strongSelf currentItemIndex] < strongSelf.model.items.count)
                focusItem = strongSelf.model.items[[strongSelf currentItemIndex]];
            
            TGModernGalleryItemView *currentItemView = nil;
            for (TGModernGalleryItemView *itemView in strongSelf->_visibleItemViews)
            {
                if ([itemView.item isEqual:focusItem])
                {
                    currentItemView = itemView;
                    break;
                }
            }
            
            if (strongSelf.hasFadeOutTransition)
            {
                if (strongSelf.beginTransitionOut)
                    strongSelf.beginTransitionOut(focusItem, currentItemView);
                
                [strongSelf->_view fadeOutWithDuration:0.3f completion:^
                {
                    [strongSelf dismiss];
                }];
            }
            else
            {
                UIView *transitionOutToView = nil;
                UIView *transitionOutFromView = nil;
                CGRect transitionOutFromViewContentRect = CGRectZero;
                
                if (strongSelf.beginTransitionOut && focusItem != nil)
                    transitionOutToView = strongSelf.beginTransitionOut(focusItem, currentItemView);
                if (transitionOutToView != nil && currentItemView != nil)
                {
                    transitionOutFromView = [currentItemView transitionView];
                    transitionOutFromViewContentRect = [currentItemView transitionViewContentRect];
                }
                
                if (transitionOutFromView != nil && transitionOutToView != nil)
                {
                    [strongSelf animateTransitionOutFromView:transitionOutFromView fromViewContentRect:transitionOutFromViewContentRect toView:transitionOutToView velocity:CGPointMake(0.0f, velocity * 3.8f)];
                    [strongSelf->_view transitionOutWithDuration:0.15];
                    [strongSelf->_view.interfaceView animateTransitionOutWithDuration:0.15];
                }
                else
                {
                    if (iosMajorVersion() >= 7 && strongSelf.shouldAnimateStatusBarStyleTransition)
                    {
                        [strongSelf animateStatusBarTransition:0.2];
                        strongSelf->_statusBarStyle = strongSelf->_defaultStatusBarStyle;
                        [strongSelf setNeedsStatusBarAppearanceUpdate];
                    }
                    
                    if (strongSelf.adjustsStatusBarVisibility)
                    {
                        [UIView animateWithDuration:0.2 animations:^
                        {
                            //[strongSelf->_context setApplicationStatusBarAlpha:1.0f];
                        }];
                    }
                    
                    [strongSelf->_view simpleTransitionOutWithVelocity:velocity completion:^
                    {
                        __strong TGModernGalleryController *strongSelf2 = weakSelf;
                        [strongSelf2 dismiss];
                    }];
                }
            }
        }
        return true;
    };
    
    _view.transitionProgress = ^(CGFloat progress, bool manual)
    {
        __strong TGModernGalleryController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (iosMajorVersion() >= 7 && strongSelf.shouldAnimateStatusBarStyleTransition)
            {
                if (progress > FLT_EPSILON)
                {
                    if (strongSelf->_statusBarStyle != strongSelf->_defaultStatusBarStyle)
                    {
                        [strongSelf animateStatusBarTransition:0.2];
                        strongSelf->_statusBarStyle = strongSelf->_defaultStatusBarStyle;
                        [strongSelf setNeedsStatusBarAppearanceUpdate];
                    }
                }
                else if (!manual)
                {
                    [strongSelf animateStatusBarTransition:0.2];
                    strongSelf->_statusBarStyle = UIStatusBarStyleLightContent;
                    [strongSelf setNeedsStatusBarAppearanceUpdate];
                }
            }
        }
    };
    
    [self reloadDataAtItem:_model.focusItem synchronously:!_asyncTransitionIn];
    
    if (_animateTransition) {
        UIView *transitionInFromView = nil;
        UIView *transitionInToView = nil;
        TGModernGalleryItemView *transitionFromItemView = nil;
        CGRect transitionInToViewContentRect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
        if (_beginTransitionIn && _model.focusItem != nil)
        {
            TGModernGalleryItemView *itemView = nil;
            for (TGModernGalleryItemView *visibleItemView in self->_visibleItemViews)
            {
                if ([visibleItemView.item isEqual:self.model.focusItem])
                {
                    itemView = visibleItemView;
                    transitionFromItemView = itemView;
                    
                    break;
                }
            }
            
            transitionInFromView = _beginTransitionIn(_model.focusItem, itemView);
        }
        if (transitionInFromView != nil)
        {
            for (TGModernGalleryItemView *itemView in _visibleItemViews)
            {
                if ([itemView.item isEqual:_model.focusItem])
                {
                    transitionInToView = [itemView transitionView];
                    transitionInToViewContentRect = [itemView transitionViewContentRect];
                    
                    break;
                }
            }
        }
    
        if (transitionInFromView != nil && transitionInToView != nil && transitionInToView.frame.size.width > FLT_EPSILON && transitionInToView.frame.size.height > FLT_EPSILON && transitionInToViewContentRect.size.width > FLT_EPSILON && transitionInToViewContentRect.size.height > FLT_EPSILON)
        {
            if (_asyncTransitionIn) {
                __weak TGModernGalleryController *weakSelf = self;
                self.view.hidden = true;
                _transitionInDisposable = [[[[transitionFromItemView readyForTransitionIn] take:1] timeout:1.0 onQueue:[SQueue mainQueue] orSignal:[SSignal single:@true]] startWithNext:^(__unused id next) {
                    __strong TGModernGalleryController *strongSelf = weakSelf;
                    if (strongSelf != nil) {
                        [strongSelf animateTransitionInFromView:transitionInFromView toView:transitionInToView toViewContentRect:transitionInToViewContentRect];
                        [strongSelf->_view transitionInWithDuration:0.15];
                        
                        [strongSelf animateStatusBarTransition:0.2];
                        strongSelf.view.hidden = false;
                        
                        if (strongSelf->_startedTransitionIn) {
                            strongSelf->_startedTransitionIn();
                        }
                    }
                }];
            } else {
                if (_startedTransitionIn) {
                    _startedTransitionIn();
                }
                [self animateTransitionInFromView:transitionInFromView toView:transitionInToView toViewContentRect:transitionInToViewContentRect];
                [_view transitionInWithDuration:0.15];
                
                [self animateStatusBarTransition:0.2];
            }
        }
        else if (!_previewMode)
        {
            if (_startedTransitionIn) {
                _startedTransitionIn();
            }
            
            [_view simpleTransitionInWithCompletion:
            ^{
                if (_finishedTransitionIn && _model.focusItem != nil)
                {
                    TGModernGalleryItemView *itemView = nil;
                    if (self.finishedTransitionIn && self.model.focusItem != nil)
                    {
                        for (TGModernGalleryItemView *visibleItemView in self->_visibleItemViews)
                        {
                            if ([visibleItemView.item isEqual:self.model.focusItem])
                            {
                                itemView = visibleItemView;
                                
                                break;
                            }
                        }
                    }
                    
                    _finishedTransitionIn(_model.focusItem, itemView);
                    
                    [_model _transitionCompleted];
                }
                else
                    [_model _transitionCompleted];
            }];
            
            [_view transitionInWithDuration:0.15];
            
            [self animateStatusBarTransition:0.2];
        }
    }
    else
    {
        if (_finishedTransitionIn && _model.focusItem != nil)
        {
            TGModernGalleryItemView *itemView = nil;
            if (self.finishedTransitionIn && self.model.focusItem != nil)
            {
                for (TGModernGalleryItemView *visibleItemView in self->_visibleItemViews)
                {
                    if ([visibleItemView.item isEqual:self.model.focusItem])
                    {
                        itemView = visibleItemView;
                        
                        break;
                    }
                }
            }
            
            _finishedTransitionIn(_model.focusItem, itemView);
        }
        
        [_model _transitionCompleted];
    }
    
    if (!_showInterface) {
        [_view enableInstantDismiss];
        __weak TGModernGalleryController *weakSelf = self;
        _view.instantDismiss = ^{
            __strong TGModernGalleryController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf dismiss];
            }
        };
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    _view.interfaceView.safeAreaInset = self.controllerSafeAreaInset;
}

- (UIView *)findScrollView:(UIView *)view
{
    if (view == nil || ([view isKindOfClass:[UIScrollView class]] && view.tag != 0xbeef))
        return view;
    
    return [self findScrollView:view.superview];
}

- (UIView *)topSuperviewOfView:(UIView *)view
{
    if (view.superview == nil)
        return view;
    
    return [self topSuperviewOfView:view.superview];
}

- (UIView *)findCommonSuperviewOfView:(UIView *)view andView:(UIView *)andView
{
    UIView *leftSuperview = [self topSuperviewOfView:view];
    UIView *rightSuperview = [self topSuperviewOfView:andView];
    
    if (leftSuperview != rightSuperview)
        return nil;
    
    return leftSuperview;
}

- (UIView *)subviewOfView:(UIView *)view containingView:(UIView *)containingView
{
    if (view == containingView)
        return view;
    
    for (UIView *subview in view.subviews)
    {
        if ([self subviewOfView:subview containingView:containingView] != nil)
            return subview;
    }
    
    return nil;
}

static CGRect adjustFrameForOriginalSubframe(CGRect originalFrame, CGRect originalSubframe, CGRect frame)
{
    if (originalSubframe.size.width < FLT_EPSILON || originalSubframe.size.height < FLT_EPSILON)
        return frame;
    
    CGFloat widthFactor = frame.size.width / originalSubframe.size.width;
    CGFloat heightFactor = frame.size.height / originalSubframe.size.height;
    
    CGRect adjustedFrame = CGRectMake(frame.origin.x - originalSubframe.origin.x * widthFactor, frame.origin.y - originalSubframe.origin.y * heightFactor, originalFrame.size.width * widthFactor, originalFrame.size.height * heightFactor);
    
    return adjustedFrame;
}

- (CGRect)convertFrameOfView:(UIView *)view fromSubframe:(CGRect)fromSubframe toView:(UIView *)toView toSubframe:(CGRect)toSubframe outRotationZ:(CGFloat *)outRotationZ
{
    if (view == toView)
        return view.bounds;
    
    CGFloat sourceWindowRotation = 0.0f;
    
    CGRect frame = fromSubframe;
    
    UIView *currentView = view;
    while (currentView != nil)
    {
        frame.origin.x += currentView.frame.origin.x - currentView.bounds.origin.x;
        frame.origin.y += currentView.frame.origin.y - currentView.bounds.origin.y;
        
        CGFloat rotation = transformRotation(currentView.transform);
        if (ABS(rotation) > FLT_EPSILON)
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(currentView.bounds.size.width / 2.0f, currentView.bounds.size.height / 2.0f);
            transform = CGAffineTransformRotate(transform, rotation);
            transform = CGAffineTransformTranslate(transform, -currentView.bounds.size.width / 2.0f, -currentView.bounds.size.height / 2.0f);
            
            frame = CGRectApplyAffineTransform(frame, transform);
        }
        
        //TGLegacyLog(@"%f: %@", rotation, currentView);
        
        if ([currentView.superview isKindOfClass:[UIWindow class]])
            sourceWindowRotation = rotation;
        
        //frame = CGRectApplyAffineTransform(frame, transform);
        
        currentView = currentView.superview;
    }
    
    UIView *subview = [self topSuperviewOfView:toView];
    while (subview != nil && subview != toView)
    {
        frame.origin.x -= subview.frame.origin.x - subview.bounds.origin.x;
        frame.origin.y -= subview.frame.origin.y - subview.bounds.origin.y;
        
        if (ABS(sourceWindowRotation) > FLT_EPSILON)
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(subview.bounds.size.width / 2.0f, subview.bounds.size.height / 2.0f);
            transform = CGAffineTransformRotate(transform, -sourceWindowRotation);
            transform = CGAffineTransformTranslate(transform, -subview.bounds.size.width / 2.0f, -subview.bounds.size.height / 2.0f);
            
            frame = CGRectApplyAffineTransform(frame, transform);
            
            sourceWindowRotation = 0.0f;
        }
        
        subview = [self subviewOfView:subview containingView:toView];
    }
    
    frame = adjustFrameForOriginalSubframe(toView.frame, toSubframe, frame);
    
    /*frame.origin.x = CGFloor(frame.origin.x);
    frame.origin.y = CGFloor(frame.origin.y);
    frame.size.width = CGFloor(frame.size.width);
    frame.size.height = CGFloor(frame.size.height);*/
    
    if (outRotationZ != NULL)
        *outRotationZ = 0.0f;
    
    return frame;
}

static CGFloat transformRotation(CGAffineTransform transform)
{
    return (CGFloat)atan2(transform.b, transform.a);
}

- (void)animateView:(UIView *)view frameFrom:(CGRect)fromFrame to:(CGRect)toFrame velocity:(CGPoint)__unused velocity rotationFrom:(CGFloat)fromRotation to:(CGFloat)toRotation animatingIn:(bool)animatingIn completion:(void (^)(bool))completion
{
    if (fromFrame.size.width < FLT_EPSILON || fromFrame.size.height < FLT_EPSILON )
    {
        completion(true);
        return;
    }
    
    if (ABS(toRotation - fromRotation) > FLT_EPSILON)
    {
    }
    
    if (![UIView areAnimationsEnabled]) {
        view.frame = toFrame;
        completion(true);
        return;
    }
    
    [CATransaction begin];
    
    CGFloat damping = animatingIn ? 25.0f : 30.0f;
    CGFloat mass = 0.8f;
    CGFloat durationFactor = animatingIn ? 1.8f : 2.0f;
    
    CGPoint fromPosition = CGPointMake(CGRectGetMidX(fromFrame), CGRectGetMidY(fromFrame));
    CGPoint toPosition = CGPointMake(CGRectGetMidX(toFrame), CGRectGetMidY(toFrame));
    JNWSpringAnimation *positionAnimation = [JNWSpringAnimation animationWithKeyPath:@"position"];
    positionAnimation.fromValue = [NSValue valueWithCGPoint:fromPosition];
    positionAnimation.toValue = [NSValue valueWithCGPoint:toPosition];
    positionAnimation.damping = damping;
    positionAnimation.mass = mass;
    positionAnimation.removedOnCompletion = true;
    positionAnimation.fillMode = kCAFillModeForwards;
    positionAnimation.durationFactor = durationFactor;
    TGAnimationBlockDelegate *delegate = [[TGAnimationBlockDelegate alloc] initWithLayer:view.layer];
    delegate.completion = ^(BOOL finished)
    {
        if (completion)
            completion(finished);
    };
    positionAnimation.delegate = delegate;
    view.layer.position = toPosition;
    [view.layer addAnimation:positionAnimation forKey:@"position"];
    
    CGPoint fromScale = CGPointMake(fromFrame.size.width / view.bounds.size.width, fromFrame.size.height/ view.bounds.size.height);
    CGPoint toScale = CGPointMake(toFrame.size.width / view.bounds.size.width, toFrame.size.height / view.bounds.size.height);
    view.layer.transform = CATransform3DMakeScale(toFrame.size.width / view.bounds.size.width, toFrame.size.height / view.bounds.size.height, 1.0f);
    {
        JNWSpringAnimation *scaleAnimation = [JNWSpringAnimation animationWithKeyPath:@"transform.scale.x"];
        scaleAnimation.fromValue = @(fromScale.x);
        scaleAnimation.toValue = @(toScale.x);
        scaleAnimation.damping = damping;
        scaleAnimation.mass = mass;
        scaleAnimation.removedOnCompletion = true;
        scaleAnimation.fillMode = kCAFillModeForwards;
        scaleAnimation.durationFactor = durationFactor;
        [view.layer addAnimation:scaleAnimation forKey:@"transform.scale.x"];
    }
    {
        JNWSpringAnimation *scaleAnimation = [JNWSpringAnimation animationWithKeyPath:@"transform.scale.y"];
        scaleAnimation.fromValue = @(fromScale.y);
        scaleAnimation.toValue = @(toScale.y);
        scaleAnimation.damping = damping;
        scaleAnimation.mass = mass;
        scaleAnimation.removedOnCompletion = true;
        scaleAnimation.fillMode = kCAFillModeForwards;
        scaleAnimation.durationFactor = durationFactor;
        [view.layer addAnimation:scaleAnimation forKey:@"transform.scale.y"];
    }
    
    [CATransaction commit];
}

- (void)animateTransitionInFromView:(UIView *)fromView toView:(UIView *)toView toViewContentRect:(CGRect)toViewContentRect
{
    UIView *fromScrollView = nil;
    if (self.transitionHost != nil)
        fromScrollView = self.transitionHost();
    else
        fromScrollView = [self findScrollView:fromView];
    UIView *fromContainerView = fromScrollView.superview;
    
    CGFloat fromRotationZ = 0.0f;
    CGRect fromFrame = [self convertFrameOfView:fromView fromSubframe:(CGRect){CGPointZero, fromView.frame.size} toView:toView.superview toSubframe:[toView.superview convertRect:toViewContentRect fromView:toView] outRotationZ:&fromRotationZ];
    
    bool disableOffsetFix = false;
    if ([fromScrollView conformsToProtocol:@protocol(TGModernGalleryTransitionHostScrollView)]) {
        disableOffsetFix = [(id<TGModernGalleryTransitionHostScrollView>)fromScrollView disableGalleryTransitionOffsetFix];
    }
    
    if (!disableOffsetFix) {
        fromFrame.origin.y += fromScrollView.frame.origin.y * 2.0f;
    }
    
    fromFrame.origin.x -= toView.superview.frame.origin.x;
    fromFrame.origin.y -= toView.superview.frame.origin.y;
    
    CGRect fromContainerFromFrame = [fromContainerView convertRect:fromView.bounds fromView:fromView];
    CGRect fromContainerFrame = [self convertFrameOfView:toView fromSubframe:toViewContentRect toView:fromContainerView toSubframe:(CGRect){CGPointZero, fromContainerView.frame.size} outRotationZ:NULL];
    
    if ([fromView conformsToProtocol:@protocol(TGModernGalleryTransitionView)] && [fromView respondsToSelector:@selector(transitionContentRect)])
    {
        CGRect fromContentRect = [(id<TGModernGalleryTransitionView>)fromView transitionContentRect];
        if (fromContentRect.size.width > FLT_EPSILON && fromContentRect.size.height > FLT_EPSILON)
        {
            fromContainerFrame = adjustFrameForOriginalSubframe(fromView.frame, fromContentRect, fromContainerFrame);
        }
    }
    
    UIView *fromViewContainerCopy = nil;
    
    if ([fromView conformsToProtocol:@protocol(TGModernGalleryTransitionView)])
    {
        UIImage *transitionImage = [(id<TGModernGalleryTransitionView>)fromView transitionImage];
        if (transitionImage != nil)
            fromViewContainerCopy = [[UIImageView alloc] initWithImage:transitionImage];
    }
    
    if (fromViewContainerCopy == nil)
        fromViewContainerCopy = [fromView snapshotViewAfterScreenUpdates:false];
    if (fromViewContainerCopy == nil)
        fromViewContainerCopy = [fromView snapshotViewAfterScreenUpdates:true];
    
    fromViewContainerCopy.frame = fromContainerFromFrame;
    [fromContainerView insertSubview:fromViewContainerCopy aboveSubview:fromScrollView];
    
    __weak TGModernGalleryController *weakSelf = self;
    self.view.userInteractionEnabled = false;
    [self animateView:toView frameFrom:fromFrame to:toView.frame velocity:CGPointZero rotationFrom:fromRotationZ to:0.0f animatingIn:true completion:^(bool __unused finished)
    {
        __strong TGModernGalleryController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf.view.userInteractionEnabled = true;
            
            TGModernGalleryItemView *itemView = nil;
            if (strongSelf.finishedTransitionIn && strongSelf.model.focusItem != nil)
            {
                for (TGModernGalleryItemView *visibleItemView in strongSelf->_visibleItemViews)
                {
                    if ([visibleItemView.item isEqual:strongSelf.model.focusItem])
                    {
                        itemView = visibleItemView;
                        
                        break;
                    }
                }
            }
            
            if (strongSelf.finishedTransitionIn)
                strongSelf.finishedTransitionIn(strongSelf.model.focusItem, itemView);
            
            strongSelf->_preloadVisibleItemViews = true;
            [strongSelf scrollViewBoundsChanged:strongSelf->_view.scrollView.bounds synchronously:false];
            
            [strongSelf.model _transitionCompleted];
        }
    }];
    
    __weak UIView *weakFromViewContainerCopy = fromViewContainerCopy;
    [self animateView:fromViewContainerCopy frameFrom:fromViewContainerCopy.frame to:fromContainerFrame velocity:CGPointZero rotationFrom:0.0f to:0.0f animatingIn:true completion:^(__unused bool finished)
    {
        __strong UIView *strongFromViewContainerCopy = weakFromViewContainerCopy;
        [strongFromViewContainerCopy removeFromSuperview];
    }];
    toView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.07 animations:^{
        toView.alpha = 1.0f;
    }];
}

- (void)animateTransitionOutFromView:(UIView *)fromView fromViewContentRect:(CGRect)fromViewContentRect toView:(UIView *)toView velocity:(CGPoint)velocity
{
    UIView *toScrollView = nil;
    if (self.transitionHost != nil)
        toScrollView = self.transitionHost();
    else
        toScrollView = [self findScrollView:toView];
    UIView *toContainerView = toScrollView.superview;
    
    CGRect toContainerFrame = [toContainerView convertRect:toView.bounds fromView:toView];
    CGRect toContainerFromFrame = [toContainerView convertRect:[fromView convertRect:fromViewContentRect toView:nil] fromView:nil];
    
    UIView *toViewCopy = nil;
    TGModernGalleryComplexTransitionDescription *transitionDesc = nil;
    
    if ([toView conformsToProtocol:@protocol(TGModernGalleryTransitionView)])
    {
        if ([toView respondsToSelector:@selector(hasComplexTransition)] && [(id<TGModernGalleryTransitionView>)toView hasComplexTransition])
        {
            transitionDesc = [(id<TGModernGalleryTransitionView>)toView complexTransitionDescription];
        }
        else
        {
            UIImage *transitionImage = [(id<TGModernGalleryTransitionView>)toView transitionImage];
            if (transitionImage != nil)
            {
                toViewCopy = [[UIImageView alloc] initWithImage:transitionImage];
            }
        }
    }
    
    UIEdgeInsets toFrameInsets = UIEdgeInsetsZero;

    if (transitionDesc == nil)
    {
        [UIView animateWithDuration:0.1 animations:^{
            fromView.alpha = 0.0f;
        }];
    }
    else
    {
        if (transitionDesc.cornerRadius > FLT_EPSILON)
        {
            if ([fromView isKindOfClass:[TGModernGalleryImageItemContainerView class]])
            {
                UIView *contentView = ((TGModernGalleryImageItemContainerView *)fromView).contentView();
                CGFloat scale = [[contentView.layer valueForKeyPath:@"transform.scale.x"] floatValue];
                contentView.layer.cornerRadius = transitionDesc.cornerRadius / scale;
                contentView.clipsToBounds = true;
            }
        }
        if (transitionDesc.overlayImage != nil)
        {
            if ([fromView isKindOfClass:[TGModernGalleryImageItemContainerView class]])
            {
                UIView *contentView = ((TGModernGalleryImageItemContainerView *)fromView).contentView();
             
                UIImageView *overlayImageView = [[UIImageView alloc] initWithImage:transitionDesc.overlayImage];
                overlayImageView.alpha = 0.0f;
                overlayImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                overlayImageView.frame = contentView.bounds;
                [contentView addSubview:overlayImageView];
                
                [UIView animateWithDuration:0.1 animations:^{
                    overlayImageView.alpha = 1.0f;
                }];
            }
        }
        if (!UIEdgeInsetsEqualToEdgeInsets(transitionDesc.insets, UIEdgeInsetsZero))
        {
            toFrameInsets = transitionDesc.insets;
        }
    }
    
    CGRect toRect;
    if (toView.superview != nil) {
        toRect = [toView convertRect:CGRectInset(toView.bounds, toFrameInsets.left, toFrameInsets.top) toView:nil];
    } else {
        toRect = CGRectInset(toView.frame, toFrameInsets.left, toFrameInsets.top);
    }
    CGRect toFrame = [fromView.superview convertRect:toRect fromView:nil];
    toFrame = adjustFrameForOriginalSubframe(fromView.frame, fromViewContentRect, toFrame);
    
    if (transitionDesc == nil && toViewCopy == nil)
    {
        CGFloat toViewAlpha = toView.alpha;
        bool toViewHidden = toView.hidden;
        CGRect toViewFrame = toView.frame;
        toView.alpha = 1.0f;
        toView.hidden = false;
        toView.frame = CGRectOffset(toViewFrame, 1000.0f, 0.0f);
        toViewCopy = [toView snapshotViewAfterScreenUpdates:true];
        toView.alpha = toViewAlpha;
        toView.hidden = toViewHidden;
        toView.frame = toViewFrame;
    }
    
    toViewCopy.frame = toContainerFromFrame;
    if (toViewCopy != nil)
        [toContainerView insertSubview:toViewCopy aboveSubview:toScrollView];
    
    __weak TGModernGalleryController *weakSelf = self;
    self.view.userInteractionEnabled = false;
    [self animateView:fromView frameFrom:fromView.frame to:toFrame velocity:velocity rotationFrom:0.0f to:0.0f animatingIn:false completion:^(__unused bool finished)
    {
        __strong TGModernGalleryController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (transitionDesc != nil)
                [strongSelf complexDismiss];
            else
                [strongSelf dismiss];
        }
    }];
    
    if (toViewCopy != nil)
    {
        __weak UIView *weakToViewCopy = toViewCopy;
        [self animateView:toViewCopy frameFrom:toViewCopy.frame to:toContainerFrame velocity:velocity rotationFrom:0.0f to:0.0f animatingIn:false completion:^(__unused bool finished)
        {
            __strong UIView *strongToViewCopy = weakToViewCopy;
            [strongToViewCopy removeFromSuperview];
        }];
    }
    
    if (iosMajorVersion() >= 7 && self.shouldAnimateStatusBarStyleTransition)
    {
        [self animateStatusBarTransition:0.2];
        self->_statusBarStyle = _defaultStatusBarStyle;
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    if (self.adjustsStatusBarVisibility)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            //[_context setApplicationStatusBarAlpha:1.0f];
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_previewMode && animated)
    {
        if (_finishedTransitionIn && _model.focusItem != nil)
        {
            TGModernGalleryItemView *itemView = nil;
            if (self.finishedTransitionIn && self.model.focusItem != nil)
            {
                for (TGModernGalleryItemView *visibleItemView in self->_visibleItemViews)
                {
                    if ([visibleItemView.item isEqual:self.model.focusItem])
                    {
                        itemView = visibleItemView;
                        
                        break;
                    }
                }
            }
            
            _finishedTransitionIn(_model.focusItem, itemView);
            
            [_model _transitionCompleted];
        }
        else
            [_model _transitionCompleted];
    }
    
    if (!_previewMode) {
        if (self.adjustsStatusBarVisibility && (!_showInterface || [_view.interfaceView prefersStatusBarHidden]))
        {
            [_context setApplicationStatusBarAlpha:0.0f];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_previewMode)
        return;
    
    if (!_showInterface)
    {
        _view.interfaceView.alpha = 0.0f;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_previewMode && animated)
    {
        if (self.beginTransitionOut != nil)
        {
            id<TGModernGalleryItem> item = [self currentItem];
            self.beginTransitionOut(item, [self itemViewForItem:item]);
        }
        return;
    }

    if (self.adjustsStatusBarVisibility)
    {
        //[_context setApplicationStatusBarAlpha:1.0f];
    }
}

#pragma mark -

- (void)setCurrentItemIndex:(NSUInteger)index animated:(bool)animated
{
    [self setCurrentItemIndex:index direction:TGModernGalleryScrollAnimationDirectionDefault animated:animated];
}

- (void)setCurrentItemIndex:(NSUInteger)index direction:(TGModernGalleryScrollAnimationDirection)direction animated:(bool)animated
{
    if (index == [self currentItemIndex])
        return;
    
    if (animated)
    {
        UIView *currentItemView = [self itemViewForItem:[self currentItem]];
        
        UIView *outgoingItemView = [currentItemView snapshotViewAfterScreenUpdates:false];
        [_view insertSubview:outgoingItemView belowSubview:_view.interfaceView];
        
        if (direction == TGModernGalleryScrollAnimationDirectionDefault)
            direction = (index > [self currentItemIndex]) ? TGModernGalleryScrollAnimationDirectionRight : TGModernGalleryScrollAnimationDirectionLeft;
        
        [self setCurrentItemIndex:index synchronously:false];
        
        UIView *incomingItemView = [self itemViewForItem:[self currentItem]];
        CGPoint incomingItemStartPosition = incomingItemView.center;
        CGPoint incomingItemTargetPosition = incomingItemView.center;
        
        CGPoint outgoingItemTargetPosition = CGPointMake(0, incomingItemTargetPosition.y);
        
        CGSize referenceSize = [_context fullscreenBounds].size;
        
        switch (direction)
        {
            case TGModernGalleryScrollAnimationDirectionLeft:
                incomingItemStartPosition.x += -referenceSize.width - 2 * TGModernGalleryItemPadding;
                outgoingItemTargetPosition.x = referenceSize.width * 1.5f + 2 * TGModernGalleryItemPadding;
                break;
                
            case TGModernGalleryScrollAnimationDirectionRight:
                incomingItemStartPosition.x += referenceSize.width + 2 * TGModernGalleryItemPadding;
                outgoingItemTargetPosition.x = -(referenceSize.width / 2) - 2 * TGModernGalleryItemPadding;
                break;
                
            default:
                break;
        }
        
        incomingItemView.center = incomingItemStartPosition;
        
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^
        {
            incomingItemView.center = incomingItemTargetPosition;
            outgoingItemView.center = outgoingItemTargetPosition;
        } completion:^(__unused BOOL finished)
        {
            [outgoingItemView removeFromSuperview];
            [self _updateItemViewsCurrent];
        }];
    }
    else
    {
        [self setCurrentItemIndex:index synchronously:false];
    }
}

- (id<TGModernGalleryItem>)currentItem
{
    return _model.items.count > 0 ? [_model.items objectAtIndex:[self currentItemIndex]] : nil;
}

- (void)setCurrentItemIndex:(NSUInteger)currentItemIndex synchronously:(bool)synchronously
{
    NSUInteger previousItemIndex = [self currentItemIndex];
    
    _synchronousBoundsChange = synchronously;
    _view.scrollView.bounds = CGRectMake(_view.scrollView.bounds.size.width * currentItemIndex, 0.0f, _view.scrollView.bounds.size.width, _view.scrollView.bounds.size.height);
    _synchronousBoundsChange = false;
    
    if (ABS((NSInteger)previousItemIndex - (NSInteger)currentItemIndex) == 1 && previousItemIndex < _model.items.count)
    {
        TGModernGalleryItemView *previousItemView = [self itemViewForItem:_model.items[previousItemIndex]];
        [previousItemView reset];
    }
}

- (NSUInteger)currentItemIndex
{
    return _model.items.count == 0 ? 0 : (NSUInteger)([self currentItemFuzzyIndex]);
}

- (CGFloat)currentItemFuzzyIndex
{
    if (_model.items.count == 0)
        return 0.0f;
    
    if (_view.scrollView.bounds.size.width <= FLT_EPSILON) {
        return 0.0f;
    }
    
    return CGFloor((_view.scrollView.bounds.origin.x + _view.scrollView.bounds.size.width / 2.0f) / _view.scrollView.bounds.size.width);
}

- (NSArray *)visibleItems
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    for (TGModernGalleryItemView *itemView in _visibleItemViews)
    {
        if (itemView.item != nil)
            [items addObject:itemView.item];
    }
    
    return items;
}

- (void)reloadDataAtItem:(id<TGModernGalleryItem>)atItem synchronously:(bool)synchronously
{
    NSMutableIndexSet *removeIndices = nil;
    
    id<TGModernGalleryItem> focusItem = atItem;
    
    if (focusItem == nil)
    {
        for (TGModernGalleryItemView *itemView in _visibleItemViews)
        {
            if (itemView.index == [self currentItemIndex])
            {
                focusItem = itemView.item;
                
                break;
            }
        }
    }
    
    NSInteger itemViewIndex = -1;
    for (TGModernGalleryItemView *itemView in _visibleItemViews)
    {
        itemViewIndex++;
        
        NSInteger itemIndex = -1;
        bool itemFound = false;
        for (id<TGModernGalleryItem> item in _model.items)
        {
            itemIndex++;
            
            if ([item isEqual:itemView.item])
            {
                itemView.index = (NSUInteger)itemIndex;
                itemFound = true;
                
                break;
            }
        }
        
        if (!itemFound)
        {
            if (removeIndices == nil)
                removeIndices = [[NSMutableIndexSet alloc] init];
            [removeIndices addIndex:(NSUInteger)itemViewIndex];
        
            UIView *itemHeaderView = [itemView headerView];
            if (itemHeaderView != nil)
                [_view removeItemHeaderView:itemHeaderView];
            
            UIView *itemDefaultLeftAcessoryView = [itemView defaultFooterAccessoryLeftView];
            if (itemDefaultLeftAcessoryView != nil)
                [_view.interfaceView removeItemLeftAcessoryView:itemDefaultLeftAcessoryView];
            
            UIView *itemDefaultRightAcessoryView = [itemView defaultFooterAccessoryRightView];
            if (itemDefaultRightAcessoryView != nil)
                [_view.interfaceView removeItemRightAcessoryView:itemDefaultRightAcessoryView];
            
            UIView *itemFooterView = [itemView footerView];
            if (itemFooterView != nil)
                [_view removeItemFooterView:itemFooterView];
            [itemView removeFromSuperview];
            [self enqueueView:itemView];
        }
    }
    
    if (removeIndices != nil)
        [_visibleItemViews removeObjectsAtIndexes:removeIndices];
    
    _reloadingItems = true;
    
    NSUInteger index = (focusItem == nil || _model.items.count == 0) ? NSNotFound : [_model.items indexOfObject:focusItem];
    if (index != NSNotFound && index != _lastReportedFocusedIndex)
    {
        _lastReportedFocusedIndex = NSNotFound;
        [self setCurrentItemIndex:index == NSNotFound ? 0 : index synchronously:synchronously];
    }
    else
    {
        _lastReportedFocusedIndex = NSNotFound;
        
        CGFloat itemWidth = _view.scrollView.bounds.size.width;
        CGSize contentSize = CGSizeMake(_model.items.count * itemWidth, _view.scrollView.bounds.size.height);
        if (!CGSizeEqualToSize(_view.scrollView.contentSize, contentSize))
        {
            _view.scrollView.contentSize = contentSize;
            if (_view.scrollView.bounds.origin.x > contentSize.width - itemWidth)
            {
                _view.scrollView.bounds = CGRectMake(contentSize.width - itemWidth, 0.0f, itemWidth, _view.scrollView.bounds.size.height);
            }
            else
                [self scrollViewBoundsChanged:_view.scrollView.bounds];
        }
        else
            [self scrollViewBoundsChanged:_view.scrollView.bounds];
    }
    
    _reloadingItems = false;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)__unused scrollView
{
}

- (void)scrollViewBoundsChanged:(CGRect)bounds
{
    [self scrollViewBoundsChanged:bounds synchronously:_synchronousBoundsChange];
}

- (void)scrollViewBoundsChanged:(CGRect)bounds synchronously:(bool)synchronously
{
    if (_view == nil)
        return;
    
    CGFloat itemWidth = bounds.size.width;
    
    NSUInteger leftmostVisibleItemIndex = 0;
    if (bounds.origin.x > 0.0f)
        leftmostVisibleItemIndex = (NSUInteger)floor((bounds.origin.x + 1.0f) / itemWidth);
    NSUInteger leftmostTrulyVisibleItemIndex = leftmostVisibleItemIndex;
    
    NSUInteger rightmostVisibleItemIndex = _model.items.count - 1;
    if (bounds.origin.x + bounds.size.width < _model.items.count * itemWidth)
        rightmostVisibleItemIndex = (NSUInteger)CGFloor((bounds.origin.x + bounds.size.width - 1.0f) / itemWidth);
    NSUInteger rightmostTrulyVisibleItemIndex = rightmostVisibleItemIndex;
    
    if (_preloadVisibleItemViews)
    {
        if (leftmostVisibleItemIndex >= 1)
            leftmostVisibleItemIndex = leftmostVisibleItemIndex - 1;
        if (rightmostVisibleItemIndex < _model.items.count - 1)
            rightmostVisibleItemIndex = rightmostVisibleItemIndex + 1;
    }
    
    if (leftmostVisibleItemIndex <= rightmostVisibleItemIndex && _model.items.count != 0)
    {
        CGSize contentSize = CGSizeMake(_model.items.count * itemWidth, bounds.size.height);
        if (!CGSizeEqualToSize(_view.scrollView.contentSize, contentSize))
            _view.scrollView.contentSize = contentSize;
        
        NSUInteger loadedVisibleViewIndices[16];
        NSUInteger loadedVisibleViewIndexCount = 0;
        
        NSUInteger visibleViewCount = _visibleItemViews.count;
        for (NSUInteger i = 0; i < visibleViewCount; i++)
        {
            TGModernGalleryItemView *itemView = _visibleItemViews[i];
            if (itemView.index < leftmostVisibleItemIndex || itemView.index > rightmostVisibleItemIndex)
            {
                UIView *itemHeaderView = [itemView headerView];
                if (itemHeaderView != nil)
                    [_view removeItemHeaderView:itemHeaderView];
                
                UIView *itemDefaultLeftAcessoryView = [itemView defaultFooterAccessoryLeftView];
                if (itemDefaultLeftAcessoryView != nil)
                    [_view.interfaceView removeItemLeftAcessoryView:itemDefaultLeftAcessoryView];
                
                UIView *itemDefaultRightAcessoryView = [itemView defaultFooterAccessoryRightView];
                if (itemDefaultRightAcessoryView != nil)
                    [_view.interfaceView removeItemRightAcessoryView:itemDefaultRightAcessoryView];
                
                UIView *itemFooterView = [itemView footerView];
                if (itemFooterView != nil)
                    [_view removeItemFooterView:itemFooterView];
                
                [self enqueueView:itemView];
                [itemView removeFromSuperview];
                [_visibleItemViews removeObjectAtIndex:i];
                i--;
                visibleViewCount--;
            }
            else
            {
                if (loadedVisibleViewIndexCount < 16)
                    loadedVisibleViewIndices[loadedVisibleViewIndexCount++] = itemView.index;
                
                [itemView setIsVisible:itemView.index >= leftmostTrulyVisibleItemIndex && itemView.index <= rightmostTrulyVisibleItemIndex];
                [itemView setIsCurrent:itemView.index == [self currentItemIndex]];
                
                CGRect itemFrame = CGRectMake(itemWidth * itemView.index + TGModernGalleryItemPadding, 0.0f, itemWidth - TGModernGalleryItemPadding * 2.0f, bounds.size.height);
                if (!CGRectEqualToRect(itemView.frame, itemFrame))
                    itemView.frame = itemFrame;
            }
        }
        
        for (NSUInteger i = leftmostVisibleItemIndex; i <= rightmostVisibleItemIndex; i++)
        {
            bool itemHasVisibleView = false;
            for (NSUInteger j = 0; j < loadedVisibleViewIndexCount; j++)
            {
                if (loadedVisibleViewIndices[j] == i)
                {
                    itemHasVisibleView = true;
                    break;
                }
            }
            
            if (!itemHasVisibleView)
            {
                id<TGModernGalleryItem> item = _model.items[i];
                TGModernGalleryItemView *itemView = [self dequeueViewForItem:item];
                if (itemView != nil)
                {
                    itemView.frame = CGRectMake(itemWidth * i + TGModernGalleryItemPadding, 0.0f, itemWidth - TGModernGalleryItemPadding * 2.0f, bounds.size.height);
                    [itemView setItem:item synchronously:synchronously];
                    itemView.index = i;
                    [itemView setIsVisible:itemView.index >= leftmostTrulyVisibleItemIndex && itemView.index <= rightmostTrulyVisibleItemIndex];
                    [itemView setIsCurrent:itemView.index == [self currentItemIndex]];
                    [_view.scrollView addSubview:itemView];
                    
                    UIView *headerView = [itemView headerView];
                    if (headerView != nil)
                        [_view addItemHeaderView:headerView];
                    
                    UIView *itemDefaultLeftAcessoryView = [itemView defaultFooterAccessoryLeftView];
                    if (itemDefaultLeftAcessoryView != nil)
                        [_view.interfaceView addItemLeftAcessoryView:itemDefaultLeftAcessoryView];
                    
                    UIView *itemDefaultRightAcessoryView = [itemView defaultFooterAccessoryRightView];
                    if (itemDefaultRightAcessoryView != nil)
                        [_view.interfaceView addItemRightAcessoryView:itemDefaultRightAcessoryView];
                    
                    UIView *footerView = [itemView footerView];
                    if (footerView != nil)
                        [_view addItemFooterView:footerView];
                    [_visibleItemViews addObject:itemView];
                }
            }
        }
    }
    else if (_visibleItemViews.count != 0)
    {
        _view.scrollView.contentSize = CGSizeZero;
        
        for (TGModernGalleryItemView *itemView in _visibleItemViews)
        {
            UIView *itemHeaderView = [itemView headerView];
            if (itemHeaderView != nil)
                [_view removeItemHeaderView:itemHeaderView];
            
            UIView *itemDefaultLeftAcessoryView = [itemView defaultFooterAccessoryLeftView];
            if (itemDefaultLeftAcessoryView != nil)
                [_view.interfaceView addItemLeftAcessoryView:itemDefaultLeftAcessoryView];
            
            UIView *itemDefaultRightAcessoryView = [itemView defaultFooterAccessoryRightView];
            if (itemDefaultRightAcessoryView != nil)
                [_view.interfaceView addItemRightAcessoryView:itemDefaultRightAcessoryView];
            
            UIView *itemFooterView = [itemView footerView];
            if (itemFooterView != nil)
                [_view removeItemFooterView:itemFooterView];
            
            [itemView removeFromSuperview];
            [self enqueueView:itemView];
        }
        [_visibleItemViews removeAllObjects];
    }
    
    CGFloat fuzzyIndex = MAX(0, MIN(_model.items.count - 1, (_view.scrollView.bounds.origin.x) / _view.scrollView.bounds.size.width));
    CGFloat titleAlpha = 1.0f;
    
    NSUInteger currentItemIndex = [self currentItemIndex];
    TGModernGalleryItemView *currentItemView = nil;
    
    for (TGModernGalleryItemView *itemView in _visibleItemViews)
    {
        CGFloat alpha = MAX(0.0f, MIN(1.0f, 1.0f - ABS(itemView.index - fuzzyIndex)));
        
        UIView *itemHeaderView = [itemView headerView];
        if (itemHeaderView != nil)
        {
            itemHeaderView.alpha = alpha;
            itemHeaderView.hidden = (alpha < FLT_EPSILON);
            if (itemHeaderView.tag != 0xbeef) {
                titleAlpha -= alpha;
            }
        }
        
        CGFloat footerAlpha = itemView.index == currentItemIndex ? 1.0f : 0.0f;
        
        if (itemView.index == currentItemIndex)
            currentItemView = itemView;
        
        UIView *itemDefaultLeftAcessoryView = [itemView defaultFooterAccessoryLeftView];
        if (itemDefaultLeftAcessoryView != nil)
            itemDefaultLeftAcessoryView.alpha = footerAlpha;
        
        UIView *itemDefaultRightAcessoryView = [itemView defaultFooterAccessoryRightView];
        if (itemDefaultRightAcessoryView != nil)
            itemDefaultRightAcessoryView.alpha = footerAlpha;
        
        UIView *itemFooterView = [itemView footerView];
        if (itemFooterView != nil)
            itemFooterView.alpha = footerAlpha;
    }
    
    _defaultHeaderView.alpha = MAX(0.0f, MIN(1.0f, titleAlpha));
    
    if (_lastReportedFocusedIndex != [self currentItemIndex])
    {
        if (!_reloadingItems && _lastReportedFocusedIndex != NSNotFound)
            [_view updateInterfaceVisibility];
    
        NSUInteger previousFocusedIndex = _lastReportedFocusedIndex;
        _lastReportedFocusedIndex = [self currentItemIndex];
        
        if (_lastReportedFocusedIndex < _model.items.count)
        {
            if (_itemFocused)
                _itemFocused(_model.items[_lastReportedFocusedIndex]);
            
            [_view.interfaceView itemFocused:_model.items[_lastReportedFocusedIndex] itemView:currentItemView];
            
            if (previousFocusedIndex < _model.items.count)
                [[self itemViewForItem:_model.items[previousFocusedIndex]] setFocused:false];
            [[self itemViewForItem:_model.items[_lastReportedFocusedIndex]] setFocused:true];
            
            [_defaultHeaderView setItem:_model.items[_lastReportedFocusedIndex]];
            [_defaultFooterView setItem:_model.items[_lastReportedFocusedIndex]];
        }
    }
    
    CGFloat transitionProgress = fuzzyIndex - [self currentItemIndex];
    [_model _interItemTransitionProgressChanged:transitionProgress];
}

- (void)_updateItemViewsCurrent
{
    NSUInteger visibleViewCount = _visibleItemViews.count;
    for (NSUInteger i = 0; i < visibleViewCount; i++)
    {
        TGModernGalleryItemView *itemView = _visibleItemViews[i];
        //[itemView setIsVisible:itemView.index >= leftmostTrulyVisibleItemIndex && itemView.index <= rightmostTrulyVisibleItemIndex];
        [itemView setIsCurrent:itemView.index == [self currentItemIndex]];
    }
}

- (bool)scrollViewShouldScrollWithTouchAtPoint:(CGPoint)point
{
    NSUInteger currentItemIndex = [self currentItemIndex];
    
    for (TGModernGalleryItemView *itemView in _visibleItemViews)
    {
        if (itemView.index == currentItemIndex)
        {
            CGPoint localPoint = [itemView convertPoint:point fromView:_view.scrollView];
            return [itemView allowsScrollingAtPoint:localPoint];
        }
    }
    
    return true;
}

- (void)animateStatusBarTransition:(NSTimeInterval)duration
{
    if (iosMajorVersion() >= 7 && self.shouldAnimateStatusBarStyleTransition)
    {
        [_context animateApplicationStatusBarStyleTransitionWithDuration:duration];
    }
}

- (void)processKeyCommand:(UIKeyCommand *)keyCommand
{
    if ([keyCommand.input isEqualToString:UIKeyInputLeftArrow])
    {
        NSInteger newIndex = [self currentItemIndex] - 1;
        if (newIndex >= 0)
            [self setCurrentItemIndex:newIndex animated:true];
    }
    else if ([keyCommand.input isEqualToString:UIKeyInputRightArrow])
    {
        NSUInteger newIndex = [self currentItemIndex] + 1;
        if (newIndex < _model.items.count)
            [self setCurrentItemIndex:newIndex animated:true];
    }
    else if ([keyCommand.input isEqualToString:UIKeyInputEscape])
    {
        _view.transitionOut(0.0f);
    }
}

- (NSArray *)availableKeyCommands
{
    return @
    [
        [TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputLeftArrow modifierFlags:0],
        [TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputRightArrow modifierFlags:0],
        [TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputEscape modifierFlags:0],
        [TGKeyCommand keyCommandWithTitle:nil input:@"\t" modifierFlags:0]
    ];
}

- (bool)isExclusive
{
    return true;
}

- (void)setPreviewMode:(bool)previewMode
{
    bool previousMode = _previewMode;
    
    _previewMode = previewMode;
    [_view setPreviewMode:_previewMode];
    
    if (previousMode)
    {
        _view.userInteractionEnabled = true;
        [_view disableInstantDismiss];
        
        self.showInterface = true;
        if (_itemFocused != nil)
            _itemFocused(self.currentItem);
    }
}

@end
