//
//  DetailCellNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASCellNode.h>

@class ASNetworkImageNode;

@interface DetailCellNode : ASCellNode
@property (nonatomic, assign) NSInteger row;
@property (nonatomic, copy) NSString *imageCategory;
@property (nonatomic, strong) ASNetworkImageNode *imageNode;
@end
