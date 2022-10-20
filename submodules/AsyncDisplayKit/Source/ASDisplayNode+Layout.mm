//
//  ASDisplayNode+Layout.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayout.h>
#import "ASLayoutElementStylePrivate.h"
#import <AsyncDisplayKit/NSArray+Diffing.h>

using AS::MutexLocker;

#pragma mark - ASDisplayNode (ASLayoutElement)

@implementation ASDisplayNode (ASLayoutElement)

#pragma mark <ASLayoutElement>

- (BOOL)implementsLayoutMethod
{
  MutexLocker l(__instanceLock__);
  return (_methodOverrides & (ASDisplayNodeMethodOverrideLayoutSpecThatFits |
                              ASDisplayNodeMethodOverrideCalcLayoutThatFits |
                              ASDisplayNodeMethodOverrideCalcSizeThatFits)) != 0 || _layoutSpecBlock != nil;
}


- (ASLayoutElementStyle *)style
{
  MutexLocker l(__instanceLock__);
  return [self _locked_style];
}

- (ASLayoutElementStyle *)_locked_style
{
  if (_style == nil) {
    _style = [[ASLayoutElementStyle alloc] init];
  }
  return _style;
}

- (ASLayoutElementType)layoutElementType
{
  return ASLayoutElementTypeDisplayNode;
}

- (NSArray<id<ASLayoutElement>> *)sublayoutElements
{
  return self.subnodes;
}

#pragma mark Measurement Pass

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
}

- (CGSize)measure:(CGSize)constrainedSize {
  return [self layoutThatFits:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;
}

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  ASScopedLockSelfOrToRoot();

  // If one or multiple layout transitions are in flight it still can happen that layout information is requested
  // on other threads. As the pending and calculated layout to be updated in the layout transition in here just a
  // layout calculation wil be performed without side effect
  if ([self _isLayoutTransitionInvalid]) {
    return [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize];
  }

  ASLayout *layout = nil;
  NSUInteger version = _layoutVersion;
  if (_calculatedDisplayNodeLayout.isValid(constrainedSize, parentSize, version)) {
    ASDisplayNodeAssertNotNil(_calculatedDisplayNodeLayout.layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _calculatedDisplayNodeLayout.layout should not be nil! %@", self);
    layout = _calculatedDisplayNodeLayout.layout;
  } else if (_pendingDisplayNodeLayout.isValid(constrainedSize, parentSize, version)) {
    ASDisplayNodeAssertNotNil(_pendingDisplayNodeLayout.layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _pendingDisplayNodeLayout.layout should not be nil! %@", self);
    layout = _pendingDisplayNodeLayout.layout;
  } else {
    // Create a pending display node layout for the layout pass
    layout = [self calculateLayoutThatFits:constrainedSize
                          restrictedToSize:self.style.size
                      relativeToParentSize:parentSize];
    _pendingDisplayNodeLayout = ASDisplayNodeLayout(layout, constrainedSize, parentSize,version);
    ASDisplayNodeAssertNotNil(layout, @"-[ASDisplayNode layoutThatFits:parentSize:] newly calculated layout should not be nil! %@", self);
  }
  
  return layout ?: [ASLayout layoutWithLayoutElement:self size:{0, 0}];
}

#pragma mark ASLayoutElementStyleExtensibility

ASLayoutElementStyleExtensibilityForwarding

#pragma mark ASPrimitiveTraitCollection

- (ASPrimitiveTraitCollection)primitiveTraitCollection
{
  return _primitiveTraitCollection.load();
}

- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(traitCollection, _primitiveTraitCollection.load()) == NO) {
    _primitiveTraitCollection = traitCollection;
    ASDisplayNodeLogEvent(self, @"asyncTraitCollectionDidChange: %@", NSStringFromASPrimitiveTraitCollection(traitCollection));

    [self asyncTraitCollectionDidChange];
  }
}

- (ASTraitCollection *)asyncTraitCollection
{
  return [ASTraitCollection traitCollectionWithASPrimitiveTraitCollection:self.primitiveTraitCollection];
}

#pragma mark - ASLayoutElementAsciiArtProtocol

- (NSString *)asciiArtString
{
  return [ASLayoutSpec asciiArtStringForChildren:@[] parentName:[self asciiArtName]];
}

