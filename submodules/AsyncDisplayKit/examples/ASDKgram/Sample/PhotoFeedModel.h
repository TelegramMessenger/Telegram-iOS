//
//  PhotoFeedModel.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoModel.h"
#import <IGListKit/IGListKit.h>

typedef NS_ENUM(NSInteger, PhotoFeedModelType) {
  PhotoFeedModelTypePopular,
  PhotoFeedModelTypeLocation,
  PhotoFeedModelTypeUserPhotos
};

@interface PhotoFeedModel : NSObject <IGListDiffable>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPhotoFeedModelType:(PhotoFeedModelType)type imageSize:(CGSize)size NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSArray<PhotoModel *> *photos;

- (NSUInteger)totalNumberOfPhotos;
- (NSUInteger)numberOfItemsInFeed;
- (PhotoModel *)objectAtIndex:(NSUInteger)index;
- (NSInteger)indexOfPhotoModel:(PhotoModel *)photoModel;

- (void)updatePhotoFeedModelTypeUserId:(NSUInteger)userID;

- (void)clearFeed;
- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults;
- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults;

@end
