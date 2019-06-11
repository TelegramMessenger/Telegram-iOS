#import "TGPhotoStickersView.h"

#import "LegacyComponentsContext.h"
#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGColor.h"

#import "TGStickerPack.h"
#import "TGDocumentMediaAttachment.h"

#import <LegacyComponents/TGPaintUtils.h>

#import <LegacyComponents/TGModernButton.h>
#import "TGStickerKeyboardTabPanel.h"

#import "TGPhotoStickersCollectionView.h"
#import "TGPhotoStickersCollectionLayout.h"
#import "TGPhotoStickersSectionHeader.h"
#import "TGPhotoStickersSectionHeaderView.h"
#import "TGStickerCollectionViewCell.h"

#import "TGItemPreviewController.h"
#import "TGStickerItemPreviewView.h"

const CGFloat TGPhotoStickersPreloadInset = 160.0f;
const CGFloat TGPhotoStickersViewMargin = 19.0f;

typedef enum {
    TGPhotoStickersViewSectionMasks = 0,
    TGPhotoStickersViewSectionGeneric = 1
} TGPhotoStickersViewSection;

@interface TGPhotoStickersView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate>
{
    id<SDisposable> _stickerPacksDisposable;
    
    TGPhotoStickersViewSection _section;
    
    NSArray<TGStickerPack *> *_genericStickerPacks;
    NSArray<TGStickerPack *> *_maskStickerPacks;
    NSArray *_recentDocumentsOriginal;
    NSArray *_recentDocumentsSorted;
    NSArray *_recentStickers;
    NSArray *_recentMasks;
    NSDictionary *_packReferenceToPack;
    
    bool _ignoreSetSection;
    
    UIView *_dimView;
    UIView *_blurView;
    UIImageView *_backgroundView;
    
    UIView *_wrapperView;
    UISegmentedControl *_segmentedControl;
    TGModernButton *_cancelButton;
    
    TGStickerKeyboardTabPanel *_tabPanel;
    UIView *_separatorView;
    
    UIView *_collectionWrapperView;
    TGPhotoStickersCollectionView *_collectionView;
    UICollectionViewFlowLayout *_collectionLayout;
    UIView *_headersView;
    
    UIPanGestureRecognizer *_panRecognizer;
    
    CGFloat _masksContentOffset;
    CGFloat _stickersContentOffset;
    
    __weak TGItemPreviewController *_previewController;
    
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGPhotoStickersView

@synthesize interfaceOrientation = _interfaceOrientation;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context frame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _context = context;
        
        _masksContentOffset = FLT_MAX;
        _stickersContentOffset = FLT_MAX;
        
        bool compact = [_context currentSizeClass] == UIUserInterfaceSizeClassCompact;
        if (compact)
        {
            if (iosMajorVersion() >= 8)
            {
                _blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
            }
            else
            {
                _blurView = [[UIToolbar alloc] init];
                _blurView.alpha = 0.0f;
                ((UIToolbar *)_blurView).barStyle = UIBarStyleBlackTranslucent;
            }
            [self addSubview:_blurView];
        }
        else
        {
            _interfaceOrientation = UIInterfaceOrientationPortrait;
            
            _backgroundView = [[UIImageView alloc] init];
            _backgroundView.alpha = 0.98f;
            _backgroundView.image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupCenterBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
            [self addSubview:_backgroundView];
        }
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.clipsToBounds = true;
        [self addSubview:_wrapperView];
        
