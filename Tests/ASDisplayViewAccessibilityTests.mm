//
//  ASDisplayViewAccessibilityTests.mm
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>

@interface ASDisplayViewAccessibilityTests : XCTestCase
@end

@implementation ASDisplayViewAccessibilityTests

- (void)testAccessibilityElementsAccessors
{
  // Setup nodes with accessibility info
  ASDisplayNode *node = nil;
  ASDisplayNode *subnode = nil;
  node = [[ASDisplayNode alloc] init];
  subnode = [[ASDisplayNode alloc] init];
  NSString *label = @"foo";
  subnode.isAccessibilityElement = YES;
  subnode.accessibilityLabel = label;
  [node addSubnode:subnode];
  XCTAssertEqualObjects([node.view.accessibilityElements.firstObject accessibilityLabel], label);
  // NOTE: The following tests will fail unless accessibility is enabled, e.g. by turning the
  // accessibility inspector on. See https://github.com/TextureGroup/Texture/pull/1069 for details.
  /*XCTAssertEqualObjects([[node.view accessibilityElementAtIndex:0] accessibilityLabel], label);
  XCTAssertEqual(node.view.accessibilityElementCount, 1);
  XCTAssertEqual([node.view indexOfAccessibilityElement:node.view.accessibilityElements.firstObject], 0);*/
}

- (void)testThatSubnodeAccessibilityLabelAggregationWorks {
  // Setup nodes
  ASDisplayNode *node = nil;
  ASDisplayNode *innerNode1 = nil;
  ASDisplayNode *innerNode2 = nil;
  node = [[ASDisplayNode alloc] init];
  innerNode1 = [[ASDisplayNode alloc] init];
  innerNode2 = [[ASDisplayNode alloc] init];

  // Initialize nodes with relevant accessibility data
  node.isAccessibilityContainer = YES;
  innerNode1.accessibilityLabel = @"hello";
  innerNode2.accessibilityLabel = @"world";

  // Attach the subnodes to the parent node, then ensure their accessibility labels have been'
  // aggregated to the parent's accessibility label
  [node addSubnode:innerNode1];
  [node addSubnode:innerNode2];
  XCTAssertEqualObjects([node.view.accessibilityElements.firstObject accessibilityLabel],
                        @"hello, world", @"Subnode accessibility label aggregation broken %@",
                        [node.view.accessibilityElements.firstObject accessibilityLabel]);
}

- (void)testThatContainerAccessibilityLabelOverrideStopsAggregation {
  // Setup nodes
  ASDisplayNode *node = nil;
  ASDisplayNode *innerNode = nil;
  node = [[ASDisplayNode alloc] init];
  innerNode = [[ASDisplayNode alloc] init];

  // Initialize nodes with relevant accessibility data
  node.isAccessibilityContainer = YES;
  node.accessibilityLabel = @"hello";
  innerNode.accessibilityLabel = @"world";

  // Attach the subnode to the parent node, then ensure the parent's accessibility label does not
  // get aggregated with the subnode's label
  [node addSubnode:innerNode];
  XCTAssertEqualObjects([node.view.accessibilityElements.firstObject accessibilityLabel], @"hello",
                        @"Container accessibility label override broken %@",
                        [node.view.accessibilityElements.firstObject accessibilityLabel]);
}

@end
