//
//  ASDisplayNode+LayoutSpec.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASLayout;

NS_ASSUME_NONNULL_BEGIN

@interface ASDisplayNode (ASLayoutSpec)

/**
 * @abstract Provides a way to declare a block to provide an ASLayoutSpec without having to subclass ASDisplayNode and
 * implement layoutSpecThatFits:
 *
 * @return A block that takes a constrainedSize ASSizeRange argument, and must return an ASLayoutSpec that includes all
 * of the subnodes to position in the layout. This input-output relationship is identical to the subclass override
 * method -layoutSpecThatFits:
 *
 * @warning Subclasses that implement -layoutSpecThatFits: must not also use .layoutSpecBlock. Doing so will trigger
 * an exception. A future version of the framework may support using both, calling them serially, with the
 * .layoutSpecBlock superseding any values set by the method override.
 *
 * @code ^ASLayoutSpec *(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {};
 */
@property (nullable) ASLayoutSpecBlock layoutSpecBlock;

@end

// These methods are intended to be used internally to Texture, and should not be called directly.
@interface ASDisplayNode (ASLayoutSpecPrivate)

///  For internal usage only
- (ASLayout *)calculateLayoutLayoutSpec:(ASSizeRange)constrainedSize;

@end

@interface ASDisplayNode (ASLayoutSpecSubclasses)

/**
 * @abstract Return a layout spec that describes the layout of the receiver and its children.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @discussion Subclasses that override should expect this method to be called on a non-main thread. The returned layout spec
 * is used to calculate an ASLayout and cached by ASDisplayNode for quick access during -layout. Other expensive work that needs to
 * be done before display can be performed here, and using ivars to cache any valuable intermediate results is
 * encouraged.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -layoutThatFits: instead.
 *
 * @warning Subclasses that implement -layoutSpecThatFits: must not use .layoutSpecBlock. Doing so will trigger an
 * exception. A future version of the framework may support using both, calling them serially, with the .layoutSpecBlock
 * superseding any values set by the method override.
 */
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize;

@end

NS_ASSUME_NONNULL_END