- (NSString *)asciiArtName
{
  NSMutableString *result = [NSMutableString stringWithCString:object_getClassName(self) encoding:NSASCIIStringEncoding];
  if (_debugName) {
    [result appendFormat:@" (%@)", _debugName];
  }
  return result;
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (ASLayout)

@implementation ASDisplayNode (ASLayout)

- (ASLayoutEngineType)layoutEngineType
{
#if YOGA
  MutexLocker l(__instanceLock__);
  YGNodeRef yogaNode = _style.yogaNode;
  BOOL hasYogaParent = (_yogaParent != nil);
  BOOL hasYogaChildren = (_yogaChildren.count > 0);
  if (yogaNode != NULL && (hasYogaParent || hasYogaChildren)) {
    return ASLayoutEngineTypeYoga;
  }
#endif

  return ASLayoutEngineTypeLayoutSpec;
}

- (ASLayout *)calculatedLayout
{
  MutexLocker l(__instanceLock__);
  return _calculatedDisplayNodeLayout.layout;
}

- (CGSize)calculatedSize
{
  MutexLocker l(__instanceLock__);
  if (_pendingDisplayNodeLayout.isValid(_layoutVersion)) {
    return _pendingDisplayNodeLayout.layout.size;
  }
  return _calculatedDisplayNodeLayout.layout.size;
}

- (ASSizeRange)constrainedSizeForCalculatedLayout
{
  MutexLocker l(__instanceLock__);
  return [self _locked_constrainedSizeForCalculatedLayout];
}

- (ASSizeRange)_locked_constrainedSizeForCalculatedLayout
{
  ASAssertLocked(__instanceLock__);
  if (_pendingDisplayNodeLayout.isValid(_layoutVersion)) {
    return _pendingDisplayNodeLayout.constrainedSize;
  }
  return _calculatedDisplayNodeLayout.constrainedSize;
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (ASLayoutElementStylability)

@implementation ASDisplayNode (ASLayoutElementStylability)

- (instancetype)styledWithBlock:(AS_NOESCAPE void (^)(__kindof ASLayoutElementStyle *style))styleBlock
{
  styleBlock(self.style);
  return self;
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (ASLayoutInternal)

@implementation ASDisplayNode (ASLayoutInternal)

/**
 * @abstract Informs the root node that the intrinsic size of the receiver is no longer valid.
 *
 * @discussion The size of a root node is determined by each subnode. Calling invalidateSize will let the root node know
 * that the intrinsic size of the receiver node is no longer valid and a resizing of the root node needs to happen.
 */
- (void)_u_setNeedsLayoutFromAbove
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASAssertUnlocked(__instanceLock__);

  // Mark the node for layout in the next layout pass
  [self setNeedsLayout];
  
  __instanceLock__.lock();
  // Escalate to the root; entire tree must allow adjustments so the layout fits the new child.
  // Much of the layout will be re-used as cached (e.g. other items in an unconstrained stack)
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  if (supernode) {
    // Threading model requires that we unlock before calling a method on our parent.
    [supernode _u_setNeedsLayoutFromAbove];
  } else {
    // Let the root node method know that the size was invalidated
    [self _rootNodeDidInvalidateSize];
  }
}

// TODO It would be easier to work with if we could `ASAssertUnlocked` here, but we
// cannot due to locking to root in `_u_measureNodeWithBoundsIfNecessary`.
- (void)_rootNodeDidInvalidateSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  __instanceLock__.lock();
  
  // We are the root node and need to re-flow the layout; at least one child needs a new size.
  CGSize boundsSizeForLayout = ASCeilSizeValues(self.bounds.size);

  // Figure out constrainedSize to use
  ASSizeRange constrainedSize = ASSizeRangeMake(boundsSizeForLayout);
  if (_pendingDisplayNodeLayout.layout != nil) {
    constrainedSize = _pendingDisplayNodeLayout.constrainedSize;
  } else if (_calculatedDisplayNodeLayout.layout != nil) {
    constrainedSize = _calculatedDisplayNodeLayout.constrainedSize;
  }

  __instanceLock__.unlock();

  // Perform a measurement pass to get the full tree layout, adapting to the child's new size.
  ASLayout *layout = [self layoutThatFits:constrainedSize];
  
  // Check if the returned layout has a different size than our current bounds.
  if (CGSizeEqualToSize(boundsSizeForLayout, layout.size) == NO) {
    // If so, inform our container we need an update (e.g Table, Collection, ViewController, etc).
    [self displayNodeDidInvalidateSizeNewSize:layout.size];
  }
}

// TODO
// We should remove this logic, which is relatively new, and instead
// rely on the parent / host of the root node to do this size change. That's always been the
// expectation with other node containers like ASTableView, ASCollectionView, ASViewController, etc.
// E.g. in ASCellNode the _interactionDelegate is a Table or Collection that will resize in this
// case. By resizing without participating with the parent, we could get cases where our parent size
// does not match, especially if there is a size constraint that is applied at that level.
//
// In general a node should never need to set its own size, instead allowing its parent to do so -
// even in the root case. Anyhow this is a separate / pre-existing issue, but I think it could be
// causing real issues in cases of resizing nodes.
- (void)displayNodeDidInvalidateSizeNewSize:(CGSize)size
{
  ASDisplayNodeAssertThreadAffinity(self);

  // The default implementation of display node changes the size of itself to the new size
  CGRect oldBounds = self.bounds;
  CGSize oldSize = oldBounds.size;
  CGSize newSize = size;
  
  if (! CGSizeEqualToSize(oldSize, newSize)) {
    self.bounds = (CGRect){ oldBounds.origin, newSize };
    
    // Frame's origin must be preserved. Since it is computed from bounds size, anchorPoint
    // and position (see frame setter in ASDisplayNode+UIViewBridge), position needs to be adjusted.
    CGPoint anchorPoint = self.anchorPoint;
    CGPoint oldPosition = self.position;
    CGFloat xDelta = (newSize.width - oldSize.width) * anchorPoint.x;
    CGFloat yDelta = (newSize.height - oldSize.height) * anchorPoint.y;
    self.position = CGPointMake(oldPosition.x + xDelta, oldPosition.y + yDelta);
  }
}

- (void)_u_measureNodeWithBoundsIfNecessary:(CGRect)bounds
{
  // ASAssertUnlocked(__instanceLock__);
  ASScopedLockSelfOrToRoot();

  // Check if we are a subnode in a layout transition.
  // In this case no measurement is needed as it's part of the layout transition
  if ([self _locked_isLayoutTransitionInvalid]) {
    return;
  }

  CGSize boundsSizeForLayout = ASCeilSizeValues(bounds.size);

  // Prefer a newer and not yet applied _pendingDisplayNodeLayout over _calculatedDisplayNodeLayout
  // If there is no such _pending, check if _calculated is valid to reuse (avoiding recalculation below).
  BOOL pendingLayoutIsPreferred = NO;
  if (_pendingDisplayNodeLayout.isValid(_layoutVersion)) {
    NSUInteger calculatedVersion = _calculatedDisplayNodeLayout.version;
    NSUInteger pendingVersion = _pendingDisplayNodeLayout.version;
    if (pendingVersion > calculatedVersion) {
      pendingLayoutIsPreferred = YES; // Newer _pending
    } else if (pendingVersion == calculatedVersion
               && !ASSizeRangeEqualToSizeRange(_pendingDisplayNodeLayout.constrainedSize,
                                               _calculatedDisplayNodeLayout.constrainedSize)) {
                 pendingLayoutIsPreferred = YES; // _pending with a different constrained size
               }
  }
  BOOL calculatedLayoutIsReusable = (_calculatedDisplayNodeLayout.isValid(_layoutVersion)
                                     && (_calculatedDisplayNodeLayout.requestedLayoutFromAbove
                                         || CGSizeEqualToSize(_calculatedDisplayNodeLayout.layout.size, boundsSizeForLayout)));
  if (!pendingLayoutIsPreferred && calculatedLayoutIsReusable) {
    return;
  }
  // _calculatedDisplayNodeLayout is not reusable we need to transition to a new one
  [self cancelLayoutTransition];

  BOOL didCreateNewContext = NO;
  ASLayoutElementContext *context = ASLayoutElementGetCurrentContext();
  if (context == nil) {
    context = [[ASLayoutElementContext alloc] init];
    ASLayoutElementPushContext(context);
    didCreateNewContext = YES;
  }

  // Figure out previous and pending layouts for layout transition
  ASDisplayNodeLayout nextLayout = _pendingDisplayNodeLayout;
  #define layoutSizeDifferentFromBounds !CGSizeEqualToSize(nextLayout.layout.size, boundsSizeForLayout)

  // nextLayout was likely created by a call to layoutThatFits:, check if it is valid and can be applied.
  // If our bounds size is different than it, or invalid, recalculate.  Use #define to avoid nullptr->
  BOOL pendingLayoutApplicable = NO;
  if (nextLayout.layout == nil) {
  } else if (!nextLayout.isValid(_layoutVersion)) {
  } else if (layoutSizeDifferentFromBounds) {
  } else {
    pendingLayoutApplicable = YES;
  }

  if (!pendingLayoutApplicable) {
    // Use the last known constrainedSize passed from a parent during layout (if never, use bounds).
    NSUInteger version = _layoutVersion;
    ASSizeRange constrainedSize = [self _locked_constrainedSizeForLayoutPass];
    ASLayout *layout = [self calculateLayoutThatFits:constrainedSize
                                    restrictedToSize:self.style.size
                                relativeToParentSize:boundsSizeForLayout];
    nextLayout = ASDisplayNodeLayout(layout, constrainedSize, boundsSizeForLayout, version);
    // Now that the constrained size of pending layout might have been reused, the layout is useless
    // Release it and any orphaned subnodes it retains
    _pendingDisplayNodeLayout.layout = nil;
  }

  if (didCreateNewContext) {
    ASLayoutElementPopContext();
  }

  // If our new layout's desired size for self doesn't match current size, ask our parent to update it.
  // This can occur for either pre-calculated or newly-calculated layouts.
  if (nextLayout.requestedLayoutFromAbove == NO
      && CGSizeEqualToSize(boundsSizeForLayout, nextLayout.layout.size) == NO) {
    // The layout that we have specifies that this node (self) would like to be a different size
    // than it currently is.  Because that size has been computed within the constrainedSize, we
    // expect that calling setNeedsLayoutFromAbove will result in our parent resizing us to this.
    // However, in some cases apps may manually interfere with this (setting a different bounds).
    // In this case, we need to detect that we've already asked to be resized to match this
    // particular ASLayout object, and shouldn't loop asking again unless we have a different ASLayout.
    nextLayout.requestedLayoutFromAbove = YES;

    {
      __instanceLock__.unlock();
      [self _u_setNeedsLayoutFromAbove];
      __instanceLock__.lock();
    }

    // Update the layout's version here because _u_setNeedsLayoutFromAbove calls __setNeedsLayout which in turn increases _layoutVersion
    // Failing to do this will cause the layout to be invalid immediately
    nextLayout.version = _layoutVersion;
  }

  // Prepare to transition to nextLayout
  ASDisplayNodeAssertNotNil(nextLayout.layout, @"nextLayout.layout should not be nil! %@", self);
  _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                        pendingLayout:nextLayout
                                                       previousLayout:_calculatedDisplayNodeLayout];

  // If a parent is currently executing a layout transition, perform our layout application after it.
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO) {
    // If no transition, apply our new layout immediately (common case).
    [self _completePendingLayoutTransition];
  }
}

