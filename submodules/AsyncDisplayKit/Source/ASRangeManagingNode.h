//
//  ASRangeManagingNode.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASTraitCollection.h>

@class ASCellNode;

NS_ASSUME_NONNULL_BEGIN

/**
 * Basically ASTableNode or ASCollectionNode.
 */
@protocol ASRangeManagingNode <NSObject, ASTraitEnvironment>

/**
 * Retrieve the index path for the given node, if it's a member of this container.
 *
 * @param node The node.
 * @return The index path, or nil if the node is not part of this container.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)node;

@end

NS_ASSUME_NONNULL_END
