//
//  ASDisplayNode+Convenience.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@class UIViewController;

@interface ASDisplayNode (Convenience)

/**
 * @abstract Returns the view controller nearest to this node in the view hierarchy.
 *
 * @warning This property may only be accessed on the main thread. This property may
 *   be @c nil until the node's view is actually hosted in the view hierarchy.
 */
@property (nonatomic, nullable, readonly) __kindof UIViewController *closestViewController;

@end

NS_ASSUME_NONNULL_END