        _segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 0, 29.0f)];
        
        TGStickerKeyboardViewStyle stickersStyle = TGStickerKeyboardViewPaintStyle;
        if (compact)
        {
            _wrapperView.alpha = 0.0f;
            _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            stickersStyle = TGStickerKeyboardViewPaintDarkStyle;
            
            _cancelButton = [[TGModernButton alloc] init];
            _cancelButton.exclusiveTouch = true;
            _cancelButton.titleLabel.font = TGSystemFontOfSize(17.0f);
            [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
            [_cancelButton setTitleColor:UIColorRGB(0xafb2b1)];
            [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_cancelButton sizeToFit];
            [_wrapperView addSubview:_cancelButton];
            
            [_segmentedControl setBackgroundImage:TGTintedImage(TGComponentsImageNamed(@"ModernSegmentedControlBackground.png"), UIColorRGB(0xafb2b1)) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGTintedImage(TGComponentsImageNamed(@"ModernSegmentedControlSelected.png"), UIColorRGB(0xafb2b1)) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGTintedImage(TGComponentsImageNamed(@"ModernSegmentedControlSelected.png"), UIColorRGB(0xafb2b1)) forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGComponentsImageNamed(@"PaintSegmentedControlHighlighted.png") forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [_segmentedControl setDividerImage:TGTintedImage(TGComponentsImageNamed(@"ModernSegmentedControlDivider.png"), UIColorRGB(0xafb2b1)) forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: UIColorRGB(0xafb2b1), UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateNormal];
            [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor blackColor], UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateSelected];
        }
        else
        {
            [_segmentedControl setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlBackground.png") forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [_segmentedControl setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlHighlighted.png") forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [_segmentedControl setDividerImage:TGComponentsImageNamed(@"ModernSegmentedControlDivider.png") forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: TGAccentColor(), UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateNormal];
            [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor], UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateSelected];
        }
        
        [_segmentedControl insertSegmentWithTitle:TGLocalized(@"Paint.Masks") atIndex:0 animated:false];
        [_segmentedControl insertSegmentWithTitle:TGLocalized(@"Paint.Stickers") atIndex:1 animated:false];
        [_segmentedControl setSelectedSegmentIndex:0];
        [_segmentedControl addTarget:self action:@selector(segmentedControlChanged) forControlEvents:UIControlEventValueChanged];
        [_wrapperView addSubview:_segmentedControl];
        
        __weak TGPhotoStickersView *weakSelf = self;
        _tabPanel = [[TGStickerKeyboardTabPanel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 45.0f) style:stickersStyle];
        _tabPanel.currentStickerPackIndexChanged = ^(NSUInteger index)
        {
            __strong TGPhotoStickersView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf scrollToSection:index == 1 ? 0 : index - 2];
        };
        [_wrapperView addSubview:_tabPanel];
        
        CGFloat thickness = TGScreenPixel;
        _separatorView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, thickness)];
        _separatorView.backgroundColor = UIColorRGB(0xafb2b1);
        //[_wrapperView addSubview:_separatorView];
        
        _collectionWrapperView = [[UIView alloc] init];
        _collectionWrapperView.clipsToBounds = true;
        [_wrapperView addSubview:_collectionWrapperView];
        
        _collectionLayout = [[TGPhotoStickersCollectionLayout alloc] init];
        _collectionView = [[TGPhotoStickersCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_collectionLayout];
        if (iosMajorVersion() >= 11)
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.opaque = false;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.showsVerticalScrollIndicator = false;
        _collectionView.alwaysBounceVertical = true;
        _collectionView.delaysContentTouches = false;
        _collectionView.contentInset = UIEdgeInsetsMake(TGPhotoStickersPreloadInset - TGPhotoStickersSectionHeaderHeight, 0.0f, TGPhotoStickersPreloadInset, 0.0f);
        [_collectionView registerClass:[TGStickerCollectionViewCell class] forCellWithReuseIdentifier:@"TGStickerCollectionViewCell"];
        if (!compact)
            _collectionView.headerTextColor = UIColorRGB(0x787878);
        [_collectionWrapperView addSubview:_collectionView];
        
        _headersView = [[UIView alloc] init];
        _headersView.userInteractionEnabled = false;
        [_wrapperView addSubview:_headersView];
        _collectionView.headersParentView = _headersView;
        
        UILongPressGestureRecognizer *tapRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerPress:)];
        tapRecognizer.minimumPressDuration = 0.25;
        [_collectionView addGestureRecognizer:tapRecognizer];
        
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerPan:)];
        _panRecognizer.delegate = self;
        _panRecognizer.cancelsTouchesInView = false;
        [_collectionView addGestureRecognizer:_panRecognizer];

        _stickerPacksDisposable = [[[SSignal combineSignals:@[[[LegacyComponentsGlobals provider] maskStickerPacksSignal], [[LegacyComponentsGlobals provider] stickerPacksSignal], [[LegacyComponentsGlobals provider] recentStickerMasksSignal]]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *masksAndStickers)
        {
            NSDictionary *masks = masksAndStickers[0];
            NSDictionary *stickers = masksAndStickers[1];
            NSArray *recentStickers = masksAndStickers[2];
            
            NSMutableArray *filteredPacks = [[NSMutableArray alloc] init];
            for (TGStickerPack *pack in stickers[@"packs"])
            {
                if ([pack.packReference isKindOfClass:[TGStickerPackIdReference class]] && !pack.hidden)
                    [filteredPacks addObject:pack];
            }
            
            NSMutableArray *filteredMaskPacks = [[NSMutableArray alloc] init];
            for (TGStickerPack *pack in masks[@"packs"])
            {
                if ([pack.packReference isKindOfClass:[TGStickerPackIdReference class]] && !pack.hidden)
                    [filteredMaskPacks addObject:pack];
            }
            
            NSArray *sortedStickerPacks = filteredPacks;
            NSArray *sortedMaskStickerPacks = filteredMaskPacks;
            
            NSMutableArray *reversed = [[NSMutableArray alloc] init];
            for (id item in sortedStickerPacks)
            {
                [reversed addObject:item];
            }
            
            NSMutableArray<TGStickerPack *> *reversedMasks = [[NSMutableArray alloc] init];
            for (id item in sortedMaskStickerPacks)
            {
                [reversedMasks addObject:item];
            }
            
            __strong TGPhotoStickersView *strongSelf = weakSelf;
            if (strongSelf != nil) {
                bool masksAreEqual = true;
                if (strongSelf->_maskStickerPacks.count == reversedMasks.count) {
                    for (int setIndex = 0; setIndex < (int)strongSelf->_maskStickerPacks.count; setIndex++) {
                        if (strongSelf->_maskStickerPacks[setIndex].documents.count == reversedMasks[setIndex].documents.count) {
                            for (int documentIndex = 0; documentIndex < (int)_maskStickerPacks[setIndex].documents.count; documentIndex++) {
                                TGDocumentMediaAttachment *lhsDocument = _maskStickerPacks[setIndex].documents[documentIndex];
                                TGDocumentMediaAttachment *rhsDocument = reversedMasks[setIndex].documents[documentIndex];
                                if (![lhsDocument isEqual:rhsDocument]) {
                                    masksAreEqual = false;
                                    break;
                                }
                            }
                            if (!masksAreEqual) {
                                break;
                            }
                        } else {
                            masksAreEqual = false;
                            break;
                        }
                    }
                } else {
                    masksAreEqual = false;
                }
                
                if (![strongSelf->_genericStickerPacks isEqual:reversed] || !masksAreEqual) {
                    [strongSelf setStickerPacks:reversed maskStickerPacks:reversedMasks recentDocuments:recentStickers];
                }
                
                [strongSelf updateCurrentSection];
            }
        }];
    }
    return self;
}

