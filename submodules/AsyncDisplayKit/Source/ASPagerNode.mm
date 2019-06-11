//
//  ASPagerNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASPagerNode.h>
#import <AsyncDisplayKit/ASPagerNode+Beta.h>

#import <AsyncDisplayKit/ASCollectionGalleryLayoutDelegate.h>
#import <AsyncDisplayKit/ASCollectionNode+Beta.h>
#import <AsyncDisplayKit/ASDelegateProxy.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASPagerFlowLayout.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>
#import <AsyncDisplayKit/UIResponder+AsyncDisplayKit.h>

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionDelegate, ASCollectionDelegateFlowLayout, ASDelegateProxyInterceptor, ASCollectionGalleryLayoutPropertiesProviding>
{
  __weak id <ASPagerDataSource> _pagerDataSource;
  ASPagerNodeProxy *_proxyDataSource;
  struct {
    unsigned nodeBlockAtIndex:1;
    unsigned nodeAtIndex:1;
  } _pagerDataSourceFlags;

  __weak id <ASPagerDelegate> _pagerDelegate;
  ASPagerNodeProxy *_proxyDelegate;
}

@end

@implementation ASPagerNode

@dynamic view, delegate, dataSource;

#pragma mark - Lifecycle

- (instancetype)init
{
  ASPagerFlowLayout *flowLayout = [[ASPagerFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  return [self initWithCollectionViewLayout:flowLayout];
}

- (instancetype)initWithCollectionViewLayout:(ASPagerFlowLayout *)flowLayout;
{
  ASDisplayNodeAssert([flowLayout isKindOfClass:[ASPagerFlowLayout class]], @"ASPagerNode requires a flow layout.");
  ASDisplayNodeAssertTrue(flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal);
  self = [super initWithCollectionViewLayout:flowLayout];
  return self;
}

- (instancetype)initUsingAsyncCollectionLayout
{
  ASCollectionGalleryLayoutDelegate *layoutDelegate = [[ASCollectionGalleryLayoutDelegate alloc] initWithScrollableDirections:ASScrollDirectionHorizontalDirections];
  self = [super initWithLayoutDelegate:layoutDelegate layoutFacilitator:nil];
  if (self) {
    layoutDelegate.propertiesProvider = self;
  }
  return self;
}

#pragma mark - ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *cv = self.view;
  cv.asyncDataSource = (id<ASCollectionDataSource>)_proxyDataSource ?: self;
  cv.asyncDelegate = (id<ASCollectionDelegate>)_proxyDelegate ?: self;
#if TARGET_OS_IOS
  cv.pagingEnabled = YES;
  cv.scrollsToTop = NO;
#endif
  cv.allowsSelection = NO;
  cv.showsVerticalScrollIndicator = NO;
  cv.showsHorizontalScrollIndicator = NO;

  ASRangeTuningParameters minimumRenderParams = { .leadingBufferScreenfuls = 0.0, .trailingBufferScreenfuls = 0.0 };
  ASRangeTuningParameters minimumPreloadParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  [self setTuningParameters:minimumRenderParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:minimumPreloadParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypePreload];
  
  ASRangeTuningParameters fullRenderParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  ASRangeTuningParameters fullPreloadParams = { .leadingBufferScreenfuls = 2.0, .trailingBufferScreenfuls = 2.0 };
  [self setTuningParameters:fullRenderParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:fullPreloadParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypePreload];
}

#pragma mark - Getters / Setters

- (NSInteger)currentPageIndex
{
  return (self.view.contentOffset.x / [self pageSize].width);
}

- (CGSize)pageSize
{
  UIEdgeInsets contentInset = self.contentInset;
  CGSize pageSize = self.bounds.size;
  pageSize.height -= (contentInset.top + contentInset.bottom);
  return pageSize;
}

#pragma mark - Helpers

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
  [self scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:animated];
}

- (ASCellNode *)nodeForPageAtIndex:(NSInteger)index
{
  return [self nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
}

- (NSInteger)indexOfPageWithNode:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (!indexPath) {
    return NSNotFound;
  }
  return indexPath.row;
}

#pragma mark - ASCollectionGalleryLayoutPropertiesProviding

- (CGSize)galleryLayoutDelegate:(nonnull ASCollectionGalleryLayoutDelegate *)delegate sizeForElements:(nonnull ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  return [self pageSize];
}

#pragma mark - ASCollectionDataSource

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (_pagerDataSourceFlags.nodeBlockAtIndex) {
    return [_pagerDataSource pagerNode:self nodeBlockAtIndex:indexPath.item];
  } else if (_pagerDataSourceFlags.nodeAtIndex) {
    ASCellNode *node = [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
    return ^{ return node; };
  } else {
    ASDisplayNodeFailAssert(@"Pager data source must implement either %@ or %@. Data source: %@", NSStringFromSelector(@selector(pagerNode:nodeBlockAtIndex:)), NSStringFromSelector(@selector(pagerNode:nodeAtIndex:)), _pagerDataSource);
    return ^{
      return [[ASCellNode alloc] init];
    };
  }
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

#pragma mark - ASCollectionDelegate

- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake([self pageSize]);
}

#pragma mark - Data Source Proxy

- (id <ASPagerDataSource>)dataSource
{
  return _pagerDataSource;
}

- (void)setDataSource:(id <ASPagerDataSource>)dataSource
{
  if (dataSource != _pagerDataSource) {
    _pagerDataSource = dataSource;
    
    if (dataSource == nil) {
      memset(&_pagerDataSourceFlags, 0, sizeof(_pagerDataSourceFlags));
    } else {
      _pagerDataSourceFlags.nodeBlockAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeBlockAtIndex:)];
      _pagerDataSourceFlags.nodeAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeAtIndex:)];
    }
    
    _proxyDataSource = dataSource ? [[ASPagerNodeProxy alloc] initWithTarget:dataSource interceptor:self] : nil;
    
    super.dataSource = (id <ASCollectionDataSource>)_proxyDataSource;
  }
}

- (void)setDelegate:(id<ASPagerDelegate>)delegate
{
  if (delegate != _pagerDelegate) {
    _pagerDelegate = delegate;
    _proxyDelegate = delegate ? [[ASPagerNodeProxy alloc] initWithTarget:delegate interceptor:self] : nil;
    super.delegate = (id <ASCollectionDelegate>)_proxyDelegate;
  }
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  [self setDataSource:nil];
  [self setDelegate:nil];
}

- (void)didEnterHierarchy
{
	[super didEnterHierarchy];

	// Check that our view controller does not automatically set our content insets
	// In every use case I can imagine, the pager is not hosted inside a range-managed node.
	if (_allowsAutomaticInsetsAdjustment == NO) {
		UIViewController *vc = [self.view asdk_associatedViewController];
		if (vc.automaticallyAdjustsScrollViewInsets) {
			NSLog(@"AsyncDisplayKit: ASPagerNode is setting automaticallyAdjustsScrollViewInsets=NO on its owning view controller %@. This automatic behavior will be disabled in the future. Set allowsAutomaticInsetsAdjustment=YES on the pager node to suppress this behavior.", vc);
			vc.automaticallyAdjustsScrollViewInsets = NO;
		}
	}
}

@end

#endif
