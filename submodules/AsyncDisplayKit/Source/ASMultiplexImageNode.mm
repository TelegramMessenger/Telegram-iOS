//
//  ASMultiplexImageNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//
#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASMultiplexImageNode.h>

#if TARGET_OS_IOS && AS_USE_ASSETS_LIBRARY
#import <AssetsLibrary/AssetsLibrary.h>
#endif

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASThread.h>

#if AS_USE_PHOTOS
#import <AsyncDisplayKit/ASPhotosFrameworkImageRequest.h>
#endif

#if AS_PIN_REMOTE_IMAGE
#import <AsyncDisplayKit/ASPINRemoteImageDownloader.h>
#else
#import <AsyncDisplayKit/ASBasicImageDownloader.h>
#endif

using AS::MutexLocker;

NSString *const ASMultiplexImageNodeErrorDomain = @"ASMultiplexImageNodeErrorDomain";

#if AS_USE_ASSETS_LIBRARY
static NSString *const kAssetsLibraryURLScheme = @"assets-library";
#endif

static const CGSize kMinReleaseImageOnBackgroundSize = {20.0, 20.0};

/**
  @abstract Signature for the block to be performed after an image has loaded.
  @param image The image that was loaded, or nil if no image was loaded.
  @param imageIdentifier The identifier of the image that was loaded, or nil if no image was loaded.
  @param error An error describing why an image couldn't be loaded, if it failed to load; nil otherwise.
 */
typedef void(^ASMultiplexImageLoadCompletionBlock)(UIImage *image, id imageIdentifier, NSError *error);

@interface ASMultiplexImageNode ()
{
@private
  // Core.
  id<ASImageCacheProtocol> _cache;

  id<ASImageDownloaderProtocol> _downloader;
  struct {
    unsigned int downloaderImplementsSetProgress:1;
    unsigned int downloaderImplementsSetPriority:1;
    unsigned int downloaderImplementsDownloadWithPriority:1;
  } _downloaderFlags;

  __weak id<ASMultiplexImageNodeDelegate> _delegate;
  struct {
    unsigned int downloadStart:1;
    unsigned int downloadProgress:1;
    unsigned int downloadFinish:1;
    unsigned int updatedImageDisplayFinish:1;
    unsigned int updatedImage:1;
    unsigned int displayFinish:1;
  } _delegateFlags;

  __weak id<ASMultiplexImageNodeDataSource> _dataSource;
  struct {
    unsigned int image:1;
    unsigned int URL:1;
    unsigned int asset:1;
  } _dataSourceFlags;

  // Image flags.
  BOOL _downloadsIntermediateImages; // Defaults to NO.
  AS::Mutex _imageIdentifiersLock;
  NSArray *_imageIdentifiers;
  id _loadedImageIdentifier;
  id _loadingImageIdentifier;
  id _displayedImageIdentifier;
  __weak NSOperation *_phImageRequestOperation;
  
  // Networking.
  AS::RecursiveMutex _downloadIdentifierLock;
  id _downloadIdentifier;
  
  // Properties
  BOOL _shouldRenderProgressImages;
  
  //set on init only
  BOOL _cacheSupportsClearing;
}

//! @abstract Read-write redeclaration of property declared in ASMultiplexImageNode.h.
@property (nonatomic, copy) id loadedImageIdentifier;

//! @abstract The image identifier that's being loaded by _loadNextImageWithCompletion:.
@property (nonatomic, copy) id loadingImageIdentifier;

/**
  @abstract Returns the next image identifier that should be downloaded.
  @discussion This method obeys and reflects the value of `downloadsIntermediateImages`.
  @result The next image identifier, from `_imageIdentifiers`, that should be downloaded, or nil if no image should be downloaded next.
 */
- (id)_nextImageIdentifierToDownload;

/**
  @abstract Returns the best image that is immediately available from our datasource without downloading or hitting the cache.
  @param imageIdentifierOut Upon return, the image identifier for the returned image; nil otherwise.
  @discussion This method exclusively uses the data source's -multiplexImageNode:imageForIdentifier: method to return images. It does not fetch from the cache or kick off downloading.
  @result The best UIImage available immediately; nil if no image is immediately available.
 */
- (UIImage *)_bestImmediatelyAvailableImageFromDataSource:(id *)imageIdentifierOut;

/**
  @abstract Loads and displays the next image in the receiver's loading sequence.
  @discussion This method obeys `downloadsIntermediateImages`. This method has no effect if nothing further should be loaded, as indicated by `_nextImageIdentifierToDownload`. This method will load the next image from the data-source, if possible; otherwise, the session's image cache will be queried for the desired image, and as a last resort, the image will be downloaded.
 */
