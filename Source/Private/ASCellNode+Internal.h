//
//  ASCellNode+Internal.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
@property (nonatomic, strong, nullable) UICollectionViewLayoutAttributes *layoutAttributes;

@property (atomic, weak, nullable) ASCollectionElement *collectionElement;

@property (atomic, weak, nullable) id<ASRangeManagingNode> owningNode;

@property (nonatomic, assign) BOOL shouldUseUIKitCell;

@end

NS_ASSUME_NONNULL_END

#endif
