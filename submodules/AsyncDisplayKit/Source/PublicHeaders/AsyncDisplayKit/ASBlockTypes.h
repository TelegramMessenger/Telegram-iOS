//
//  ASBlockTypes.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ASCellNode;

/**
 * ASCellNode creation block. Used to lazily create the ASCellNode instance for a specified indexPath.
 */
typedef ASCellNode * _Nonnull(^ASCellNodeBlock)(void);

// Type for the cancellation checker block passed into the async display blocks. YES means the operation has been cancelled, NO means continue.
typedef BOOL(^asdisplaynode_iscancelled_block_t)(void);
