//
//  ASNetworkImageLoadInfo.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ASNetworkImageSourceType) {
  ASNetworkImageSourceUnspecified = 0,
  ASNetworkImageSourceSynchronousCache,
  ASNetworkImageSourceAsynchronousCache,
  ASNetworkImageSourceFileURL,
  ASNetworkImageSourceDownload,
};

AS_SUBCLASSING_RESTRICTED
@interface ASNetworkImageLoadInfo : NSObject <NSCopying>

/// The type of source from which the image was loaded.
@property (readonly) ASNetworkImageSourceType sourceType;

/// The image URL that was downloaded.
@property (readonly) NSURL *url;

/// The download identifier, if one was provided.
@property (nullable, readonly) id downloadIdentifier;

/// The userInfo object provided by the downloader, if one was provided.
@property (nullable, readonly) id userInfo;

@end

NS_ASSUME_NONNULL_END
