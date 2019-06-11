//
//  ASTipProvider.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode, ASTip;

NS_ASSUME_NONNULL_BEGIN

/**
 * An abstract superclass for all tip providers.
 */
@interface ASTipProvider : NSObject

/**
 * The provider looks at the node's current situation and
 * generates a tip, if any, to add to the node.
 *
 * Subclasses must override this.
 */
- (nullable ASTip *)tipForNode:(ASDisplayNode *)node;

@end

@interface ASTipProvider (Lookup)

@property (class, nonatomic, copy, readonly) NSArray<__kindof ASTipProvider *> *all;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
