//
//  ASLayoutSpec+Subclasses.h
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

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASLayout.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASLayoutElement;

@interface ASLayoutSpec (Subclassing)

/**
 * Adds a child with the given identifier to this layout spec.
 *
 * @param child A child to be added.
 *
 * @param index An index associated with the child.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * responsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass can use the setChild method to set the "primary" child. It should then use this method
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:forIndex: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 * property that behind the scenes is calling setChild:forIndex:.
 */
- (void)setChild:(id<ASLayoutElement>)child atIndex:(NSUInteger)index;

/**
 * Returns the child added to this layout spec using the given index.
 *
 * @param index An identifier associated with the the child.
 */
- (nullable id<ASLayoutElement>)childAtIndex:(NSUInteger)index;

@end

@interface ASLayout ()

/**
 * Position in parent. Default to CGPointNull.
 *
 * @discussion When being used as a sublayout, this property must not equal CGPointNull.
 */
@property (nonatomic, assign, readwrite) CGPoint position;

@end

NS_ASSUME_NONNULL_END
