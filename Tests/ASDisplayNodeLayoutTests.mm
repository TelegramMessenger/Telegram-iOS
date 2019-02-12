//
//  ASDisplayNodeLayoutTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASXCTExtensions.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <stdatomic.h>

#import "ASLayoutSpecSnapshotTestsHelper.h"

@interface ASDisplayNodeLayoutTests : XCTestCase
@end

@implementation ASDisplayNodeLayoutTests

- (void)testMeasureOnLayoutIfNotHappenedBefore
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  displayNode.style.width = ASDimensionMake(100);
  displayNode.style.height = ASDimensionMake(100);
  
  // Use a button node in here as ASButtonNode uses layoutSpecThatFits:
  ASButtonNode *buttonNode = [ASButtonNode new];
  [displayNode addSubnode:buttonNode];
  
  displayNode.frame = {.size = nodeSize};
  buttonNode.frame = {.size = nodeSize};
  
  ASXCTAssertEqualSizes(displayNode.calculatedSize, CGSizeZero, @"Calculated size before measurement and layout should be 0");
  ASXCTAssertEqualSizes(buttonNode.calculatedSize, CGSizeZero, @"Calculated size before measurement and layout should be 0");
  
  // Trigger view creation and layout pass without a manual -layoutThatFits: call before so the automatic measurement
  // pass will trigger in the layout pass
  [displayNode.view layoutIfNeeded];
  
  ASXCTAssertEqualSizes(displayNode.calculatedSize, nodeSize, @"Automatic measurement pass should have happened in layout pass");
  ASXCTAssertEqualSizes(buttonNode.calculatedSize, nodeSize, @"Automatic measurement pass should have happened in layout pass");
}

#if DEBUG
- (void)testNotAllowAddingSubnodesInLayoutSpecThatFits
{
  ASDisplayNode *displayNode = [ASDisplayNode new];
  ASDisplayNode *someOtherNode = [ASDisplayNode new];
  
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    [node addSubnode:someOtherNode];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
  };
  
  XCTAssertThrows([displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 100))], @"Should throw if subnode was added in layoutSpecThatFits:");
}

- (void)testNotAllowModifyingSubnodesInLayoutSpecThatFits
{
  ASDisplayNode *displayNode = [ASDisplayNode new];
  ASDisplayNode *someOtherNode = [ASDisplayNode new];
  
  [displayNode addSubnode:someOtherNode];
  
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    [someOtherNode removeFromSupernode];
    [node addSubnode:[ASDisplayNode new]];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
  };
  
  XCTAssertThrows([displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 100))], @"Should throw if subnodes where modified in layoutSpecThatFits:");
}
#endif

- (void)testMeasureOnLayoutIfNotHappenedBeforeNoRemeasureForSameBounds
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASDisplayNode *displayNode = [ASDisplayNode new];
  displayNode.style.width = ASDimensionMake(nodeSize.width);
  displayNode.style.height = ASDimensionMake(nodeSize.height);
  
  ASButtonNode *buttonNode = [ASButtonNode new];
  [displayNode addSubnode:buttonNode];
  
  __block atomic_int numberOfLayoutSpecThatFitsCalls = ATOMIC_VAR_INIT(0);
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    atomic_fetch_add(&numberOfLayoutSpecThatFitsCalls, 1);
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:buttonNode];
  };
  
  displayNode.frame = {.size = nodeSize};
  
  // Trigger initial layout pass without a measurement pass before
  [displayNode.view layoutIfNeeded];
  XCTAssertEqual(numberOfLayoutSpecThatFitsCalls, 1, @"Should measure during layout if not measured");
  
  [displayNode layoutThatFits:ASSizeRangeMake(nodeSize, nodeSize)];
  XCTAssertEqual(numberOfLayoutSpecThatFitsCalls, 1, @"Should not remeasure with same bounds");
}

- (void)testThatLayoutWithInvalidSizeCausesException
{
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.layoutSpecBlock = ^ASLayoutSpec *(ASDisplayNode *node, ASSizeRange constrainedSize) {
    return [ASWrapperLayoutSpec wrapperWithLayoutElement:displayNode];
  };
  
  XCTAssertThrows([node layoutThatFits:ASSizeRangeMake(CGSizeMake(0, FLT_MAX))]);
}

- (void)testThatLayoutCreatedWithInvalidSizeCausesException
{
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(FLT_MAX, FLT_MAX)]);
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)]);
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(INFINITY, INFINITY)]);
}

- (void)testThatLayoutElementCreatedInLayoutSpecThatFitsDoNotGetDeallocated
{
  const CGSize kSize = CGSizeMake(300, 300);
  
  ASDisplayNode *subNode = [[ASDisplayNode alloc] init];
  subNode.automaticallyManagesSubnodes = YES;
  subNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASTextNode *textNode = [ASTextNode new];
    textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Test Test Test Test Test Test Test Test"];
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:textNode];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:insetSpec];
  };
  
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  rootNode.automaticallyManagesSubnodes = YES;
  rootNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASTextNode *textNode = [ASTextNode new];
    textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Test Test Test Test Test"];
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:textNode];
    
    return [ASStackLayoutSpec
            stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
            spacing:0.0
            justifyContent:ASStackLayoutJustifyContentStart
            alignItems:ASStackLayoutAlignItemsStretch
            children:@[insetSpec, subNode]];
  };

  rootNode.frame = CGRectMake(0, 0, kSize.width, kSize.height);
  [rootNode view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Execute measure and layout pass"];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    [rootNode layoutThatFits:ASSizeRangeMake(kSize)];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertNoThrow([rootNode.view layoutIfNeeded]);
      [expectation fulfill];
    });
  });
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

@end
