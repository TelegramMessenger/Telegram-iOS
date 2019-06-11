//
//  ASTextNode+Beta.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASTextNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASTextNode ()

/**
 @abstract An array of descending scale factors that will be applied to this text node to try to make it fit within its constrained size
 @discussion This array should be in descending order and NOT contain the scale factor 1.0. For example, it could return @[@(.9), @(.85), @(.8)];
 @default nil (no scaling)
 */
@property (nullable, nonatomic, copy) NSArray<NSNumber *> *pointSizeScaleFactors;

/**
 @abstract Text margins for text laid out in the text node.
 @discussion defaults to UIEdgeInsetsZero.
 This property can be useful for handling text which does not fit within the view by default. An example: like UILabel,
 ASTextNode will clip the left and right of the string "judar" if it's rendered in an italicised font.
 */
@property (nonatomic) UIEdgeInsets textContainerInset;

/**
 * Returns YES if this node is using the experimental implementation. NO otherwise. Will not change.
 */
@property (readonly) BOOL usingExperiment;

/**
 * Returns a Boolean indicating if the text node will truncate for the given constrained size
 */
- (BOOL)shouldTruncateForConstrainedSize:(ASSizeRange)constrainedSize;

@end

NS_ASSUME_NONNULL_END
