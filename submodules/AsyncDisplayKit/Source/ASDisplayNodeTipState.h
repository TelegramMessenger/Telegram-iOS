//
//  ASDisplayNodeTipState.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASDisplayNode, ASTipNode;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASDisplayNodeTipState : NSObject

- (instancetype)initWithNode:(ASDisplayNode *)node NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Unsafe because once the node is deallocated, we will not be able to access the tip state.
@property (nonatomic, unsafe_unretained, readonly) ASDisplayNode *node;

/// Main-thread-only.
@property (nonatomic, nullable) ASTipNode *tipNode;

@end

NS_ASSUME_NONNULL_END
