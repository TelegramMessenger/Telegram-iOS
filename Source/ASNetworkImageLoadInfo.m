//
//  ASNetworkImageLoadInfo.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
