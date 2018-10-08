//
//  ASBasicImageDownloader.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASImageProtocols.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @abstract Simple NSURLSession-based image downloader.
 */
@interface ASBasicImageDownloader : NSObject <ASImageDownloaderProtocol>

/**
 * A shared image downloader which can be used by @c ASNetworkImageNodes and @c ASMultiplexImageNodes.
 * The userInfo provided by this downloader is `nil`.
 *
 * This is a very basic image downloader. It does not support caching, progressive downloading and likely
 * isn't something you should use in production. If you'd like something production ready, see @c ASPINRemoteImageDownloader
 *
 * @note It is strongly recommended you include PINRemoteImage and use @c ASPINRemoteImageDownloader instead.
 */
@property (class, readonly) ASBasicImageDownloader *sharedImageDownloader;
+ (ASBasicImageDownloader *)sharedImageDownloader NS_RETURNS_RETAINED;

+ (instancetype)new __attribute__((unavailable("+[ASBasicImageDownloader sharedImageDownloader] must be used.")));
- (instancetype)init __attribute__((unavailable("+[ASBasicImageDownloader sharedImageDownloader] must be used.")));

@end

NS_ASSUME_NONNULL_END

#endif
