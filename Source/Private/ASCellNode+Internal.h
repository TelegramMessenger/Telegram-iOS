//
//  ASCellNode+Internal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASCellNode.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionElement;

@protocol ASCellNodeInteractionDelegate <NSObject>

/**
 * Notifies the delegate that a specified cell node invalidates it's size what could result into a size change.
 *
 * @param node A node informing the delegate about the relayout.
 */
- (void)nodeDidInvalidateSize:(ASCellNode *)node;

/*
 * Methods to be called whenever the selection or highlight state changes
 * on ASCellNode. UIKit internally stores these values to update reusable cells.
 */

- (void)nodeSelectedStateDidChange:(ASCellNode *)node;
- (void)nodeHighlightedStateDidChange:(ASCellNode *)node;

@end

@interface ASCellNode ()

@property (nonatomic, weak) id <ASCellNodeInteractionDelegate> interactionDelegate;

/*
 * Back-pointer to the containing scrollView instance, set only for visible cells.  Used for Cell Visibility Event callbacks.
 */
@property (nonatomic, weak) UIScrollView *scrollView;

- (void)__setSelectedFromUIKit:(BOOL)selected;
- (void)__setHighlightedFromUIKit:(BOOL)highlighted;

/**
 * @note This could be declared @c copy, but since this is only settable internally, we can ensure
 *   that it's always safe simply to retain it, and copy if needed. Since @c UICollectionViewLayoutAttributes
 *   is always mutable, @c copy is never "free" like it is for e.g. NSString.
 */
@property (nullable, nonatomic) UICollectionViewLayoutAttributes *layoutAttributes;

@property (weak, nullable) ASCollectionElement *collectionElement;

@property (weak, nullable) id<ASRangeManagingNode> owningNode;

@property (nonatomic, readonly) BOOL shouldUseUIKitCell;

@end

@class ASWrapperCellNode;

typedef CGSize (^ASSizeForItemBlock)(ASWrapperCellNode *node, CGSize collectionSize);
typedef UICollectionViewCell * _Nonnull(^ASCellForItemBlock)(ASWrapperCellNode *node);
typedef UICollectionReusableView * _Nonnull(^ASViewForSupplementaryBlock)(ASWrapperCellNode *node);

@interface ASWrapperCellNode : ASCellNode

@property (nonatomic, readonly) ASSizeForItemBlock sizeForItemBlock;
@property (nonatomic, readonly) ASCellForItemBlock cellForItemBlock;
@property (nonatomic, readonly) ASViewForSupplementaryBlock viewForSupplementaryBlock;

@end

NS_ASSUME_NONNULL_END

#endif
