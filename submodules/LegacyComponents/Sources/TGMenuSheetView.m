#import "TGMenuSheetView.h"
#import "TGMenuSheetItemView.h"
#import "TGMenuSheetController.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGColor.h"

NSString *const TGMenuDividerTop = @"top";
NSString *const TGMenuDividerBottom = @"bottom";

const bool TGMenuSheetUseEffectView = false;

const CGFloat TGMenuSheetCornerRadius = 14.5f;
const UIEdgeInsets TGMenuSheetPhoneEdgeInsets = { 10.0f, 10.0f, 10.0f, 10.0f };
const CGFloat TGMenuSheetInterSectionSpacing = 8.0f;

@implementation TGMenuSheetScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.scrollsToTop = false;
        self.showsHorizontalScrollIndicator = false;
        self.showsVerticalScrollIndicator = false;
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)__unused view
{
    return true;
}

@end

@interface TGMenuSheetBackgroundView : UIView
{
    UIVisualEffectView *_effectView;
    UIImageView *_imageView;
}
@end

@implementation TGMenuSheetBackgroundView

- (instancetype)initWithFrame:(CGRect)frame sizeClass:(UIUserInterfaceSizeClass)sizeClass dark:(bool)dark
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        if (dark)
        {
            if (iosMajorVersion() >= 8)
            {
                self.layer.cornerRadius = TGMenuSheetCornerRadius;
                
                _effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
                _effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                _effectView.frame = self.bounds;
                [self addSubview:_effectView];
                
                if (@available(iOS 11.0, *)) {
                    _effectView.accessibilityIgnoresInvertColors = true;
                }
            }
            else
            {
                self.backgroundColor = UIColorRGBA(0x181818, 0.9f);
            }
        }
        else
        {
            if (TGMenuSheetUseEffectView)
            {
                self.layer.cornerRadius = TGMenuSheetCornerRadius;
                
                _effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
                _effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                _effectView.frame = self.bounds;
                [self addSubview:_effectView];
            }
            else
            {
                self.backgroundColor = [UIColor whiteColor];
            }
        }
        
        [self updateTraitsWithSizeClass:sizeClass];
    }
    return self;
}

- (void)setMaskEnabled:(bool)enabled
{
    if (_effectView != nil)
        return;
    
    self.layer.cornerRadius = enabled ? TGMenuSheetCornerRadius : 0.0f;
}

- (void)updateTraitsWithSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    bool hidden = (sizeClass == UIUserInterfaceSizeClassRegular);
    _effectView.hidden = hidden;
    _imageView.hidden = hidden;
    
    [self setMaskEnabled:!hidden];
}

@end

@interface TGMenuSheetView () <UIScrollViewDelegate>
{
    TGMenuSheetBackgroundView *_headerBackgroundView;
    TGMenuSheetBackgroundView *_mainBackgroundView;
    TGMenuSheetBackgroundView *_footerBackgroundView;
    
    TGMenuSheetScrollView *_scrollView;
    
    NSMutableArray *_itemViews;
    NSMutableDictionary *_dividerViews;
    
    UIUserInterfaceSizeClass _sizeClass;
    bool _dark;
    bool _borderless;
    
    id _panHandlingItemView;
    bool _expectsPreciseContentTouch;
    
    id<LegacyComponentsContext> _context;
    
    TGMenuSheetPallete *_pallete;
}
@end

@implementation TGMenuSheetView

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context pallete:(TGMenuSheetPallete *)pallete itemViews:(NSArray *)itemViews sizeClass:(UIUserInterfaceSizeClass)sizeClass dark:(bool)dark borderless:(bool)borderless
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _context = context;
        _borderless = borderless;
        _dark = dark;
        _pallete = pallete;
        
        _itemViews = [[NSMutableArray alloc] init];
        _dividerViews = [[NSMutableDictionary alloc] init];
        
        _sizeClass = sizeClass;
        
        self.backgroundColor = [UIColor clearColor];
        [self addItemViews:itemViews];
    }
    return self;
}

