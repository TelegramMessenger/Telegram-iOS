//
//  ASCornerLayoutSpec.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

/**
 The corner location for positioning corner element.
 */
typedef NS_ENUM(NSInteger, ASCornerLayoutLocation) {
    ASCornerLayoutLocationTopLeft,
    ASCornerLayoutLocationTopRight,
    ASCornerLayoutLocationBottomLeft,
    ASCornerLayoutLocationBottomRight,
};

NS_ASSUME_NONNULL_BEGIN

/**
 A layout spec that positions a corner element which relatives to the child element.

 @warning Both child element and corner element must have valid preferredSize for layout calculation.
 */
@interface ASCornerLayoutSpec : ASLayoutSpec

/**
 A layout spec that positions a corner element which relatives to the child element.
 
 @param child A child that is laid out to determine the size of this spec.
 @param corner A layoutElement object that is laid out to a corner on the child.
 @param location The corner position option.
 @return An ASCornerLayoutSpec object with a given child and an layoutElement that act as corner.
 */
- (instancetype)initWithChild:(id <ASLayoutElement>)child corner:(id <ASLayoutElement>)corner location:(ASCornerLayoutLocation)location AS_WARN_UNUSED_RESULT;

/**
 A layout spec that positions a corner element which relatives to the child element.
 
 @param child A child that is laid out to determine the size of this spec.
 @param corner A layoutElement object that is laid out to a corner on the child.
 @param location The corner position option.
 @return An ASCornerLayoutSpec object with a given child and an layoutElement that act as corner.
 */
+ (instancetype)cornerLayoutSpecWithChild:(id <ASLayoutElement>)child corner:(id <ASLayoutElement>)corner location:(ASCornerLayoutLocation)location NS_RETURNS_RETAINED AS_WARN_UNUSED_RESULT;

/**
 A layoutElement object that is laid out to a corner on the child.
 */
@property (nonatomic) id <ASLayoutElement> corner;

/**
 The corner position option.
 */
@property (nonatomic) ASCornerLayoutLocation cornerLocation;

/**
 The point which offsets from the corner location. Use this property to make delta
 distance from the default corner location. Default is CGPointZero.
 */
@property (nonatomic) CGPoint offset;

/**
 Whether should include corner element into layout size calculation. If included,
 the layout size will be the union size of both child and corner; If not included,
 the layout size will be only child's size. Default is NO.
 */
@property (nonatomic) BOOL wrapsCorner;

@end

NS_ASSUME_NONNULL_END
