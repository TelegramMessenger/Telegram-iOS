//
//  AsyncDisplayKit+Tips.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ASTipDisplayBlock)(ASDisplayNode *node, NSString *message);

/**
 * The methods added to ASDisplayNode to control the tips system.
 *
 * To enable tips, define AS_ENABLE_TIPS=1 (e.g. modify ASBaseDefines.h).
 */
@interface ASDisplayNode (Tips)

/**
 * Whether this class should have tips active. Default YES.
 *
 * NOTE: This property is for _disabling_ tips on a per-class basis,
 * if they become annoying or have false-positives. The tips system
 * is completely disabled unless you define AS_ENABLE_TIPS=1.
 */
@property (class) BOOL enableTips;

/**
 * A block to be run on the main thread to show text when a tip is tapped.
 *
 * If nil, the default, the message is just logged to the console with the
 * ancestry of the node.
 */
@property (class, nonatomic, null_resettable) ASTipDisplayBlock tipDisplayBlock;

@end

NS_ASSUME_NONNULL_END
