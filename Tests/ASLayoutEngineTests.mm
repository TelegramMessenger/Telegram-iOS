//
//  ASLayoutEngineTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTestCase.h"
#import "ASLayoutTestNode.h"
#import "ASXCTExtensions.h"
#import "ASTLayoutFixture.h"

@interface ASLayoutEngineTests : ASTestCase

@end

@implementation ASLayoutEngineTests {
  ASLayoutTestNode *nodeA;
  ASLayoutTestNode *nodeB;
  ASLayoutTestNode *nodeC;
  ASLayoutTestNode *nodeD;
  ASLayoutTestNode *nodeE;
  ASTLayoutFixture *fixture1;
  ASTLayoutFixture *fixture2;
  ASTLayoutFixture *fixture3;
  ASTLayoutFixture *fixture4;
  ASTLayoutFixture *fixture5;

  // fixtures 1, 3 and 5 share the same exact node A layout spec block.
  // we don't want the infra to call -setNeedsLayout when we switch fixtures
  // so we need to use the same exact block.
  ASLayoutSpecBlock fixture1and3and5NodeALayoutSpecBlock;

  UIWindow *window;
  UIViewController *vc;
  NSArray<ASLayoutTestNode *> *allNodes;
  NSTimeInterval verifyDelay;
  // See -stubCalculatedLayoutDidChange.
  BOOL stubbedCalculatedLayoutDidChange;
}

- (void)setUp
{
  [super setUp];
  verifyDelay = 3;
  window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
  vc = [[UIViewController alloc] init];
  nodeA = [ASLayoutTestNode new];
  nodeA.backgroundColor = [UIColor redColor];

  // NOTE: nodeB has flexShrink, the others don't
  nodeB = [ASLayoutTestNode new];
  nodeB.style.flexShrink = 1;
  nodeB.backgroundColor = [UIColor orangeColor];

  nodeC = [ASLayoutTestNode new];
  nodeC.backgroundColor = [UIColor yellowColor];
  nodeD = [ASLayoutTestNode new];
  nodeD.backgroundColor = [UIColor greenColor];
  nodeE = [ASLayoutTestNode new];
  nodeE.backgroundColor = [UIColor blueColor];
  allNodes = @[ nodeA, nodeB, nodeC, nodeD, nodeE ];
  ASSetDebugNames(nodeA, nodeB, nodeC, nodeD, nodeE);
  ASLayoutSpecBlock b = ^ASLayoutSpec * _Nonnull(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    return [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:0 justifyContent:ASStackLayoutJustifyContentSpaceBetween alignItems:ASStackLayoutAlignItemsStart children:@[ nodeB, nodeC, nodeD ]];
  };
  fixture1and3and5NodeALayoutSpecBlock = b;
  fixture1 = [self createFixture1];
  fixture2 = [self createFixture2];
  fixture3 = [self createFixture3];
  fixture4 = [self createFixture4];
  fixture5 = [self createFixture5];

  nodeA.frame = vc.view.bounds;
  nodeA.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [vc.view addSubnode:nodeA];

  window.rootViewController = vc;
  [window makeKeyAndVisible];
}

- (void)tearDown
{
  nodeA.layoutSpecBlock = nil;
  for (ASLayoutTestNode *node in allNodes) {
    OCMVerifyAllWithDelay(node.mock, verifyDelay);
  }
  [super tearDown];
}

- (void)testFirstLayoutPassWhenInWindow
{
  [self runFirstLayoutPassWithFixture:fixture1];
}

- (void)testSetNeedsLayoutAndNormalLayoutPass
{
  [self runFirstLayoutPassWithFixture:fixture1];

  [fixture2 apply];

  // skip nodeB because its layout doesn't change.
  for (ASLayoutTestNode *node in @[ nodeA, nodeC, nodeE ]) {
    [fixture2 withSizeRangesForNode:node block:^(ASSizeRange sizeRange) {
      OCMExpect([node.mock calculateLayoutThatFits:sizeRange]).onMainThread();
    }];
    OCMExpect([node.mock calculatedLayoutDidChange]).onMainThread();
  }

  [window layoutIfNeeded];
  [self verifyFixture:fixture2];
}

