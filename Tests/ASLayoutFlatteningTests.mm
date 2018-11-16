//
//  ASLayoutFlatteningTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>

@interface ASLayoutFlatteningTests : XCTestCase
@end

@implementation ASLayoutFlatteningTests

static ASLayout *layoutWithCustomPosition(CGPoint position, id<ASLayoutElement> element, NSArray<ASLayout *> *sublayouts)
{
  return [ASLayout layoutWithLayoutElement:element
                                      size:CGSizeMake(100, 100)
                                  position:position
                                sublayouts:sublayouts];
}

static ASLayout *layout(id<ASLayoutElement> element, NSArray<ASLayout *> *sublayouts)
{
  return layoutWithCustomPosition(CGPointZero, element, sublayouts);
}

- (void)testThatFlattenedLayoutContainsOnlyDirectSubnodesInValidOrder
{
  ASLayout *flattenedLayout;
  
  @autoreleasepool {
    NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
    NSMutableArray<ASLayoutSpec *> *layoutSpecs = [NSMutableArray array];
    NSMutableArray<ASDisplayNode *> *indirectSubnodes = [NSMutableArray array];
    
    ASDisplayNode *(^subnode)(void) = ^ASDisplayNode *() { [subnodes addObject:[[ASDisplayNode alloc] init]]; return [subnodes lastObject]; };
    ASLayoutSpec *(^layoutSpec)(void) = ^ASLayoutSpec *() { [layoutSpecs addObject:[[ASLayoutSpec alloc] init]]; return [layoutSpecs lastObject]; };
    ASDisplayNode *(^indirectSubnode)(void) = ^ASDisplayNode *() { [indirectSubnodes addObject:[[ASDisplayNode alloc] init]]; return [indirectSubnodes lastObject]; };
    
    NSArray<ASLayout *> *sublayouts = @[
                                        layout(subnode(), @[
                                                            layout(indirectSubnode(), @[]),
                                                            ]),
                                        layout(layoutSpec(), @[
                                                               layout(subnode(), @[]),
                                                               layout(layoutSpec(), @[
                                                                                      layout(layoutSpec(), @[]),
                                                                                      layout(subnode(), @[]),
                                                                                      ]),
                                                               layout(layoutSpec(), @[]),
                                                               ]),
                                        layout(layoutSpec(), @[
                                                               layout(subnode(), @[
                                                                                   layout(indirectSubnode(), @[]),
                                                                                   layout(indirectSubnode(), @[
                                                                                                               layout(indirectSubnode(), @[])
                                                                                                               ]),
                                                                                   ])
                                                               ]),
                                        layout(subnode(), @[]),
                                        ];
    
    ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
    ASLayout *originalLayout = [ASLayout layoutWithLayoutElement:rootNode
                                                            size:CGSizeMake(1000, 1000)
                                                      sublayouts:sublayouts];
    flattenedLayout = [originalLayout filteredNodeLayoutTree];
    NSArray<ASLayout *> *flattenedSublayouts = flattenedLayout.sublayouts;
    NSUInteger sublayoutsCount = flattenedSublayouts.count;
    
    XCTAssertEqualObjects(originalLayout.layoutElement, flattenedLayout.layoutElement, @"The root node should be reserved");
    XCTAssertTrue(ASPointIsNull(flattenedLayout.position), @"Position of the root layout should be null");
    XCTAssertEqual(subnodes.count, sublayoutsCount, @"Flattened layout should only contain direct subnodes");
    for (int i = 0; i < sublayoutsCount; i++) {
      XCTAssertEqualObjects(subnodes[i], flattenedSublayouts[i].layoutElement, @"Sublayouts should be in correct order (flattened in DFS fashion)");
    }
  }
  
  for (ASLayout *sublayout in flattenedLayout.sublayouts) {
    XCTAssertNotNil(sublayout.layoutElement, @"Sublayout elements should be retained");
    XCTAssertEqual(0, sublayout.sublayouts.count, @"Sublayouts should not have their own sublayouts");
  }
}

#pragma mark - Test reusing ASLayouts while flattening

- (void)testThatLayoutWithNonNullPositionIsNotReused
{
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  ASLayout *originalLayout = layoutWithCustomPosition(CGPointMake(10, 10), rootNode, @[]);
  ASLayout *flattenedLayout = [originalLayout filteredNodeLayoutTree];
  XCTAssertNotEqualObjects(originalLayout, flattenedLayout, "@Layout should be reused");
  XCTAssertTrue(ASPointIsNull(flattenedLayout.position), @"Position of a root layout should be null");
}

- (void)testThatLayoutWithNullPositionAndNoSublayoutIsReused
{
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  ASLayout *originalLayout = layoutWithCustomPosition(ASPointNull, rootNode, @[]);
  ASLayout *flattenedLayout = [originalLayout filteredNodeLayoutTree];
  XCTAssertEqualObjects(originalLayout, flattenedLayout, "@Layout should be reused");
  XCTAssertTrue(ASPointIsNull(flattenedLayout.position), @"Position of a root layout should be null");
}