- (ASSizeRange)_constrainedSizeForLayoutPass
{
  MutexLocker l(__instanceLock__);
  return [self _locked_constrainedSizeForLayoutPass];
}

- (ASSizeRange)_locked_constrainedSizeForLayoutPass
{
  // TODO: The logic in -_u_setNeedsLayoutFromAbove seems correct and doesn't use this method.
  // logic seems correct.  For what case does -this method need to do the CGSizeEqual checks?
  // IF WE CAN REMOVE BOUNDS CHECKS HERE, THEN WE CAN ALSO REMOVE "REQUESTED FROM ABOVE" CHECK

  ASAssertLocked(__instanceLock__);

  CGSize boundsSizeForLayout = ASCeilSizeValues(self.threadSafeBounds.size);

  // Checkout if constrained size of pending or calculated display node layout can be used
  if (_pendingDisplayNodeLayout.requestedLayoutFromAbove
          || CGSizeEqualToSize(_pendingDisplayNodeLayout.layout.size, boundsSizeForLayout)) {
    // We assume the size from the last returned layoutThatFits: layout was applied so use the pending display node
    // layout constrained size
    return _pendingDisplayNodeLayout.constrainedSize;
  } else if (_calculatedDisplayNodeLayout.layout != nil
             && (_calculatedDisplayNodeLayout.requestedLayoutFromAbove
                 || CGSizeEqualToSize(_calculatedDisplayNodeLayout.layout.size, boundsSizeForLayout))) {
    // We assume the  _calculatedDisplayNodeLayout is still valid and the frame is not different
    return _calculatedDisplayNodeLayout.constrainedSize;
  } else {
    // In this case neither the _pendingDisplayNodeLayout or the _calculatedDisplayNodeLayout constrained size can
    // be reused, so the current bounds is used. This is usual the case if a frame was set manually that differs to
    // the one returned from layoutThatFits: or layoutThatFits: was never called
    return ASSizeRangeMake(boundsSizeForLayout);
  }
}