- (void)dealloc {
    [_stickerPacksDisposable dispose];
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    return CGSizeMake(375.0f + TGPhotoStickersViewMargin * 2.0f, 568.0f + TGPhotoStickersViewMargin * 2.0f);
}

- (void)setSeparatorHidden:(bool)hidden animated:(bool)animated
{
    if ((hidden && _separatorView.alpha < 1.0f - FLT_EPSILON) || (!hidden && _separatorView.alpha > FLT_EPSILON))
        return;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _separatorView.alpha = hidden ? 0.0f : 1.0f;
        }];
    }
    else
    {
        _separatorView.alpha = hidden ? 0.0f : 1.0f;
    }
}

#pragma mark - 

- (void)handleStickerPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint point = [recognizer locationInView:_collectionView];
        
        for (NSIndexPath *indexPath in [_collectionView indexPathsForVisibleItems])
        {
            TGStickerCollectionViewCell *cell = (TGStickerCollectionViewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
            if (CGRectContainsPoint(cell.frame, point))
            {
                TGViewController *parentViewController = _parentViewController;
                if (parentViewController != nil)
                {
                    TGStickerItemPreviewView *previewView = [[TGStickerItemPreviewView alloc] initWithContext:_context frame:CGRectZero];
                    if ((NSInteger)TGScreenSize().height == 736)
                        previewView.eccentric = false;
                    
                    TGItemPreviewController *controller = [[TGItemPreviewController alloc] initWithContext:_context parentController:parentViewController previewView:previewView];
                    _previewController = controller;
                    
                    __weak TGPhotoStickersView *weakSelf = self;
                    controller.sourcePointForItem = ^(id item)
                    {
                        __strong TGPhotoStickersView *strongSelf = weakSelf;
                        if (strongSelf == nil)
                            return CGPointZero;
                        
                        for (TGStickerCollectionViewCell *cell in strongSelf->_collectionView.visibleCells)
                        {
                            if ([cell.documentMedia isEqual:item])
                            {
                                NSIndexPath *indexPath = [strongSelf->_collectionView indexPathForCell:cell];
                                if (indexPath != nil)
                                    return [strongSelf->_collectionView convertPoint:cell.center toView:nil];
                            }
                        }
                        
                        return CGPointZero;
                    };
                    
                    TGDocumentMediaAttachment *sticker = [self documentAtIndexPath:indexPath];
                    TGStickerPack *stickerPack = [self stickerPackAtIndexPath:indexPath];
                    NSArray *associations = _section == TGPhotoStickersViewSectionGeneric ? stickerPack.stickerAssociations : nil;
                    [previewView setSticker:sticker associations:associations];
                    
                    [cell setHighlightedWithBounce:true];
                }
                
                break;
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled)
    {
        TGItemPreviewController *controller = _previewController;
        [controller dismiss];
        
        for (TGStickerCollectionViewCell *cell in [_collectionView visibleCells])
            [cell setHighlightedWithBounce:false];
    }
}

- (void)handleStickerPan:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (_previewController != nil && gestureRecognizer.state == UIGestureRecognizerStateChanged)
    {
        TGStickerItemPreviewView *previewView = (TGStickerItemPreviewView *)_previewController.previewView;
        
        CGPoint point = [gestureRecognizer locationInView:_collectionView];
        CGPoint relativePoint = [gestureRecognizer locationInView:self];
        
        if (CGRectContainsPoint(CGRectOffset(_collectionView.frame, 0, TGPhotoStickersPreloadInset), relativePoint))
        {
            for (NSIndexPath *indexPath in [_collectionView indexPathsForVisibleItems])
            {
                TGStickerCollectionViewCell *cell = (TGStickerCollectionViewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
                if (CGRectContainsPoint(cell.frame, point))
                {
                    TGDocumentMediaAttachment *document = [self documentAtIndexPath:indexPath];
                    TGStickerPack *stickerPack = [self stickerPackAtIndexPath:indexPath];
                    NSArray *associations = _section == TGPhotoStickersViewSectionGeneric ? stickerPack.stickerAssociations : nil;
                    if (document != nil)
                        [previewView setSticker:document associations:associations];
                    [cell setHighlightedWithBounce:true];
                }
                else
                {
                    [cell setHighlightedWithBounce:false];
                }
            }
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _panRecognizer || otherGestureRecognizer == _panRecognizer)
        return true;
    
    return false;
}

#pragma mark - 

- (void)setStickerPacks:(NSArray *)stickerPacks maskStickerPacks:(NSArray *)maskStickerPacks recentDocuments:(NSArray *)recentDocuments
{
    _genericStickerPacks = stickerPacks;
    _maskStickerPacks = maskStickerPacks;
    
    _recentDocumentsSorted = recentDocuments;
    _recentDocumentsOriginal = recentDocuments;
    
    [self updateRecentDocuments];
    
    [_collectionView reloadData];
    
    [_tabPanel setStickerPacks:_section == TGPhotoStickersViewSectionMasks ? _maskStickerPacks : _genericStickerPacks showRecent:_section == TGPhotoStickersViewSectionMasks ? (_recentMasks.count != 0) : (_recentStickers.count != 0) showFavorite:false showGroup:false showGroupLast:false showGifs:false showTrendingFirst:false showTrendingLast:false];
}

- (void)updateRecentDocuments
{
    NSMutableArray *recentStickers = [[NSMutableArray alloc] init];
    NSMutableArray *recentMasks = [[NSMutableArray alloc] init];
    NSMutableDictionary *packReferenceToPack = [[NSMutableDictionary alloc] init];
    
    for (TGStickerPack *pack in _genericStickerPacks) {
        if (pack.packReference != nil) {
            packReferenceToPack[pack.packReference] = pack;
        }
    }
    
    for (TGStickerPack *pack in _maskStickerPacks) {
        if (pack.packReference != nil) {
            packReferenceToPack[pack.packReference] = pack;
        }
    }
    
    for (TGDocumentMediaAttachment *document in _recentDocumentsSorted) {
        for (id attribute in document.attributes) {
            if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
                if (((TGDocumentAttributeSticker *)attribute).packReference != nil) {
                    TGStickerPack *pack = packReferenceToPack[((TGDocumentAttributeSticker *)attribute).packReference];
                    if (pack != nil) {
                        if (pack.isMask) {
                            [recentMasks addObject:document];
                        } else {
                            [recentStickers addObject:document];
                        }
                    }
                }
                break;
            }
        }
    }
    
    if (recentStickers.count > 20) {
        [recentStickers removeObjectsInRange:NSMakeRange(20, recentStickers.count - 20)];
    }
    
    if (recentMasks.count > 20) {
        [recentMasks removeObjectsInRange:NSMakeRange(20, recentMasks.count - 20)];
    }
    
    _recentStickers = recentStickers;
    _recentMasks = recentMasks;
    _packReferenceToPack = packReferenceToPack;
}

#pragma mark -

- (void)cancelButtonPressed
{
    [self dismissWithCompletion:nil];
}

- (void)scrollToSection:(NSUInteger)section
{
    _ignoreSetSection = false;
    
    [_tabPanel setCurrentStickerPackIndex:section animated:false];
    
    NSArray *recentDocuments = _section == TGPhotoStickersViewSectionMasks ? _recentMasks : _recentStickers;
    NSArray *stickerPacks = _section == TGPhotoStickersViewSectionMasks ? _maskStickerPacks : _genericStickerPacks;
    
    if (section == 0)
    {
        if (recentDocuments.count != 0)
        {
            _ignoreSetSection = true;
            [_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:true];
        }
        else
        {
            _ignoreSetSection = true;
            [_collectionView setContentOffset:CGPointMake(0.0f, -_collectionView.contentInset.top) animated:true];
        }
    }
    else
    {
        if (section == 1 && recentDocuments.count == 0) {
            _ignoreSetSection = true;
            [_collectionView setContentOffset:CGPointMake(0.0f, -_collectionView.contentInset.top) animated:true];
        } else if (((TGStickerPack *)stickerPacks[section - 1]).documents.count != 0) {
            UICollectionViewLayoutAttributes *attributes = [_collectionView layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]];
            
            CGFloat verticalOffset = attributes.frame.origin.y - [self collectionView:_collectionView layout:_collectionLayout minimumLineSpacingForSectionAtIndex:section];
            CGFloat effectiveInset = 0.0f;
            if (verticalOffset < _collectionView.contentOffset.y)
                effectiveInset = _collectionView.contentInset.top + TGPhotoStickersSectionHeaderHeight;
            else
                effectiveInset = TGPhotoStickersPreloadInset;
            
            effectiveInset -= 8.0f;
            
            CGFloat contentOffset = verticalOffset - effectiveInset;
            if (contentOffset > _collectionView.contentSize.height - _collectionView.frame.size.height + _collectionView.contentInset.bottom) {
                contentOffset = _collectionView.contentSize.height - _collectionView.frame.size.height + _collectionView.contentInset.bottom;
            }
            
            _ignoreSetSection = true;
            [_collectionView setContentOffset:CGPointMake(0.0f, contentOffset) animated:true];
        }
    }
}

