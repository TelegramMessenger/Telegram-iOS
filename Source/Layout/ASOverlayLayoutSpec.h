//
//  ASOverlayLayoutSpec.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This layout spec lays out a single layoutElement child and then overlays a layoutElement object on top of it streched to its size
 */
@interface ASOverlayLayoutSpec : ASLayoutSpec

/**
 * Overlay layoutElement of this layout spec
 */
@property (nonatomic) id<ASLayoutElement> overlay;

/**
 * Creates and returns an ASOverlayLayoutSpec object with a given child and an layoutElement that act as overlay.
 *
 * @param child A child that is laid out to determine the size of this spec.
 * @param overlay A layoutElement object that is laid out over the child.
 */
+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutElement>)child overlay:(id<ASLayoutElement>)overlay NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END