- (void)_layoutSublayouts
{
  ASDisplayNodeAssertThreadAffinity(self);
  // ASAssertUnlocked(__instanceLock__);
  
  ASLayout *layout;
  {
    MutexLocker l(__instanceLock__);
    if (_calculatedDisplayNodeLayout.version < _layoutVersion) {
      return;
    }
    layout = _calculatedDisplayNodeLayout.layout;
  }
  
  for (ASDisplayNode *node in self.subnodes) {
    CGRect frame = [layout frameForElement:node];
    if (CGRectIsNull(frame)) {
      // There is no frame for this node in our layout.
      // This currently can happen if we get a CA layout pass
      // while waiting for the client to run animateLayoutTransition:
    } else {
      node.frame = frame;
    }
  }
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (ASAutomatic Subnode Management)

@implementation ASDisplayNode (ASAutomaticSubnodeManagement)

#pragma mark Automatically Manages Subnodes

- (BOOL)automaticallyManagesSubnodes
{
  MutexLocker l(__instanceLock__);
  return _automaticallyManagesSubnodes;
}

- (void)setAutomaticallyManagesSubnodes:(BOOL)automaticallyManagesSubnodes
{
  MutexLocker l(__instanceLock__);
  _automaticallyManagesSubnodes = automaticallyManagesSubnodes;
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (ASLayoutTransition)

@implementation ASDisplayNode (ASLayoutTransition)

- (BOOL)_isLayoutTransitionInvalid
{
  MutexLocker l(__instanceLock__);
  return [self _locked_isLayoutTransitionInvalid];
}

- (BOOL)_locked_isLayoutTransitionInvalid
{
  ASAssertLocked(__instanceLock__);
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    ASLayoutElementContext *context = ASLayoutElementGetCurrentContext();
    if (context == nil || _pendingTransitionID != context.transitionID) {
      return YES;
    }
  }
  return NO;
}

/// Starts a new transition and returns the transition id
- (int32_t)_startNewTransition
{
  static std::atomic<int32_t> gNextTransitionID;
  int32_t newTransitionID = gNextTransitionID.fetch_add(1) + 1;
  _transitionID = newTransitionID;
  return newTransitionID;
}

/// Returns NO if there was no transition to cancel/finish.
- (BOOL)_finishOrCancelTransition
{
  int32_t oldValue = _transitionID.exchange(ASLayoutElementContextInvalidTransitionID);
  return oldValue != ASLayoutElementContextInvalidTransitionID;
}

#pragma mark Layout Transition

- (void)transitionLayoutWithAnimation:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  ASDisplayNodeAssertMainThread();
  [self transitionLayoutWithSizeRange:[self _constrainedSizeForLayoutPass]
                             animated:animated
                   shouldMeasureAsync:shouldMeasureAsync
                measurementCompletion:completion];
}

- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  ASDisplayNodeAssertMainThread();
  
  if (constrainedSize.max.width <= 0.0 || constrainedSize.max.height <= 0.0) {
    // Using CGSizeZero for the sizeRange can cause negative values in client layout code.
    // Most likely called transitionLayout: without providing a size, before first layout pass.
    return;
  }
    
  {
    MutexLocker l(__instanceLock__);

    // Check if we are a subnode in a layout transition.
    // In this case no measurement is needed as we're part of the layout transition.
    if ([self _locked_isLayoutTransitionInvalid]) {
      return;
    }

    if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
      ASDisplayNodeAssert(NO, @"Can't start a transition when one of the supernodes is performing one.");
      return;
    }
  }

  // Invalidate calculated layout because this method acts as an animated "setNeedsLayout" for nodes.
  // If the user has reconfigured the node and calls this, we should never return a stale layout
  // for subsequent calls to layoutThatFits: regardless of size range. We choose this method rather than
  // -setNeedsLayout because that method also triggers a CA layout invalidation, which isn't necessary at this time.
  // See https://github.com/TextureGroup/Texture/issues/463
  [self invalidateCalculatedLayout];

  // Every new layout transition has a transition id associated to check in subsequent transitions for cancelling
  int32_t transitionID = [self _startNewTransition];
  // NOTE: This block captures self. It's cheaper than hitting the weak table.
  asdisplaynode_iscancelled_block_t isCancelled = ^{
    BOOL result = (_transitionID != transitionID);
    if (result) {
    }
    return result;
  };

  // Move all subnodes in layout pending state for this transition
  ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
    ASDisplayNodeAssert(node->_transitionID == ASLayoutElementContextInvalidTransitionID, @"Can't start a transition when one of the subnodes is performing one.");
    node.hierarchyState |= ASHierarchyStateLayoutPending;
    node->_pendingTransitionID = transitionID;
  });
  
  // Transition block that executes the layout transition
  void (^transitionBlock)(void) = ^{
    if (isCancelled()) {
      return;
    }
    
    // Perform a full layout creation pass with passed in constrained size to create the new layout for the transition
    NSUInteger newLayoutVersion = _layoutVersion;
    ASLayout *newLayout;
    {
      ASScopedLockSelfOrToRoot();

      ASLayoutElementContext *ctx = [[ASLayoutElementContext alloc] init];
      ctx.transitionID = transitionID;
      ASLayoutElementPushContext(ctx);

      BOOL automaticallyManagesSubnodesDisabled = (self.automaticallyManagesSubnodes == NO);
      self.automaticallyManagesSubnodes = YES; // Temporary flag for 1.9.x
      newLayout = [self calculateLayoutThatFits:constrainedSize
                               restrictedToSize:self.style.size
                           relativeToParentSize:constrainedSize.max];
      if (automaticallyManagesSubnodesDisabled) {
        self.automaticallyManagesSubnodes = NO; // Temporary flag for 1.9.x
      }
      
      ASLayoutElementPopContext();
    }
    
    if (isCancelled()) {
      return;
    }
    
    ASPerformBlockOnMainThread(^{
      if (isCancelled()) {
        return;
      }
      ASLayoutTransition *pendingLayoutTransition;
      _ASTransitionContext *pendingLayoutTransitionContext;
      {
        // Grab __instanceLock__ here to make sure this transition isn't invalidated
        // right after it passed the validation test and before it proceeds
        MutexLocker l(__instanceLock__);
        
        // Update calculated layout
        const auto previousLayout = _calculatedDisplayNodeLayout;
        const auto pendingLayout = ASDisplayNodeLayout(newLayout,
                                                constrainedSize,
                                                constrainedSize.max,
                                                newLayoutVersion);
        [self _locked_setCalculatedDisplayNodeLayout:pendingLayout];
        
        // Setup pending layout transition for animation
        _pendingLayoutTransition = pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                                                        pendingLayout:pendingLayout
                                                                                       previousLayout:previousLayout];
        // Setup context for pending layout transition. we need to hold a strong reference to the context
        _pendingLayoutTransitionContext = pendingLayoutTransitionContext = [[_ASTransitionContext alloc] initWithAnimation:animated
                                                                                                            layoutDelegate:_pendingLayoutTransition
                                                                                                        completionDelegate:self];
      }
      
      // Apply complete layout transitions for all subnodes
      {
        ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
          [node _completePendingLayoutTransition];
          node.hierarchyState &= (~ASHierarchyStateLayoutPending);
        });
      }
      
      // Measurement pass completion
      // Give the subclass a change to hook into before calling the completion block
      [self _layoutTransitionMeasurementDidFinish];
      if (completion) {
        completion();
      }
      
      // Apply the subnode insertion immediately to be able to animate the nodes
      [pendingLayoutTransition applySubnodeInsertionsAndMoves];
      
      // Kick off animating the layout transition
      {
        [self animateLayoutTransition:pendingLayoutTransitionContext];
      }
      
      // Mark transaction as finished
      [self _finishOrCancelTransition];
    });
  };
  
  // Start transition based on flag on current or background thread
  if (shouldMeasureAsync) {
    ASPerformBlockOnBackgroundThread(transitionBlock);
  } else {
    transitionBlock();
  }
}

