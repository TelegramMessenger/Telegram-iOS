//
//  ASScrollNodeTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "ASXCTExtensions.h"

@interface ASScrollNodeTests : XCTestCase

@property (nonatomic) ASScrollNode *scrollNode;
@property (nonatomic) ASDisplayNode *subnode;

@end

@implementation ASScrollNodeTests

- (void)setUp
{
  ASDisplayNode *subnode = [[ASDisplayNode alloc] init];
  self.subnode = subnode;

  self.scrollNode = [[ASScrollNode alloc] init];
  self.scrollNode.scrollableDirections = ASScrollDirectionVerticalDirections;
  self.scrollNode.automaticallyManagesContentSize = YES;
  self.scrollNode.automaticallyManagesSubnodes = YES;
  self.scrollNode.layoutSpecBlock = ^ASLayoutSpec * _Nonnull(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    return [[ASWrapperLayoutSpec alloc] initWithLayoutElement:subnode];
  };
  [self.scrollNode view];
}

- (void)testSubnodeLayoutCalculatedWithUnconstrainedMaxSizeInScrollableDirection
{
  CGSize parentSize = CGSizeMake(100, 100);
  ASSizeRange sizeRange = ASSizeRangeMake(parentSize);

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];

  ASSizeRange subnodeSizeRange = sizeRange;
  subnodeSizeRange.max.height = CGFLOAT_MAX;
  XCTAssertEqual(self.scrollNode.scrollableDirections, ASScrollDirectionVerticalDirections);
  ASXCTAssertEqualSizeRanges(self.subnode.constrainedSizeForCalculatedLayout, subnodeSizeRange);

  // Same test for horizontal scrollable directions
  self.scrollNode.scrollableDirections = ASScrollDirectionHorizontalDirections;
  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];

  subnodeSizeRange = sizeRange;
  subnodeSizeRange.max.width = CGFLOAT_MAX;

  ASXCTAssertEqualSizeRanges(self.subnode.constrainedSizeForCalculatedLayout, subnodeSizeRange);
}

- (void)testAutomaticallyManagesContentSizeUnderflow
{
  CGSize subnodeSize = CGSizeMake(100, 100);
  CGSize parentSize = CGSizeMake(100, 200);
  ASSizeRange sizeRange = ASSizeRangeUnconstrained;

  self.subnode.style.preferredSize = subnodeSize;

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];
  [self.scrollNode layout];

  ASXCTAssertEqualSizes(self.scrollNode.calculatedSize, parentSize);
  ASXCTAssertEqualSizes(self.scrollNode.view.contentSize, subnodeSize);
}

- (void)testAutomaticallyManagesContentSizeOverflow
{
  CGSize subnodeSize = CGSizeMake(100, 500);
  CGSize parentSize = CGSizeMake(100, 200);
  ASSizeRange sizeRange = ASSizeRangeUnconstrained;

  self.subnode.style.preferredSize = subnodeSize;

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];
  [self.scrollNode layout];

  ASXCTAssertEqualSizes(self.scrollNode.calculatedSize, parentSize);
  ASXCTAssertEqualSizes(self.scrollNode.view.contentSize, subnodeSize);
}

- (void)testAutomaticallyManagesContentSizeWithSizeRangeSmallerThanParentSize
{
  CGSize subnodeSize = CGSizeMake(100, 100);
  CGSize parentSize = CGSizeMake(100, 500);
  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeMake(100, 100), CGSizeMake(100, 200));

  self.subnode.style.preferredSize = subnodeSize;

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];
  [self.scrollNode layout];

  ASXCTAssertEqualSizes(self.scrollNode.calculatedSize, sizeRange.max);
  ASXCTAssertEqualSizes(self.scrollNode.view.contentSize, subnodeSize);
}

- (void)testAutomaticallyManagesContentSizeWithSizeRangeBiggerThanParentSize
{
  CGSize subnodeSize = CGSizeMake(100, 200);
  CGSize parentSize = CGSizeMake(100, 100);
  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeMake(100, 150));

  self.subnode.style.preferredSize = subnodeSize;

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];
  [self.scrollNode layout];

  ASXCTAssertEqualSizes(self.scrollNode.calculatedSize, sizeRange.min);
  ASXCTAssertEqualSizes(self.scrollNode.view.contentSize, subnodeSize);
}

- (void)testAutomaticallyManagesContentSizeWithInvalidCalculatedSizeForLayout
{
  CGSize subnodeSize = CGSizeMake(100, 200);
  CGSize parentSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
  ASSizeRange sizeRange = ASSizeRangeUnconstrained;

  self.subnode.style.preferredSize = subnodeSize;

  [self.scrollNode layoutThatFits:sizeRange parentSize:parentSize];
  [self.scrollNode layout];

  ASXCTAssertEqualSizes(self.scrollNode.calculatedSize, subnodeSize);
  ASXCTAssertEqualSizes(self.scrollNode.view.contentSize, subnodeSize);
}

- (void)testASScrollNodeAccessibility {
  ASDisplayNode *scrollNode = [[ASDisplayNode alloc] init];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.isAccessibilityContainer = YES;
  node.accessibilityLabel = @"node";
  [scrollNode addSubnode:node];
  node.frame = CGRectMake(0,0,100,100);
  ASTextNode2 *text = [[ASTextNode2 alloc] init];
  text.attributedText = [[NSAttributedString alloc] initWithString:@"text"];
  [node addSubnode:text];

  ASTextNode2 *text2 = [[ASTextNode2 alloc] init];
  text2.attributedText = [[NSAttributedString alloc] initWithString:@"text2"];
  [node addSubnode:text2];
  __unused UIView *view = scrollNode.view;
  XCTAssertTrue(node.view.accessibilityElements.firstObject, @"node");

  // Following tests will only pass when accessibility is enabled.
  // More details: https://github.com/TextureGroup/Texture/pull/1188

  // A bunch of a11y containers each of which hold aggregated labels.
  /* NSArray *a11yElements = [scrollNode.view accessibilityElements];
  XCTAssertTrue(a11yElements.count > 0, @"accessibilityElements should exist");
  
  UIAccessibilityElement *container = a11yElements.firstObject;
  XCTAssertTrue(container.isAccessibilityElement == false && container.accessibilityElements.count > 0);
  UIAccessibilityElement *ae = container.accessibilityElements.firstObject;
  XCTAssertTrue([[ae accessibilityLabel] isEqualToString:@"node, text, text2"]);
  */
}

@end