- (void)updateCurrentSection
{
    NSArray *layoutAttributes = [_collectionLayout layoutAttributesForElementsInRect:CGRectMake(0.0f, _collectionView.contentOffset.y - 45.0f + TGPhotoStickersPreloadInset + 7.0f, _collectionView.frame.size.width, _collectionView.frame.size.height - 45.0f - TGPhotoStickersPreloadInset - 7.0f)];
    NSInteger minSection = INT_MAX;
    for (UICollectionViewLayoutAttributes *attributes in layoutAttributes)
    {
        minSection = MIN(attributes.indexPath.section, minSection);
    }
    if (minSection != INT_MAX)
        [_tabPanel setCurrentStickerPackIndex:minSection animated:true];
}

#pragma mark -

- (void)present
{
    self.userInteractionEnabled = true;
    
    if ([_context currentSizeClass] == UIUserInterfaceSizeClassCompact)
    {
        void (^changeBlock)(void) = ^
        {
            if (iosMajorVersion() >= 8)
                ((UIVisualEffectView *)_blurView).effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            else
                _blurView.alpha = 1.0f;
            _wrapperView.alpha = 1.0f;
        };
        
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:changeBlock completion:nil];
    }
    else
    {
        self.alpha = 0.0f;
        
        self.layer.rasterizationScale = TGScreenScaling();
        self.layer.shouldRasterize = true;
        
        [UIView animateWithDuration:0.2 animations:^
        {
            self.alpha = 1.0f;
        } completion:^(__unused BOOL finished)
        {
            self.layer.shouldRasterize = false;
        }];
    }
}

