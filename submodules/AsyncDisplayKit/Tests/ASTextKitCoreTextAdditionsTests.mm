//
//  ASTextKitCoreTextAdditionsTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <CoreText/CoreText.h>

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASTextKitCoreTextAdditions.h>

#if AS_ENABLE_TEXTNODE

BOOL floatsCloseEnough(CGFloat float1, CGFloat float2) {
  CGFloat epsilon = 0.00001;
  return (fabs(float1 - float2) < epsilon);
}

@interface ASTextKitCoreTextAdditionsTests : XCTestCase

@end

@implementation ASTextKitCoreTextAdditionsTests

- (void)testAttributeCleansing
{
  UIFont *font = [UIFont systemFontOfSize:12.0];
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:font}];
  CFRange cfRange = CFRangeMake(0, testString.length);
  CGColorRef blueColor = CGColorRetain([UIColor blueColor].CGColor);
  CFAttributedStringSetAttribute((CFMutableAttributedStringRef)testString,
                                 cfRange,
                                 kCTForegroundColorAttributeName,
                                 blueColor);
  UIColor *color = [UIColor colorWithCGColor:blueColor];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([[actualCleansedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] isEqual:color], @"Expected the %@ core text attribute to be cleansed from the string %@\n Should match %@", kCTForegroundColorFromContextAttributeName, actualCleansedString, color);
  CGColorRelease(blueColor);
}

- (void)testNoAttributeCleansing
{
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0],
                                                                                                                 NSForegroundColorAttributeName : [UIColor blueColor]}];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([testString isEqualToAttributedString:actualCleansedString], @"Expected the output string %@ to be the same as the input %@ if there are no core text attributes", actualCleansedString, testString);
}

- (void)testNSParagraphStyleNoCleansing
{
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.lineSpacing = 10.0;

  //NSUnderlineStyleAttributeName flags the unsupported CT attribute check
  NSDictionary *attributes = @{NSParagraphStyleAttributeName:paragraphStyle,
                               NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)};

  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"Test" attributes:attributes];
  NSAttributedString *cleansedString = ASCleanseAttributedStringOfCoreTextAttributes(attributedString);

  NSParagraphStyle *cleansedParagraphStyle = [cleansedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];

  XCTAssertTrue(floatsCloseEnough(cleansedParagraphStyle.lineSpacing, paragraphStyle.lineSpacing), @"Expected the output line spacing: %f to be equal to the input line spacing: %f", cleansedParagraphStyle.lineSpacing, paragraphStyle.lineSpacing);
}

@end

#endif
