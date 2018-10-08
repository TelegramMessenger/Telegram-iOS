//
//  ASLayoutSpec.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>
#import <AsyncDisplayKit/ASLocking.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A layout spec is an immutable object that describes a layout, loosely inspired by React.
 */
@interface ASLayoutSpec : NSObject <ASLayoutElement, ASLayoutElementStylability, NSFastEnumeration, ASDescriptionProvider, ASLocking>

/** 
 * Creation of a layout spec should only happen by a user in layoutSpecThatFits:. During that method, a
 * layout spec can be created and mutated. Once it is passed back to ASDK, the isMutable flag will be
 * set to NO and any further mutations will cause an assert.
 */
@property (nonatomic) BOOL isMutable;

/**
 * First child within the children's array.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * responsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass should use this method to set the "primary" child. It can then use setChild:atIndex:
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:atIndex: internally. For example, ASBackgroundLayoutSpec exposes a "background"
 * property that behind the scenes is calling setChild:atIndex:.
 */
@property (nullable, nonatomic) id<ASLayoutElement> child;

/**
 * An array of ASLayoutElement children
 * 
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * reponsibility of holding on to the spec children. Some layout specs, like ASStackLayoutSpec,
 * can take an unknown number of children. In this case, the this method should be used.
 * For good measure, in these layout specs it probably makes sense to define
 * setChild: and setChild:forIdentifier: methods to do something appropriate or to assert.
 */
@property (nullable, nonatomic) NSArray<id<ASLayoutElement>> *children;

@end

/**
 * An ASLayoutSpec subclass that can wrap one or more ASLayoutElement and calculates the layout based on the
 * sizes of the children. If multiple children are provided the size of the biggest child will be used to for
 * size of this layout spec.
 */
@interface ASWrapperLayoutSpec : ASLayoutSpec

/*
 * Returns an ASWrapperLayoutSpec object with the given layoutElement as child.
 */
+ (instancetype)wrapperWithLayoutElement:(id<ASLayoutElement>)layoutElement NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

/*
 * Returns an ASWrapperLayoutSpec object with the given layoutElements as children.
 */
+ (instancetype)wrapperWithLayoutElements:(NSArray<id<ASLayoutElement>> *)layoutElements NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

/*
 * Returns an ASWrapperLayoutSpec object initialized with the given layoutElement as child.
 */
- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement AS_WARN_UNUSED_RESULT;

/*
 * Returns an ASWrapperLayoutSpec object initialized with the given layoutElements as children.
 */
- (instancetype)initWithLayoutElements:(NSArray<id<ASLayoutElement>> *)layoutElements AS_WARN_UNUSED_RESULT;

/*
 * Init not available for ASWrapperLayoutSpec
 */
- (instancetype)init NS_UNAVAILABLE;

@end

@interface ASLayoutSpec (Debugging) <ASDebugNameProvider>
/**
 *  Used by other layout specs to create ascii art debug strings
 */
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction;
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName;

@end

NS_ASSUME_NONNULL_END