- (void)didChangeAbsoluteFrame
{
    for (TGMenuSheetItemView *itemView in _itemViews)
    {
        [itemView didChangeAbsoluteFrame];
    }
}

#pragma mark -

- (void)setHandleInternalPan:(void (^)(UIPanGestureRecognizer *))handleInternalPan
{
    _handleInternalPan = [handleInternalPan copy];
    for (TGMenuSheetItemView *itemView in self.itemViews)
    {
        itemView.handleInternalPan = handleInternalPan;
    }
}

- (void)addItemsView:(TGMenuSheetItemView *)itemView
{
    [self addItemView:itemView hasHeader:self.hasHeader hasFooter:self.hasFooter];
}

- (void)addItemView:(TGMenuSheetItemView *)itemView hasHeader:(bool)hasHeader hasFooter:(bool)hasFooter
{
    TGMenuSheetItemView *previousItemView = nil;
    
    itemView.sizeClass = _sizeClass;
    itemView.tag = _itemViews.count;
    itemView.handleInternalPan = [self.handleInternalPan copy];
    if (_dark)
        [itemView setDark];
    
    switch (itemView.type)
    {
        case TGMenuSheetItemTypeDefault:
        {
            if (hasFooter)
                [_itemViews insertObject:itemView atIndex:_itemViews.count - 1];
            else
                [_itemViews addObject:itemView];
            
            if (_mainBackgroundView == nil)
            {
                _mainBackgroundView = [[TGMenuSheetBackgroundView alloc] initWithFrame:CGRectZero sizeClass:_sizeClass dark:_dark];
                [self insertSubview:_mainBackgroundView atIndex:0];
                
                if (_pallete != nil)
                    _mainBackgroundView.backgroundColor = _pallete.backgroundColor;
                
                _scrollView = [[TGMenuSheetScrollView alloc] initWithFrame:CGRectZero];
                if (@available(iOS 11.0, *)) {
                    _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
                }
                _scrollView.delegate = self;
                [_mainBackgroundView addSubview:_scrollView];
            }
            
            [_scrollView addSubview:itemView];
            
            UIView *divider = [self createDividerForItemView:itemView previousItemView:previousItemView];
            if (divider != nil)
                [_scrollView addSubview:divider];
            
            if (itemView.requiresClearBackground)
            {
                _mainBackgroundView.backgroundColor = [UIColor clearColor];
                _expectsPreciseContentTouch = true;
            }
        }
            break;
        
        case TGMenuSheetItemTypeHeader:
        {
            if (hasHeader)
                return;
            
            [_itemViews insertObject:itemView atIndex:0];
            
            if (_headerBackgroundView == nil)
            {
                _headerBackgroundView = [[TGMenuSheetBackgroundView alloc] initWithFrame:CGRectZero sizeClass:_sizeClass dark:_dark];
                [self insertSubview:_headerBackgroundView atIndex:0];
                
                if (_pallete != nil)
                    _headerBackgroundView.backgroundColor = _pallete.backgroundColor;
            }
            
            [_headerBackgroundView addSubview:itemView];
        }
            break;
            
        case TGMenuSheetItemTypeFooter:
        {
            if (hasFooter)
                return;
            
            [_itemViews addObject:itemView];
            
            if (_footerBackgroundView == nil)
            {
                _footerBackgroundView = [[TGMenuSheetBackgroundView alloc] initWithFrame:CGRectZero sizeClass:_sizeClass dark:_dark];
                [self insertSubview:_footerBackgroundView atIndex:0];
                
                if (_pallete != nil)
                    _footerBackgroundView.backgroundColor = _pallete.backgroundColor;
            }
            
            [_footerBackgroundView addSubview:itemView];
        }
            break;
            
        default:
            break;
    }
    
    __weak TGMenuSheetView *weakSelf = self;
    itemView.layoutUpdateBlock = ^
    {
        __strong TGMenuSheetView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf layoutSubviews];
        if (strongSelf.menuRelayout != nil)
            strongSelf.menuRelayout();
    };
    
    itemView.highlightUpdateBlock = ^(__unused bool highlighted)
    {
    };
}

