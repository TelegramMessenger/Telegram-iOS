//
//  ASTextKitFontSizeAdjusterTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitFontSizeAdjuster.h>
#import <XCTest/XCTest.h>

#if AS_ENABLE_TEXTNODE

@interface ASFontSizeAdjusterTests : XCTestCase

@end

@implementation ASFontSizeAdjusterTests

- (void)testFontSizeAdjusterAttributes
{
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  paragraphStyle.lineHeightMultiple = 2.0;
  paragraphStyle.lineSpacing = 2.0;
  paragraphStyle.paragraphSpacing = 4.0;
  paragraphStyle.firstLineHeadIndent = 6.0;
  paragraphStyle.headIndent = 8.0;
  paragraphStyle.tailIndent = 10.0;
  paragraphStyle.minimumLineHeight = 12.0;
  paragraphStyle.maximumLineHeight = 14.0;

  NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet"
                                                                             attributes:@{ NSParagraphStyleAttributeName: paragraphStyle }];

  [ASTextKitFontSizeAdjuster adjustFontSizeForAttributeString:string withScaleFactor:0.5];

  NSParagraphStyle *adjustedParagraphStyle = [string attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];

  XCTAssertEqual(adjustedParagraphStyle.lineHeightMultiple, 2.0);
  XCTAssertEqual(adjustedParagraphStyle.lineSpacing, 1.0);
  XCTAssertEqual(adjustedParagraphStyle.paragraphSpacing, 2.0);
  XCTAssertEqual(adjustedParagraphStyle.firstLineHeadIndent, 3.0);
  XCTAssertEqual(adjustedParagraphStyle.headIndent, 4.0);
  XCTAssertEqual(adjustedParagraphStyle.tailIndent, 5.0);
  XCTAssertEqual(adjustedParagraphStyle.minimumLineHeight, 6.0);
  XCTAssertEqual(adjustedParagraphStyle.maximumLineHeight, 7.0);
}

@end

#endif
