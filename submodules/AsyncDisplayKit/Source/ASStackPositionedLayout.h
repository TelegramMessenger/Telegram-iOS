//
//  ASStackPositionedLayout.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASStackUnpositionedLayout.h>

/** Represents a set of laid out and positioned stack layout children. */
struct ASStackPositionedLayout {
  const std::vector<ASStackLayoutSpecItem> items;
  /** Final size of the stack */
  const CGSize size;
  
  /** Given an unpositioned layout, computes the positions each child should be placed at. */
  static ASStackPositionedLayout compute(const ASStackUnpositionedLayout &unpositionedLayout,
                                         const ASStackLayoutSpecStyle &style,
                                         const ASSizeRange &constrainedSize);
};