- (void)addItemViews:(NSArray *)itemViews
{
    bool hasHeader = self.hasHeader;
    bool hasFooter = self.hasFooter;
    
    for (TGMenuSheetItemView *itemView in itemViews)
    {
        if (_pallete != nil)
            [itemView setPallete:_pallete];
        [self addItemView:itemView hasHeader:hasHeader hasFooter:hasFooter];
        
        if (itemView.type == TGMenuSheetItemTypeHeader)
            hasHeader = true;
        else if (itemView.type == TGMenuSheetItemTypeFooter)
            hasFooter = true;
    }
}

- (void)setItemViews:(NSArray *)itemViews animated:(bool)animated
{
    NSMutableArray *itemViewsToDelete = [[NSMutableArray alloc] init];
    for (TGMenuSheetItemView *itemView in _itemViews)
    {
        if (![itemViews containsObject:itemView])
        {
            [itemViewsToDelete addObject:itemView];
        }
    }
    
    if (animated)
    {
        
    }
    else
    {
        
    }
}

- (UIView *)createDividerForItemView:(TGMenuSheetItemView *)itemView previousItemView:(TGMenuSheetItemView *)previousItemView
{
    if (!itemView.requiresDivider)
        return nil;
    
    UIView *topDivider = nil;
    if (previousItemView != nil)
        topDivider = _dividerViews[@(previousItemView.tag)][TGMenuDividerBottom];
        
    UIView *bottomDivider = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, TGScreenPixel)];
    bottomDivider.backgroundColor = _dark ? UIColorRGBA(0xffffff, 0.18f) : TGSeparatorColor();
    
    if (_pallete != nil)
        bottomDivider.backgroundColor = _pallete.separatorColor;
    
    NSMutableDictionary *dividers = [[NSMutableDictionary alloc] init];
    if (topDivider != nil)
        dividers[TGMenuDividerTop] = topDivider;
    dividers[TGMenuDividerBottom] = bottomDivider;
    _dividerViews[@(itemView.tag)] = dividers;
    
    return bottomDivider;
}

#pragma mark -

- (void)updateTraitsWithSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    _sizeClass = sizeClass;
    
    bool hideNonRegularItems = (_sizeClass == UIUserInterfaceSizeClassRegular);
    
    for (TGMenuSheetItemView *itemView in _itemViews)
    {
        itemView.sizeClass = sizeClass;
        if (itemView.type == TGMenuSheetItemTypeHeader || itemView.type == TGMenuSheetItemTypeFooter)
            [itemView setHidden:hideNonRegularItems animated:false];
    }
    
    [_headerBackgroundView updateTraitsWithSizeClass:sizeClass];
    [_mainBackgroundView updateTraitsWithSizeClass:sizeClass];
    [_footerBackgroundView updateTraitsWithSizeClass:sizeClass];
}

#pragma mark -

- (UIEdgeInsets)edgeInsets
{
    if (_sizeClass == UIUserInterfaceSizeClassRegular || _borderless)
        return UIEdgeInsetsZero;

    return TGMenuSheetPhoneEdgeInsets;
}

- (CGFloat)interSectionSpacing
{
    return TGMenuSheetInterSectionSpacing;
}

- (CGSize)menuSize
{
    return CGSizeMake(self.menuWidth, self.menuHeight);
}

