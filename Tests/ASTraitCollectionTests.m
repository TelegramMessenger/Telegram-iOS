//
//  ASTraitCollectionTests.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
