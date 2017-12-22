#import "TGModernConversationMentionsAssociatedPanel.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGFont.h>
#import <LegacyComponents/TGViewController.h>

#import "TGMentionPanelCell.h"

@interface TGModernConversationMentionsAssociatedPanel () <UITableViewDelegate, UITableViewDataSource>
{
    SMetaDisposable *_disposable;
    NSArray *_userList;
 
    UIView *_backgroundView;
    UIView *_effectView;
    
    UITableView *_tableView;
    UIView *_stripeView;
    UIView *_separatorView;
    
    UIView *_bottomView;
    UIView *_tableViewBackground;
    UIView *_tableViewSeparator;
    
    bool _resetOffsetOnLayout;
    bool _animatingOut;
}

@end

@implementation TGModernConversationMentionsAssociatedPanel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _disposable = [[SMetaDisposable alloc] init];
        
        UIColor *backgroundColor = [UIColor whiteColor];
        UIColor *bottomColor = UIColorRGBA(0xfafafa, 0.98f);
        UIColor *separatorColor = UIColorRGB(0xc5c7d0);
        UIColor *cellSeparatorColor = UIColorRGB(0xdbdbdb);
        
        self.clipsToBounds = true;
        
        if (self.style == TGModernConversationAssociatedInputPanelDarkStyle)
        {
            backgroundColor = UIColorRGB(0x171717);
            bottomColor = backgroundColor;
            separatorColor = UIColorRGB(0x292929);
            cellSeparatorColor = separatorColor;
        }
        else if (self.style == TGModernConversationAssociatedInputPanelDarkBlurredStyle)
        {
            backgroundColor = [UIColor clearColor];
            separatorColor = UIColorRGBA(0xb2b2b2, 0.7f);
            cellSeparatorColor = UIColorRGBA(0xb2b2b2, 0.4f);
            bottomColor = [UIColor clearColor];
            
            CGFloat backgroundAlpha = 0.8f;
            if (iosMajorVersion() >= 8)
            {
                UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
                blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                blurEffectView.frame = self.bounds;
                [self addSubview:blurEffectView];
                _effectView = blurEffectView;
                
                backgroundAlpha = 0.4f;
            }
            
            _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
            _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _backgroundView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:backgroundAlpha];
            [self addSubview:_backgroundView];
        }
        
        _bottomView = [[UIView alloc] init];
        _bottomView.backgroundColor = bottomColor;
        [self addSubview:_bottomView];
        
        _tableViewBackground = [[UIView alloc] init];
        _tableViewBackground.backgroundColor = backgroundColor;
        [self addSubview:_tableViewBackground];
        
        _tableView = [[UITableView alloc] init];
        if (iosMajorVersion() >= 11)
            _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _tableView.tableFooterView = [[UIView alloc] init];
        if (iosMajorVersion() >= 7)
        {
            _tableView.separatorColor = cellSeparatorColor;
            _tableView.separatorInset = UIEdgeInsetsMake(0.0f, 52.0f, 0.0f, 0.0f);
        }
        _tableView.backgroundColor = nil;
        _tableView.opaque = false;
        _tableView.showsVerticalScrollIndicator = false;
        _tableView.showsHorizontalScrollIndicator = false;
        
        [self addSubview:_tableView];
        
        _tableViewSeparator = [[UIView alloc] init];
        _tableViewSeparator.backgroundColor = separatorColor;
        [self addSubview:_tableViewSeparator];
        
        _stripeView = [[UIView alloc] init];
        _stripeView.backgroundColor = separatorColor;
        [self addSubview:_stripeView];
        
        if (self.style != TGModernConversationAssociatedInputPanelDarkBlurredStyle)
        {
            _separatorView = [[UIView alloc] init];
            _separatorView.backgroundColor = separatorColor;
            [self addSubview:_separatorView];
        }
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)setPallete:(TGConversationAssociatedInputPanelPallete *)pallete
{
    [super setPallete:pallete];
    if (self.pallete == nil)
        return;
    
    _bottomView.backgroundColor = pallete.barBackgroundColor;
    _tableViewBackground.backgroundColor = pallete.backgroundColor;
    _tableViewSeparator.backgroundColor = pallete.barSeparatorColor;
    _tableView.separatorColor = pallete.separatorColor;
    _stripeView.backgroundColor = pallete.barSeparatorColor;
    _separatorView.backgroundColor = pallete.barSeparatorColor;
}