- (CGFloat)menuHeight
{
    CGFloat maxHeight = [_context fullscreenBounds].size.height;
    if (self.maxHeight > FLT_EPSILON)
        maxHeight = MIN(self.maxHeight, maxHeight);
    
    CGFloat edgeInsetLeft = _narrowInLandscape ? self.edgeInsets.left :  MAX(self.edgeInsets.left, self.safeAreaInset.left);
    CGFloat edgeInsetRight = _narrowInLandscape ? self.edgeInsets.right : MAX(self.edgeInsets.right, self.safeAreaInset.right);
    
    CGFloat width = self.menuWidth - edgeInsetLeft - edgeInsetRight;
    return MIN(maxHeight, [self menuHeightForWidth:width]);
}

- (CGFloat)menuHeightForWidth:(CGFloat)width
{
    CGFloat height = 0.0f;
    CGFloat screenHeight = [_context fullscreenBounds].size.height;
    UIEdgeInsets edgeInsets = self.edgeInsets;
    
    bool hasRegularItems = false;
    bool hasHeader = false;
    bool hasFooter = false;
    
    for (TGMenuSheetItemView *itemView in self.itemViews)
    {
        bool skip = false;
        
        switch (itemView.type)
        {
            case TGMenuSheetItemTypeDefault:
                hasRegularItems = true;
                break;
                
            case TGMenuSheetItemTypeHeader:
                if (_sizeClass == UIUserInterfaceSizeClassRegular)
                    skip = true;
                else
                    hasHeader = true;
                break;
                
            case TGMenuSheetItemTypeFooter:
                if (_sizeClass == UIUserInterfaceSizeClassRegular)
                    skip = true;
                else
                    hasFooter = true;
                break;
                
            default:
                break;
        }
        
        if (!skip)
        {
            height += [itemView preferredHeightForWidth:width screenHeight:screenHeight];
            height += itemView.contentHeightCorrection;
        }
    }
    
    if (hasRegularItems || hasHeader || hasFooter)
        height += self.edgeInsets.top + self.edgeInsets.bottom;
    
    if ((hasRegularItems && hasHeader) || (hasRegularItems && hasFooter) || (hasHeader && hasFooter))
        height += self.interSectionSpacing;
    
    if (hasHeader && hasFooter && hasRegularItems)
        height += self.interSectionSpacing;
    
    if (self.keyboardOffset > 0)
    {
        height += self.keyboardOffset;
        height -= [self.footerItemView preferredHeightForWidth:width screenHeight:screenHeight] + self.interSectionSpacing;
    }
    
    if (fabs(height - screenHeight) <= edgeInsets.top)
        height = screenHeight;
    
    return height;
}

- (CGFloat)contentHeightCorrection
{
    CGFloat height = 0.0f;
    
    for (TGMenuSheetItemView *itemView in self.itemViews)
        height += itemView.contentHeightCorrection;
    
    return height;
}

#pragma mark - 

- (TGMenuSheetItemView *)headerItemView
{
    if (_sizeClass == UIUserInterfaceSizeClassRegular)
        return nil;
    
    if ([(TGMenuSheetItemView *)self.itemViews.firstObject type] == TGMenuSheetItemTypeHeader)
        return self.itemViews.firstObject;
    
    return nil;
}

- (TGMenuSheetItemView *)footerItemView
{
    if (_sizeClass == UIUserInterfaceSizeClassRegular)
        return nil;
    
    if ([(TGMenuSheetItemView *)self.itemViews.lastObject type] == TGMenuSheetItemTypeFooter)
        return self.itemViews.lastObject;
    
    return nil;
}

- (bool)hasHeader
{
    if (_sizeClass == UIUserInterfaceSizeClassRegular)
        return nil;
    
    return (self.headerItemView != nil);
}

- (bool)hasFooter
{
    if (_sizeClass == UIUserInterfaceSizeClassRegular)
        return nil;
    
    return (self.footerItemView != nil);
}

- (NSValue *)mainFrame
{
    if (_mainBackgroundView != nil)
        return [NSValue valueWithCGRect:_mainBackgroundView.frame];
    
    return nil;
}

