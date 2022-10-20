#import "TGModernGalleryDefaultInterfaceView.h"

#import "LegacyComponentsInternal.h"
#import "LegacyComponentsGlobals.h"
#import "TGImageUtils.h"
#import "TGViewController.h"

#import "TGModernGalleryItemView.h"
#import "TGModernGalleryDefaultFooterView.h"

#import "TGModernBackToolbarButton.h"

#import <CoreMotion/CoreMotion.h>

@interface TGModernGalleryToolbarView : UIView

@end

@interface TGModernGalleryDefaultInterfaceView ()
{
    __weak TGModernGalleryItemView *_currentItemView;
    
    TGModernBackToolbarButton *_closeButton;
    
    NSMutableArray *_itemHeaderViews;
    NSMutableArray *_itemFooterViews;
    NSMutableArray *_itemLeftAcessoryViews;
    NSMutableArray *_itemRightAcessoryViews;
    
    UIView *_statusBarCoveringView;
    
    CGFloat _transitionProgress;
}

@property (nonatomic, strong, readonly) UIView *toolbarView;
@property (nonatomic, strong, readonly) UIView *navigationBarView;
@property (nonatomic, copy) void (^closePressed)();
@property (nonatomic, copy) UIViewController *(^controller)();

@end

@implementation TGModernGalleryDefaultInterfaceView

@synthesize safeAreaInset = _safeAreaInset;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        if (iosMajorVersion() >= 7 && [TGViewController isWidescreen] && [CMMotionActivityManager isActivityAvailable])
        {
            UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicator.alpha = 0.02f;
            [self addSubview:activityIndicator];
            [activityIndicator startAnimating];
        }
        
        _itemHeaderViews = [[NSMutableArray alloc] init];
        _itemFooterViews = [[NSMutableArray alloc] init];
        _itemLeftAcessoryViews = [[NSMutableArray alloc] init];
        _itemRightAcessoryViews = [[NSMutableArray alloc] init];
        
        _navigationBarView = [[UIView alloc] initWithFrame:[self navigationBarFrameForSize:frame.size transitionProgress:_transitionProgress]];
        _navigationBarView.backgroundColor = UIColorRGBA(0x000000, 0.65f);
        [self addSubview:_navigationBarView];
        
        _statusBarCoveringView = [[UIView alloc] init];
        _statusBarCoveringView.backgroundColor = UIColorRGBA(0x000000, 0.35f);
        [self addSubview:_statusBarCoveringView];
        
        _toolbarView = [[TGModernGalleryToolbarView alloc] initWithFrame:[self toolbarFrameForSize:frame.size transitionProgress:_transitionProgress]];
        _toolbarView.backgroundColor = UIColorRGBA(0x000000, 0.65f);
        [self addSubview:_toolbarView];
        
        _closeButton = [[TGModernBackToolbarButton alloc] init];
        [_closeButton sizeToFit];
        [_closeButton addTarget:self action:@selector(closeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _closeButton.frame = [self closeButtonFrameForSize:frame.size];
        [_navigationBarView addSubview:_closeButton];
        
        if (@available(iOS 11.0, *)) {
            self.accessibilityIgnoresInvertColors = true;
        }
    }
    return self;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    
    [_currentItemView setSafeAreaInset:_safeAreaInset];
    for (UIView *view in _itemFooterViews)
    {
        if ([view respondsToSelector:@selector(setSafeAreaInset:)])
            [(id<TGModernGalleryDefaultFooterView>)view setSafeAreaInset:safeAreaInset];
    }
    
    [self layout];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isDescendantOfView:_navigationBarView] || [view isDescendantOfView:_toolbarView])
        return view;
    
    return nil;
}

- (CGRect)navigationBarFrameForSize:(CGSize)size transitionProgress:(CGFloat)transitionProgress
{
    CGFloat inset = _safeAreaInset.top > FLT_EPSILON ? _safeAreaInset.top : ([self prefersStatusBarHidden] ? 0.0f : 20.0f);
    return CGRectMake(0.0f, -transitionProgress * (inset + 44.0f), size.width, 44.0f + inset);
}