- (void)setInverted:(bool)inverted {
    if (_inverted != inverted) {
        _inverted = inverted;
        
        if (_inverted) {
            self.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
        } else {
            self.transform = CGAffineTransformIdentity;
        }
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    self.alpha = frame.size.height >= FLT_EPSILON;
}

- (bool)fillsAvailableSpace {
    return true;//iosMajorVersion() >= 9;
}

- (CGFloat)preferredHeight {
    return [self preferredHeightAndOverlayHeight:NULL];
}

- (CGFloat)preferredHeightAndOverlayHeight:(CGFloat *)overlayHeight
{
    CGFloat height = 0.0f;
    CGFloat lastHeight = 0.0f;
    NSInteger lastIndex = MIN([TGViewController isWidescreen] ? 4 : 3, (NSInteger)_userList.count - 1);
    for (NSInteger i = 0; i <= lastIndex; i++) {
        CGFloat rowHeight = [self tableView:_tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        if (i == lastIndex) {
            lastHeight = rowHeight;
        } else {
            height += rowHeight;
        }
    }
    
    CGFloat completeHeight = 0.0f;
    for (NSInteger i = 0; i < (NSInteger)_userList.count; i++) {
        CGFloat rowHeight = [self tableView:_tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        completeHeight += rowHeight;
    }
    
    CGFloat maxHeight = CGFloor(self.frame.size.height * 2.0f / 3.0f);
    
    height = completeHeight;
    
    CGFloat overlayHeightValue = 0.0f;
    if (height + self.barInset < self.frame.size.height) {
        overlayHeightValue = self.barInset;
    }
    
    if (overlayHeight) {
        *overlayHeight = overlayHeightValue;
    }
    
    height += overlayHeightValue;
    
    if (lastIndex > 0) {
        return MIN(maxHeight, CGFloor(height));
    } else {
        return MIN(maxHeight, height);
    }
}

- (void)setUserListSignal:(SSignal *)userListSignal
{
    if (userListSignal == nil)
    {
        [_disposable setDisposable:nil];
        [self setUserList:@[]];
    }
    else
    {
        __weak TGModernConversationMentionsAssociatedPanel *weakSelf = self;
        [_disposable setDisposable:[[userListSignal deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *userList)
        {
            __strong TGModernConversationMentionsAssociatedPanel *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setUserList:userList];
        }]];
    }
}

- (void)setUserList:(NSArray *)userList
{
    bool wasEmpty = _userList.count == 0;
    _userList = userList;
    
    if (iosMajorVersion() >= 7) {
        _tableView.separatorStyle = _userList.count <= 1 ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
    }
    
    [_tableView reloadData];
    
    [self setNeedsPreferredHeightUpdate];
    
    _stripeView.hidden = userList.count == 0;
    _separatorView.hidden = userList.count == 0 || _inverted;
    _bottomView.hidden = userList.count == 0;
    
    [self scrollViewDidScroll:_tableView];
    
    if (_userList.count != 0 && wasEmpty) {
        [self animateIn];
    } else {
        [self layoutSubviews];
    }
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _userList.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath {
    return 41.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGMentionPanelCell *cell = (TGMentionPanelCell *)[tableView dequeueReusableCellWithIdentifier:TGMentionPanelCellKind];
    if (cell == nil) {
        cell = [[TGMentionPanelCell alloc] initWithStyle:self.style];
        if (_inverted) {
            [UIView performWithoutAnimation:^{
                cell.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
            }];
        } else {
            cell.transform = CGAffineTransformIdentity;
        }
    }
    cell.pallete = self.pallete;
    if (iosMajorVersion() >= 7)
    {
        if (indexPath.row == 0 && _inverted) {
            cell.separatorInset = UIEdgeInsetsMake(0.0f, 2000.0f, 0.0f, 0.0f);
        } else {
            cell.separatorInset = tableView.separatorInset;
        }
    }
    
    [cell setUser:_userList[indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGUser *user = _userList[indexPath.row];
    if (_userSelected)
        _userSelected(user);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _tableView) {
        [self updateTableBackground];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_animatingOut) {
        return;
    }
    
    _backgroundView.frame = CGRectMake(-1000, 0, self.frame.size.width + 2000, self.frame.size.height);
    _effectView.frame = CGRectMake(-1000, 0, self.frame.size.width + 2000, self.frame.size.height);
    
    CGFloat separatorHeight = TGScreenPixel;
    _separatorView.frame = CGRectMake(0.0f, self.frame.size.height - separatorHeight, self.frame.size.width, separatorHeight);
    
    UIEdgeInsets previousInset = _tableView.contentInset;
    
    _tableView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
    
    if ([self fillsAvailableSpace]) {
        CGFloat overlayHeight = 0.0;
        CGFloat preferredHeight = [self preferredHeightAndOverlayHeight:&overlayHeight];
        
        CGFloat topInset = MAX(0.0f, self.frame.size.height - preferredHeight);
        CGFloat insetDifference = topInset - _tableView.contentInset.top;
        UIEdgeInsets finalInset = UIEdgeInsetsMake(topInset, 0.0f, MAX(0.0f, overlayHeight - 1.0f / TGScreenScaling()), 0.0f);
        
        if (_resetOffsetOnLayout) {
            _resetOffsetOnLayout = false;
            _tableView.contentInset = finalInset;
            [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
        } else if (ABS(insetDifference) > FLT_EPSILON) {
            //if (ABS(insetDifference) <= 36.0f + 0.1) {
            {
                [self _autoAdjustInsetsForScrollView:_tableView finalInset:finalInset previousInset:previousInset];
                
                //contentOffset.y -= insetDifference;
                //_tableView.contentOffset = contentOffset;
            }
        }
    } else {
        _tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    _bottomView.frame = CGRectMake(0.0f, self.frame.size.height, self.frame.size.width, 4.0f);
    
    [self updateTableBackground];
}

- (void)_autoAdjustInsetsForScrollView:(UIScrollView *)scrollView finalInset:(UIEdgeInsets)finalInset previousInset:(UIEdgeInsets)previousInset
{
    CGPoint contentOffset = scrollView.contentOffset;
    
    scrollView.contentInset = finalInset;
    if (iosMajorVersion() <= 8 && scrollView.subviews.count != 0) {
        if ([NSStringFromClass([scrollView.subviews.firstObject class]) hasPrefix:@"UITableViewWra"]) {
            CGRect frame = scrollView.subviews.firstObject.frame;
            frame.origin = CGPointZero;
            scrollView.subviews.firstObject.frame = frame;
        }
    }
    
    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        CGFloat maxOffset = scrollView.contentSize.height - (scrollView.frame.size.height - finalInset.bottom);
        
        contentOffset.y += previousInset.top - finalInset.top;
        contentOffset.y = MAX(-finalInset.top, MIN(contentOffset.y, maxOffset));
        [scrollView setContentOffset:contentOffset animated:false];
    }
    else if (contentOffset.y < finalInset.top)
    {
        contentOffset.y = -finalInset.top;
        [scrollView setContentOffset:contentOffset animated:false];
    }
}

- (void)updateTableBackground {
    if (_animatingOut) {
        return;
    }
    
    CGFloat backgroundOriginY = MAX(0.0f, -_tableView.contentOffset.y);
    _tableViewBackground.frame = CGRectMake(0.0f, backgroundOriginY, self.frame.size.width, self.frame.size.height - backgroundOriginY);
    _tableViewSeparator.frame = CGRectMake(0.0f, backgroundOriginY - 0.5f, self.frame.size.width, 0.5f);
    
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(backgroundOriginY, 0.0f, 0.0f, 0.0f);
    
    self.overlayBarOffset = _tableView.contentOffset.y + _tableView.contentInset.top;
    if (self.updateOverlayBarOffset) {
        self.updateOverlayBarOffset(self.overlayBarOffset);
    }
}

- (CGRect)tableBackgroundFrame {
    return _tableViewBackground.frame;
}

- (bool)hasSelectedItem
{
    return _tableView.indexPathForSelectedRow != nil;
}

- (void)selectPreviousItem
{
    if ([self tableView:_tableView numberOfRowsInSection:0] == 0)
        return;
    
    NSIndexPath *newIndexPath = _tableView.indexPathForSelectedRow;
    
    if (newIndexPath == nil)
        newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    else if (newIndexPath.row > 0)
        newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row - 1 inSection:0];
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:false];
    
    if (newIndexPath != nil)
        [_tableView selectRowAtIndexPath:newIndexPath animated:false scrollPosition:UITableViewScrollPositionBottom];
}

- (void)selectNextItem
{
    if ([self tableView:_tableView numberOfRowsInSection:0] == 0)
        return;
    
    NSIndexPath *newIndexPath = _tableView.indexPathForSelectedRow;
    
    if (newIndexPath == nil)
        newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    else if (newIndexPath.row < [self tableView:_tableView numberOfRowsInSection:newIndexPath.section] - 1)
        newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row + 1 inSection:0];
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:false];
    
    if (newIndexPath != nil)
        [_tableView selectRowAtIndexPath:newIndexPath animated:false scrollPosition:UITableViewScrollPositionBottom];
}

- (void)commitSelectedItem
{
    if ([self tableView:_tableView numberOfRowsInSection:0] == 0)
        return;
    
    NSIndexPath *selectedIndexPath = _tableView.indexPathForSelectedRow;
    if (selectedIndexPath == nil)
        selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self tableView:_tableView didSelectRowAtIndexPath:selectedIndexPath];
}

