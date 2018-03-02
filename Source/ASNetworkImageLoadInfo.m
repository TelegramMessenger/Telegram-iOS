//
//  ASNetworkImageLoadInfo.m
//  AsyncDisplayKit
//
//  Created by Adlai on 1/30/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASNetworkImageLoadInfo.h>
#import <AsyncDisplayKit/ASNetworkImageLoadInfo+Private.h>

@implementation ASNetworkImageLoadInfo

- (instancetype)initWithURL:(NSURL *)url sourceType:(ASNetworkImageSourceType)sourceType downloadIdentifier:(id)downloadIdentifier userInfo:(id)userInfo
{
  if (self = [super init]) {
    _url = [url copy];
    _sourceType = sourceType;
    _downloadIdentifier = downloadIdentifier;
    _userInfo = userInfo;
  }
  return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

@end
