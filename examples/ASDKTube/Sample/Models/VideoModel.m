//
//  VideoModel.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "VideoModel.h"

@implementation VideoModel
- (instancetype)init
{
  self = [super init];
  if (self) {
    NSString *videoUrlString = @"https://www.w3schools.com/html/mov_bbb.mp4";
    NSString *avatarUrlString = [NSString stringWithFormat:@"https://api.adorable.io/avatars/50/%@",[[NSProcessInfo processInfo] globallyUniqueString]];

    _title      = @"Demo title";
    _url        = [NSURL URLWithString:videoUrlString];
    _userName   = @"Random User";
    _avatarUrl  = [NSURL URLWithString:avatarUrlString];
  }

  return self;
}
@end
