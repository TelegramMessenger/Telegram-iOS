//
//  ASTLayoutFixture.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "ASTestCase.h"
#import "ASLayoutTestNode.h"

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASTLayoutFixture : NSObject

/// The correct layout. The root should be unpositioned (same as -calculatedLayout).
@property (nonatomic, nullable) ASLayout *layout;

/// The layoutSpecBlocks for non-leaf nodes.
@property (nonatomic, readonly) NSMapTable<ASDisplayNode *, ASLayoutSpecBlock> *layoutSpecBlocks;

@property (nonatomic, readonly) ASLayoutTestNode *rootNode;

@property (nonatomic, readonly) NSSet<ASLayoutTestNode *> *allNodes;

/// Get the (correct) layout for the specified node.
- (ASLayout *)layoutForNode:(ASLayoutTestNode *)node;

/// Add this to the list of expected size ranges for the given node.
- (void)addSizeRange:(ASSizeRange)sizeRange forNode:(ASLayoutTestNode *)node;

/// If you have a node that wants a size different than it gets, set it here.
/// For any leaf nodes that you don't call this on, the node will return the correct size
/// based on the fixture's layout. This is useful for triggering multipass stack layout.
- (void)setReturnedSize:(CGSize)size forNode:(ASLayoutTestNode *)node;

/// Get the first expected size range for the node.
- (ASSizeRange)firstSizeRangeForNode:(ASLayoutTestNode *)node;

/// Enumerate all the size ranges for all the nodes using the provided block.
- (void)withSizeRangesForAllNodesUsingBlock:(void (^)(ASLayoutTestNode *node, ASSizeRange sizeRange))block;

/// Enumerate all the size ranges for the node.
- (void)withSizeRangesForNode:(ASLayoutTestNode *)node block:(void (^)(ASSizeRange sizeRange))block;

/// Configure the nodes for this fixture. Set testSize on leaf nodes, layoutSpecBlock on container nodes.
- (void)apply;

@end

@interface ASLayout (TestHelpers)

@property (nonatomic, readonly) NSArray<ASDisplayNode *> *allNodes;

@end

NS_ASSUME_NONNULL_END
