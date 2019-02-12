//
//  ASTextNode2SnapshotTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//


#import "ASTestCase.h"
#import "ASSnapshotTestCase.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASTextNode2SnapshotTests : ASSnapshotTestCase

@end

@interface LineBreakConfig : NSObject

@property (nonatomic, assign) NSUInteger numberOfLines;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;

+ (NSArray<LineBreakConfig *> *)configs;

- (instancetype)initWithNumberOfLines:(NSUInteger)numberOfLines lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (NSString *)breakModeDescription;

@end

@implementation LineBreakConfig

+ (NSArray<LineBreakConfig *> *)configs
{
  static dispatch_once_t init_predicate;
  static NSArray<LineBreakConfig *> *allConfigs = nil;

  dispatch_once(&init_predicate, ^{
    NSMutableArray *setup = [NSMutableArray new];
    for (int i = 0; i <= 3; i++) {
      for (int j = NSLineBreakByWordWrapping; j <= NSLineBreakByTruncatingMiddle; j++) {
        if (j == NSLineBreakByClipping) continue;
        [setup addObject:[[LineBreakConfig alloc] initWithNumberOfLines:i lineBreakMode:(NSLineBreakMode) j]];
      }

      allConfigs = [NSArray arrayWithArray:setup];
    }
  });
  return allConfigs;
}

- (instancetype)initWithNumberOfLines:(NSUInteger)numberOfLines lineBreakMode:(NSLineBreakMode)lineBreakMode
{
  self = [super init];
  if (self != nil) {
    _numberOfLines = numberOfLines;
    _lineBreakMode = lineBreakMode;

    return self;
  }
  return nil;
}

- (NSString *)breakModeDescription {
  NSString *lineBreak = nil;
  switch (self.lineBreakMode) {
    case NSLineBreakByTruncatingHead:
      lineBreak = @"NSLineBreakByTruncatingHead";
          break;
    case NSLineBreakByCharWrapping:
      lineBreak = @"NSLineBreakByCharWrapping";
          break;
    case NSLineBreakByClipping:
      lineBreak = @"NSLineBreakByClipping";
          break;
    case NSLineBreakByWordWrapping:
      lineBreak = @"NSLineBreakByWordWrapping";
          break;
    case NSLineBreakByTruncatingTail:
      lineBreak = @"NSLineBreakByTruncatingTail";
          break;
    case NSLineBreakByTruncatingMiddle:
      lineBreak = @"NSLineBreakByTruncatingMiddle";
          break;
    default:
      lineBreak = @"Unknown?";
          break;
  }
  return lineBreak;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"numberOfLines: %lu\nlineBreakMode: %@", (unsigned long) self.numberOfLines, [self breakModeDescription]];
}

@end

@implementation ASTextNode2SnapshotTests

- (void)setUp
{
  [super setUp];

  // This will use ASTextNode2 for snapshot tests.
  // All tests are duplicated from ASTextNodeSnapshotTests.
  ASConfiguration *config = [[ASConfiguration alloc] initWithDictionary:nil];
#if AS_ENABLE_TEXTNODE
  config.experimentalFeatures = ASExperimentalTextNode;
#endif
  [ASConfigurationManager test_resetWithConfiguration:config];

  self.recordMode = NO;
}

- (void)tearDown
{
  [super tearDown];
  ASConfiguration *config = [[ASConfiguration alloc] initWithDictionary:nil];
  config.experimentalFeatures = kNilOptions;
  [ASConfigurationManager test_resetWithConfiguration:config];
}

