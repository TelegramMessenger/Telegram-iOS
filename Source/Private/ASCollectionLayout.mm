//
//  ASCollectionLayout.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayout.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutCache.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext+Private.h>
#import <AsyncDisplayKit/ASCollectionLayoutDelegate.h>
#import <AsyncDisplayKit/ASCollectionLayoutState+Private.h>
#import <AsyncDisplayKit/ASCollectionNode+Beta.h>
#import <AsyncDisplayKit/ASDispatch.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASPageTable.h>

static const ASRangeTuningParameters kASDefaultMeasureRangeTuningParameters = {
  .leadingBufferScreenfuls = 2.0,
  .trailingBufferScreenfuls = 2.0
};

static const ASScrollDirection kASStaticScrollDirection = (ASScrollDirectionRight | ASScrollDirectionDown);

@interface ASCollectionLayout () <ASDataControllerLayoutDelegate> {
  ASCollectionLayoutCache *_layoutCache;
  ASCollectionLayoutState *_layout; // Main thread only.

  struct {
    unsigned int implementsAdditionalInfoForLayoutWithElements:1;
  } _layoutDelegateFlags;
}

@end

@implementation ASCollectionLayout

- (instancetype)initWithLayoutDelegate:(id<ASCollectionLayoutDelegate>)layoutDelegate
{
  self = [super init];
  if (self) {
    ASDisplayNodeAssertNotNil(layoutDelegate, @"Collection layout delegate cannot be nil");
    _layoutDelegate = layoutDelegate;
    _layoutDelegateFlags.implementsAdditionalInfoForLayoutWithElements = [layoutDelegate respondsToSelector:@selector(additionalInfoForLayoutWithElements:)];
    _layoutCache = [[ASCollectionLayoutCache alloc] init];
  }
  return self;
}

#pragma mark - ASDataControllerLayoutDelegate

- (ASCollectionLayoutContext *)layoutContextWithElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();

  Class<ASCollectionLayoutDelegate> layoutDelegateClass = [_layoutDelegate class];
  ASCollectionLayoutCache *layoutCache = _layoutCache;
  ASCollectionNode *collectionNode = _collectionNode;
  if (collectionNode == nil) {
    return [[ASCollectionLayoutContext alloc] initWithViewportSize:CGSizeZero
                                              initialContentOffset:CGPointZero
                                              scrollableDirections:ASScrollDirectionNone
                                                          elements:[[ASElementMap alloc] init]
                                               layoutDelegateClass:layoutDelegateClass
                                                       layoutCache:layoutCache
                                                    additionalInfo:nil];
  }

  ASScrollDirection scrollableDirections = [_layoutDelegate scrollableDirections];
  CGSize viewportSize = [ASCollectionLayout _viewportSizeForCollectionNode:collectionNode scrollableDirections:scrollableDirections];
  CGPoint contentOffset = collectionNode.contentOffset;

  id additionalInfo = nil;
  if (_layoutDelegateFlags.implementsAdditionalInfoForLayoutWithElements) {
    additionalInfo = [_layoutDelegate additionalInfoForLayoutWithElements:elements];
  }

  return [[ASCollectionLayoutContext alloc] initWithViewportSize:viewportSize
                                            initialContentOffset:contentOffset
                                            scrollableDirections:scrollableDirections
                                                        elements:elements
                                             layoutDelegateClass:layoutDelegateClass
                                                     layoutCache:layoutCache
                                                  additionalInfo:additionalInfo];
}

