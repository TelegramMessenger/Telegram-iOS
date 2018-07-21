//
//  ASNetworkImageLoadInfo+Private.h
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

NS_ASSUME_NONNULL_BEGIN

@interface ASNetworkImageLoadInfo ()

- (instancetype)initWithURL:(NSURL *)url
                 sourceType:(ASNetworkImageSourceType)sourceType
         downloadIdentifier:(nullable id)downloadIdentifier
                   userInfo:(nullable id)userInfo;

@end

NS_ASSUME_NONNULL_END
