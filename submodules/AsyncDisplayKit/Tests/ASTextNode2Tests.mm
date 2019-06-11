//
//  ASTextNode2Tests.mm
//  TextureTests
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <CoreText/CoreText.h>

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASTextNode2.h>
#import <AsyncDisplayKit/ASTextNode+Beta.h>

#import "ASTestCase.h"

@interface ASTextNode2Tests : XCTestCase

@property(nonatomic) ASTextNode2 *textNode;
@property(nonatomic, copy) NSAttributedString *attributedText;

@end

@implementation ASTextNode2Tests

- (void)setUp
{
  [super setUp];
  _textNode = [[ASTextNode2 alloc] init];

  UIFontDescriptor *desc = [UIFontDescriptor fontDescriptorWithName:@"Didot" size:18];
  NSArray *arr = @[ @{
                      UIFontFeatureTypeIdentifierKey : @(kLetterCaseType),
                      UIFontFeatureSelectorIdentifierKey : @(kSmallCapsSelector)
                      } ];
  desc = [desc fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute : arr}];
  UIFont *f = [UIFont fontWithDescriptor:desc size:0];
  NSDictionary *d = @{NSFontAttributeName : f};
  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc]
                                    initWithString:
                                    @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor "
                                    @"incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud "
                                    @"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure "
                                    @"dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
                                    @"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt "
                                    @"mollit anim id est laborum."
                                    attributes:d];
  NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
  para.alignment = NSTextAlignmentCenter;
  para.lineSpacing = 1.0;
  [mas addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, mas.length - 1)];

  // Vary the linespacing on the last line
  NSMutableParagraphStyle *lastLinePara = [NSMutableParagraphStyle new];
  lastLinePara.alignment = para.alignment;
  lastLinePara.lineSpacing = 5.0;
  [mas addAttribute:NSParagraphStyleAttributeName
              value:lastLinePara
              range:NSMakeRange(mas.length - 1, 1)];

  _attributedText = mas;
  _textNode.attributedText = _attributedText;
}

- (void)testTruncation
{
  XCTAssertTrue([(ASTextNode *)_textNode shouldTruncateForConstrainedSize:ASSizeRangeMake(CGSizeMake(100, 100))], @"Text Node should truncate");

  _textNode.frame = CGRectMake(0, 0, 100, 100);
  XCTAssertTrue(_textNode.isTruncated, @"Text Node should be truncated");
}

- (void)testAccessibility
{
  XCTAssertTrue(_textNode.isAccessibilityElement, @"Should be an accessibility element");
  XCTAssertTrue(_textNode.accessibilityTraits == UIAccessibilityTraitStaticText,
                @"Should have static text accessibility trait, instead has %llu",
                _textNode.accessibilityTraits);
  XCTAssertTrue(_textNode.defaultAccessibilityTraits == UIAccessibilityTraitStaticText,
                @"Default accessibility traits should return static text accessibility trait, "
                @"instead returns %llu",
                _textNode.defaultAccessibilityTraits);

  XCTAssertTrue([_textNode.accessibilityLabel isEqualToString:_attributedText.string],
                @"Accessibility label is incorrectly set to \n%@\n when it should be \n%@\n",
                _textNode.accessibilityLabel, _attributedText.string);
  XCTAssertTrue([_textNode.defaultAccessibilityLabel isEqualToString:_attributedText.string],
                @"Default accessibility label incorrectly returns \n%@\n when it should be \n%@\n",
                _textNode.defaultAccessibilityLabel, _attributedText.string);
}

@end
