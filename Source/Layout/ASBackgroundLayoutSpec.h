//
//  ASBackgroundLayoutSpec.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Lays out a single layoutElement child, then lays out a background layoutElement instance behind it stretched to its size.
 */
@interface ASBackgroundLayoutSpec : ASLayoutSpec

/**
 * Background layoutElement for this layout spec
 */
@property (nonatomic) id<ASLayoutElement> background;

/**
 * Creates and returns an ASBackgroundLayoutSpec object
 *
 * @param child A child that is laid out to determine the size of this spec.
 * @param background A layoutElement object that is laid out behind the child.
 */
+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
