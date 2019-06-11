//
//  ASCenterLayoutSpec.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASRelativeLayoutSpec.h>

/** 
  * How the child is centered within the spec.
  *
  * The default option will position the child at {0,0} relatively to the layout bound.
  * Swift: use [] for the default behavior.
  */
typedef NS_OPTIONS(NSUInteger, ASCenterLayoutSpecCenteringOptions) {
  /** The child is positioned in {0,0} relatively to the layout bounds */
  ASCenterLayoutSpecCenteringNone = 0,
  /** The child is centered along the X axis */
  ASCenterLayoutSpecCenteringX = 1 << 0,
  /** The child is centered along the Y axis */
  ASCenterLayoutSpecCenteringY = 1 << 1,
  /** Convenience option to center both along the X and Y axis */
  ASCenterLayoutSpecCenteringXY = ASCenterLayoutSpecCenteringX | ASCenterLayoutSpecCenteringY
};

/** 
  * How much space the spec will take up.
  *
  * The default option will allow the spec to take up the maximum size possible.
  * Swift: use [] for the default behavior.
  */
typedef NS_OPTIONS(NSUInteger, ASCenterLayoutSpecSizingOptions) {
  /** The spec will take up the maximum size possible */
  ASCenterLayoutSpecSizingOptionDefault = ASRelativeLayoutSpecSizingOptionDefault,
  /** The spec will take up the minimum size possible along the X axis */
  ASCenterLayoutSpecSizingOptionMinimumX = ASRelativeLayoutSpecSizingOptionMinimumWidth,
  /** The spec will take up the minimum size possible along the Y axis */
  ASCenterLayoutSpecSizingOptionMinimumY = ASRelativeLayoutSpecSizingOptionMinimumHeight,
  /** Convenience option to take up the minimum size along both the X and Y axis */
  ASCenterLayoutSpecSizingOptionMinimumXY = ASRelativeLayoutSpecSizingOptionMinimumSize
};

NS_ASSUME_NONNULL_BEGIN

/** Lays out a single layoutElement child and position it so that it is centered into the layout bounds.
  * NOTE: ASRelativeLayoutSpec offers all of the capabilities of Center, and more.
  * Check it out if you would like to be able to position the child at any corner or the middle of an edge.
 */
@interface ASCenterLayoutSpec : ASRelativeLayoutSpec

@property (nonatomic) ASCenterLayoutSpecCenteringOptions centeringOptions;
@property (nonatomic) ASCenterLayoutSpecSizingOptions sizingOptions;

/**
 * Initializer.
 *
 * @param centeringOptions How the child is centered.
 * @param sizingOptions How much space will be taken up.
 * @param child The child to center.
 */
+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutElement>)child NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
