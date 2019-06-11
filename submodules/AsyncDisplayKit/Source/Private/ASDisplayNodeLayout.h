//
//  ASDisplayNodeLayout.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

#import <AsyncDisplayKit/ASDimension.h>

@class ASLayout;

/*
 * Represents a connection between an ASLayout and a ASDisplayNode
 * ASDisplayNode uses this to store additional information that are necessary besides the layout
 */
struct ASDisplayNodeLayout {
  ASLayout *layout;
  ASSizeRange constrainedSize;
  CGSize parentSize;
  BOOL requestedLayoutFromAbove;
  NSUInteger version;
  
  /*
   * Create a new display node layout with
   * @param layout The layout to associate, usually returned from a call to -layoutThatFits:parentSize:
   * @param constrainedSize Constrained size used to create the layout
   * @param parentSize Parent size used to create the layout
   * @param version The version of the source layout data – see ASDisplayNode's _layoutVersion. 
   */
  ASDisplayNodeLayout(ASLayout *layout, ASSizeRange constrainedSize, CGSize parentSize, NSUInteger version)
  : layout(layout), constrainedSize(constrainedSize), parentSize(parentSize), requestedLayoutFromAbove(NO), version(version) {};
  
  /*
   * Creates a layout without any layout associated. By default this display node layout is dirty.
   */
  ASDisplayNodeLayout()
  : layout(nil), constrainedSize({{0, 0}, {0, 0}}), parentSize({0, 0}), requestedLayoutFromAbove(NO), version(0) {};

  /**
   * Returns whether this is valid for a given version
   */
  BOOL isValid(NSUInteger versionArg) {
    return layout != nil && version >= versionArg;
  }

  /**
   * Returns whether this is valid for a given constrained size, parent size, and version
   */
  BOOL isValid(ASSizeRange theConstrainedSize, CGSize theParentSize, NSUInteger versionArg) {
    return isValid(versionArg)
    && CGSizeEqualToSize(parentSize, theParentSize)
    && ASSizeRangeEqualToSizeRange(constrainedSize, theConstrainedSize);
  }
};