- (void)_loadNextImage;

/**
  @abstract Fetches the image corresponding to the given imageIdentifier from the given URL from the session's image cache.
  @param imageIdentifier The identifier for the image to be fetched. May not be nil.
  @param imageURL The URL of the image to fetch. May not be nil.
  @param completionBlock The block to be performed when the image has been fetched from the cache, if possible. May not be nil.
  @discussion This method queries both the session's in-memory and on-disk caches (with preference for the in-memory cache).
 */
- (void)_fetchImageWithIdentifierFromCache:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image))completionBlock;

#if TARGET_OS_IOS && AS_USE_ASSETS_LIBRARY
/**
  @abstract Loads the image corresponding to the given assetURL from the device's Assets Library.
  @param imageIdentifier The identifier for the image to be loaded. May not be nil.
  @param assetURL The assets-library URL (e.g., "assets-library://identifier") of the image to load, from ALAsset. May not be nil.
  @param completionBlock The block to be performed when the image has been loaded, if possible. May not be nil.
 */
- (void)_loadALAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock;
#endif

#if AS_USE_PHOTOS
/**
  @abstract Loads the image corresponding to the given image request from the Photos framework.
  @param imageIdentifier The identifier for the image to be loaded. May not be nil.
  @param request The photos image request to load. May not be nil.
  @param completionBlock The block to be performed when the image has been loaded, if possible. May not be nil.
 */
- (void)_loadPHAssetWithRequest:(ASPhotosFrameworkImageRequest *)request identifier:(id)imageIdentifier completion:(void (^)(UIImage *image, NSError *error))completionBlock API_AVAILABLE(ios(8.0), tvos(10.0));
#endif

/**
 @abstract Downloads the image corresponding to the given imageIdentifier from the given URL.
 @param imageIdentifier The identifier for the image to be downloaded. May not be nil.
 @param imageURL The URL of the image to downloaded. May not be nil.
 @param completionBlock The block to be performed when the image has been downloaded, if possible. May not be nil.
 */
- (void)_downloadImageWithIdentifier:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image, NSError *error))completionBlock;

@end

@implementation ASMultiplexImageNode

#pragma mark - Getting Started / Tearing Down
- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = (id<ASImageCacheProtocol>)cache;
  _downloader = (id<ASImageDownloaderProtocol>)downloader;
  
  _downloaderFlags.downloaderImplementsSetProgress = [downloader respondsToSelector:@selector(setProgressImageBlock:callbackQueue:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsSetPriority = [downloader respondsToSelector:@selector(setPriority:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsDownloadWithPriority = [downloader respondsToSelector:@selector(downloadImageWithURL:priority:callbackQueue:downloadProgress:completion:)];

  _cacheSupportsClearing = [cache respondsToSelector:@selector(clearFetchedImageFromCacheWithURL:)];
  
  _shouldRenderProgressImages = YES;

  self.shouldBypassEnsureDisplay = YES;

  return self;
}

- (instancetype)init
{
#if AS_PIN_REMOTE_IMAGE
  return [self initWithCache:[ASPINRemoteImageDownloader sharedDownloader] downloader:[ASPINRemoteImageDownloader sharedDownloader]];
#else
  return [self initWithCache:nil downloader:[ASBasicImageDownloader sharedImageDownloader]];
#endif
}

- (void)dealloc
{
  [_phImageRequestOperation cancel];
}

#pragma mark - ASDisplayNode Overrides

- (void)clearContents
{
  [super clearContents]; // This actually clears the contents, so we need to do this first for our displayedImageIdentifier to be meaningful.
  [self _setDisplayedImageIdentifier:nil withImage:nil];

  // NOTE: We intentionally do not cancel image downloads until `clearPreloadedData`.
}

- (void)didExitPreloadState
{
  [super didExitPreloadState];
    
  [_phImageRequestOperation cancel];

  [self _setDownloadIdentifier:nil];
  
  if (_cacheSupportsClearing && self.loadedImageIdentifier != nil) {
    NSURL *URL = [_dataSource multiplexImageNode:self URLForImageIdentifier:self.loadedImageIdentifier];
    if (URL != nil) {
      [_cache clearFetchedImageFromCacheWithURL:URL];
    }
  }

  // setting this to nil makes the node fetch images the next time its display starts
  _loadedImageIdentifier = nil;
  [self _setImage:nil];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];

  [self _loadImageIdentifiers];
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  // We may now be displaying the loaded identifier, if they're different.
  UIImage *displayedImage = self.image;
  if (displayedImage) {
    if (!ASObjectIsEqual(_displayedImageIdentifier, _loadedImageIdentifier))
      [self _setDisplayedImageIdentifier:_loadedImageIdentifier withImage:displayedImage];

    // Delegateify
    if (_delegateFlags.displayFinish) {
      if (ASDisplayNodeThreadIsMain())
        [_delegate multiplexImageNodeDidFinishDisplay:self];
      else {
        __weak __typeof__(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
          __typeof__(self) strongSelf = weakSelf;
          if (!strongSelf)
            return;
          [strongSelf.delegate multiplexImageNodeDidFinishDisplay:strongSelf];
        });
      }
    }
  }
}

- (BOOL)placeholderShouldPersist
{
  return (self.image == nil && self.animatedImage == nil && self.imageIdentifiers.count > 0);
}

/* displayWillStartAsynchronously in ASNetworkImageNode has a very similar implementation. Changes here are likely necessary
 in ASNetworkImageNode as well. */
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  [super displayWillStartAsynchronously:asynchronously];
  [self didEnterPreloadState];
  [self _updatePriorityOnDownloaderIfNeededWithDefaultPriority:ASImageDownloaderPriorityImminent];
}