- (void)cancelLayoutTransition
{
  if ([self _finishOrCancelTransition]) {
    // Tell subnodes to exit layout pending state and clear related properties
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
      node.hierarchyState &= (~ASHierarchyStateLayoutPending);
    });
  }
}

- (void)setDefaultLayoutTransitionDuration:(NSTimeInterval)defaultLayoutTransitionDuration
{
  MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionDuration = defaultLayoutTransitionDuration;
}

- (NSTimeInterval)defaultLayoutTransitionDuration
{
  MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionDuration;
}

- (void)setDefaultLayoutTransitionDelay:(NSTimeInterval)defaultLayoutTransitionDelay
{
  MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionDelay = defaultLayoutTransitionDelay;
}

- (NSTimeInterval)defaultLayoutTransitionDelay
{
  MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionDelay;
}

- (void)setDefaultLayoutTransitionOptions:(UIViewAnimationOptions)defaultLayoutTransitionOptions
{
  MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionOptions = defaultLayoutTransitionOptions;
}

- (UIViewAnimationOptions)defaultLayoutTransitionOptions
{
  MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionOptions;
}

#pragma mark <LayoutTransitioning>

/*
 * Hook for subclasses to perform an animation based on the given ASContextTransitioning. By default a fade in and out
 * animation is provided.
 */
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  if ([context isAnimated] == NO) {
    [self _layoutSublayouts];
    [context completeTransition:YES];
    return;
  }
 
  ASDisplayNode *node = self;
  
  NSAssert(node.isNodeLoaded == YES, @"Invalid node state");
  
  NSArray<ASDisplayNode *> *removedSubnodes = [context removedSubnodes];
  NSMutableArray<ASDisplayNode *> *insertedSubnodes = [[context insertedSubnodes] mutableCopy];
  const auto movedSubnodes = [[NSMutableArray<ASDisplayNode *> alloc] init];
  
  const auto insertedSubnodeContexts = [[NSMutableArray<_ASAnimatedTransitionContext *> alloc] init];
  const auto removedSubnodeContexts = [[NSMutableArray<_ASAnimatedTransitionContext *> alloc] init];
  
  for (ASDisplayNode *subnode in [context subnodesForKey:ASTransitionContextToLayoutKey]) {
    if ([insertedSubnodes containsObject:subnode] == NO) {
      // This is an existing subnode, check if it is resized, moved or both
      CGRect fromFrame = [context initialFrameForNode:subnode];
      CGRect toFrame = [context finalFrameForNode:subnode];
      if (CGSizeEqualToSize(fromFrame.size, toFrame.size) == NO) {
        [insertedSubnodes addObject:subnode];
      }
      if (CGPointEqualToPoint(fromFrame.origin, toFrame.origin) == NO) {
        [movedSubnodes addObject:subnode];
      }
    }
  }
  
  // Create contexts for inserted and removed subnodes
  for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
    [insertedSubnodeContexts addObject:[_ASAnimatedTransitionContext contextForNode:insertedSubnode alpha:insertedSubnode.alpha]];
  }
  for (ASDisplayNode *removedSubnode in removedSubnodes) {
    [removedSubnodeContexts addObject:[_ASAnimatedTransitionContext contextForNode:removedSubnode alpha:removedSubnode.alpha]];
  }
  
  // Fade out inserted subnodes
  for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
    insertedSubnode.frame = [context finalFrameForNode:insertedSubnode];
    insertedSubnode.alpha = 0;
  }
  
  // Adjust groupOpacity for animation
  BOOL originAllowsGroupOpacity = node.allowsGroupOpacity;
  node.allowsGroupOpacity = YES;

  [UIView animateWithDuration:self.defaultLayoutTransitionDuration delay:self.defaultLayoutTransitionDelay options:self.defaultLayoutTransitionOptions animations:^{
    // Fade removed subnodes and views out
    for (ASDisplayNode *removedSubnode in removedSubnodes) {
      removedSubnode.alpha = 0;
    }
    
    // Fade inserted subnodes in
    for (_ASAnimatedTransitionContext *insertedSubnodeContext in insertedSubnodeContexts) {
      insertedSubnodeContext.node.alpha = insertedSubnodeContext.alpha;
    }
    
    // Update frame of self and moved subnodes
    CGSize fromSize = [context layoutForKey:ASTransitionContextFromLayoutKey].size;
    CGSize toSize = [context layoutForKey:ASTransitionContextToLayoutKey].size;
    BOOL isResized = (CGSizeEqualToSize(fromSize, toSize) == NO);
    if (isResized == YES) {
      CGPoint position = node.frame.origin;
      node.frame = CGRectMake(position.x, position.y, toSize.width, toSize.height);
    }
    for (ASDisplayNode *movedSubnode in movedSubnodes) {
      movedSubnode.frame = [context finalFrameForNode:movedSubnode];
    }
  } completion:^(BOOL finished) {
    // Restore all removed subnode alpha values
    for (_ASAnimatedTransitionContext *removedSubnodeContext in removedSubnodeContexts) {
      removedSubnodeContext.node.alpha = removedSubnodeContext.alpha;
    }
    
    // Restore group opacity
    node.allowsGroupOpacity = originAllowsGroupOpacity;
    
    // Subnode removals are automatically performed
    [context completeTransition:finished];
  }];
}