- (void)animateIn {
    [self layoutSubviews];
    CGFloat offset = [self preferredHeight];
    CGRect normalFrame = _tableView.frame;
    _tableView.frame = CGRectMake(normalFrame.origin.x, normalFrame.origin.y + offset, normalFrame.size.width, normalFrame.size.height);
    CGRect normalBackgroundFrame = _tableViewBackground.frame;
    _tableViewBackground.frame = CGRectMake(normalBackgroundFrame.origin.x, normalBackgroundFrame.origin.y + offset, normalBackgroundFrame.size.width, normalBackgroundFrame.size.height);
    CGRect normalSeparatorFrame = _tableViewSeparator.frame;
    _tableViewSeparator.frame = CGRectMake(normalSeparatorFrame.origin.x, normalSeparatorFrame.origin.y + offset, normalSeparatorFrame.size.width, normalSeparatorFrame.size.height);
    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
        _tableView.frame = normalFrame;
        _tableViewBackground.frame = normalBackgroundFrame;
        _tableViewSeparator.frame = normalSeparatorFrame;
    } completion:nil];
}

- (void)animateOut:(void (^)())completion {
    CGFloat offset = self.frame.size.height - _tableViewBackground.frame.origin.y;
    CGRect normalFrame = _tableView.frame;
    CGRect normalBackgroundFrame = _tableViewBackground.frame;
    CGRect normalSeparatorFrame = _tableViewSeparator.frame;
    _animatingOut = true;
    
    [UIView animateWithDuration:0.15 delay:0.0 options:0 animations:^{
        _tableView.frame = CGRectMake(normalFrame.origin.x, normalFrame.origin.y + offset, normalFrame.size.width, normalFrame.size.height);
        _tableViewBackground.frame = CGRectMake(normalBackgroundFrame.origin.x, normalBackgroundFrame.origin.y + offset, normalBackgroundFrame.size.width, normalBackgroundFrame.size.height);
        _tableViewSeparator.frame = CGRectMake(normalSeparatorFrame.origin.x, normalSeparatorFrame.origin.y + offset, normalSeparatorFrame.size.width, normalSeparatorFrame.size.height);
    } completion:^(__unused BOOL finished) {
        completion();
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(_tableViewBackground.frame, point)) {
        return [super hitTest:point withEvent:event];
    }
    return nil;
}

- (void)setBarInset:(CGFloat)barInset animated:(bool)animated {
    if (ABS(barInset - self.barInset) > FLT_EPSILON) {
        [super setBarInset:barInset animated:animated];
        
        if (animated) {
            [self layoutSubviews];
        } else {
            [UIView animateWithDuration:0.3 animations:^{
                [self layoutSubviews];
            }];
        }
    }
}

@end
