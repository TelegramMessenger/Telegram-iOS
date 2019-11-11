//
//  ASPhotosFrameworkImageRequest.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_USE_PHOTOS

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

AS_EXTERN NSString *const ASPhotosURLScheme;

/**
 @abstract Use ASPhotosFrameworkImageRequest to encapsulate all the information needed to request an image from
 the Photos framework and store it in a URL.
 */
API_AVAILABLE(ios(8.0), tvos(10.0))
@interface ASPhotosFrameworkImageRequest : NSObject <NSCopying>

- (instancetype)initWithAssetIdentifier:(NSString *)assetIdentifier NS_DESIGNATED_INITIALIZER;

/**
 @return A new image request deserialized from `url`, or nil if `url` is not a valid photos URL.
 */
+ (nullable ASPhotosFrameworkImageRequest *)requestWithURL:(NSURL *)url;

/**
 @abstract The asset identifier for this image request provided during initialization.
 */
@property (nonatomic, readonly) NSString *assetIdentifier;

/**
 @abstract The target size for this image request. Defaults to `PHImageManagerMaximumSize`.
 */
@property (nonatomic) CGSize targetSize;

/**
 @abstract The content mode for this image request. Defaults to `PHImageContentModeDefault`.
 
 @see `PHImageManager`
 */
@property (nonatomic) PHImageContentMode contentMode;

/**
 @abstract The options specified for this request. Default value is the result of `[PHImageRequestOptions new]`.
 
 @discussion Some properties of this object are ignored when converting this request into a URL.
 As of iOS SDK 9.0, these properties are `progressHandler` and `synchronous`.
 */
@property (nonatomic) PHImageRequestOptions *options;

/**
 @return A new URL converted from this request.
 */
@property (nonatomic, readonly) NSURL *url;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif // AS_USE_PHOTOS