- (void)dismissWithCompletion:(void (^)(void))completion
{
    self.userInteractionEnabled = false;
    
    if ([_context currentSizeClass] == UIUserInterfaceSizeClassCompact)
    {
        void (^changeBlock)(void) = ^
        {
            if (iosMajorVersion() >= 8)
                ((UIVisualEffectView *)_blurView).effect = nil;
            else
                _blurView.alpha = 0.0f;
            _wrapperView.alpha = 0.0f;
        };
        
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:changeBlock completion:^(__unused BOOL finished)
        {
            if (self.dismissed != nil)
                self.dismissed();
            
            if (completion != nil)
                completion();
        }];
    }
    else
    {
        self.layer.rasterizationScale = TGScreenScaling();
        self.layer.shouldRasterize = true;
        
        [UIView animateWithDuration:0.2 animations:^
        {
            self.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (self.dismissed != nil)
                self.dismissed();
            
            if (completion != nil)
                completion();
        }];
    }
}

- (void)dismissWithSnapshotView:(UIView *)outSnapshotview startPoint:(CGPoint)startPoint targetFrame:(CGRect)targetFrame targetRotation:(CGFloat)targetRotation completion:(void (^)(void))completion
{
    [self dismissWithCompletion:^
    {
        for (UICollectionViewCell *cell in _collectionView.visibleCells)
            cell.hidden = false;
    }];
    
    [self.outerView addSubview:outSnapshotview];
    outSnapshotview.center = startPoint;
    
    UIView *inSnapshotView = [outSnapshotview snapshotViewAfterScreenUpdates:false];
    inSnapshotView.center = [self.outerView convertPoint:startPoint toView:self.targetView];
    [self.targetView addSubview:inSnapshotView];
    
    CGAffineTransform inTransform = CGAffineTransformInvert(self.targetView.transform);
    inTransform = CGAffineTransformConcat(inTransform, CGAffineTransformInvert(self.targetView.superview.transform));
    inSnapshotView.transform = inTransform;
    
    CGFloat targetScale = targetFrame.size.width / outSnapshotview.frame.size.width * 0.985f;
    CGAffineTransform targetTransform = CGAffineTransformScale(outSnapshotview.transform, targetScale, targetScale);
    targetTransform = CGAffineTransformRotate(targetTransform, targetRotation);
    
    CGAffineTransform middleTransform = CGAffineTransformScale(targetTransform, 1.17f, 1.17f);
    
    [UIView animateWithDuration:0.35 delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
    {
        CGPoint targetPoint = TGPaintCenterOfRect(targetFrame);
        outSnapshotview.center = targetPoint;
        inSnapshotView.center = [self.outerView convertPoint:targetPoint toView:self.targetView];
    } completion:nil];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        outSnapshotview.transform = middleTransform;
        inSnapshotView.transform = CGAffineTransformConcat(middleTransform, inTransform);
    } completion:^(__unused BOOL finished)
    {
        [UIView animateWithDuration:0.15 delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            outSnapshotview.transform = targetTransform;
            inSnapshotView.transform = CGAffineTransformConcat(targetTransform, inTransform);
            outSnapshotview.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [outSnapshotview removeFromSuperview];
            [inSnapshotView removeFromSuperview];
            
            if (completion != nil)
                completion();
        }];
    }];
}
#pragma mark - 