/* didEnterVisibleState / didExitVisibleState in ASNetworkImageNode has a very similar implementation. Changes here are likely necessary
 in ASNetworkImageNode as well. */
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  [self _updatePriorityOnDownloaderIfNeededWithDefaultPriority:ASImageDownloaderPriorityVisible];
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];
  [self _updatePriorityOnDownloaderIfNeededWithDefaultPriority:ASImageDownloaderPriorityPreload];
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)didExitDisplayState
{
  [super didExitDisplayState];
  if (ASActivateExperimentalFeature(ASExperimentalImageDownloaderPriority)) {
    [self _updatePriorityOnDownloaderIfNeededWithDefaultPriority:ASImageDownloaderPriorityPreload];
  }
}

#pragma mark - Core

- (void)setImage:(UIImage *)image
{
  ASDisplayNodeAssert(NO, @"Setting the image directly on an ASMultiplexImageNode is unsafe. It will be cleared in didExitPreloadRange and will have no way to restore in didEnterPreloadRange");
  super.image = image;
}

- (void)_setImage:(UIImage *)image
{
  super.image = image;
}

- (void)setDelegate:(id <ASMultiplexImageNodeDelegate>)delegate
{
  if (_delegate == delegate)
    return;

  _delegate = delegate;
  _delegateFlags.downloadStart = [_delegate respondsToSelector:@selector(multiplexImageNode:didStartDownloadOfImageWithIdentifier:)];
  _delegateFlags.downloadProgress = [_delegate respondsToSelector:@selector(multiplexImageNode:didUpdateDownloadProgress:forImageWithIdentifier:)];
  _delegateFlags.downloadFinish = [_delegate respondsToSelector:@selector(multiplexImageNode:didFinishDownloadingImageWithIdentifier:error:)];
  _delegateFlags.updatedImageDisplayFinish = [_delegate respondsToSelector:@selector(multiplexImageNode:didDisplayUpdatedImage:withIdentifier:)];
  _delegateFlags.updatedImage = [_delegate respondsToSelector:@selector(multiplexImageNode:didUpdateImage:withIdentifier:fromImage:withIdentifier:)];
  _delegateFlags.displayFinish = [_delegate respondsToSelector:@selector(multiplexImageNodeDidFinishDisplay:)];
}


- (void)setDataSource:(id <ASMultiplexImageNodeDataSource>)dataSource
{
  if (_dataSource == dataSource)
    return;

  _dataSource = dataSource;
  _dataSourceFlags.image = [_dataSource respondsToSelector:@selector(multiplexImageNode:imageForImageIdentifier:)];
  _dataSourceFlags.URL = [_dataSource respondsToSelector:@selector(multiplexImageNode:URLForImageIdentifier:)];
  if (AS_AVAILABLE_IOS_TVOS(9, 10)) {
    _dataSourceFlags.asset = [_dataSource respondsToSelector:@selector(multiplexImageNode:assetForLocalIdentifier:)];
  }
}