/**
 * Transition from fixture1 to Fixture2 on node A.
 *
 * Expect A and D to calculate once off main, and
 * to receive calculatedLayoutDidChange on main,
 * then to get the measurement completion call on main,
 * then to get animateLayoutTransition: and didCompleteLayoutTransition: on main.
 */
- (void)testLayoutTransitionWithAsyncMeasurement
{
  [self stubCalculatedLayoutDidChange];
  [self runFirstLayoutPassWithFixture:fixture1];

  [fixture2 apply];

  // Expect A, C, E to calculate new layouts off-main
  // dispatch_once onto main to run our injectedMainThread work while the transition calculates.
  __block dispatch_block_t injectedMainThreadWork = nil;
  for (ASLayoutTestNode *node in @[ nodeA, nodeC, nodeE ]) {
    [fixture2 withSizeRangesForNode:node block:^(ASSizeRange sizeRange) {
      OCMExpect([node.mock calculateLayoutThatFits:sizeRange])
      .offMainThread()
      .andDo(^(NSInvocation *inv) {
        // On first calculateLayoutThatFits, schedule our injected main thread work.
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          dispatch_async(dispatch_get_main_queue(), ^{
            injectedMainThreadWork();
          });
        });
      });
    }];
  }

  // The code in this section is designed to move in time order, all on the main thread:

  OCMExpect([nodeA.mock animateLayoutTransition:OCMOCK_ANY]).onMainThread();
  OCMExpect([nodeA.mock didCompleteLayoutTransition:OCMOCK_ANY]).onMainThread();

  // Trigger the layout transition.
  __block dispatch_block_t measurementCompletionBlock = nil;
  [nodeA transitionLayoutWithAnimation:NO shouldMeasureAsync:YES measurementCompletion:^{
    measurementCompletionBlock();
  }];

  // This block will get run after bg layout calculate starts, but before measurementCompletion
  __block BOOL injectedMainThreadWorkDone = NO;
  injectedMainThreadWork = ^{
    injectedMainThreadWorkDone = YES;

    [window layoutIfNeeded];

    // Ensure we're still on the old layout. We should stay on this until the transition completes.
    [self verifyFixture:fixture1];
  };

  measurementCompletionBlock = ^{
    XCTAssert(injectedMainThreadWorkDone, @"We hoped to get onto the main thread before the measurementCompletion callback ran.");
  };

  for (ASLayoutTestNode *node in allNodes) {
    OCMVerifyAllWithDelay(node.mock, verifyDelay);
  }

  [self verifyFixture:fixture2];
}

/**
 * Transition from fixture1 to Fixture2 on node A.
 *
 * Expect A and D to calculate once on main, and
 * to receive calculatedLayoutDidChange on main,
 * then to get animateLayoutTransition: and didCompleteLayoutTransition: on main.
 */
- (void)testLayoutTransitionWithSyncMeasurement
{
  [self stubCalculatedLayoutDidChange];

  // Precondition
  XCTAssertFalse(CGSizeEqualToSize(fixture5.layout.size, fixture1.layout.size));

  // First, apply fixture 5 and run a measurement pass, but don't run a layout pass
  // After this step, nodes will have pending layouts that are not yet applied
  [fixture5 apply];
  [fixture5 withSizeRangesForAllNodesUsingBlock:^(ASLayoutTestNode * _Nonnull node, ASSizeRange sizeRange) {
    OCMExpect([node.mock calculateLayoutThatFits:sizeRange])
    .onMainThread();
  }];

  [nodeA layoutThatFits:ASSizeRangeMake(fixture5.layout.size)];

  // Assert that node A has layout size and size range from fixture 5
  XCTAssertTrue(CGSizeEqualToSize(fixture5.layout.size, nodeA.calculatedSize));
  XCTAssertTrue(ASSizeRangeEqualToSizeRange([fixture5 firstSizeRangeForNode:nodeA], nodeA.constrainedSizeForCalculatedLayout));

  // Then switch to fixture 1 and kick off a synchronous layout transition
  // Unapplied pending layouts from the previous measurement pass will be outdated
  [fixture1 apply];
  [fixture1 withSizeRangesForAllNodesUsingBlock:^(ASLayoutTestNode * _Nonnull node, ASSizeRange sizeRange) {
    OCMExpect([node.mock calculateLayoutThatFits:sizeRange])
    .onMainThread();
  }];

  OCMExpect([nodeA.mock animateLayoutTransition:OCMOCK_ANY]).onMainThread();
  OCMExpect([nodeA.mock didCompleteLayoutTransition:OCMOCK_ANY]).onMainThread();

  [nodeA transitionLayoutWithAnimation:NO shouldMeasureAsync:NO measurementCompletion:nil];

  // Assert that node A picks up new layout size and size range from fixture 1
  XCTAssertTrue(CGSizeEqualToSize(fixture1.layout.size, nodeA.calculatedSize));
  XCTAssertTrue(ASSizeRangeEqualToSizeRange([fixture1 firstSizeRangeForNode:nodeA], nodeA.constrainedSizeForCalculatedLayout));

  [window layoutIfNeeded];
  [self verifyFixture:fixture1];
}