- (TGStickerPack *)stickerPackAtIndexPath:(NSIndexPath *)indexPath
{
    if (_section == TGPhotoStickersViewSectionMasks) {
        if (indexPath.section == 0)
        {
            TGDocumentMediaAttachment *document = [self documentAtIndexPath:indexPath];
            id<TGStickerPackReference> packReference = document.stickerPackReference;
            if (packReference != nil) {
                return _packReferenceToPack[packReference];
            }
        }
        else
        {
            return _maskStickerPacks[indexPath.section - 1];
        }
    } else {
        if (indexPath.section == 0)
        {
            TGDocumentMediaAttachment *document = [self documentAtIndexPath:indexPath];
            id<TGStickerPackReference> packReference = document.stickerPackReference;
            if (packReference != nil) {
                return _packReferenceToPack[packReference];
            }
        }
        else
        {
            return _genericStickerPacks[indexPath.section - 1];
        }
    }
    return nil;
}

- (TGDocumentMediaAttachment *)documentAtIndexPath:(NSIndexPath *)indexPath
{
    if (_section == TGPhotoStickersViewSectionMasks) {
        if (indexPath.section == 0)
            return _recentMasks[indexPath.item];
        else
            return ((TGStickerPack *)_maskStickerPacks[indexPath.section - 1]).documents[indexPath.item];
    } else {
        if (indexPath.section == 0)
            return _recentStickers[indexPath.item];
        else
            return ((TGStickerPack *)_genericStickerPacks[indexPath.section - 1]).documents[indexPath.item];
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGStickerCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TGStickerCollectionViewCell" forIndexPath:indexPath];
    [cell setDocumentMedia:[self documentAtIndexPath:indexPath]];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)__unused collectionView setupSectionHeaderView:(TGPhotoStickersSectionHeaderView *)sectionHeaderView forSectionHeader:(TGPhotoStickersSectionHeader *)sectionHeader
{
    NSString *title = TGLocalized(@"Paint.RecentStickers");
    
    if (sectionHeader.index > 0)
    {
        if (_section == TGPhotoStickersViewSectionMasks) {
            TGStickerPack *stickerPack = _maskStickerPacks[sectionHeader.index - 1];
            title = stickerPack.title;
        } else {
            TGStickerPack *stickerPack = _genericStickerPacks[sectionHeader.index - 1];
            title = stickerPack.title;
        }
    }
    
    [sectionHeaderView setTitle:title];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)__unused collectionView
{
    if (_section == TGPhotoStickersViewSectionMasks) {
        return 1 + _maskStickerPacks.count;
    } else {
        return 1 + _genericStickerPacks.count;
    }
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)section
{
    if (_section == TGPhotoStickersViewSectionMasks) {
        if (section == 0) {
            return (NSInteger)_recentMasks.count;
        } else {
            return ((TGStickerPack *)_maskStickerPacks[section - 1]).documents.count;
        }
    } else {
        if (section == 0) {
            return (NSInteger)_recentStickers.count;
        } else {
            return ((TGStickerPack *)_genericStickerPacks[section - 1]).documents.count;
        }
    }
}

- (CGSize)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return CGSizeMake(62.0f, 62.0f);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    CGFloat sideInset = (collectionView.frame.size.width < 330.0f) ? 3.0f : 15.0f;
    CGFloat bottomInset = (section == [self numberOfSectionsInCollectionView:collectionView] - 1) ? 14.0f : 0.0f;

    NSArray *recent = (_section == TGPhotoStickersViewSectionMasks) ? _recentMasks : _recentStickers;
    if (section == 0 && recent.count == 0)
        return UIEdgeInsetsMake(0, 0, 0, 0);
    
    return UIEdgeInsetsMake(TGPhotoStickersSectionHeaderHeight, sideInset, bottomInset, sideInset);
}