- (void)setShouldRenderProgressImages:(BOOL)shouldRenderProgressImages
{
  [self lock];
  if (shouldRenderProgressImages == _shouldRenderProgressImages) {
    [self unlock];
    return;
  }
  
  _shouldRenderProgressImages = shouldRenderProgressImages;
  
  [self unlock];
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (BOOL)shouldRenderProgressImages
{
  return ASLockedSelf(_shouldRenderProgressImages);
}

#pragma mark -

#pragma mark -

- (NSArray *)imageIdentifiers
{
  MutexLocker l(_imageIdentifiersLock);
  return _imageIdentifiers;
}

- (void)setImageIdentifiers:(NSArray *)imageIdentifiers
{
  {
    MutexLocker l(_imageIdentifiersLock);
    if (ASObjectIsEqual(_imageIdentifiers, imageIdentifiers)) {
      return;
    }

    _imageIdentifiers = [[NSArray alloc] initWithArray:imageIdentifiers copyItems:YES];
  }

  [self setNeedsPreload];
}

- (void)reloadImageIdentifierSources
{
  // setting this to nil makes the node think it has not downloaded any images
  _loadedImageIdentifier = nil;
  [self _loadImageIdentifiers];
}

#pragma mark -


#pragma mark - Core Internal
- (void)_setDisplayedImageIdentifier:(id)displayedImageIdentifier withImage:(UIImage *)image
{
  ASDisplayNodeAssertMainThread();
    
  if (ASObjectIsEqual(_displayedImageIdentifier, displayedImageIdentifier)) {
    return;
  }

  _displayedImageIdentifier = displayedImageIdentifier;

  // Delegateify.
  // Note that we're using the params here instead of self.image and _displayedImageIdentifier because those can change before the async block below executes.
  if (_delegateFlags.updatedImageDisplayFinish) {
    if (ASDisplayNodeThreadIsMain())
      [_delegate multiplexImageNode:self didDisplayUpdatedImage:image withIdentifier:displayedImageIdentifier];
    else {
      __weak __typeof__(self) weakSelf = self;
      dispatch_async(dispatch_get_main_queue(), ^{
        __typeof__(self) strongSelf = weakSelf;
        if (!strongSelf)
          return;
        [strongSelf.delegate multiplexImageNode:strongSelf didDisplayUpdatedImage:image withIdentifier:displayedImageIdentifier];
      });
    }
  }
}

- (void)_setDownloadIdentifier:(id)downloadIdentifier
{
  MutexLocker l(_downloadIdentifierLock);
  if (ASObjectIsEqual(downloadIdentifier, _downloadIdentifier))
    return;

  if (_downloadIdentifier) {
    [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
  }
  _downloadIdentifier = downloadIdentifier;
}

#pragma mark - Image Loading Machinery

- (void)_loadImageIdentifiers
{
  // Grab the best possible image we can load right now.
  id bestImmediatelyAvailableImageIdentifier = nil;
  UIImage *bestImmediatelyAvailableImage = [self _bestImmediatelyAvailableImageFromDataSource:&bestImmediatelyAvailableImageIdentifier];
  as_log_verbose(ASImageLoadingLog(), "%@ Best immediately available image identifier is %@", self, bestImmediatelyAvailableImageIdentifier);

  // Load it. This kicks off cache fetching/downloading, as appropriate.
  [self _finishedLoadingImage:bestImmediatelyAvailableImage forIdentifier:bestImmediatelyAvailableImageIdentifier error:nil];
}

- (UIImage *)_bestImmediatelyAvailableImageFromDataSource:(id *)imageIdentifierOut
{
  MutexLocker l(_imageIdentifiersLock);

  // If we don't have any identifiers to load or don't implement the image DS method, bail.
  if ([_imageIdentifiers count] == 0 || !_dataSourceFlags.image) {
    return nil;
  }

  // Grab the best available image from the data source.
  UIImage *existingImage = self.image;
  for (id imageIdentifier in _imageIdentifiers) {
    // If this image is already loaded, don't request it from the data source again because
    // the data source may generate a new instance of UIImage that returns NO for isEqual:
    // and we'll end up in an infinite loading loop.
    UIImage *image = ASObjectIsEqual(imageIdentifier, _loadedImageIdentifier) ? existingImage : [_dataSource multiplexImageNode:self imageForImageIdentifier:imageIdentifier];
    if (image) {
      if (imageIdentifierOut) {
        *imageIdentifierOut = imageIdentifier;
      }

      return image;
    }
  }

  return nil;
}

#pragma mark -

- (void)_updatePriorityOnDownloaderIfNeededWithDefaultPriority:(ASImageDownloaderPriority)defaultPriority
{
  ASAssertUnlocked(_downloadIdentifierLock);

  if (_downloaderFlags.downloaderImplementsSetPriority) {
    // Read our interface state before locking so that we don't lock super while holding our lock.
    ASInterfaceState interfaceState = self.interfaceState;
    MutexLocker l(_downloadIdentifierLock);

    if (_downloadIdentifier != nil) {
      ASImageDownloaderPriority priority = defaultPriority;
      if (ASActivateExperimentalFeature(ASExperimentalImageDownloaderPriority)) {
        priority = ASImageDownloaderPriorityWithInterfaceState(interfaceState);
      }

      [_downloader setPriority:priority withDownloadIdentifier:_downloadIdentifier];
    }
  }
}

- (void)_updateProgressImageBlockOnDownloaderIfNeeded
{
  ASAssertUnlocked(_downloadIdentifierLock);

  BOOL shouldRenderProgressImages = self.shouldRenderProgressImages;
  
  // Read our interface state before locking so that we don't lock super while holding our lock.
  ASInterfaceState interfaceState = self.interfaceState;
  MutexLocker l(_downloadIdentifierLock);
  
  if (!_downloaderFlags.downloaderImplementsSetProgress || _downloadIdentifier == nil) {
    return;
  }
  
  ASImageDownloaderProgressImage progress = nil;
  if (shouldRenderProgressImages && ASInterfaceStateIncludesVisible(interfaceState)) {
    __weak __typeof__(self) weakSelf = self;
    progress = ^(UIImage * _Nonnull progressImage, CGFloat progress, id _Nullable downloadIdentifier) {
      __typeof__(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      
      MutexLocker l(strongSelf->_downloadIdentifierLock);
      //Getting a result back for a different download identifier, download must not have been successfully canceled
      if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
        return;
      }
      [strongSelf _setImage:progressImage];
    };
  }
  [_downloader setProgressImageBlock:progress callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:_downloadIdentifier];
}

- (void)_clearImage
{
  // Destruction of bigger images on the main thread can be expensive
  // and can take some time, so we dispatch onto a bg queue to
  // actually dealloc.
  UIImage *image = self.image;
  CGSize imageSize = image.size;
  BOOL shouldReleaseImageOnBackgroundThread = imageSize.width > kMinReleaseImageOnBackgroundSize.width ||
  imageSize.height > kMinReleaseImageOnBackgroundSize.height;
  [self _setImage:nil];
  if (shouldReleaseImageOnBackgroundThread) {
    ASPerformBackgroundDeallocation(&image);
  }
}

#pragma mark -
- (id)_nextImageIdentifierToDownload
{
  MutexLocker l(_imageIdentifiersLock);

  // If we've already loaded the best identifier, we've got nothing else to do.
  id bestImageIdentifier = _imageIdentifiers.firstObject;
  if (!bestImageIdentifier || ASObjectIsEqual(_loadedImageIdentifier, bestImageIdentifier)) {
    return nil;
  }

  id nextImageIdentifierToDownload = nil;

  // If we're not supposed to download intermediate images, load the best identifier we've got.
  if (!_downloadsIntermediateImages) {
    nextImageIdentifierToDownload = bestImageIdentifier;
  }
  // Otherwise, load progressively.
  else {
    NSUInteger loadedIndex = [_imageIdentifiers indexOfObject:_loadedImageIdentifier];

    // If nothing has loaded yet, load the worst identifier.
    if (loadedIndex == NSNotFound) {
      nextImageIdentifierToDownload = [_imageIdentifiers lastObject];
    }
    // Otherwise, load the next best identifier (if there is one)
    else if (loadedIndex > 0) {
      nextImageIdentifierToDownload = _imageIdentifiers[loadedIndex - 1];
    }
  }

  return nextImageIdentifierToDownload;
}

- (void)_loadNextImage
{
  // Determine the next identifier to load (if any).
  id nextImageIdentifier = [self _nextImageIdentifierToDownload];
  if (!nextImageIdentifier) {
    [self _finishedLoadingImage:nil forIdentifier:nil error:nil];
    return;
  }

  as_activity_create_for_scope("Load next image for multiplex image node");
  as_log_verbose(ASImageLoadingLog(), "Loading image for %@ ident: %@", self, nextImageIdentifier);
  self.loadingImageIdentifier = nextImageIdentifier;

  __weak __typeof__(self) weakSelf = self;
  ASMultiplexImageLoadCompletionBlock finishedLoadingBlock = ^(UIImage *image, id imageIdentifier, NSError *error) {
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    // Only nil out the loading identifier if the loading identifier hasn't changed.
    if (ASObjectIsEqual(strongSelf.loadingImageIdentifier, nextImageIdentifier)) {
      strongSelf.loadingImageIdentifier = nil;
    }
    [strongSelf _finishedLoadingImage:image forIdentifier:imageIdentifier error:error];
  };

  // Ask our data-source if it's got this image.
  if (_dataSourceFlags.image) {
    UIImage *image = [_dataSource multiplexImageNode:self imageForImageIdentifier:nextImageIdentifier];
    if (image) {
      as_log_verbose(ASImageLoadingLog(), "Acquired image from data source for %@ ident: %@", self, nextImageIdentifier);
      finishedLoadingBlock(image, nextImageIdentifier, nil);
      return;
    }
  }

  NSURL *nextImageURL = (_dataSourceFlags.URL) ? [_dataSource multiplexImageNode:self URLForImageIdentifier:nextImageIdentifier] : nil;
  // If we fail to get a URL for the image, we have no source and can't proceed.
  if (!nextImageURL) {
    as_log_error(ASImageLoadingLog(), "Could not acquire URL %@ ident: (%@)", self, nextImageIdentifier);
    finishedLoadingBlock(nil, nil, [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodeNoSourceForImage userInfo:nil]);
    return;
  }

#if TARGET_OS_IOS && AS_USE_ASSETS_LIBRARY
  // If it's an assets-library URL, we need to fetch it from the assets library.
  if ([[nextImageURL scheme] isEqualToString:kAssetsLibraryURLScheme]) {
    // Load the asset.
    [self _loadALAssetWithIdentifier:nextImageIdentifier URL:nextImageURL completion:^(UIImage *downloadedImage, NSError *error) {
      as_log_verbose(ASImageLoadingLog(), "Acquired image from assets library for %@ %@", weakSelf, nextImageIdentifier);
      finishedLoadingBlock(downloadedImage, nextImageIdentifier, error);
    }];
    
    return;
  }
#endif
  
#if AS_USE_PHOTOS
  if (AS_AVAILABLE_IOS_TVOS(9, 10)) {
    // Likewise, if it's a Photos asset, we need to fetch it accordingly.
    if (ASPhotosFrameworkImageRequest *request = [ASPhotosFrameworkImageRequest requestWithURL:nextImageURL]) {
      [self _loadPHAssetWithRequest:request identifier:nextImageIdentifier completion:^(UIImage *image, NSError *error) {
        as_log_verbose(ASImageLoadingLog(), "Acquired image from Photos for %@ %@", weakSelf, nextImageIdentifier);
        finishedLoadingBlock(image, nextImageIdentifier, error);
      }];
      
      return;
    }
  }
#endif
  
  // Otherwise, it's a web URL that we can download.
  // First, check the cache.
  [self _fetchImageWithIdentifierFromCache:nextImageIdentifier URL:nextImageURL completion:^(UIImage *imageFromCache) {
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf)
      return;
    
    // If we had a cache-hit, we're done.
    if (imageFromCache) {
      as_log_verbose(ASImageLoadingLog(), "Acquired image from cache for %@ id: %@ img: %@", strongSelf, nextImageIdentifier, imageFromCache);
      finishedLoadingBlock(imageFromCache, nextImageIdentifier, nil);
      return;
    }
    
    // If the next image to load has changed, bail.
    if (!ASObjectIsEqual([strongSelf _nextImageIdentifierToDownload], nextImageIdentifier)) {
      finishedLoadingBlock(nil, nil, [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodeBestImageIdentifierChanged userInfo:nil]);
      return;
    }
    
    // Otherwise, we've got to download it.
    [strongSelf _downloadImageWithIdentifier:nextImageIdentifier URL:nextImageURL completion:^(UIImage *downloadedImage, NSError *error) {
      __typeof__(self) strongSelf = weakSelf;
      if (downloadedImage) {
        as_log_verbose(ASImageLoadingLog(), "Acquired image from download for %@ id: %@ img: %@", strongSelf, nextImageIdentifier, downloadedImage);
      } else {
        as_log_error(ASImageLoadingLog(), "Error downloading image for %@ id: %@ err: %@", strongSelf, nextImageIdentifier, error);
      }
      finishedLoadingBlock(downloadedImage, nextImageIdentifier, error);
    }];
  }];
}
#if TARGET_OS_IOS && AS_USE_ASSETS_LIBRARY
- (void)_loadALAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(assetURL, @"assetURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");
  
  // ALAssetsLibrary was replaced in iOS 8 and deprecated in iOS 9.
  // We'll drop support very soon.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];

  [assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
    ALAssetRepresentation *representation = [asset defaultRepresentation];
    CGImageRef coreGraphicsImage = [representation fullScreenImage];

    UIImage *downloadedImage = (coreGraphicsImage ? [UIImage imageWithCGImage:coreGraphicsImage] : nil);
    completionBlock(downloadedImage, nil);
  } failureBlock:^(NSError *error) {
    completionBlock(nil, error);
  }];
