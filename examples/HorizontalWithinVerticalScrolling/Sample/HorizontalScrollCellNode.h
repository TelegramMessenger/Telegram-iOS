//
//  HorizontalScrollCellNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * This ASCellNode contains an ASCollectionNode.  It intelligently interacts with a containing ASCollectionView or ASTableView,
 * to preload and clean up contents as the user scrolls around both vertically and horizontally — in a way that minimizes memory usage.
 */
@interface HorizontalScrollCellNode : ASCellNode <ASCollectionDelegate, ASCollectionDataSource>

- (instancetype)initWithElementSize:(CGSize)size;

@end
