//
//  DetailRootNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode.h>

@class ASCollectionNode;

@interface DetailRootNode : ASDisplayNode

@property (nonatomic, strong, readonly) ASCollectionNode *collectionNode;

- (instancetype)initWithImageCategory:(NSString *)imageCategory;

@end
