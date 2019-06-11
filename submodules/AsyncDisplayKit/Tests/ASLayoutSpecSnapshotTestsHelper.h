//
//  ASLayoutSpecSnapshotTestsHelper.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASSnapshotTestCase.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@class ASLayoutSpec;

@interface ASLayoutSpecSnapshotTestCase: ASSnapshotTestCase
/**
 Test the layout spec or records a snapshot if recordMode is YES.
 @param layoutSpec The layout spec under test or to snapshot
 @param sizeRange The size range used to calculate layout of the given layout spec.
 @param subnodes An array of ASDisplayNodes used within the layout spec.
 @param identifier An optional identifier, used to identify this snapshot test.
 
 @discussion In order to make the layout spec visible, it is embeded to a ASDisplayNode host.
 Any subnodes used within the layout spec must be provided.
 They will be added to the host in the same order as the array.
 */
- (void)testLayoutSpec:(ASLayoutSpec *)layoutSpec
             sizeRange:(ASSizeRange)sizeRange
              subnodes:(NSArray *)subnodes
            identifier:(NSString *)identifier;
@end

__attribute__((overloadable)) static inline ASDisplayNode *ASDisplayNodeWithBackgroundColor(UIColor *backgroundColor, CGSize size) {
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.layerBacked = YES;
  node.backgroundColor = backgroundColor;
  node.style.width = ASDimensionMakeWithPoints(size.width);
  node.style.height = ASDimensionMakeWithPoints(size.height);
  return node;
}

__attribute__((overloadable)) static inline ASDisplayNode *ASDisplayNodeWithBackgroundColor(UIColor *backgroundColor)
{
  return ASDisplayNodeWithBackgroundColor(backgroundColor, CGSizeZero);
}