- (CGRect)toolbarFrameForSize:(CGSize)size transitionProgress:(CGFloat)transitionProgress
{
    return CGRectMake(0.0f, size.height - 44.0f + transitionProgress * (44.0f + _safeAreaInset.bottom) - _safeAreaInset.bottom, size.width, 44.0f + _safeAreaInset.bottom);
}

- (CGRect)itemHeaderViewFrameForSize:(CGSize)size
{
    CGFloat closeButtonMaxX = CGRectGetMaxX([self closeButtonFrameForSize:size]);
    CGFloat spacing = 10.0f;
    CGFloat inset = _safeAreaInset.top > FLT_EPSILON ? _safeAreaInset.top : ([self prefersStatusBarHidden] ? 0.0f : 20.0f);
    return CGRectMake(closeButtonMaxX + spacing, inset, size.width - (closeButtonMaxX + spacing) * 2.0f, 44.0f);
}

- (CGRect)itemFooterViewFrameForSize:(CGSize)size
{
    CGFloat padding = 44.0f;
    
    return CGRectMake(padding, 0.0f, size.width - padding * 2.0f, 44.0f);
}

- (CGRect)itemLeftAcessoryViewFrameForSize:(CGSize)__unused size
{
    return CGRectMake(_safeAreaInset.left, 0.0f, 44.0f, 44.0f);
}

- (CGRect)itemRightAcessoryViewFrameForSize:(CGSize)size
{
    return CGRectMake(size.width - 44.0f - _safeAreaInset.right, 0.0f, 44.0f, 44.0f);
}

- (CGRect)closeButtonFrameForSize:(CGSize)__unused size
{
    CGFloat leftInset = _safeAreaInset.left;
    CGFloat topInset = _safeAreaInset.top > FLT_EPSILON ? _safeAreaInset.top : ([self prefersStatusBarHidden] ? 0.0f : 20.0f);
    return (CGRect){{leftInset + 10.0f, topInset + 9.0f}, _closeButton.frame.size};
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self layout];
}

- (void)layout
{
    CGRect frame = self.frame;
    _navigationBarView.frame = [self navigationBarFrameForSize:frame.size transitionProgress:_transitionProgress];
    _toolbarView.frame = [self toolbarFrameForSize:frame.size transitionProgress:_transitionProgress];
    
    CGRect itemHeaderViewFrame = [self itemHeaderViewFrameForSize:frame.size];
    for (UIView *itemHeaderView in _itemHeaderViews)
    {
        itemHeaderView.frame = itemHeaderViewFrame;
    }
    
    CGRect itemFooterViewFrame = [self itemFooterViewFrameForSize:frame.size];
    for (UIView *itemFooterView in _itemFooterViews)
    {
        itemFooterView.frame = itemFooterViewFrame;
    }
    
    CGRect itemLeftAcessoryViewFrame = [self itemLeftAcessoryViewFrameForSize:frame.size];
    for (UIView *itemLeftAcessoryView in _itemLeftAcessoryViews)
    {
        itemLeftAcessoryView.frame = itemLeftAcessoryViewFrame;
    }
    
    CGRect itemRightAcessoryViewFrame = [self itemRightAcessoryViewFrameForSize:frame.size];
    for (UIView *itemRightAcessoryView in _itemRightAcessoryViews)
    {
        itemRightAcessoryView.frame = itemRightAcessoryViewFrame;
    }
    
    _closeButton.frame = [self closeButtonFrameForSize:frame.size];
}

- (void)addItemHeaderView:(UIView *)itemHeaderView
{
    if (itemHeaderView == nil)
        return;
    
    [_itemHeaderViews addObject:itemHeaderView];
    [_navigationBarView addSubview:itemHeaderView];
    itemHeaderView.frame = [self itemHeaderViewFrameForSize:self.frame.size];
}

- (void)removeItemHeaderView:(UIView *)itemHeaderView
{
    if (itemHeaderView == nil)
        return;
    
    [itemHeaderView removeFromSuperview];
    [_itemHeaderViews removeObject:itemHeaderView];
}

- (void)addItemFooterView:(UIView *)itemFooterView
{
    if (itemFooterView == nil)
        return;
    
    [_itemFooterViews addObject:itemFooterView];
    [_toolbarView addSubview:itemFooterView];
    itemFooterView.frame = [self itemFooterViewFrameForSize:self.frame.size];
}