+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context
{
  if (context.elements == nil) {
    return [[ASCollectionLayoutState alloc] initWithContext:context];
  }

  ASCollectionLayoutState *layout = [context.layoutDelegateClass calculateLayoutWithContext:context];
  [context.layoutCache setLayout:layout forContext:context];

  // Measure elements in the measure range ahead of time
  CGSize viewportSize = context.viewportSize;
  CGPoint contentOffset = context.initialContentOffset;
  CGRect initialRect = CGRectMake(contentOffset.x, contentOffset.y, viewportSize.width, viewportSize.height);
  CGRect measureRect = CGRectExpandToRangeWithScrollableDirections(initialRect,
                                                                   kASDefaultMeasureRangeTuningParameters,
                                                                   context.scrollableDirections,
                                                                   kASStaticScrollDirection);
  // The first call to -layoutAttributesForElementsInRect: will be with a rect that is way bigger than initialRect here.
  // If we only block on initialRect, a few elements that are outside of initialRect but inside measureRect
  // may not be available by the time -layoutAttributesForElementsInRect: is called.
  // Since this method is usually run off main, let's spawn more threads to measure and block on all elements in measureRect.
  [self _measureElementsInRect:measureRect blockingRect:measureRect layout:layout];

  return layout;
}

#pragma mark - UICollectionViewLayout overrides

- (void)prepareLayout
{
  ASDisplayNodeAssertMainThread();
  [super prepareLayout];

  ASCollectionLayoutContext *context = [self layoutContextWithElements:_collectionNode.visibleElements];
  if (_layout != nil && ASObjectIsEqual(_layout.context, context)) {
    // The existing layout is still valid. No-op
    return;
  }

  if (ASCollectionLayoutState *cachedLayout = [_layoutCache layoutForContext:context]) {
    _layout = cachedLayout;
  } else {
    // A new layout is needed now. Calculate and apply it immediately
    _layout = [ASCollectionLayout calculateLayoutWithContext:context];
  }
}

- (void)invalidateLayout
{
  ASDisplayNodeAssertMainThread();
  [super invalidateLayout];
  if (_layout != nil) {
    [_layoutCache removeLayoutForContext:_layout.context];
    _layout = nil;
  }
}

/**
 * NOTE: It is suggested practice on the Web to override invalidationContextForInteractivelyMovingItems… and call out to the
 * data source to move the item (so that if e.g. the item size depends on the data, you get the data you expect). However, as of iOS 11 this
 * doesn't work, because UICV machinery will also call out to the data source to move the item after the interaction is done. The result is
 * that your data source state will be incorrect due to this last move call. Plus it's just an API violation.
 *
 * Things tried:
 *   - Doing the speculative data source moves, and then UNDOING the last one in invalidationContextForEndingInteractiveMovementOfItems…
 *     but this does not work because the UICV machinery informs its data source before it calls that method on us, so we are too late.
 *
 * The correct practice is to use the UIDataSourceTranslating API introduced in iOS 11. Currently Texture does not support this API but we can
 * build it if there is demand. We could add an id<UIDataSourceTranslating> field onto the layout context object, and the layout client can
 * use data source index paths when it reads nodes or other data source data.
 */

- (CGSize)collectionViewContentSize
{
  ASDisplayNodeAssertMainThread();
  // The content size can be queried right after a layout invalidation (https://github.com/TextureGroup/Texture/pull/509).
  // In that case, return zero.
  return _layout ? _layout.contentSize : CGSizeZero;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)blockingRect
{
  ASDisplayNodeAssertMainThread();
  if (CGRectIsEmpty(blockingRect)) {
    return nil;
  }

  // Measure elements in the measure range, block on the requested rect
  CGRect measureRect = CGRectExpandToRangeWithScrollableDirections(blockingRect,
                                                                   kASDefaultMeasureRangeTuningParameters,
                                                                   _layout.context.scrollableDirections,
                                                                   kASStaticScrollDirection);
  [ASCollectionLayout _measureElementsInRect:measureRect blockingRect:blockingRect layout:_layout];
  
  NSArray<UICollectionViewLayoutAttributes *> *result = [_layout layoutAttributesForElementsInRect:blockingRect];

  ASElementMap *elements = _layout.context.elements;
  for (UICollectionViewLayoutAttributes *attrs in result) {
    ASCollectionElement *element = [elements elementForLayoutAttributes:attrs];
    ASCollectionLayoutSetSizeToElement(attrs.frame.size, element);
  }

  return result;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();

  ASCollectionElement *element = [_layout.context.elements elementForItemAtIndexPath:indexPath];
  UICollectionViewLayoutAttributes *attrs = [_layout layoutAttributesForElement:element];

  ASCellNode *node = element.node;
  CGSize elementSize = attrs.frame.size;
  if (! CGSizeEqualToSize(elementSize, node.calculatedSize)) {
    [node layoutThatFits:ASCollectionLayoutElementSizeRangeFromSize(elementSize)];
  }

  ASCollectionLayoutSetSizeToElement(attrs.frame.size, element);
  return attrs;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionElement *element = [_layout.context.elements supplementaryElementOfKind:elementKind atIndexPath:indexPath];
  UICollectionViewLayoutAttributes *attrs = [_layout layoutAttributesForElement:element];

  ASCellNode *node = element.node;
  CGSize elementSize = attrs.frame.size;
  if (! CGSizeEqualToSize(elementSize, node.calculatedSize)) {
    [node layoutThatFits:ASCollectionLayoutElementSizeRangeFromSize(elementSize)];
  }

  ASCollectionLayoutSetSizeToElement(attrs.frame.size, element);
  return attrs;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
  return (! CGSizeEqualToSize([ASCollectionLayout _boundsForCollectionNode:_collectionNode], newBounds.size));
}