/**
 * Hook for subclasses to clean up nodes after the transition happened. Furthermore this can be used from subclasses
 * to manually perform deletions.
 */
- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context
{
  ASDisplayNodeAssertMainThread();

  __instanceLock__.lock();
  ASLayoutTransition *pendingLayoutTransition = _pendingLayoutTransition;
  __instanceLock__.unlock();

  [pendingLayoutTransition applySubnodeRemovals];
}

/**
 * Completes the pending layout transition immediately without going through the the Layout Transition Animation API
 */
- (void)_completePendingLayoutTransition
{
  __instanceLock__.lock();
  ASLayoutTransition *pendingLayoutTransition = _pendingLayoutTransition;
  __instanceLock__.unlock();

  if (pendingLayoutTransition != nil) {
    [self _setCalculatedDisplayNodeLayout:pendingLayoutTransition.pendingLayout];
    [self _completeLayoutTransition:pendingLayoutTransition];
    [self _pendingLayoutTransitionDidComplete];
  }
}

/**
 * Can be directly called to commit the given layout transition immediately to complete without calling through to the
 * Layout Transition Animation API
 */
- (void)_completeLayoutTransition:(ASLayoutTransition *)layoutTransition
{
  // Layout transition is not supported for nodes that do not have automatic subnode management enabled
  if (layoutTransition == nil || self.automaticallyManagesSubnodes == NO) {
    return;
  }

  // Trampoline to the main thread if necessary
  if (ASDisplayNodeThreadIsMain() || layoutTransition.isSynchronous == NO) {
    // Committing the layout transition will result in subnode insertions and removals, both of which must be called without the lock held
    // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
    // ASAssertUnlocked(__instanceLock__);
    [layoutTransition commitTransition];
  } else {
    // Subnode insertions and removals need to happen always on the main thread if at least one subnode is already loaded
    ASPerformBlockOnMainThread(^{
      [layoutTransition commitTransition];
    });
  }
}

