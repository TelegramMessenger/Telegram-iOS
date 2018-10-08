//
//  ASNetworkImageNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASImageNode.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASNetworkImageNodeDelegate, ASImageCacheProtocol, ASImageDownloaderProtocol;
@class ASNetworkImageLoadInfo;


/**
 * ASNetworkImageNode is a simple image node that can download and display an image from the network, with support for a
 * placeholder image (<defaultImage>).  The currently-displayed image is always available in the inherited ASImageNode
 * <image> property.
 *
 * @see ASMultiplexImageNode for a more powerful counterpart to this class.
 */
@interface ASNetworkImageNode : ASImageNode

/**
 * The designated initializer. Cache and Downloader are WEAK references.
 *
 * @param cache The object that implements a cache of images for the image node.  Weak reference.
 * @param downloader The object that implements image downloading for the image node.  Must not be nil.  Weak reference.
 *
 * @discussion If `cache` is nil, the receiver will not attempt to retrieve images from a cache before downloading them.
 *
 * @return An initialized ASNetworkImageNode.
 */
- (instancetype)initWithCache:(nullable id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader NS_DESIGNATED_INITIALIZER;

/**
 * Convenience initializer.
 *
 * @return An ASNetworkImageNode configured to use the NSURLSession-powered ASBasicImageDownloader, and no extra cache.
 */
- (instancetype)init;

/**
 * The delegate, which must conform to the <ASNetworkImageNodeDelegate> protocol.
 */
@property (nullable, weak) id<ASNetworkImageNodeDelegate> delegate;

/**
 * The delegate will receive callbacks on main thread. Default to YES.
 */
@property (class) BOOL useMainThreadDelegateCallbacks;

/**
 * The image to display.
 *
 * @discussion By setting an image to the image property the ASNetworkImageNode will act like a plain ASImageNode.
 * As soon as the URL is set the ASNetworkImageNode will act like an ASNetworkImageNode and the image property
 * will be managed internally. This means the image property will be cleared out and replaced by the placeholder 
 * (<defaultImage>) image while loading and the final image after the new image data was downloaded and processed.
 * If you want to use a placholder image functionality use the defaultImage property instead.
 */
@property (nullable) UIImage *image;

/**
 * A placeholder image to display while the URL is loading. This is slightly different than placeholderImage in the
 * ASDisplayNode superclass as defaultImage will *not* be displayed synchronously. If you wish to have the image
 * displayed synchronously, use @c placeholderImage.
 */
@property (nullable) UIImage *defaultImage;

/**
 * The URL of a new image to download and display.
 *
 * @discussion By setting an URL, the image property of this node will be managed internally. This means previously
 * directly set images to the image property will be cleared out and replaced by the placeholder (<defaultImage>) image
 * while loading and the final image after the new image data was downloaded and processed.
 */
@property (nullable, copy) NSURL *URL;

/**
  * An array of URLs of increasing cost to download.
  *
  * @discussion By setting an array of URLs, the image property of this node will be managed internally. This means previously
  * directly set images to the image property will be cleared out and replaced by the placeholder (<defaultImage>) image
  * while loading and the final image after the new image data was downloaded and processed.
  *
  * @deprecated This API has been removed for now due to the increased complexity to the class that it brought.
  * Please use .URL instead.
  */
@property (nullable, copy) NSArray <NSURL *> *URLs ASDISPLAYNODE_DEPRECATED_MSG("Please use URL instead.");

/**
 * Download and display a new image.
 *
 * @param URL The URL of a new image to download and display.
 * @param reset Whether to display a placeholder (<defaultImage>) while loading the new image.
 *
 * @discussion By setting an URL, the image property of this node will be managed internally. This means previously
 * directly set images to the image property will be cleared out and replaced by the placeholder (<defaultImage>) image
 * while loading and the final image after the new image data was downloaded and processed.
 */
- (void)setURL:(nullable NSURL *)URL resetToDefault:(BOOL)reset;

/**
 * If <URL> is a local file, set this property to YES to take advantage of UIKit's image caching.  Defaults to YES.
 */
@property BOOL shouldCacheImage;

/**
 * If the downloader implements progressive image rendering and this value is YES progressive renders of the
 * image will be displayed as the image downloads. Regardless of this properties value, progress renders will
 * only occur when the node is visible. Defaults to YES.
 */
@property BOOL shouldRenderProgressImages;

/**
 * The image quality of the current image.
 *
 * If the URL is set, this is a number between 0 and 1 and can be used to track
 * progressive progress. Calculated by dividing number of bytes / expected number of total bytes.
 * This is zero until the first progressive render or the final display.
 *
 * If the URL is unset, this is 1 if defaultImage or image is set to non-nil.
 *
 */
@property (readonly) CGFloat currentImageQuality;

/**
 * The currentImageQuality (value between 0 and 1) of the last image that completed displaying.
 */
@property (readonly) CGFloat renderedImageQuality;

@end


#pragma mark -

/**
 * The methods declared by the ASNetworkImageNodeDelegate protocol allow the adopting delegate to respond to
 * notifications such as finished decoding and downloading an image.
 */
@protocol ASNetworkImageNodeDelegate <NSObject>
@optional

/**
 * Notification that the image node finished downloading an image, with additional info.
 * If implemented, this method will be called instead of `imageNode:didLoadImage:`.
 *
 * @param imageNode The sender.
 * @param image The newly-loaded image.
 * @param info Additional information about the image load.
 *
 * @discussion Called on the main thread if useMainThreadDelegateCallbacks=YES (the default), otherwise on a background thread.
 */
- (void)imageNode:(ASNetworkImageNode *)imageNode didLoadImage:(UIImage *)image info:(ASNetworkImageLoadInfo *)info;

/**
 * Notification that the image node finished downloading an image.
 *
 * @param imageNode The sender.
 * @param image The newly-loaded image.
 *
 * @discussion Called on the main thread if useMainThreadDelegateCallbacks=YES (the default), otherwise on a background thread.
 */
- (void)imageNode:(ASNetworkImageNode *)imageNode didLoadImage:(UIImage *)image;

/**
 * Notification that the image node started to load
 *
 * @param imageNode The sender.
 *
 * @discussion Called on a background queue.
 */
- (void)imageNodeDidStartFetchingData:(ASNetworkImageNode *)imageNode;

/**
 * Notification that the image node failed to download the image.
 *
 * @param imageNode The sender.
 * @param error The error with details.
 *
 * @discussion Called on the main thread if useMainThreadDelegateCallbacks=YES (the default), otherwise on a background thread.
 */
- (void)imageNode:(ASNetworkImageNode *)imageNode didFailWithError:(NSError *)error;

/**
 * Notification that the image node finished decoding an image.
 *
 * @param imageNode The sender.
 */
- (void)imageNodeDidFinishDecoding:(ASNetworkImageNode *)imageNode;

@end

NS_ASSUME_NONNULL_END

#endif
