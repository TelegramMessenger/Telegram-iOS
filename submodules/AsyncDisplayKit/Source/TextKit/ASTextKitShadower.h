//
//  ASTextKitShadower.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_ENABLE_TEXTNODE

#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 * @abstract an immutable class for calculating shadow padding drawing a shadowed background for text
 */
AS_SUBCLASSING_RESTRICTED
@interface ASTextKitShadower : NSObject

+ (ASTextKitShadower *)shadowerWithShadowOffset:(CGSize)shadowOffset
                                    shadowColor:(UIColor *)shadowColor
                                  shadowOpacity:(CGFloat)shadowOpacity
                                   shadowRadius:(CGFloat)shadowRadius;

/**
 * @abstract The offset from the top-left corner at which the shadow starts.
 * @discussion A positive width will move the shadow to the right.
 *             A positive height will move the shadow downwards.
 */
@property (nonatomic, readonly) CGSize shadowOffset;

//! CGColor in which the shadow is drawn
@property (nonatomic, copy, readonly) UIColor *shadowColor;

//! Alpha of the shadow
@property (nonatomic, readonly) CGFloat shadowOpacity;

//! Radius, in pixels
@property (nonatomic, readonly) CGFloat shadowRadius;

/**
 * @abstract The edge insets which represent shadow padding
 * @discussion Each edge inset is less than or equal to zero.
 *
 * Example:
 *  CGRect boundsWithoutShadowPadding; // Large enough to fit text, not large enough to fit the shadow as well
 *  UIEdgeInsets shadowPadding = [shadower shadowPadding];
 *  CGRect boundsWithShadowPadding = UIEdgeInsetsRect(boundsWithoutShadowPadding, shadowPadding);
 */
- (UIEdgeInsets)shadowPadding;

- (CGSize)insetSizeWithConstrainedSize:(CGSize)constrainedSize;

- (CGRect)insetRectWithConstrainedRect:(CGRect)constrainedRect;

- (CGSize)outsetSizeWithInsetSize:(CGSize)insetSize;

- (CGRect)outsetRectWithInsetRect:(CGRect)insetRect;

- (CGRect)offsetRectWithInternalRect:(CGRect)internalRect;

- (CGPoint)offsetPointWithInternalPoint:(CGPoint)internalPoint;

- (CGPoint)offsetPointWithExternalPoint:(CGPoint)externalPoint;

/**
 * @abstract draws the shadow for text in the provided CGContext
 * @discussion Call within the text node's +drawRect method
 */
- (void)setShadowInContext:(CGContextRef)context;

@end

#endif
