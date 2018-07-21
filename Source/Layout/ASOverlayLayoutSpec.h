//
//  ASOverlayLayoutSpec.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