- (void)testTextContainerInset_ASTextNode2
{
  // trivial test case to ensure ASSnapshotTestCase works
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"judar"
                                                        attributes:@{NSFontAttributeName: [UIFont italicSystemFontOfSize:24]}];
  textNode.textContainerInset = UIEdgeInsetsMake(0, 2, 0, 2);
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)));

  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testTextTruncationModes_ASTextNode2
{
  UIView *container = [[UIView alloc] initWithFrame:(CGRect) {CGPointZero, (CGSize) {375.0f, 667.0f}}];

  UILabel *textNodeLabel = [[UILabel alloc] init];
  UILabel *uiLabelLabel = [[UILabel alloc] init];
  UILabel *description = [[UILabel alloc] init];
  textNodeLabel.text = @"ASTextNode2:";
  textNodeLabel.font = [UIFont boldSystemFontOfSize:16.0];
  textNodeLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];
  uiLabelLabel.text = @"UILabel:";
  uiLabelLabel.font = [UIFont boldSystemFontOfSize:16.0];
  uiLabelLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];

  description.text = @"<Description>";
  description.font = [UIFont italicSystemFontOfSize:16.0];
  description.numberOfLines = 0;

  uiLabelLabel.textColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];

  UILabel *reference = [[UILabel alloc] init];
  ASTextNode *textNode = [[ASTextNode alloc] init]; // ASTextNode2

  NSMutableAttributedString *refString = [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
          attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:18.0f] }];
  NSMutableAttributedString *asString = [refString mutableCopy];

  reference.attributedText = refString;
  textNode.attributedText = asString;

  CGSize size = (CGSize) {container.bounds.size.width, 120.0};
  CGPoint origin = (CGPoint) {CGRectGetWidth(container.bounds) / 2 - size.width / 2, CGRectGetHeight(container.bounds) / 2 - size.height / 2}; // center

  textNode.frame = (CGRect) {origin, size};
  reference.frame = CGRectOffset(textNode.frame, 0, -160.0f);

  textNodeLabel.bounds = (CGRect) {CGPointZero, (CGSize) {container.bounds.size.width, textNodeLabel.font.lineHeight}};
  origin = (CGPoint) {textNode.frame.origin.x, textNode.frame.origin.y - textNodeLabel.bounds.size.height};
  textNodeLabel.frame = (CGRect) {origin, textNodeLabel.bounds.size};

  uiLabelLabel.bounds = (CGRect) {CGPointZero, (CGSize) {container.bounds.size.width, uiLabelLabel.font.lineHeight}};
  origin = (CGPoint) {reference.frame.origin.x, reference.frame.origin.y - uiLabelLabel.bounds.size.height};
  uiLabelLabel.frame = (CGRect) {origin, uiLabelLabel.bounds.size};

  uiLabelLabel.bounds = (CGRect) {CGPointZero, (CGSize) {container.bounds.size.width, uiLabelLabel.font.lineHeight}};
  origin = (CGPoint) {textNode.frame.origin.x, textNode.frame.origin.y - uiLabelLabel.bounds.size.height};
  uiLabelLabel.frame = (CGRect) {origin, uiLabelLabel.bounds.size};

  uiLabelLabel.bounds = (CGRect) {CGPointZero, (CGSize) {container.bounds.size.width, uiLabelLabel.font.lineHeight}};
  origin = (CGPoint) {reference.frame.origin.x, reference.frame.origin.y - uiLabelLabel.bounds.size.height};
  uiLabelLabel.frame = (CGRect) {origin, uiLabelLabel.bounds.size};

  description.bounds = textNode.bounds;
  description.frame = (CGRect) {(CGPoint) {0, container.bounds.size.height * 0.8}, description.bounds.size};

  [container addSubview:reference];
  [container addSubview:textNode.view];
  [container addSubview:textNodeLabel];
  [container addSubview:uiLabelLabel];
  [container addSubview:description];

  NSArray<LineBreakConfig *> *c = [LineBreakConfig configs];
  for (LineBreakConfig *config in c) {
    reference.lineBreakMode = textNode.truncationMode = config.lineBreakMode;
    reference.numberOfLines = textNode.maximumNumberOfLines = config.numberOfLines;
    description.text = config.description;
    [container setNeedsLayout];
    NSString *identifier = [NSString stringWithFormat:@"%@_%luLines", [config breakModeDescription], (unsigned long)config.numberOfLines];
    [ASSnapshotTestCase hackilySynchronouslyRecursivelyRenderNode:textNode];
    ASSnapshotVerifyViewWithTolerance(container, identifier, 0.01);
  }
}

- (void)testTextContainerInsetIsIncludedWithSmallerConstrainedSize_ASTextNode2
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

- (void)testTextContainerInsetHighlight_ASTextNode2
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
- (void)DISABLED_testThatFastPathTruncationWorks_ASTextNode2
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is Important" attributes:@{ NSForegroundColorAttributeName: [UIColor blueColor], NSFontAttributeName: [UIFont italicSystemFontOfSize:24] }];
  [textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 50))];
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testThatSlowPathTruncationWorks_ASTextNode2
{
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Quality is Important" attributes:@{ NSForegroundColorAttributeName: [UIColor blueColor], NSFontAttributeName: [UIFont italicSystemFontOfSize:24] }];
  // Set exclusion paths to trigger slow path
  textNode.exclusionPaths = @[ [UIBezierPath bezierPath] ];
  ASDisplayNodeSizeToFitSizeRange(textNode, ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 50)));
  ASSnapshotVerifyNode(textNode, nil);
}

- (void)testShadowing_ASTextNode2
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
- (void)DISABLED_testThatTruncationTokenAttributesPrecedeThoseInheritedFromTextWhenTruncateTailMode_ASTextNode2
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

@end
