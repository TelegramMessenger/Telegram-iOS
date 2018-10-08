//
//  ASTraitCollectionTests.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASTraitCollection.h>

@interface ASTraitCollectionTests : XCTestCase

@end

@implementation ASTraitCollectionTests

- (void)testPrimitiveContentSizeCategoryLifetime
{
  ASPrimitiveContentSizeCategory primitiveContentSize;
  @autoreleasepool {
    // Make sure the compiler won't optimize string alloc/dealloc
    NSString *contentSizeCategory = [NSString stringWithCString:"UICTContentSizeCategoryL" encoding:NSUTF8StringEncoding];
    primitiveContentSize = ASPrimitiveContentSizeCategoryMake(contentSizeCategory);
  }

  XCTAssertEqual(primitiveContentSize, UIContentSizeCategoryLarge);
}

@end
