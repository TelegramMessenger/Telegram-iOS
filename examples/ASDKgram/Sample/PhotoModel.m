//
//  PhotoModel.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoModel.h"
#import "Utilities.h"

@implementation PhotoModel
{
  NSDictionary     *_dictionaryRepresentation;
  NSString         *_uploadDateRaw;
  CommentFeedModel *_commentFeed;
}

#pragma mark - Properties

- (CommentFeedModel *)commentFeed
{
  if (!_commentFeed) {
    _commentFeed = [[CommentFeedModel alloc] initWithPhotoID:_photoID];
  }
  
  return _commentFeed;
}

#pragma mark - Lifecycle

- (instancetype)initWith500pxPhoto:(NSDictionary *)photoDictionary
{
  self = [super init];
  
  if (self) {
    _dictionaryRepresentation = photoDictionary;
    _uploadDateRaw            = [photoDictionary objectForKey:@"created_at"];
    _photoID                  = [[photoDictionary objectForKey:@"id"] description];
    _title                    = [photoDictionary objectForKey:@"title"];
    _descriptionText          = [photoDictionary valueForKeyPath:@"name"];
    _commentsCount            = [[photoDictionary objectForKey:@"comments_count"] integerValue];
    _likesCount               = [[photoDictionary objectForKey:@"positive_votes_count"] integerValue];
    
    NSString *urlString       = [[photoDictionary objectForKey:@"image_url"] firstObject];
    _URL                      = urlString ? [NSURL URLWithString:urlString] : nil;
    
    _location                 = [[LocationModel alloc] initWith500pxPhoto:photoDictionary];
    _ownerUserProfile         = [[UserModel alloc] initWith500pxPhoto:photoDictionary];
    _uploadDateString         = [NSString elapsedTimeStringSinceDate:_uploadDateRaw];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size
{
  NSString *string               = [NSString stringWithFormat:@"%@ %@", self.ownerUserProfile.username, self.descriptionText];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string
                                                                         fontSize:size
                                                                            color:[UIColor darkGrayColor]
                                                                   firstWordColor:[UIColor darkBlueColor]];
  return attrString;
}

- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.uploadDateString fontSize:size color:[UIColor lightGrayColor] firstWordColor:nil];
}

- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size
{
  NSString *likesString = [NSString stringWithFormat:@"♥︎ %lu likes", (unsigned long)_likesCount];

  return [NSAttributedString attributedStringWithString:likesString fontSize:size color:[UIColor darkBlueColor] firstWordColor:nil];
}

- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.location.locationString fontSize:size color:[UIColor lightBlueColor] firstWordColor:nil];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ - %@", _photoID, _descriptionText];
}

- (id<NSObject>)diffIdentifier
{
  return self.photoID;
}

- (BOOL)isEqualToDiffableObject:(id<IGListDiffable>)object
{
  return [self isEqual:object];
}

@end
