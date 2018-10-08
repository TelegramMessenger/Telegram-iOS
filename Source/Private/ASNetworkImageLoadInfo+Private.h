//
//  ASNetworkImageLoadInfo+Private.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
