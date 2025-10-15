//
//  ASLayoutSpec+Subclasses.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
@property (nonatomic) CGPoint position;

@end

NS_ASSUME_NONNULL_END