- (CGFloat)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return 7.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)__unused collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)__unused section
{
    return (collectionView.frame.size.width < 330.0f) ? 0.0f : 4.0f;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGStickerCollectionViewCell *cell = (TGStickerCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isEnabled])
    {
        [cell setDisabledTimeout];
        
        if (_section == TGPhotoStickersViewSectionMasks) {
            TGDocumentMediaAttachment *document = [self documentAtIndexPath:indexPath];
            
            if (self.stickerSelected != nil)
                self.stickerSelected(document, [cell.superview convertPoint:cell.center toView:self.outerView], self, [cell snapshotViewAfterScreenUpdates:false]);
        } else {
            TGDocumentMediaAttachment *document = [self documentAtIndexPath:indexPath];
            if (self.stickerSelected != nil)
                self.stickerSelected(document, [cell.superview convertPoint:cell.center toView:self.outerView], self, [cell snapshotViewAfterScreenUpdates:false]);
        }
        
        cell.hidden = true;
    }
}

#pragma mark - 

- (void)scrollViewDidScroll:(UIScrollView *)__unused scrollView
{
    if (!_ignoreSetSection)
        [self updateCurrentSection];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)__unused scrollView
{
    _ignoreSetSection = false;
    [self updateCurrentSection];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)__unused scrollView
{
    _ignoreSetSection = false;
    [self updateCurrentSection];
}

