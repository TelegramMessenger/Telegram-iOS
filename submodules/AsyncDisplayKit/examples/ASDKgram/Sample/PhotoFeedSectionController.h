//
//  PhotoFeedSectionController.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <IGListKit/IGListKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "RefreshingSectionControllerType.h"
#import "ASCollectionSectionController.h"

@class PhotoFeedModel;

NS_ASSUME_NONNULL_BEGIN

@interface PhotoFeedSectionController : ASCollectionSectionController <ASSectionController, RefreshingSectionControllerType>

@property (nonatomic, strong, nullable) PhotoFeedModel *photoFeed;

@end

NS_ASSUME_NONNULL_END