#pragma mark - Private methods

+ (CGSize)_boundsForCollectionNode:(nonnull ASCollectionNode *)collectionNode
{
  if (collectionNode == nil) {
    return CGSizeZero;
  }

  if (!collectionNode.isNodeLoaded) {
    // TODO consider calculatedSize as well
    return collectionNode.threadSafeBounds.size;
  }

  ASDisplayNodeAssertMainThread();
  return collectionNode.view.bounds.size;
}

+ (CGSize)_viewportSizeForCollectionNode:(nonnull ASCollectionNode *)collectionNode scrollableDirections:(ASScrollDirection)scrollableDirections
{
  if (collectionNode == nil) {
    return CGSizeZero;
  }

  CGSize result = [ASCollectionLayout _boundsForCollectionNode:collectionNode];
  // TODO: Consider using adjustedContentInset on iOS 11 and later, to include the safe area of the scroll view
  UIEdgeInsets contentInset = collectionNode.contentInset;
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections)) {
    result.height -= (contentInset.top + contentInset.bottom);
  } else {
    result.width -= (contentInset.left + contentInset.right);
  }
  return result;
}

/**
 * Measures all elements in the specified rect and blocks the calling thread while measuring those in the blocking rect.
 */
+ (void)_measureElementsInRect:(CGRect)rect blockingRect:(CGRect)blockingRect layout:(ASCollectionLayoutState *)layout
{
  if (CGRectIsEmpty(rect) || layout.context.elements == nil) {
    return;
  }
  BOOL hasBlockingRect = !CGRectIsEmpty(blockingRect);
  if (hasBlockingRect && CGRectContainsRect(rect, blockingRect) == NO) {
    ASDisplayNodeCAssert(NO, @"Blocking rect, if specified, must be within the other (outer) rect");
    return;
  }

  // Step 1: Clamp the specified rects between the bounds of content rect
  CGSize contentSize = layout.contentSize;
  CGRect contentRect = CGRectMake(0, 0, contentSize.width, contentSize.height);
  rect = CGRectIntersection(contentRect, rect);
  if (CGRectIsNull(rect)) {
    return;
  }
  if (hasBlockingRect) {
    blockingRect = CGRectIntersection(contentRect, blockingRect);
    hasBlockingRect = !CGRectIsNull(blockingRect);
  }

  // Step 2: Get layout attributes of all elements within the specified outer rect
  ASPageToLayoutAttributesTable *attrsTable = [layout getAndRemoveUnmeasuredLayoutAttributesPageTableInRect:rect];
  if (attrsTable.count == 0) {
    // No elements in this rect! Bail early
    return;
  }

  // Step 3: Split all those attributes into blocking and non-blocking buckets
  // Use ordered sets here because some items may span multiple pages, and the sets will be accessed by indexes later on.
  ASCollectionLayoutContext *context = layout.context;
  CGSize pageSize = context.viewportSize;
  NSMutableOrderedSet<UICollectionViewLayoutAttributes *> *blockingAttrs = hasBlockingRect ? [NSMutableOrderedSet orderedSet] : nil;
  NSMutableOrderedSet<UICollectionViewLayoutAttributes *> *nonBlockingAttrs = [NSMutableOrderedSet orderedSet];
  for (id pagePtr in attrsTable) {
    ASPageCoordinate page = (ASPageCoordinate)pagePtr;
    NSArray<UICollectionViewLayoutAttributes *> *attrsInPage = [attrsTable objectForPage:page];
    // Calculate the page's rect but only if it's going to be used.
    CGRect pageRect = hasBlockingRect ? ASPageCoordinateGetPageRect(page, pageSize) : CGRectZero;

    if (hasBlockingRect && CGRectContainsRect(blockingRect, pageRect)) {
      // The page fits well within the blocking rect. All attributes in this page are blocking.
      [blockingAttrs addObjectsFromArray:attrsInPage];
    } else if (hasBlockingRect && CGRectIntersectsRect(blockingRect, pageRect)) {
      // The page intersects the blocking rect. Some elements in this page are blocking, some are not.
      for (UICollectionViewLayoutAttributes *attrs in attrsInPage) {
        if (CGRectIntersectsRect(blockingRect, attrs.frame)) {
          [blockingAttrs addObject:attrs];
        } else {
          [nonBlockingAttrs addObject:attrs];
        }
      }
    } else {
      // The page doesn't intersect the blocking rect. All elements in this page are non-blocking.
      [nonBlockingAttrs addObjectsFromArray:attrsInPage];
    }
  }

  // Step 4: Allocate and measure blocking elements' node
  ASElementMap *elements = context.elements;
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  if (NSUInteger count = blockingAttrs.count) {
    ASDispatchApply(count, queue, 0, ^(size_t i) {
      UICollectionViewLayoutAttributes *attrs = blockingAttrs[i];
      ASCellNode *node = [elements elementForItemAtIndexPath:attrs.indexPath].node;
      CGSize expectedSize = attrs.frame.size;
      if (! CGSizeEqualToSize(expectedSize, node.calculatedSize)) {
        [node layoutThatFits:ASCollectionLayoutElementSizeRangeFromSize(expectedSize)];
      }
    });
  }

  // Step 5: Allocate and measure non-blocking ones
  if (NSUInteger count = nonBlockingAttrs.count) {
    __weak ASElementMap *weakElements = elements;
    ASDispatchAsync(count, queue, 0, ^(size_t i) {
      __strong ASElementMap *strongElements = weakElements;
      if (strongElements) {
        UICollectionViewLayoutAttributes *attrs = nonBlockingAttrs[i];
        ASCellNode *node = [elements elementForItemAtIndexPath:attrs.indexPath].node;
        CGSize expectedSize = attrs.frame.size;
        if (! CGSizeEqualToSize(expectedSize, node.calculatedSize)) {
          [node layoutThatFits:ASCollectionLayoutElementSizeRangeFromSize(expectedSize)];
        }
      }
    });
  }
}

# pragma mark - Convenient inline functions

ASDISPLAYNODE_INLINE ASSizeRange ASCollectionLayoutElementSizeRangeFromSize(CGSize size)
{
  // The layout delegate consulted us that this element must fit within this size,
  // and the only way to achieve that without asking it again is to use an exact size range here.
  return ASSizeRangeMake(size);
}

ASDISPLAYNODE_INLINE void ASCollectionLayoutSetSizeToElement(CGSize size, ASCollectionElement *element)
{
  if (ASCellNode *node = element.node) {
    if (! CGSizeEqualToSize(size, node.frame.size)) {
      CGRect frame = CGRectZero;
      frame.size = size;
      node.frame = frame;
    }
  }
}

@end

#endif