#pragma mark -

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    _tabPanel.safeAreaInset = safeAreaInset;
    _collectionView.contentInset = UIEdgeInsetsMake(TGPhotoStickersPreloadInset - TGPhotoStickersSectionHeaderHeight, 0.0f, TGPhotoStickersPreloadInset + _safeAreaInset.bottom, 0.0f);
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    bool compact = [_context currentSizeClass] == UIUserInterfaceSizeClassCompact;
    if (compact)
    {
        CGRect previousRect = _blurView.frame;
        _blurView.frame = self.bounds;
        
        if (!CGRectEqualToRect(previousRect, _blurView.frame))
            [_collectionLayout invalidateLayout];
        
        _segmentedControl.frame = CGRectMake(12.0f + _safeAreaInset.left, 12.0f + _safeAreaInset.top, self.frame.size.width - _safeAreaInset.left - _safeAreaInset.right - 17.0f * 2 - _cancelButton.frame.size.width, _segmentedControl.frame.size.height);
    }
    else
    {
        _wrapperView.frame = CGRectMake(0.0f, 0.0f, self.bounds.size.width, self.bounds.size.height - TGPhotoStickersViewMargin);
        _backgroundView.frame = CGRectMake(TGPhotoStickersViewMargin, TGPhotoStickersViewMargin, self.frame.size.width - TGPhotoStickersViewMargin * 2, self.frame.size.height - TGPhotoStickersViewMargin * 2 + 13.0f);
        
        bounds = CGRectInset(bounds, TGPhotoStickersViewMargin, TGPhotoStickersViewMargin);
        
        _segmentedControl.frame = CGRectMake(bounds.origin.x + 12.0f, bounds.origin.y + 12.0f, bounds.size.width - 24.0f, _segmentedControl.frame.size.height);
    }
    
    if (compact)
    {
        _cancelButton.frame = CGRectMake(bounds.origin.x + bounds.size.width - _cancelButton.frame.size.width - 11.0f - _safeAreaInset.right, bounds.origin.y + 4.0f + _safeAreaInset.top, _cancelButton.frame.size.width, 44.0f);
    }
    
    _tabPanel.frame = CGRectMake(bounds.origin.x, bounds.origin.y + 50.0f + _safeAreaInset.top, bounds.size.width, _tabPanel.frame.size.height);
    
    _collectionWrapperView.frame = CGRectMake(bounds.origin.x + _safeAreaInset.left, CGRectGetMaxY(_tabPanel.frame) + TGPhotoStickersSectionHeaderHeight - 8.0f, bounds.size.width - _safeAreaInset.left - _safeAreaInset.right, bounds.size.height - CGRectGetMaxY(_tabPanel.frame) + bounds.origin.y - TGPhotoStickersSectionHeaderHeight + 8.0f);
    _collectionView.frame = CGRectMake(0.0f, -TGPhotoStickersPreloadInset + 8.0f, _collectionWrapperView.frame.size.width, _collectionWrapperView.frame.size.height + 2 * TGPhotoStickersPreloadInset);
    _headersView.frame = [_collectionWrapperView convertRect:_collectionView.frame toView:_wrapperView];
    
    CGFloat thickness = TGScreenPixel;
    _separatorView.frame = CGRectMake(bounds.origin.x, bounds.origin.y + 143.0f - thickness, bounds.size.width, thickness);
}

- (void)segmentedControlChanged
{
    int index = (int)_segmentedControl.selectedSegmentIndex;
    TGPhotoStickersViewSection section = (TGPhotoStickersViewSection)index;
    
    if (section == TGPhotoStickersViewSectionMasks)
        _stickersContentOffset = _collectionView.contentOffset.y;
    else
        _masksContentOffset = _collectionView.contentOffset.y;
    
    if (section != _section) {
        _section = section;
        
        [_tabPanel setStickerPacks:_section == TGPhotoStickersViewSectionMasks ? _maskStickerPacks : _genericStickerPacks showRecent:_section == TGPhotoStickersViewSectionMasks ? (_recentMasks.count != 0) : (_recentStickers.count != 0) showFavorite:false showGroup:false showGroupLast:false showGifs:false showTrendingFirst:false showTrendingLast:false];
        [_collectionView reloadData];
        
        [self updateCurrentSection];
        
        CGPoint contentOffset = CGPointMake(0, -_collectionView.contentInset.top);
        if (section == TGPhotoStickersViewSectionMasks && fabs(_masksContentOffset - FLT_MAX) > FLT_EPSILON)
            contentOffset = CGPointMake(0, _masksContentOffset);
        else if (section == TGPhotoStickersViewSectionGeneric && fabs(_stickersContentOffset - FLT_MAX) > FLT_EPSILON)
            contentOffset = CGPointMake(0, _stickersContentOffset);
        [_collectionView setContentOffset:contentOffset];
    }
}

@end