#pragma clang diagnostic pop
}
#endif

#if AS_USE_PHOTOS
- (void)_loadPHAssetWithRequest:(ASPhotosFrameworkImageRequest *)request identifier:(id)imageIdentifier completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(request, @"request is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");
  
  /*
   * Locking rationale:
   * As of iOS 9, Photos.framework will eventually deadlock if you hit it with concurrent fetch requests. rdar://22984886
   * Concurrent image requests are OK, but metadata requests aren't, so we limit ourselves to one at a time.
   */
  static NSLock *phRequestLock;
  static NSOperationQueue *phImageRequestQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    phRequestLock = [NSLock new];
    phImageRequestQueue = [NSOperationQueue new];
    phImageRequestQueue.maxConcurrentOperationCount = 10;
    phImageRequestQueue.name = @"org.AsyncDisplayKit.MultiplexImageNode.phImageRequestQueue";
  });
  
  // Each ASMultiplexImageNode can have max 1 inflight Photos image request operation
  [_phImageRequestOperation cancel];
  
  __weak __typeof(self) weakSelf = self;
  NSOperation *newImageRequestOp = [NSBlockOperation blockOperationWithBlock:^{
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf == nil) { return; }
    
    PHAsset *imageAsset = nil;
    
    // Try to get the asset immediately from the data source.
    if (_dataSourceFlags.asset) {
      imageAsset = [strongSelf.dataSource multiplexImageNode:strongSelf assetForLocalIdentifier:request.assetIdentifier];
    }
    
    // Fall back to locking and getting the PHAsset.
    if (imageAsset == nil) {
      [phRequestLock lock];
      // -[PHFetchResult dealloc] plays a role in the deadlock mentioned above, so we make sure the PHFetchResult is deallocated inside the critical section
      @autoreleasepool {
        imageAsset = [PHAsset fetchAssetsWithLocalIdentifiers:@[request.assetIdentifier] options:nil].firstObject;
      }
      [phRequestLock unlock];
    }
    
    if (imageAsset == nil) {
      NSError *error = [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodePHAssetIsUnavailable userInfo:nil];
      completionBlock(nil, error);
      return;
    }
    
    PHImageRequestOptions *options = [request.options copy];
    
    // We don't support opportunistic delivery – one request, one image.
    if (options.deliveryMode == PHImageRequestOptionsDeliveryModeOpportunistic) {
      options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    }
    
    if (options.deliveryMode == PHImageRequestOptionsDeliveryModeHighQualityFormat) {
      // Without this flag the result will be delivered on the main queue, which is pointless
      // But synchronous -> HighQualityFormat so we only use it if high quality format is specified
      options.synchronous = YES;
    }
    
    PHImageManager *imageManager = strongSelf.imageManager ? : PHImageManager.defaultManager;
    [imageManager requestImageForAsset:imageAsset targetSize:request.targetSize contentMode:request.contentMode options:options resultHandler:^(UIImage *image, NSDictionary *info) {
      NSError *error = info[PHImageErrorKey];
      
      if (error == nil && image == nil) {
        error = [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodePhotosImageManagerFailedWithoutError userInfo:nil];
      }
      
      if (NSThread.isMainThread) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
          completionBlock(image, error);
        });
      } else {
        completionBlock(image, error);
      }
    }];
  }];
  // If you don't set this, iOS will sometimes infer NSQualityOfServiceUserInteractive and promote the entire queue to that level, damaging system responsiveness
  newImageRequestOp.qualityOfService = NSQualityOfServiceUserInitiated;
  _phImageRequestOperation = newImageRequestOp;
  [phImageRequestQueue addOperation:newImageRequestOp];
}
#endif