- (void)testThatLayoutWithNullPositionAndFlattenedNodeSublayoutsIsReused
{
  ASLayout *flattenedLayout;
  
  @autoreleasepool {
    ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
    NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
    ASDisplayNode *(^subnode)(void) = ^ASDisplayNode *() { [subnodes addObject:[[ASDisplayNode alloc] init]]; return [subnodes lastObject]; };
    ASLayout *originalLayout = layoutWithCustomPosition(ASPointNull,
                                                        rootNode,
                                                        @[
                                                          layoutWithCustomPosition(CGPointMake(10, 10), subnode(), @[]),
                                                          layoutWithCustomPosition(CGPointMake(20, 20), subnode(), @[]),
                                                          layoutWithCustomPosition(CGPointMake(30, 30), subnode(), @[]),
                                                          ]);
    flattenedLayout = [originalLayout filteredNodeLayoutTree];
    XCTAssertEqualObjects(originalLayout, flattenedLayout, "@Layout should be reused");
    XCTAssertTrue(ASPointIsNull(flattenedLayout.position), @"Position of the root layout should be null");
  }
  
  for (ASLayout *sublayout in flattenedLayout.sublayouts) {
    XCTAssertNotNil(sublayout.layoutElement, @"Sublayout elements should be retained");
    XCTAssertEqual(0, sublayout.sublayouts.count, @"Sublayouts should not have their own sublayouts");
  }
}

- (void)testThatLayoutWithNullPositionAndUnflattenedSublayoutsIsNotReused
{
  ASLayout *flattenedLayout;
  
  @autoreleasepool {
    ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
    NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
    NSMutableArray<ASLayoutSpec *> *layoutSpecs = [NSMutableArray array];
    NSMutableArray<ASDisplayNode *> *indirectSubnodes = [NSMutableArray array];
    NSMutableArray<ASLayout *> *reusedLayouts = [NSMutableArray array];
    
    ASDisplayNode *(^subnode)(void) = ^ASDisplayNode *() { [subnodes addObject:[[ASDisplayNode alloc] init]]; return [subnodes lastObject]; };
    ASLayoutSpec *(^layoutSpec)(void) = ^ASLayoutSpec *() { [layoutSpecs addObject:[[ASLayoutSpec alloc] init]]; return [layoutSpecs lastObject]; };
    ASDisplayNode *(^indirectSubnode)(void) = ^ASDisplayNode *() { [indirectSubnodes addObject:[[ASDisplayNode alloc] init]]; return [indirectSubnodes lastObject]; };
    ASLayout *(^reusedLayout)(ASDisplayNode *) = ^ASLayout *(ASDisplayNode *subnode) { [reusedLayouts addObject:layout(subnode, @[])]; return [reusedLayouts lastObject]; };
    
    /*
     * Layouts with sublayouts of both nodes and layout specs should not be reused.
     * However, all flattened node sublayouts with valid position should be reused.
     */
    ASLayout *originalLayout = layoutWithCustomPosition(ASPointNull,
                                                        rootNode,
                                                        @[
                                                          reusedLayout(subnode()),
                                                          // The 2 node sublayouts below should be reused although they are in a layout spec sublayout.
                                                          // That is because each of them have an absolute position of zero.
                                                          // This case can happen, for example, as the result of a background/overlay layout spec.
                                                          layout(layoutSpec(), @[
                                                                                 reusedLayout(subnode()),
                                                                                 reusedLayout(subnode())
                                                                                 ]),
                                                          layout(subnode(), @[
                                                                              layout(layoutSpec(), @[])
                                                                              ]),
                                                          layout(subnode(), @[
                                                                              layout(indirectSubnode(), @[])
                                                                              ]),
                                                          layoutWithCustomPosition(CGPointMake(10, 10), subnode(), @[]),
                                                          // The 2 node sublayouts below shouldn't be reused because they have non-zero absolute positions.
                                                          layoutWithCustomPosition(CGPointMake(20, 20), layoutSpec(), @[
                                                                                                                        layout(subnode(), @[]),
                                                                                                                        layout(subnode(), @[])
                                                                                                                        ]),
                                                          ]);
    flattenedLayout = [originalLayout filteredNodeLayoutTree];
    NSArray<ASLayout *> *flattenedSublayouts = flattenedLayout.sublayouts;
    NSUInteger sublayoutsCount = flattenedSublayouts.count;
    
    XCTAssertNotEqualObjects(originalLayout, flattenedLayout, @"Original layout should not be reused");
    XCTAssertEqualObjects(originalLayout.layoutElement, flattenedLayout.layoutElement, @"The root node should be reserved");
    XCTAssertTrue(ASPointIsNull(flattenedLayout.position), @"Position of the root layout should be null");
    XCTAssertTrue(reusedLayouts.count <= sublayoutsCount, @"Some sublayouts can't be reused");
    XCTAssertEqual(subnodes.count, sublayoutsCount, @"Flattened layout should only contain direct subnodes");
    int numOfActualReusedLayouts = 0;
    for (int i = 0; i < sublayoutsCount; i++) {
      ASLayout *sublayout = flattenedSublayouts[i];
      XCTAssertEqualObjects(subnodes[i], sublayout.layoutElement, @"Sublayouts should be in correct order (flattened in DFS fashion)");
      if ([reusedLayouts containsObject:sublayout]) {
        numOfActualReusedLayouts++;
      }
    }
    XCTAssertEqual(numOfActualReusedLayouts, reusedLayouts.count, @"Should reuse all layouts that can be reused");
  }
  
  for (ASLayout *sublayout in flattenedLayout.sublayouts) {
    XCTAssertNotNil(sublayout.layoutElement, @"Sublayout elements should be retained");
    XCTAssertEqual(0, sublayout.sublayouts.count, @"Sublayouts should not have their own sublayouts");
  }
}

@end
