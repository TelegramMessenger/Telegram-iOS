//
//  ASTextNodeSnapshotTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASSnapshotTestCase.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASTextNodeSnapshotTests : ASSnapshotTestCase

@end

@implementation ASTextNodeSnapshotTests

- (void)setUp
{
  [super setUp];
  
  self.recordMode = NO;
}

- (void)testTextContainerInset
{
  // trivial test case to ensure ASSnapshotTestCase works
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"judar"
                                                            attributes:@{NSFontAttributeName : [UIFont italicSystemFontOfSize:24]}];
  textNode.textContainerInset = UIEdgeInsetsMake(0, 2, 0, 2);
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)));
  
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testTextContainerInsetIsIncludedWithSmallerConstrainedSize
{
  UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
  backgroundView.layer.as_allowsHighlightDrawing = YES;

  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"judar judar judar judar judar judar"
                                                            attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:30] }];
  
  textNode.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
  
  ASLayout *layout = [textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 80))];
  textNode.frame = CGRectMake(50, 50, layout.size.width, layout.size.height);

  [backgroundView addSubview:textNode.view];
  backgroundView.frame = UIEdgeInsetsInsetRect(textNode.bounds, UIEdgeInsetsMake(-50, -50, -50, -50));
  
  textNode.highlightRange = NSMakeRange(0, textNode.attributedText.length);

  [ASSnapshotTestCase hackilySynchronouslyRecursivelyRenderNode:textNode];
  ASSnapshotVerifyLayer(backgroundView.layer, nil);
}

- (void)testTextContainerInsetHighlight
{
  UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
  backgroundView.layer.as_allowsHighlightDrawing = YES;

  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"yolo"
                                                            attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:30] }];

  textNode.textContainerInset = UIEdgeInsetsMake(5, 10, 10, 5);
  ASLayout *layout = [textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY))];
  textNode.frame = CGRectMake(50, 50, layout.size.width, layout.size.height);

  [backgroundView addSubview:textNode.view];
  backgroundView.frame = UIEdgeInsetsInsetRect(textNode.bounds, UIEdgeInsetsMake(-50, -50, -50, -50));

  textNode.highlightRange = NSMakeRange(0, textNode.attributedText.length);

  [ASSnapshotTestCase hackilySynchronouslyRecursivelyRenderNode:textNode];
  ASSnapshotVerifyView(backgroundView, nil);
}

// This test is disabled because the fast-path is disabled.
- (void)DISABLED_testThatFastPathTruncationWorks
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is Important" attributes:@{ NSForegroundColorAttributeName: [UIColor blueColor], NSFontAttributeName: [UIFont italicSystemFontOfSize:24] }];
  [textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 50))];
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testThatSlowPathTruncationWorks
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is Important" attributes:@{ NSForegroundColorAttributeName: [UIColor blueColor], NSFontAttributeName: [UIFont italicSystemFontOfSize:24] }];
  // Set exclusion paths to trigger slow path
  textNode.exclusionPaths = @[ [UIBezierPath bezierPath] ];
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 50)));
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testShadowing
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is Important"];
  textNode.shadowColor = [UIColor blackColor].CGColor;
  textNode.shadowOpacity = 0.3;
  textNode.shadowRadius = 3;
  textNode.shadowOffset = CGSizeMake(0, 1);
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
  ASSnapshotVerifyNode(textNode, nil);
}

/**
 * https://github.com/TextureGroup/Texture/issues/822
 */
- (void)DISABLED_testThatTruncationTokenAttributesPrecedeThoseInheritedFromTextWhenTruncateTailMode
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.style.maxSize = CGSizeMake(20, 80);
  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:@"Quality is an important "];
  [mas appendAttributedString:[[NSAttributedString alloc] initWithString:@"thing" attributes:@{ NSBackgroundColorAttributeName : UIColor.yellowColor}]];
  textNode.attributedText = mas;
  textNode.truncationMode = NSLineBreakByTruncatingTail;
  
  textNode.truncationAttributedText = [[NSAttributedString alloc] initWithString:@"\u2026" attributes:@{ NSBackgroundColorAttributeName: UIColor.greenColor }];
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testFontPointSizeScaling
{
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  paragraphStyle.lineHeightMultiple = 0.5;
  paragraphStyle.lineSpacing = 2.0;

  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.style.maxSize = CGSizeMake(60, 80);
  textNode.pointSizeScaleFactors = @[@0.5];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is an important thing"
                                                            attributes:@{ NSParagraphStyleAttributeName: paragraphStyle }];

  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
  ASSnapshotVerifyNode(textNode, nil);
}

@end
