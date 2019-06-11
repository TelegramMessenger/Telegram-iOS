//
//  PhotoFeedBaseController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "PhotoFeedControllerProtocol.h"

@protocol PhotoFeedControllerProtocol;
@class PhotoFeedModel;

@interface PhotoFeedBaseController : ASViewController <PhotoFeedControllerProtocol>

@property (nonatomic, strong, readonly) PhotoFeedModel *photoFeed;
@property (nonatomic, strong, readonly) UITableView *tableView;

- (void)refreshFeed;
- (void)insertNewRows:(NSArray *)newPhotos;

#pragma mark - Subclasses must override these methods

- (void)loadPage;

@end