- (NSValue *)headerFrame
{
    if (_headerBackgroundView != nil)
        return [NSValue valueWithCGRect:_headerBackgroundView.frame];
    
    return nil;
}

- (NSValue *)footerFrame
{
    if (_footerBackgroundView != nil)
        return [NSValue valueWithCGRect:_footerBackgroundView.frame];
    
    return nil;
}

#pragma mark - 

- (CGRect)activePanRect
{
    if (_panHandlingItemView == nil)
    {
        for (TGMenuSheetItemView *itemView in _itemViews)
        {
            if (itemView.handlesPan)
            {
                _panHandlingItemView = itemView;
                break;
            }
        }
        
        if (_panHandlingItemView == nil)
            _panHandlingItemView = [NSNull null];
    }
    
    if ([_panHandlingItemView isKindOfClass:[NSNull class]])
    {
        if (_scrollView.frame.size.height < _scrollView.contentSize.height)
            return [self convertRect:_scrollView.frame toView:self.superview.superview];
        else
            return CGRectNull;
    }
    
    TGMenuSheetItemView *itemView = (TGMenuSheetItemView *)_panHandlingItemView;
    return [itemView convertRect:itemView.bounds toView:self.superview.superview];
}

- (bool)passPanOffset:(CGFloat)offset
{
    if (_scrollView.frame.size.height < _scrollView.contentSize.height)
    {
        CGFloat bottomContentOffset = (_scrollView.contentSize.height - _scrollView.frame.size.height);
        
        if (bottomContentOffset > 0 && _scrollView.contentOffset.y > bottomContentOffset)
            return false;
        
        bool atTop = (_scrollView.contentOffset.y < FLT_EPSILON);
        bool atBottom = (_scrollView.contentOffset.y - bottomContentOffset > -FLT_EPSILON);
        
        if (atTop && offset > FLT_EPSILON)
            return true;
        
        if (atBottom && offset < 0)
            return true;
        
        return false;
    }
    else if ([_panHandlingItemView isKindOfClass:[NSNull class]])
    {
        return true;
    }
    
    TGMenuSheetItemView *itemView = (TGMenuSheetItemView *)_panHandlingItemView;
    return [itemView passPanOffset:offset];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!_expectsPreciseContentTouch)
        return [super pointInside:point withEvent:event];
    
    for (TGMenuSheetItemView *itemView in _itemViews)
    {
        if ([itemView pointInside:[self convertPoint:point toView:itemView] withEvent:event])
            return true;
    }
    
    return false;
}

#pragma mark - 

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat bottomContentOffset = (scrollView.contentSize.height - scrollView.frame.size.height);
    
    bool atTop = (scrollView.contentOffset.y < FLT_EPSILON);
    bool atBottom = (scrollView.contentOffset.y - bottomContentOffset > -FLT_EPSILON);

    if ((atTop || atBottom) && _sizeClass == UIUserInterfaceSizeClassCompact)
    {
        if (scrollView.isTracking && scrollView.bounces && (scrollView.contentOffset.y - bottomContentOffset) < 20.0f)
        {
            scrollView.bounces = false;
            if (atTop)
                scrollView.contentOffset = CGPointMake(0, 0);
            else if (atBottom)
                scrollView.contentOffset = CGPointMake(0, bottomContentOffset);
        }
    }
    else
    {
        scrollView.bounces = true;
    }
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    CGFloat bottomContentOffset = (scrollView.contentSize.height - scrollView.frame.size.height);
    
    bool atTop = (scrollView.contentOffset.y < FLT_EPSILON);
    bool atBottom = (scrollView.contentOffset.y - bottomContentOffset > -FLT_EPSILON);
    
    if ((atTop || atBottom) && scrollView.bounces && !scrollView.isTracking && _sizeClass == UIUserInterfaceSizeClassCompact)
        scrollView.bounces = false;
}

#pragma mark -

