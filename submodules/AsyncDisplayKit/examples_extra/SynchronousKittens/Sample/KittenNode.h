//
//  KittenNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * Social media-style node that displays a kitten picture and a random length
 * of lorem ipsum text.  Uses a placekitten.com kitten of the specified size.
 */
@interface KittenNode : ASCellNode

- (instancetype)initWithKittenOfSize:(CGSize)size;

- (void)toggleImageEnlargement;

@end
