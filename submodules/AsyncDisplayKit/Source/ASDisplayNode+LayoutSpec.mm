//
//  ASDisplayNode+LayoutSpec.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASAvailability.h>

#import "_ASScopeTimer.h"
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASLayout.h>
#import "ASLayoutSpec+Subclasses.h"
#import "ASLayoutSpecPrivate.h"
#import <AsyncDisplayKit/ASThread.h>


@implementation ASDisplayNode (ASLayoutSpec)

- (void)setLayoutSpecBlock:(ASLayoutSpecBlock)layoutSpecBlock
{
  // For now there should never be an override of layoutSpecThatFits: and a layoutSpecBlock together.
  ASDisplayNodeAssert(!(_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits),
                      @"Nodes with a .layoutSpecBlock must not also implement -layoutSpecThatFits:");
  AS::MutexLocker l(__instanceLock__);
  _layoutSpecBlock = layoutSpecBlock;
}

- (ASLayoutSpecBlock)layoutSpecBlock
{
  AS::MutexLocker l(__instanceLock__);
  return _layoutSpecBlock;
}

- (ASLayout *)calculateLayoutLayoutSpec:(ASSizeRange)constrainedSize
{
  AS::UniqueLock l(__instanceLock__);

  // Manual size calculation via calculateSizeThatFits:
  if (_layoutSpecBlock == NULL && (_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) == 0) {
    CGSize size = [self calculateSizeThatFits:constrainedSize.max];
    ASDisplayNodeLogEvent(self, @"calculatedSize: %@", NSStringFromCGSize(size));
    return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:nil];
  }

  // Size calcualtion with layout elements
  BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;
  if (measureLayoutSpec) {
    _layoutSpecNumberOfPasses++;
  }

  // Get layout element from the node
  id<ASLayoutElement> layoutElement = [self _locked_layoutElementThatFits:constrainedSize];
#if ASEnableVerboseLogging
  for (NSString *asciiLine in [[layoutElement asciiArtString] componentsSeparatedByString:@"\n"]) {
    as_log_verbose(ASLayoutLog(), "%@", asciiLine);
  }
#endif


  // Certain properties are necessary to set on an element of type ASLayoutSpec
  if (layoutElement.layoutElementType == ASLayoutElementTypeLayoutSpec) {
    ASLayoutSpec *layoutSpec = (ASLayoutSpec *)layoutElement;

#if AS_DEDUPE_LAYOUT_SPEC_TREE
    NSHashTable *duplicateElements = [layoutSpec findDuplicatedElementsInSubtree];
    if (duplicateElements.count > 0) {
      ASDisplayNodeFailAssert(@"Node %@ returned a layout spec that contains the same elements in multiple positions. Elements: %@", self, duplicateElements);
      // Use an empty layout spec to avoid crashes
      layoutSpec = [[ASLayoutSpec alloc] init];
    }
#endif

    ASDisplayNodeAssert(layoutSpec.isMutable, @"Node %@ returned layout spec %@ that has already been used. Layout specs should always be regenerated.", self, layoutSpec);

    layoutSpec.isMutable = NO;
  }

  // Manually propagate the trait collection here so that any layoutSpec children of layoutSpec will get a traitCollection
  {
    AS::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
    ASTraitCollectionPropagateDown(layoutElement, self.primitiveTraitCollection);
  }

  BOOL measureLayoutComputation = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutComputation;
  if (measureLayoutComputation) {
    _layoutComputationNumberOfPasses++;
  }

  // Layout element layout creation
  ASLayout *layout = ({
    AS::SumScopeTimer t(_layoutComputationTotalTime, measureLayoutComputation);
    [layoutElement layoutThatFits:constrainedSize];
  });
  ASDisplayNodeAssertNotNil(layout, @"[ASLayoutElement layoutThatFits:] should never return nil! %@, %@", self, layout);

  // Make sure layoutElementObject of the root layout is `self`, so that the flattened layout will be structurally correct.
  BOOL isFinalLayoutElement = (layout.layoutElement != self);
  if (isFinalLayoutElement) {
    layout.position = CGPointZero;
    layout = [ASLayout layoutWithLayoutElement:self size:layout.size sublayouts:@[layout]];
  }
  ASDisplayNodeLogEvent(self, @"computedLayout: %@", layout);

  // PR #1157: Reduces accuracy of _unflattenedLayout for debugging/Weaver
  if ([ASDisplayNode shouldStoreUnflattenedLayouts]) {
    _unflattenedLayout = layout;
  }
  layout = [layout filteredNodeLayoutTree];

  return layout;
}

- (id<ASLayoutElement>)_locked_layoutElementThatFits:(ASSizeRange)constrainedSize
{
  ASAssertLocked(__instanceLock__);

  BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;

  if (_layoutSpecBlock != NULL) {
    return ({
      AS::MutexLocker l(__instanceLock__);
      AS::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      _layoutSpecBlock(self, constrainedSize);
    });
  } else {
    return ({
      AS::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      [self layoutSpecThatFits:constrainedSize];
    });
  }
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDisplayNodeAssert(NO, @"-[ASDisplayNode layoutSpecThatFits:] should never return an empty value. One way this is caused is by calling -[super layoutSpecThatFits:] which is not currently supported.");
  return [[ASLayoutSpec alloc] init];
}

@end
