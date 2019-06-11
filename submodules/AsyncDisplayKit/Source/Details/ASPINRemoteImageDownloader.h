//
//  ASPINRemoteImageDownloader.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_PIN_REMOTE_IMAGE

#import <AsyncDisplayKit/ASImageProtocols.h>

NS_ASSUME_NONNULL_BEGIN

@class PINRemoteImageManager;
@protocol PINRemoteImageCaching;

@interface ASPINRemoteImageDownloader : NSObject <ASImageCacheProtocol, ASImageDownloaderProtocol>

/**
 * A shared image downloader which can be used by @c ASNetworkImageNodes and @c ASMultiplexImageNodes.
 * The userInfo provided by this downloader is an instance of `PINRemoteImageManagerResult`.
 *
 * This is the default downloader used by network backed image nodes if PINRemoteImage and PINCache are
 * available. It uses PINRemoteImage's features to provide caching and progressive image downloads.
 */
+ (ASPINRemoteImageDownloader *)sharedDownloader NS_RETURNS_RETAINED;

/**
 * Sets the default NSURLSessionConfiguration that will be used by @c ASNetworkImageNodes and @c ASMultiplexImageNodes
 * while loading images off the network. This must be specified early in the application lifecycle before
 * `sharedDownloader` is accessed.
 *
 * @param configuration The session configuration that will be used by `sharedDownloader`
 *
 */
+ (void)setSharedImageManagerWithConfiguration:(nullable NSURLSessionConfiguration *)configuration;

/**
 * Sets the default NSURLSessionConfiguration that will be used by @c ASNetworkImageNodes and @c ASMultiplexImageNodes
 * while loading images off the network. This must be specified early in the application lifecycle before
 * `sharedDownloader` is accessed.
 *
 * @param configuration The session configuration that will be used by `sharedDownloader`
 * @param imageCache The cache to be used by PINRemoteImage - nil will set up a default cache: PINCache
 * if it is available, PINRemoteImageBasicCache (NSCache) if not.
 *
 */
+ (void)setSharedImageManagerWithConfiguration:(nullable NSURLSessionConfiguration *)configuration
                                    imageCache:(nullable id<PINRemoteImageCaching>)imageCache;

/**
 * Sets a custom preconfigured PINRemoteImageManager that will be used by @c ASNetworkImageNodes and @c ASMultiplexImageNodes
 * while loading images off the network. This must be specified early in the application lifecycle before
 * `sharedDownloader` is accessed.
 *
 * @param preconfiguredPINRemoteImageManager The preconfigured remote image manager that will be used by `sharedDownloader`
 */
+ (void)setSharedPreconfiguredRemoteImageManager:(PINRemoteImageManager *)preconfiguredPINRemoteImageManager;

/**
 * The shared instance of a @c PINRemoteImageManager used by all @c ASPINRemoteImageDownloaders
 *
 * @discussion you can use this method to access the shared manager. This is useful to share a cache
 * and resources if you need to download images outside of an @c ASNetworkImageNode or 
 * @c ASMultiplexImageNode. It's also useful to access the memoryCache and diskCache to set limits
 * or handle authentication challenges.
 *
 * @return An instance of a @c PINRemoteImageManager
 */
- (PINRemoteImageManager *)sharedPINRemoteImageManager;

@end

NS_ASSUME_NONNULL_END

#endif

#endif