- (void)_fetchImageWithIdentifierFromCache:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(imageURL, @"imageURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  if (_cache) {
    [_cache cachedImageWithURL:imageURL callbackQueue:dispatch_get_main_queue() completion:^(id <ASImageContainerProtocol> imageContainer) {
      completionBlock([imageContainer asdk_image]);
    }];
  }
  // If we don't have a cache, just fail immediately.
  else {
    completionBlock(nil);
  }
}

- (void)_downloadImageWithIdentifier:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(imageURL, @"imageURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  // Delegate (start)
  if (_delegateFlags.downloadStart)
    [_delegate multiplexImageNode:self didStartDownloadOfImageWithIdentifier:imageIdentifier];

  __weak __typeof__(self) weakSelf = self;
  ASImageDownloaderProgress downloadProgressBlock = NULL;
  if (_delegateFlags.downloadProgress) {
    downloadProgressBlock = ^(CGFloat progress) {
      __typeof__(self) strongSelf = weakSelf;
      if (!strongSelf)
        return;
      [strongSelf.delegate multiplexImageNode:strongSelf didUpdateDownloadProgress:progress forImageWithIdentifier:imageIdentifier];
    };
  }

  ASImageDownloaderCompletion completion = ^(id <ASImageContainerProtocol> imageContainer, NSError *error, id downloadIdentifier, id userInfo) {
    // We dereference iVars directly, so we can't have weakSelf going nil on us.
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    MutexLocker l(strongSelf->_downloadIdentifierLock);
    //Getting a result back for a different download identifier, download must not have been successfully canceled
    if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
      return;
    }

    completionBlock([imageContainer asdk_image], error);

    // Delegateify.
    if (strongSelf->_delegateFlags.downloadFinish)
      [strongSelf->_delegate multiplexImageNode:weakSelf didFinishDownloadingImageWithIdentifier:imageIdentifier error:error];
  };

  // Download!
  ASPerformBlockOnBackgroundThread(^{
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    dispatch_queue_t callbackQueue = dispatch_get_main_queue();

    id downloadIdentifier;
    if (strongSelf->_downloaderFlags.downloaderImplementsDownloadWithPriority
        && ASActivateExperimentalFeature(ASExperimentalImageDownloaderPriority)) {

      /*
       Decide a priority based on the current interface state of this node.
       It can happen that this method was called when the node entered preload state
       but the interface state, at this point, tells us that the node is (going to be) visible,
       If that's the case, we jump to a higher priority directly.
       */
      ASImageDownloaderPriority priority = ASImageDownloaderPriorityWithInterfaceState(strongSelf.interfaceState);
      downloadIdentifier = [strongSelf->_downloader downloadImageWithURL:imageURL
                                                                priority:priority
                                                           callbackQueue:callbackQueue
                                                        downloadProgress:downloadProgressBlock
                                                              completion:completion];
    } else {
      /*
       Kick off a download with default priority.
       The actual "default" value is decided by the downloader.
       ASBasicImageDownloader and ASPINRemoteImageDownloader both use ASImageDownloaderPriorityImminent
       which is mapped to NSURLSessionTaskPriorityDefault.

       This means that preload and display nodes use the same priority
       and their requests are put into the same pool.
       */
      downloadIdentifier = [strongSelf->_downloader downloadImageWithURL:imageURL
                                                           callbackQueue:callbackQueue
                                                        downloadProgress:downloadProgressBlock
                                                              completion:completion];
    }

    [strongSelf _setDownloadIdentifier:downloadIdentifier];
    [strongSelf _updateProgressImageBlockOnDownloaderIfNeeded];
  });
}