- (void)menuWillAppearAnimated:(bool)animated
{
    for (TGMenuSheetItemView *itemView in self.itemViews)
        [itemView menuView:self willAppearAnimated:animated];
}

- (void)menuDidAppearAnimated:(bool)animated
{
    for (TGMenuSheetItemView *itemView in self.itemViews)
        [itemView menuView:self didAppearAnimated:animated];
}

- (void)menuWillDisappearAnimated:(bool)animated
{
    for (TGMenuSheetItemView *itemView in self.itemViews)
        [itemView menuView:self willDisappearAnimated:animated];
}

- (void)menuDidDisappearAnimated:(bool)animated
{
    for (TGMenuSheetItemView *itemView in self.itemViews)
        [itemView menuView:self didDisappearAnimated:animated];
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGFloat edgeInsetLeft = _narrowInLandscape ? self.edgeInsets.left :  MAX(self.edgeInsets.left, self.safeAreaInset.left);
    CGFloat edgeInsetRight = _narrowInLandscape ? self.edgeInsets.right : MAX(self.edgeInsets.right, self.safeAreaInset.right);
    
    CGFloat width = self.menuWidth - edgeInsetLeft - edgeInsetRight;
    CGFloat maxHeight = _sizeClass == UIUserInterfaceSizeClassCompact ? [_context fullscreenBounds].size.height : self.frame.size.height;
    
    if (_sizeClass == UIUserInterfaceSizeClassCompact && self.maxHeight > FLT_EPSILON)
        maxHeight = MIN(self.maxHeight , maxHeight);
    
    CGFloat screenHeight = maxHeight;
    bool fullscreen = fabs(maxHeight - [_context fullscreenBounds].size.height) < FLT_EPSILON;

    if (_sizeClass == UIUserInterfaceSizeClassCompact)
    {
        if (self.headerItemView != nil)
            maxHeight -= [self.headerItemView preferredHeightForWidth:width screenHeight:screenHeight] + self.interSectionSpacing;
        
        if (self.keyboardOffset > FLT_EPSILON)
            maxHeight -= self.keyboardOffset;
        else if (self.footerItemView != nil)
            maxHeight -= [self.footerItemView preferredHeightForWidth:width screenHeight:screenHeight] + self.interSectionSpacing;
    }
    
    CGFloat contentHeight = 0;
    bool hasRegularItems = false;
    
    NSUInteger i = 0;
    TGMenuSheetItemView *condensableItemView = nil;
    for (TGMenuSheetItemView *itemView in self.itemViews)
    {
        if (itemView.type == TGMenuSheetItemTypeDefault)
        {
            hasRegularItems = true;
            
            CGFloat height = [itemView preferredHeightForWidth:width screenHeight:screenHeight];
            itemView.screenHeight = screenHeight;
            itemView.frame = CGRectMake(0, contentHeight, width, height);
            contentHeight += height;
            
            NSUInteger lastItem = (self.footerItemView != nil) ? self.itemViews.count - 2 : self.itemViews.count - 1;
            if (itemView.requiresDivider && i != lastItem)
            {
                UIView *divider = _dividerViews[@(itemView.tag)][TGMenuDividerBottom];
                if (divider != nil)
                    divider.frame = CGRectMake(0, CGRectGetMaxY(itemView.frame) - divider.frame.size.height, width, divider.frame.size.height);
            }
            
            if (itemView.condensable)
                condensableItemView = itemView;
        }
        i++;
    }
    contentHeight += self.contentHeightCorrection;
    
    UIEdgeInsets edgeInsets = self.edgeInsets;
    CGSize statusBarSize = [[LegacyComponentsGlobals provider] statusBarFrame].size;
    CGFloat statusBarHeight = MIN(statusBarSize.width, statusBarSize.height);
    statusBarHeight = MAX(statusBarHeight, 20.0f);
    if (_safeAreaInset.top > FLT_EPSILON)
        statusBarHeight = _safeAreaInset.top;
    
    if (fullscreen)
    {
        if (contentHeight > maxHeight - edgeInsets.top - edgeInsets.bottom)
            edgeInsets.top = statusBarHeight;
    
        if (fabs(contentHeight - maxHeight + edgeInsets.bottom) <= statusBarHeight)
            edgeInsets.top = statusBarHeight;
    }
    
    if (_sizeClass == UIUserInterfaceSizeClassRegular)
        edgeInsets = UIEdgeInsetsZero;
    
    maxHeight -= edgeInsets.top + edgeInsets.bottom;
    
    if (self.keyboardOffset > FLT_EPSILON && contentHeight > maxHeight && condensableItemView != nil)
    {
        CGFloat difference = contentHeight - maxHeight;
        contentHeight -= difference;
        
        CGRect frame = condensableItemView.frame;
        condensableItemView.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height - difference);
        
        if (condensableItemView.requiresDivider)
        {
            UIView *divider = _dividerViews[@(condensableItemView.tag)][TGMenuDividerBottom];
            if (divider != nil)
            {
                CGRect dividerFrame = divider.frame;
                divider.frame = CGRectMake(dividerFrame.origin.x, dividerFrame.origin.y - difference, dividerFrame.size.width, dividerFrame.size.height);
            }
        }
        
        bool moveNextItems = false;
        for (TGMenuSheetItemView *itemView in self.itemViews)
        {
            if (moveNextItems)
            {
                CGRect frame = itemView.frame;
                itemView.frame = CGRectMake(frame.origin.x, frame.origin.y - difference, frame.size.width, frame.size.height);
                
                if (itemView.requiresDivider)
                {
                    UIView *divider = _dividerViews[@(itemView.tag)][TGMenuDividerBottom];
                    if (divider != nil)
                    {
                        CGRect dividerFrame = divider.frame;
                        divider.frame = CGRectMake(dividerFrame.origin.x, dividerFrame.origin.y - difference, dividerFrame.size.width, dividerFrame.size.height);
                    }
                }
            }
            else if (itemView == condensableItemView)
            {
                moveNextItems = true;
            }
        }
    }
    
    for (TGMenuSheetItemView *itemView in self.itemViews)
        [itemView _didLayoutSubviews];
    
    CGFloat topInset = edgeInsets.top;
    if (self.headerItemView != nil)
    {
        _headerBackgroundView.frame = CGRectMake(edgeInsetLeft, topInset, width, [self.headerItemView preferredHeightForWidth:width screenHeight:screenHeight]);
        self.headerItemView.frame = _headerBackgroundView.bounds;
        
        topInset = CGRectGetMaxY(_headerBackgroundView.frame) + TGMenuSheetInterSectionSpacing;
    }
    
    if (hasRegularItems)
    {
        CGFloat additionalHeight = _borderless ? 256.0f : 0.0f;
        _mainBackgroundView.frame = CGRectMake(edgeInsetLeft, topInset, width, MIN(contentHeight, maxHeight) + additionalHeight);
        _scrollView.frame = CGRectMake(0.0f, 0.0f, _mainBackgroundView.frame.size.width, _mainBackgroundView.frame.size.height - additionalHeight);
        _scrollView.contentSize = CGSizeMake(width, contentHeight);
    }
    
    if (self.footerItemView != nil)
    {
        CGFloat height = [self.footerItemView preferredHeightForWidth:width screenHeight:screenHeight];
        CGFloat top = self.menuHeight - edgeInsets.bottom - height;
        if (hasRegularItems && self.keyboardOffset < FLT_EPSILON)
            top = CGRectGetMaxY(_mainBackgroundView.frame) + TGMenuSheetInterSectionSpacing;
    
        _footerBackgroundView.frame = CGRectMake(edgeInsetLeft, top, width, height);
        self.footerItemView.frame = _footerBackgroundView.bounds;
    }
}

@end