/**
 * Start at fixture 1.
 * Trigger an async transition to fixture 2.
 * While it's measuring, on main switch to fixture 4 (setNeedsLayout A, D) and run a CA layout pass.
 *
 * Correct behavior, we end up at fixture 4 since it's newer.
 * Current incorrect behavior, we end up at fixture 2 and we remeasure surviving node C.
 * Note: incorrect behavior likely introduced by the early check in __layout added in
 * https://github.com/facebookarchive/AsyncDisplayKit/pull/2657
 */
- (void)DISABLE_testASetNeedsLayoutInterferingWithTheCurrentTransition
{
  static BOOL enforceCorrectBehavior = NO;

  [self stubCalculatedLayoutDidChange];
  [self runFirstLayoutPassWithFixture:fixture1];

  [fixture2 apply];

  // Expect A, C, E to calculate new layouts off-main
  // dispatch_once onto main to run our injectedMainThread work while the transition calculates.
  __block dispatch_block_t injectedMainThreadWork = nil;
  for (ASLayoutTestNode *node in @[ nodeA, nodeC, nodeE ]) {
    [fixture2 withSizeRangesForNode:node block:^(ASSizeRange sizeRange) {
      OCMExpect([node.mock calculateLayoutThatFits:sizeRange])
      .offMainThread()
      .andDo(^(NSInvocation *inv) {
        // On first calculateLayoutThatFits, schedule our injected main thread work.
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          dispatch_async(dispatch_get_main_queue(), ^{
            injectedMainThreadWork();
          });
        });
      });
    }];
  }

  // The code in this section is designed to move in time order, all on the main thread:

  // With the current behavior, the transition will continue and complete.
  if (!enforceCorrectBehavior) {
    OCMExpect([nodeA.mock animateLayoutTransition:OCMOCK_ANY]).onMainThread();
    OCMExpect([nodeA.mock didCompleteLayoutTransition:OCMOCK_ANY]).onMainThread();
  }

  // Trigger the layout transition.
  __block dispatch_block_t measurementCompletionBlock = nil;
  [nodeA transitionLayoutWithAnimation:NO shouldMeasureAsync:YES measurementCompletion:^{
    measurementCompletionBlock();
  }];

  // Injected block will get run on main after bg layout calculate starts, but before measurementCompletion
  __block BOOL injectedMainThreadWorkDone = NO;
  injectedMainThreadWork = ^{
    as_log_verbose(OS_LOG_DEFAULT, "Begin injectedMainThreadWork");
    injectedMainThreadWorkDone = YES;

    [fixture4 apply];
    as_log_verbose(OS_LOG_DEFAULT, "Did apply new fixture");

    if (enforceCorrectBehavior) {
      // Correct measurement behavior here is unclear, may depend on whether the layouts which
      // are common to both fixture2 and fixture4 are available from the cache.
    } else {
      // Incorrect behavior: nodeC will get measured against its new bounds on main.
      const auto cPendingSize = [fixture2 layoutForNode:nodeC].size;
      OCMExpect([nodeC.mock calculateLayoutThatFits:ASSizeRangeMake(cPendingSize)]).onMainThread();
    }
    [window layoutIfNeeded];
    as_log_verbose(OS_LOG_DEFAULT, "End injectedMainThreadWork");
  };

  measurementCompletionBlock = ^{
    XCTAssert(injectedMainThreadWorkDone, @"We hoped to get onto the main thread before the measurementCompletion callback ran.");
  };

  for (ASLayoutTestNode *node in allNodes) {
    OCMVerifyAllWithDelay(node.mock, verifyDelay);
  }

  // Incorrect behavior: The transition will "win" even though its transitioning to stale data.
  if (enforceCorrectBehavior) {
    [self verifyFixture:fixture4];
  } else {
    [self verifyFixture:fixture2];
  }
}