#pragma mark -
- (void)_finishedLoadingImage:(UIImage *)image forIdentifier:(id)imageIdentifier error:(NSError *)error
{
  // If we failed to load, we stop the loading process.
  // Note that if we bailed before we began downloading because the best identifier changed, we don't bail, but rather just begin loading the best image identifier.
  if (error && !([error.domain isEqual:ASMultiplexImageNodeErrorDomain] && error.code == ASMultiplexImageNodeErrorCodeBestImageIdentifierChanged))
    return;


  _imageIdentifiersLock.lock();
  NSUInteger imageIdentifierCount = [_imageIdentifiers count];
  _imageIdentifiersLock.unlock();

  // Update our image if we got one, or if we're not supposed to display one at all.
  // We explicitly perform this check because our datasource often doesn't give back immediately available images, even though we might have downloaded one already.
  // Because we seed this call with bestImmediatelyAvailableImageFromDataSource, we must be careful not to trample an existing image.
  if (image || imageIdentifierCount == 0) {
    as_log_verbose(ASImageLoadingLog(), "[%p] loaded -> displaying (%@, %@)", self, imageIdentifier, image);
    id previousIdentifier = self.loadedImageIdentifier;
    UIImage *previousImage = self.image;

    self.loadedImageIdentifier = imageIdentifier;
    [self _setImage:image];

    if (_delegateFlags.updatedImage) {
      [_delegate multiplexImageNode:self didUpdateImage:image withIdentifier:imageIdentifier fromImage:previousImage withIdentifier:previousIdentifier];
    }

  }

  // Load our next image, if we have one to load.
  if ([self _nextImageIdentifierToDownload])
    [self _loadNextImage];
}

@end

#if AS_USE_PHOTOS
@implementation NSURL (ASPhotosFrameworkURLs)

+ (NSURL *)URLWithAssetLocalIdentifier:(NSString *)assetLocalIdentifier targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(PHImageRequestOptions *)options NS_RETURNS_RETAINED
{
  ASPhotosFrameworkImageRequest *request = [[ASPhotosFrameworkImageRequest alloc] initWithAssetIdentifier:assetLocalIdentifier];
  request.options = options;
  request.contentMode = contentMode;
  request.targetSize = targetSize;
  return request.url;
}

@end
#endif
#endif