- (void)_assertSubnodeState
{
  // Verify that any orphaned nodes are removed.
  // This can occur in rare cases if main thread layout is flushed while a background layout is calculating.

  if (self.automaticallyManagesSubnodes == NO) {
    return;
  }

  MutexLocker l(__instanceLock__);
  NSArray<ASLayout *> *sublayouts = _calculatedDisplayNodeLayout.layout.sublayouts;
  unowned ASLayout *cSublayouts[sublayouts.count];
  [sublayouts getObjects:cSublayouts range:NSMakeRange(0, AS_ARRAY_SIZE(cSublayouts))];

  // Fast-path if we are in the correct state (likely).
  if (_subnodes.count == AS_ARRAY_SIZE(cSublayouts)) {
    NSUInteger i = 0;
    BOOL matches = YES;
    for (ASDisplayNode *subnode in _subnodes) {
      if (subnode != cSublayouts[i].layoutElement) {
        matches = NO;
      }
      i++;
    }
    if (matches) {
      return;
    }
  }

  NSArray<ASDisplayNode *> *layoutNodes = ASArrayByFlatMapping(sublayouts, ASLayout *layout, (ASDisplayNode *)layout.layoutElement);
  NSIndexSet *insertions, *deletions;
  [_subnodes asdk_diffWithArray:layoutNodes insertions:&insertions deletions:&deletions];
  if (insertions.count > 0) {
    NSLog(@"Warning: node's layout includes subnode that has not been added: node = %@, subnodes = %@, subnodes in layout = %@", self, _subnodes, layoutNodes);
  }

  // Remove any nodes that are in the tree but should not be.
  // Go in reverse order so we don't shift our indexes.
  if (deletions) {
    for (NSUInteger i = deletions.lastIndex; i != NSNotFound; i = [deletions indexLessThanIndex:i]) {
      NSLog(@"Automatically removing orphaned subnode %@, from parent %@", _subnodes[i], self);
      [_subnodes[i] removeFromSupernode];
    }
  }
}

- (void)_pendingLayoutTransitionDidComplete
{
  // This assertion introduces a breaking behavior for nodes that has ASM enabled but also manually manage some subnodes.
  // Let's gate it behind YOGA flag.
#if YOGA
  [self _assertSubnodeState];
#endif

  // Subclass hook
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  [self calculatedLayoutDidChange];

  // Grab lock after calling out to subclass
  MutexLocker l(__instanceLock__);

  // We generate placeholders at -layoutThatFits: time so that a node is guaranteed to have a placeholder ready to go.
  // This is also because measurement is usually asynchronous, but placeholders need to be set up synchronously.
  // First measurement is guaranteed to be before the node is onscreen, so we can create the image async. but still have it appear sync.
  if (_placeholderEnabled && !_placeholderImage && [self _locked_displaysAsynchronously]) {
    
    // Zero-sized nodes do not require a placeholder.
    CGSize layoutSize = _calculatedDisplayNodeLayout.layout.size;
    if (layoutSize.width * layoutSize.height <= 0.0) {
      return;
    }
    
    // If we've displayed our contents, we don't need a placeholder.
    // Contents is a thread-affined property and can't be read off main after loading.
    if (self.isNodeLoaded) {
      ASPerformBlockOnMainThread(^{
        if (self.contents == nil) {
          _placeholderImage = [self placeholderImage];
        }
      });
    } else {
      if (self.contents == nil) {
        _placeholderImage = [self placeholderImage];
      }
    }
  }
  
  // Cleanup pending layout transition
  _pendingLayoutTransition = nil;
}

- (void)_setCalculatedDisplayNodeLayout:(const ASDisplayNodeLayout &)displayNodeLayout
{
  MutexLocker l(__instanceLock__);
  [self _locked_setCalculatedDisplayNodeLayout:displayNodeLayout];
}

- (void)_locked_setCalculatedDisplayNodeLayout:(const ASDisplayNodeLayout &)displayNodeLayout
{
  ASAssertLocked(__instanceLock__);
  ASDisplayNodeAssertTrue(displayNodeLayout.layout.layoutElement == self);
  ASDisplayNodeAssertTrue(displayNodeLayout.layout.size.width >= 0.0);
  ASDisplayNodeAssertTrue(displayNodeLayout.layout.size.height >= 0.0);
  
  _calculatedDisplayNodeLayout = displayNodeLayout;
}

@end

#pragma mark -
#pragma mark - ASDisplayNode (YogaLayout)

@implementation ASDisplayNode (YogaLayout)

- (BOOL)locked_shouldLayoutFromYogaRoot {
#if YOGA
  YGNodeRef yogaNode = _style.yogaNode;
  BOOL hasYogaParent = (_yogaParent != nil);
  BOOL hasYogaChildren = (_yogaChildren.count > 0);
  BOOL usesYoga = (yogaNode != NULL && (hasYogaParent || hasYogaChildren));
  if (usesYoga) {
    if ([self shouldHaveYogaMeasureFunc] == NO) {
      return YES;
    } else {
      return NO;
    }
  } else {
    return NO;
  }
#else
  return NO;
#endif
}

@end