/**
 * Start on fixture 3 where nodeB is force-shrunk via multipass layout.
 * Apply fixture 1, which just changes nodeB's size and calls -setNeedsLayout on it.
 *
 * This behavior is currently broken. See implementation for correct behavior and incorrect behavior.
 */
- (void)testCallingSetNeedsLayoutOnANodeThatWasSubjectToMultipassLayout
{
  static BOOL const enforceCorrectBehavior = NO;
  [self stubCalculatedLayoutDidChange];
  [self runFirstLayoutPassWithFixture:fixture3];

  // Switch to fixture 1, updating nodeB's desired size and calling -setNeedsLayout
  // Now nodeB will fit happily into the stack.
  [fixture1 apply];

  if (enforceCorrectBehavior) {
    /*
     * Correct behavior: nodeB is remeasured against the first (unconstrained) size
     * and when it's discovered that now nodeB fits, nodeA will re-layout and we'll
     * end up correctly at fixture1.
     */
    OCMExpect([nodeB.mock calculateLayoutThatFits:[fixture3 firstSizeRangeForNode:nodeB]]);

    [fixture1 withSizeRangesForNode:nodeA block:^(ASSizeRange sizeRange) {
      OCMExpect([nodeA.mock calculateLayoutThatFits:sizeRange]);
    }];

    [window layoutIfNeeded];
    [self verifyFixture:fixture1];
  } else {
    /*
     * Incorrect behavior: nodeB is remeasured against the second (fixed-width) constraint.
     * The returned value (8) is clamped to the fixed with (7), and then compared to the previous
     * width (7) and we decide not to propagate up the invalidation, and we stay stuck on the old
     * layout (fixture3).
     */
    OCMExpect([nodeB.mock calculateLayoutThatFits:nodeB.constrainedSizeForCalculatedLayout]);
    [window layoutIfNeeded];
    [self verifyFixture:fixture3];
  }
}

#pragma mark - Helpers

- (void)verifyFixture:(ASTLayoutFixture *)fixture
{
  const auto expected = fixture.layout;

  // Ensure expected == frames
  const auto frames = [fixture.rootNode currentLayoutBasedOnFrames];
  if (![expected isEqual:frames]) {
    XCTFail(@"\n*** Layout verification failed – frames don't match expected. ***\nGot:\n%@\nExpected:\n%@", [frames recursiveDescription], [expected recursiveDescription]);
  }

  // Ensure expected == calculatedLayout
  const auto calculated = fixture.rootNode.calculatedLayout;
  if (![expected isEqual:calculated]) {
    XCTFail(@"\n*** Layout verification failed – calculated layout doesn't match expected. ***\nGot:\n%@\nExpected:\n%@", [calculated recursiveDescription], [expected recursiveDescription]);
  }
}

/**
 * Stubs calculatedLayoutDidChange for all nodes.
 *
 * It's not really a core layout engine method, and it's also
 * currently bugged and gets called a lot so for most
 * tests its better not to have expectations about it littered around.
 * https://github.com/TextureGroup/Texture/issues/422
 */
- (void)stubCalculatedLayoutDidChange
{
  stubbedCalculatedLayoutDidChange = YES;
  for (ASLayoutTestNode *node in allNodes) {
    OCMStub([node.mock calculatedLayoutDidChange]);
  }
}

/**
 * Fixture 1: A basic horizontal stack, all single-pass.
 *
 * [A: HorizStack([B, C, D])]. A is (10x1), B is (1x1), C is (2x1), D is (1x1)
 */
