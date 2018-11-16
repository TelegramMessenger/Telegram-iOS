//
//  ASButtonNodeTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASButtonNode.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>

@interface ASButtonNodeTests : XCTestCase
@end

@implementation ASButtonNodeTests

- (void)testAccessibility
{
  // Setup a button with some title.
  ASButtonNode *buttonNode = nil;
  buttonNode = [[ASButtonNode alloc] init];
  NSString *title = @"foo";
  [buttonNode setTitle:title withFont:nil withColor:nil forState:UIControlStateNormal];

  // Verify accessibility properties.
  XCTAssertTrue(buttonNode.accessibilityTraits == UIAccessibilityTraitButton,
                @"Should have button accessibility trait, instead has %llu",
                buttonNode.accessibilityTraits);
  XCTAssertTrue(buttonNode.defaultAccessibilityTraits == UIAccessibilityTraitButton,
                @"Default accessibility traits should return button accessibility trait, instead "
                @"returns %llu",
                buttonNode.defaultAccessibilityTraits);
  XCTAssertTrue([buttonNode.accessibilityLabel isEqualToString:title],
                @"Accessibility label is incorrectly set to \n%@\n when it should be \n%@\n",
                buttonNode.accessibilityLabel, title);
  XCTAssertTrue([buttonNode.defaultAccessibilityLabel isEqualToString:title],
                @"Default accessibility label incorrectly returns \n%@\n when it should be \n%@\n",
                buttonNode.defaultAccessibilityLabel, title);

  // Disable the button and verify that accessibility traits has been updated correctly.
  buttonNode.enabled = NO;
  UIAccessibilityTraits disabledButtonTrait = UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
  XCTAssertTrue(buttonNode.accessibilityTraits == disabledButtonTrait,
                @"Should have disabled button accessibility trait, instead has %llu",
                buttonNode.accessibilityTraits);
  XCTAssertTrue(buttonNode.defaultAccessibilityTraits == disabledButtonTrait,
                @"Default accessibility traits should return disabled button accessibility trait, "
                @"instead returns %llu",
                buttonNode.defaultAccessibilityTraits);
}

@end
