#import "TGModernGalleryDefaultInterfaceView.h"

#import "LegacyComponentsInternal.h"
#import "TGViewController.h"

#import "TGModernGalleryDefaultFooterView.h"

#import "TGModernBackToolbarButton.h"

#import <CoreMotion/CoreMotion.h>

@interface TGModernGalleryDefaultInterfaceView ()
{
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

@end

@implementation TGModernGalleryDefaultInterfaceView

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
        
        _toolbarView = [[UIView alloc] initWithFrame:[self toolbarFrameForSize:frame.size transitionProgress:_transitionProgress]];
        _toolbarView.backgroundColor = UIColorRGBA(0x000000, 0.65f);
        [self addSubview:_toolbarView];
        
        _closeButton = [[TGModernBackToolbarButton alloc] init];
        [_closeButton sizeToFit];
        [_closeButton addTarget:self action:@selector(closeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _closeButton.frame = [self closeButtonFrameForSize:frame.size];
        [_navigationBarView addSubview:_closeButton];
        
        if (iosMajorVersion() >= 11)
            self.accessibilityIgnoresInvertColors = true;
    }
    return self;
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
    return CGRectMake(0.0f, -transitionProgress * (20.0f + 44.0f), size.width, 20.0f + 44.0f);
}

- (CGRect)toolbarFrameForSize:(CGSize)size transitionProgress:(CGFloat)transitionProgress
{
    return CGRectMake(0.0f, size.height - 44.0f + transitionProgress * 44.0f, size.width, 44.0f);
}

- (CGRect)itemHeaderViewFrameForSize:(CGSize)size
{
    CGFloat closeButtonMaxX = CGRectGetMaxX([self closeButtonFrameForSize:size]);
    CGFloat spacing = 10.0f;
    return CGRectMake(closeButtonMaxX + spacing, 20.0f, size.width - (closeButtonMaxX + spacing) * 2.0f, 44.0f);
}

- (CGRect)itemFooterViewFrameForSize:(CGSize)size
{
    CGFloat padding = 44.0f;
    
    return CGRectMake(padding, 0.0f, size.width - padding * 2.0f, 44.0f);
}

- (CGRect)itemLeftAcessoryViewFrameForSize:(CGSize)__unused size
{
    return CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
}

- (CGRect)itemRightAcessoryViewFrameForSize:(CGSize)size
{
    return CGRectMake(size.width - 44.0f, 0.0f, 44.0f, 44.0f);
}

- (CGRect)closeButtonFrameForSize:(CGSize)__unused size
{
    return (CGRect){{10.0f, 17.0f + 12.0f}, _closeButton.frame.size};
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
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

- (void)animateTransitionInWithDuration:(NSTimeInterval)dutation
{
    [UIView animateWithDuration:dutation animations:^
    {
        //_navigationBarView.frame = CGRectOffset(_navigationBarView.frame, 0.0f, -_navigationBarView.frame.size.height);
        //_toolbarView.frame = CGRectOffset(_toolbarView.frame, 0.0f, _toolbarView.frame.size.height);
    }];
}

- (void)animateTransitionOutWithDuration:(NSTimeInterval)dutation
{
    [UIView animateWithDuration:dutation animations:^
    {
        //_navigationBarView.frame = CGRectOffset(_navigationBarView.frame, 0.0f, -_navigationBarView.frame.size.height);
        //_toolbarView.frame = CGRectOffset(_toolbarView.frame, 0.0f, _toolbarView.frame.size.height);
        
        _statusBarCoveringView.frame = (CGRect){{0.0f, -_statusBarCoveringView.frame.size.height}, _statusBarCoveringView.frame.size};
        _statusBarCoveringView.alpha = 0.0f;
    }];
}

- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress
{
    _transitionProgress = transitionOutProgress;
    
    _navigationBarView.frame = [self navigationBarFrameForSize:self.frame.size transitionProgress:_transitionProgress];
    _toolbarView.frame = [self toolbarFrameForSize:self.frame.size transitionProgress:_transitionProgress];
    
    if (CGRectGetMaxY(_navigationBarView.frame) < 20.0f)
    {
        CGFloat overlap = MAX(0.0f, MIN(20.0f, 20.0f - CGRectGetMaxY(_navigationBarView.frame)));
        _statusBarCoveringView.frame = CGRectMake(0.0f, 20.0f - overlap, self.frame.size.width, overlap);
    }
    else
    {
        _statusBarCoveringView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, 0.0f);
    }
    
    for (UIView *view in _itemFooterViews)
    {
        if ([view conformsToProtocol:@protocol(TGModernGalleryDefaultFooterView)])
        {
            id<TGModernGalleryDefaultFooterView> footerView = (id<TGModernGalleryDefaultFooterView>)view;
            if ([footerView respondsToSelector:@selector(setTransitionOutProgress:)])
                [footerView setTransitionOutProgress:transitionOutProgress];
        }
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
    return false;
}

- (bool)allowsHide
{
    return true;
}

- (void)itemFocused:(id<TGModernGalleryItem>)__unused item itemView:(TGModernGalleryItemView *)__unused itemView
{
}

- (void)setScrollViewOffsetRequested:(void (^)(CGFloat))__unused scrollViewOffsetRequested
{
}

@end