- (ASTLayoutFixture *)createFixture1
{
  const auto fixture = [[ASTLayoutFixture alloc] init];

  // nodeB
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeB];
  const auto layoutB = [ASLayout layoutWithLayoutElement:nodeB size:{1,1} position:{0,0} sublayouts:nil];

  // nodeC
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeC];
  const auto layoutC = [ASLayout layoutWithLayoutElement:nodeC size:{2,1} position:{4,0} sublayouts:nil];

  // nodeD
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeD];
  const auto layoutD = [ASLayout layoutWithLayoutElement:nodeD size:{1,1} position:{9,0} sublayouts:nil];

  [fixture addSizeRange:{{10, 1}, {10, 1}} forNode:nodeA];
  const auto layoutA = [ASLayout layoutWithLayoutElement:nodeA size:{10,1} position:ASPointNull sublayouts:@[ layoutB, layoutC, layoutD ]];
  fixture.layout = layoutA;

  [fixture.layoutSpecBlocks setObject:fixture1and3and5NodeALayoutSpecBlock forKey:nodeA];
  return fixture;
}

/**
 * Fixture 2: A simple transition away from fixture 1.
 *
 * [A: HorizStack([B, C, E])]. A is (10x1), B is (1x1), C is (4x1), E is (1x1)
 *
 * From fixture 1:
 *   B survives with same layout
 *   C survives with new layout
 *   D is removed
 *   E joins with first layout
 */
- (ASTLayoutFixture *)createFixture2
{
  const auto fixture = [[ASTLayoutFixture alloc] init];

  // nodeB
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeB];
  const auto layoutB = [ASLayout layoutWithLayoutElement:nodeB size:{1,1} position:{0,0} sublayouts:nil];

  // nodeC
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeC];
  const auto layoutC = [ASLayout layoutWithLayoutElement:nodeC size:{4,1} position:{3,0} sublayouts:nil];

  // nodeE
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeE];
  const auto layoutE = [ASLayout layoutWithLayoutElement:nodeE size:{1,1} position:{9,0} sublayouts:nil];

  [fixture addSizeRange:{{10, 1}, {10, 1}} forNode:nodeA];
  const auto layoutA = [ASLayout layoutWithLayoutElement:nodeA size:{10,1} position:ASPointNull sublayouts:@[ layoutB, layoutC, layoutE ]];
  fixture.layout = layoutA;

  ASLayoutSpecBlock specBlockA = ^ASLayoutSpec * _Nonnull(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    return [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:0 justifyContent:ASStackLayoutJustifyContentSpaceBetween alignItems:ASStackLayoutAlignItemsStart children:@[ nodeB, nodeC, nodeE ]];
  };
  [fixture.layoutSpecBlocks setObject:specBlockA forKey:nodeA];
  return fixture;
}

/**
 * Fixture 3: Multipass stack layout
 *
 * [A: HorizStack([B, C, D])]. A is (10x1), B is (7x1), C is (2x1), D is (1x1)
 *
 * nodeB (which has flexShrink=1) will return 8x1 for its size during the first
 * stack pass, and it'll be subject to a second pass where it returns 7x1.
 *
 */
- (ASTLayoutFixture *)createFixture3
{
  const auto fixture = [[ASTLayoutFixture alloc] init];

  // nodeB wants 8,1 but it will settle for 7,1
  [fixture setReturnedSize:{8,1} forNode:nodeB];
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeB];
  [fixture addSizeRange:{{7, 0}, {7, 1}} forNode:nodeB];
  const auto layoutB = [ASLayout layoutWithLayoutElement:nodeB size:{7,1} position:{0,0} sublayouts:nil];

  // nodeC
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeC];
  const auto layoutC = [ASLayout layoutWithLayoutElement:nodeC size:{2,1} position:{7,0} sublayouts:nil];

  // nodeD
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeD];
  const auto layoutD = [ASLayout layoutWithLayoutElement:nodeD size:{1,1} position:{9,0} sublayouts:nil];

  [fixture addSizeRange:{{10, 1}, {10, 1}} forNode:nodeA];
  const auto layoutA = [ASLayout layoutWithLayoutElement:nodeA size:{10,1} position:ASPointNull sublayouts:@[ layoutB, layoutC, layoutD ]];
  fixture.layout = layoutA;

  [fixture.layoutSpecBlocks setObject:fixture1and3and5NodeALayoutSpecBlock forKey:nodeA];
  return fixture;
}

