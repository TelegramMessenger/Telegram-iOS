//
//  ASRatioLayoutSpecSnapshotTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import <AsyncDisplayKit/ASRatioLayoutSpec.h>

static const ASSizeRange kFixedSize = {{0, 0}, {100, 100}};

@interface ASRatioLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASRatioLayoutSpecSnapshotTests

- (void)testRatioLayoutSpecWithRatio:(CGFloat)ratio childSize:(CGSize)childSize identifier:(NSString *)identifier
{
  ASDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], childSize);
  
  ASLayoutSpec *layoutSpec = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:ratio child:subnode];
  
  [self testLayoutSpec:layoutSpec sizeRange:kFixedSize subnodes:@[subnode] identifier:identifier];
}

- (void)testRatioLayout
{
  [self testRatioLayoutSpecWithRatio:0.5 childSize:CGSizeMake(100, 100) identifier:@"HalfRatio"];
  [self testRatioLayoutSpecWithRatio:2.0 childSize:CGSizeMake(100, 100) identifier:@"DoubleRatio"];
  [self testRatioLayoutSpecWithRatio:7.0 childSize:CGSizeMake(100, 100) identifier:@"SevenTimesRatio"];
  [self testRatioLayoutSpecWithRatio:10.0 childSize:CGSizeMake(20, 200) identifier:@"TenTimesRatioWithItemTooBig"];
}

@end
