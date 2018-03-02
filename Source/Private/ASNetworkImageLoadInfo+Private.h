//
//  ASNetworkImageLoadInfo+Private.h
//  AsyncDisplayKit
//
//  Created by Adlai on 1/30/18.
//  Copyright © 2018 Facebook. All rights reserved.
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