/**
 * Fixture 4: A different simple transition away from fixture 1.
 *
 * [A: HorizStack([B, D, E])]. A is (10x1), B is (1x1), D is (2x1), E is (1x1)
 *
 * From fixture 1:
 *   B survives with same layout
 *   C is removed
 *   D survives with new layout
 *   E joins with first layout
 *
 * From fixture 2:
 *   B survives with same layout
 *   C is removed
 *   D joins with first layout
 *   E survives with same layout
 */
- (ASTLayoutFixture *)createFixture4
{
  const auto fixture = [[ASTLayoutFixture alloc] init];

  // nodeB
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeB];
  const auto layoutB = [ASLayout layoutWithLayoutElement:nodeB size:{1,1} position:{0,0} sublayouts:nil];

  // nodeD
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeD];
  const auto layoutD = [ASLayout layoutWithLayoutElement:nodeD size:{2,1} position:{4,0} sublayouts:nil];

  // nodeE
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeE];
  const auto layoutE = [ASLayout layoutWithLayoutElement:nodeE size:{1,1} position:{9,0} sublayouts:nil];

  [fixture addSizeRange:{{10, 1}, {10, 1}} forNode:nodeA];
  const auto layoutA = [ASLayout layoutWithLayoutElement:nodeA size:{10,1} position:ASPointNull sublayouts:@[ layoutB, layoutD, layoutE ]];
  fixture.layout = layoutA;

  ASLayoutSpecBlock specBlockA = ^ASLayoutSpec * _Nonnull(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    return [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:0 justifyContent:ASStackLayoutJustifyContentSpaceBetween alignItems:ASStackLayoutAlignItemsStart children:@[ nodeB, nodeD, nodeE ]];
  };
  [fixture.layoutSpecBlocks setObject:specBlockA forKey:nodeA];
  return fixture;
}

/**
 * Fixture 5: Same as fixture 1, but with a bigger root node (node A).
 *
 * [A: HorizStack([B, C, D])]. A is (15x1), B is (1x1), C is (2x1), D is (1x1)
 */
- (ASTLayoutFixture *)createFixture5
{
  const auto fixture = [[ASTLayoutFixture alloc] init];

  // nodeB
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeB];
  const auto layoutB = [ASLayout layoutWithLayoutElement:nodeB size:{1,1} position:{0,0} sublayouts:nil];

  // nodeC
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeC];
  const auto layoutC = [ASLayout layoutWithLayoutElement:nodeC size:{2,1} position:{4,0} sublayouts:nil];

  // nodeD
  [fixture addSizeRange:{{0, 0}, {INFINITY, 1}} forNode:nodeD];
  const auto layoutD = [ASLayout layoutWithLayoutElement:nodeD size:{1,1} position:{9,0} sublayouts:nil];

  [fixture addSizeRange:{{15, 1}, {15, 1}} forNode:nodeA];
  const auto layoutA = [ASLayout layoutWithLayoutElement:nodeA size:{15,1} position:ASPointNull sublayouts:@[ layoutB, layoutC, layoutD ]];
  fixture.layout = layoutA;

  [fixture.layoutSpecBlocks setObject:fixture1and3and5NodeALayoutSpecBlock forKey:nodeA];
  return fixture;
}

- (void)runFirstLayoutPassWithFixture:(ASTLayoutFixture *)fixture
{
  [fixture apply];
  [fixture withSizeRangesForAllNodesUsingBlock:^(ASLayoutTestNode * _Nonnull node, ASSizeRange sizeRange) {
    OCMExpect([node.mock calculateLayoutThatFits:sizeRange]).onMainThread();

    if (!stubbedCalculatedLayoutDidChange) {
      OCMExpect([node.mock calculatedLayoutDidChange]).onMainThread();
    }
  }];

  // Trigger CA layout pass.
  [window layoutIfNeeded];

  // Make sure it went through.
  [self verifyFixture:fixture];
}

@end
