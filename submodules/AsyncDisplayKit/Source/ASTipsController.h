//
//  ASTipsController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASTipsController : NSObject

/**
 * The shared tip controller instance.
 */
@property (class, readonly) ASTipsController *shared;

#pragma mark - Node Event Hooks

/**
 * Informs the controller that the sender did enter the visible range.
 *
 * The controller will run a pass with its tip providers, adding tips as needed.
 */
- (void)nodeDidAppear:(ASDisplayNode *)node;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
