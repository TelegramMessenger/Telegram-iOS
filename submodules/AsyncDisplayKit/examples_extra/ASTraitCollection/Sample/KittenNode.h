//
//  KittenNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface KittenNode : ASCellNode
@property (nonatomic, strong, readonly) ASNetworkImageNode *imageNode;
@property (nonatomic, strong, readonly) ASTextNode *textNode;

@property (nonatomic, copy) dispatch_block_t imageTappedBlock;

// The default action when an image node is tapped. This action will create an
// OverrideVC and override its display traits to always be compact.
+ (void)defaultImageTappedAction:(ASViewController *)sourceViewController;
@end