- (void)removeItemFooterView:(UIView *)itemFooterView
{
    if (itemFooterView == nil)
        return;
    
    [itemFooterView removeFromSuperview];
    [_itemFooterViews removeObject:itemFooterView];
}

- (void)addItemLeftAcessoryView:(UIView *)itemLeftAcessoryView
{
    if (itemLeftAcessoryView == nil)
        return;
    
    [_itemLeftAcessoryViews addObject:itemLeftAcessoryView];
    [_toolbarView addSubview:itemLeftAcessoryView];
    itemLeftAcessoryView.frame = [self itemLeftAcessoryViewFrameForSize:self.frame.size];
}

- (void)removeItemLeftAcessoryView:(UIView *)itemLeftAcessoryView
{
    if (itemLeftAcessoryView == nil)
        return;
    
    [itemLeftAcessoryView removeFromSuperview];
    [_itemLeftAcessoryViews removeObject:itemLeftAcessoryView];
}

- (void)addItemRightAcessoryView:(UIView *)itemRightAcessoryView
{
    if (itemRightAcessoryView == nil)
        return;
    
    [_itemRightAcessoryViews addObject:itemRightAcessoryView];
    [_toolbarView addSubview:itemRightAcessoryView];
    itemRightAcessoryView.frame = [self itemRightAcessoryViewFrameForSize:self.frame.size];
}

- (void)removeItemRightAcessoryView:(UIView *)itemRightAcessoryView
{
    if (itemRightAcessoryView == nil)
        return;
    
    [itemRightAcessoryView removeFromSuperview];
    [_itemRightAcessoryViews removeObject:itemRightAcessoryView];
}

- (void)animateTransitionInWithDuration:(NSTimeInterval)__unused duration
{
}

- (void)animateTransitionOutWithDuration:(NSTimeInterval)__unused duration
{
}

- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress manual:(bool)manual
{
    _transitionProgress = transitionOutProgress;
    
    if (transitionOutProgress > FLT_EPSILON)
        [self setAllInterfaceHidden:true delay:0.0 animated:true];
    else if (!manual)
        [self setAllInterfaceHidden:false delay:0.0 animated:true];
    
    for (UIView *view in _itemFooterViews)
    {
        if ([view conformsToProtocol:@protocol(TGModernGalleryDefaultFooterView)])
        {
            id<TGModernGalleryDefaultFooterView> footerView = (id<TGModernGalleryDefaultFooterView>)view;
            if ([footerView respondsToSelector:@selector(setTransitionOutProgress:manual:)])
                [footerView setTransitionOutProgress:transitionOutProgress manual:manual];
        }
    }
}

- (void)setAllInterfaceHidden:(bool)hidden delay:(NSTimeInterval)__unused delay animated:(bool)animated
{
    CGFloat alpha = (hidden ? 0.0f : 1.0f);
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _navigationBarView.alpha = alpha;
            _toolbarView.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _navigationBarView.userInteractionEnabled = !hidden;
                _toolbarView.userInteractionEnabled = !hidden;
            }
        }];
    }
    else
    {
        _navigationBarView.alpha = alpha;
        _navigationBarView.userInteractionEnabled = !hidden;
        
        _toolbarView.alpha = alpha;
        _toolbarView.userInteractionEnabled = !hidden;
    }
}

- (void)closeButtonPressed
{
    if (_closePressed)
        _closePressed();
}

- (bool)allowsDismissalWithSwipeGesture
{
    return true;
}

- (bool)prefersStatusBarHidden
{
    return (!TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]));
}

- (bool)allowsHide
{
    return true;
}

- (void)itemFocused:(id<TGModernGalleryItem>)__unused item itemView:(TGModernGalleryItemView *)__unused itemView
{
    _currentItemView = itemView;
    [_currentItemView setSafeAreaInset:_safeAreaInset];
}

- (void)setScrollViewOffsetRequested:(void (^)(CGFloat))__unused scrollViewOffsetRequested
{
}

@end


@implementation TGModernGalleryToolbarView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool pointInside = [super pointInside:point withEvent:event];
    if (!pointInside)
    {
        for (UIView *view in self.subviews)
        {
            if ([view pointInside:[self convertPoint:point toView:view] withEvent:event])
            {
                pointInside = true;
                break;
            }
        }
    }
    return pointInside;
}

@end
