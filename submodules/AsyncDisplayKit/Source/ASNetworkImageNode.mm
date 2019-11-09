//
//  ASNetworkImageNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASNetworkImageNode.h>

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASBasicImageDownloader.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import "Private/ASInternalHelpers.h"
#import <AsyncDisplayKit/ASImageNode+Private.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageContainerProtocolCategories.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASNetworkImageLoadInfo+Private.h>

#import <atomic>

#if AS_PIN_REMOTE_IMAGE
#import <AsyncDisplayKit/ASPINRemoteImageDownloader.h>
#endif

@interface ASNetworkImageNode ()
{
  // Only access any of these while locked.
  __weak id<ASNetworkImageNodeDelegate> _delegate;

  NSURL *_URL;
  UIImage *_defaultImage;

  NSInteger _cacheSentinel;
  id _downloadIdentifier;
  // The download identifier that we have set a progress block on, if any.
  id _downloadIdentifierForProgressBlock;

  BOOL _imageLoaded;
  BOOL _imageWasSetExternally;
  CGFloat _currentImageQuality;
  CGFloat _renderedImageQuality;
  BOOL _shouldRenderProgressImages;

  struct {
    unsigned int delegateWillStartDisplayAsynchronously:1;
    unsigned int delegateWillLoadImageFromCache:1;
    unsigned int delegateWillLoadImageFromNetwork:1;
    unsigned int delegateDidStartFetchingData:1;
    unsigned int delegateDidFailWithError:1;
    unsigned int delegateDidFinishDecoding:1;
    unsigned int delegateDidLoadImage:1;
    unsigned int delegateDidLoadImageFromCache:1;
    unsigned int delegateDidLoadImageWithInfo:1;
  } _delegateFlags;

  
  // Immutable and set on init only. We don't need to lock in this case.
  __weak id<ASImageDownloaderProtocol> _downloader;
  struct {
    unsigned int downloaderImplementsSetProgress:1;
    unsigned int downloaderImplementsSetPriority:1;
    unsigned int downloaderImplementsAnimatedImage:1;
    unsigned int downloaderImplementsCancelWithResume:1;
    unsigned int downloaderImplementsDownloadWithPriority:1;
  } _downloaderFlags;

  // Immutable and set on init only. We don't need to lock in this case.
  __weak id<ASImageCacheProtocol> _cache;
  struct {
    unsigned int cacheSupportsClearing:1;
    unsigned int cacheSupportsSynchronousFetch:1;
  } _cacheFlags;
}

@end

@implementation ASNetworkImageNode

static std::atomic_bool _useMainThreadDelegateCallbacks(true);

@dynamic image;

- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = (id<ASImageCacheProtocol>)cache;
  _downloader = (id<ASImageDownloaderProtocol>)downloader;
  
  _downloaderFlags.downloaderImplementsSetProgress = [downloader respondsToSelector:@selector(setProgressImageBlock:callbackQueue:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsSetPriority = [downloader respondsToSelector:@selector(setPriority:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsAnimatedImage = [downloader respondsToSelector:@selector(animatedImageWithData:)];
  _downloaderFlags.downloaderImplementsCancelWithResume = [downloader respondsToSelector:@selector(cancelImageDownloadWithResumePossibilityForIdentifier:)];
  _downloaderFlags.downloaderImplementsDownloadWithPriority = [downloader respondsToSelector:@selector(downloadImageWithURL:priority:callbackQueue:downloadProgress:completion:)];

  _cacheFlags.cacheSupportsClearing = [cache respondsToSelector:@selector(clearFetchedImageFromCacheWithURL:)];
  _cacheFlags.cacheSupportsSynchronousFetch = [cache respondsToSelector:@selector(synchronouslyFetchedCachedImageWithURL:)];
  
  _shouldCacheImage = YES;
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
  [self _cancelImageDownloadWithResumePossibility:NO];
}

- (dispatch_queue_t)callbackQueue
{
  return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

#pragma mark - Public methods -- must lock

/// Setter for public image property. It has the side effect of setting an internal _imageWasSetExternally that prevents setting an image internally. Setting an image internally should happen with the _setImage: method
- (void)setImage:(UIImage *)image
{
  ASLockScopeSelf();
  [self _locked_setImage:image];
}

- (void)_locked_setImage:(UIImage *)image
{
  ASAssertLocked(__instanceLock__);
  
  BOOL imageWasSetExternally = (image != nil);
  BOOL shouldCancelAndClear = imageWasSetExternally && (imageWasSetExternally != _imageWasSetExternally);
  _imageWasSetExternally = imageWasSetExternally;
  if (shouldCancelAndClear) {
    ASDisplayNodeAssertNil(_URL, @"Directly setting an image on an ASNetworkImageNode causes it to behave like an ASImageNode instead of an ASNetworkImageNode. If this is what you want, set the URL to nil first.");
    _URL = nil;
    [self _locked_cancelDownloadAndClearImageWithResumePossibility:NO];
  }
  
  // If our image is being set externally, the image quality is 100%
  if (imageWasSetExternally) {
    [self _setCurrentImageQuality:1.0];
  }
  
  [self _locked__setImage:image];
}

/// Setter for private image property. See @c _locked_setImage why this is needed
- (void)_setImage:(UIImage *)image
{
  ASLockScopeSelf();
  [self _locked__setImage:image];
}

- (void)_locked__setImage:(UIImage *)image
{
  ASAssertLocked(__instanceLock__);
  [super _locked_setImage:image];
}

// Deprecated
- (void)setURLs:(NSArray<NSURL *> *)URLs
{
  [self setURL:[URLs firstObject]];
}

// Deprecated
- (NSArray<NSURL *> *)URLs
{
  return @[self.URL];
}

- (void)setURL:(NSURL *)URL
{
  [self setURL:URL resetToDefault:YES];
}

- (void)setURL:(NSURL *)URL resetToDefault:(BOOL)reset
{
  {
    ASLockScopeSelf();
    
    if (ASObjectIsEqual(URL, _URL)) {
      return;
    }
    
    URL = [URL copy];
    
    ASDisplayNodeAssert(_imageWasSetExternally == NO, @"Setting a URL to an ASNetworkImageNode after setting an image changes its behavior from an ASImageNode to an ASNetworkImageNode. If this is what you want, set the image to nil first.");
    
    _imageWasSetExternally = NO;
    
    [self _locked_cancelImageDownloadWithResumePossibility:NO];

    _imageLoaded = NO;
    
    _URL = URL;
    
    // If URL is nil and URL was not equal to _URL (checked at the top), then we previously had a URL but it's been nil'd out.
    BOOL hadURL = (URL == nil);
    if (reset || hadURL) {
      [self _setCurrentImageQuality:(hadURL ? 0.0 : 1.0)];
      [self _locked__setImage:_defaultImage];
    }
  }

  [self setNeedsPreload];
}

- (NSURL *)URL
{
  return ASLockedSelf(_URL);
}

- (void)setDefaultImage:(UIImage *)defaultImage
{
  ASLockScopeSelf();

  [self _locked_setDefaultImage:defaultImage];
}

- (void)_locked_setDefaultImage:(UIImage *)defaultImage
{
  if (ASObjectIsEqual(defaultImage, _defaultImage)) {
    return;
  }

  _defaultImage = defaultImage;

  if (!_imageLoaded) {
    [self _setCurrentImageQuality:((_URL == nil) ? 0.0 : 1.0)];
    [self _locked__setImage:defaultImage];
  }
}

- (UIImage *)defaultImage
{
  return ASLockedSelf(_defaultImage);
}

- (void)setCurrentImageQuality:(CGFloat)currentImageQuality
{
  ASLockScopeSelf();
  _currentImageQuality = currentImageQuality;
}

- (CGFloat)currentImageQuality
{
  return ASLockedSelf(_currentImageQuality);
}

/**
 * Always use these methods internally to update the current image quality
 * We want to maintain the order that currentImageQuality is set regardless of the calling thread,
 * so we always have to dispatch to the main thread to ensure that we queue the operations in the correct order.
 * (see comment in displayDidFinish)
 */
- (void)_setCurrentImageQuality:(CGFloat)imageQuality
{
  dispatch_async(dispatch_get_main_queue(), ^{
    self.currentImageQuality = imageQuality;
  });
}

- (void)setRenderedImageQuality:(CGFloat)renderedImageQuality
{
  ASLockScopeSelf();
  _renderedImageQuality = renderedImageQuality;
}

- (CGFloat)renderedImageQuality
{
  ASLockScopeSelf();
  return _renderedImageQuality;
}

- (void)setDelegate:(id<ASNetworkImageNodeDelegate>)delegate
{
  ASLockScopeSelf();
  _delegate = delegate;
  
  _delegateFlags.delegateWillStartDisplayAsynchronously = [delegate respondsToSelector:@selector(imageNodeWillStartDisplayAsynchronously:)];
  _delegateFlags.delegateWillLoadImageFromCache = [delegate respondsToSelector:@selector(imageNodeWillLoadImageFromCache:)];
  _delegateFlags.delegateWillLoadImageFromNetwork = [delegate respondsToSelector:@selector(imageNodeWillLoadImageFromNetwork:)];
  _delegateFlags.delegateDidStartFetchingData = [delegate respondsToSelector:@selector(imageNodeDidStartFetchingData:)];
  _delegateFlags.delegateDidFailWithError = [delegate respondsToSelector:@selector(imageNode:didFailWithError:)];
  _delegateFlags.delegateDidFinishDecoding = [delegate respondsToSelector:@selector(imageNodeDidFinishDecoding:)];
  _delegateFlags.delegateDidLoadImage = [delegate respondsToSelector:@selector(imageNode:didLoadImage:)];
  _delegateFlags.delegateDidLoadImageFromCache = [delegate respondsToSelector:@selector(imageNodeDidLoadImageFromCache:)];
  _delegateFlags.delegateDidLoadImageWithInfo = [delegate respondsToSelector:@selector(imageNode:didLoadImage:info:)];
}

- (id<ASNetworkImageNodeDelegate>)delegate
{
  ASLockScopeSelf();
  return _delegate;
}

- (void)setShouldRenderProgressImages:(BOOL)shouldRenderProgressImages
{
  if (ASLockedSelfCompareAssign(_shouldRenderProgressImages, shouldRenderProgressImages)) {
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
  }
}

- (BOOL)shouldRenderProgressImages
{
  ASLockScopeSelf();
  return _shouldRenderProgressImages;
}

- (BOOL)placeholderShouldPersist
{
  ASLockScopeSelf();
  return (self.image == nil && self.animatedImage == nil && _URL != nil);
}

/* displayWillStartAsynchronously: in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  [super displayWillStartAsynchronously:asynchronously];
  
  id<ASNetworkImageNodeDelegate> delegate;
  BOOL notifyDelegate;
  {
    ASLockScopeSelf();
    notifyDelegate = _delegateFlags.delegateWillStartDisplayAsynchronously;
    delegate = _delegate;
  }
  if (notifyDelegate) {
    [delegate imageNodeWillStartDisplayAsynchronously:self];
  }
  
  if (asynchronously == NO && _cacheFlags.cacheSupportsSynchronousFetch) {
    ASLockScopeSelf();

    NSURL *url = _URL;
    if (_imageLoaded == NO && url && _downloadIdentifier == nil) {
      UIImage *result = [[_cache synchronouslyFetchedCachedImageWithURL:url] asdk_image];
      if (result) {
        [self _setCurrentImageQuality:1.0];
        [self _locked__setImage:result];
        _imageLoaded = YES;
        
        // Call out to the delegate.
        if (_delegateFlags.delegateDidLoadImageWithInfo) {
          ASUnlockScope(self);
          const auto info = [[ASNetworkImageLoadInfo alloc] initWithURL:url sourceType:ASNetworkImageSourceSynchronousCache downloadIdentifier:nil userInfo:nil];
          [delegate imageNode:self didLoadImage:result info:info];
        } else if (_delegateFlags.delegateDidLoadImage) {
          ASUnlockScope(self);
          [delegate imageNode:self didLoadImage:result];
        }
      }
    }
  }

  if (self.image == nil) {
    [self _updatePriorityOnDownloaderIfNeededWithDefaultPriority:ASImageDownloaderPriorityImminent];
  }
}

/* visibileStateDidChange in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
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

- (void)didExitPreloadState
{
  [super didExitPreloadState];

  // If the image was set explicitly we don't want to remove it while exiting the preload state
  if (ASLockedSelf(_imageWasSetExternally)) {
    return;
  }

  [self _cancelDownloadAndClearImageWithResumePossibility:YES];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  // Image was set externally no need to load an image
  [self _lazilyLoadImageIfNecessary];
}

+ (void)setUseMainThreadDelegateCallbacks:(BOOL)useMainThreadDelegateCallbacks
{
  _useMainThreadDelegateCallbacks = useMainThreadDelegateCallbacks;
}

+ (BOOL)useMainThreadDelegateCallbacks
{
  return _useMainThreadDelegateCallbacks;
}

#pragma mark - Progress

- (void)handleProgressImage:(UIImage *)progressImage progress:(CGFloat)progress downloadIdentifier:(nullable id)downloadIdentifier
{
  ASLockScopeSelf();
  
  // Getting a result back for a different download identifier, download must not have been successfully canceled
  if (ASObjectIsEqual(_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
    return;
  }
  
  as_log_verbose(ASImageLoadingLog(), "Received progress image for %@ q: %.2g id: %@", self, progress, progressImage);
  [self _setCurrentImageQuality:progress];
  [self _locked__setImage:progressImage];
}

- (void)_updatePriorityOnDownloaderIfNeededWithDefaultPriority:(ASImageDownloaderPriority)defaultPriority
{
  if (_downloaderFlags.downloaderImplementsSetPriority) {
    ASLockScopeSelf();

    if (_downloadIdentifier != nil) {
      ASImageDownloaderPriority priority = defaultPriority;
      if (ASActivateExperimentalFeature(ASExperimentalImageDownloaderPriority)) {
        priority = ASImageDownloaderPriorityWithInterfaceState(_interfaceState);
      }

      [_downloader setPriority:priority withDownloadIdentifier:_downloadIdentifier];
    }
  }
}

- (void)_updateProgressImageBlockOnDownloaderIfNeeded
{
  // If the downloader doesn't do progress, we are done.
  if (_downloaderFlags.downloaderImplementsSetProgress == NO) {
    return;
  }

  // Read state.
  [self lock];
    BOOL shouldRender = _shouldRenderProgressImages && ASInterfaceStateIncludesVisible(_interfaceState);
    id oldDownloadIDForProgressBlock = _downloadIdentifierForProgressBlock;
    id newDownloadIDForProgressBlock = shouldRender ? _downloadIdentifier : nil;
    BOOL clearAndReattempt = NO;
  [self unlock];

  // If we're already bound to the correct download, we're done.
  if (ASObjectIsEqual(oldDownloadIDForProgressBlock, newDownloadIDForProgressBlock)) {
    return;
  }

  // Unbind from the previous download.
  if (oldDownloadIDForProgressBlock != nil) {
    as_log_verbose(ASImageLoadingLog(), "Disabled progress images for %@ id: %@", self, oldDownloadIDForProgressBlock);
    [_downloader setProgressImageBlock:nil callbackQueue:[self callbackQueue] withDownloadIdentifier:oldDownloadIDForProgressBlock];
  }

  // Bind to the current download.
  if (newDownloadIDForProgressBlock != nil) {
    __weak __typeof(self) weakSelf = self;
    as_log_verbose(ASImageLoadingLog(), "Enabled progress images for %@ id: %@", self, newDownloadIDForProgressBlock);
    [_downloader setProgressImageBlock:^(UIImage * _Nonnull progressImage, CGFloat progress, id  _Nullable downloadIdentifier) {
      [weakSelf handleProgressImage:progressImage progress:progress downloadIdentifier:downloadIdentifier];
    } callbackQueue:[self callbackQueue] withDownloadIdentifier:newDownloadIDForProgressBlock];
  }

  // Update state local state with lock held.
  {
    ASLockScopeSelf();
    // Check if the oldDownloadIDForProgressBlock still is the same as the _downloadIdentifierForProgressBlock
    if (_downloadIdentifierForProgressBlock == oldDownloadIDForProgressBlock) {
      _downloadIdentifierForProgressBlock = newDownloadIDForProgressBlock;
    } else if (newDownloadIDForProgressBlock != nil) {
      // If this is not the case another thread did change the _downloadIdentifierForProgressBlock already so
      // we have to deregister the newDownloadIDForProgressBlock that we registered above
      clearAndReattempt = YES;
    }
  }
  
  if (clearAndReattempt) {
    // In this case another thread changed the _downloadIdentifierForProgressBlock before we finished registering
    // the new progress block for newDownloadIDForProgressBlock ID. Let's clear it now and reattempt to register
    if (newDownloadIDForProgressBlock) {
      [_downloader setProgressImageBlock:nil callbackQueue:[self callbackQueue] withDownloadIdentifier:newDownloadIDForProgressBlock];
    }
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
  }
}

- (void)_cancelDownloadAndClearImageWithResumePossibility:(BOOL)storeResume
{
  ASLockScopeSelf();
  [self _locked_cancelDownloadAndClearImageWithResumePossibility:storeResume];
}

- (void)_locked_cancelDownloadAndClearImageWithResumePossibility:(BOOL)storeResume
{
  ASAssertLocked(__instanceLock__);
  
  [self _locked_cancelImageDownloadWithResumePossibility:storeResume];
  
  [self _locked_setAnimatedImage:nil];
  [self _setCurrentImageQuality:0.0];
  [self _locked__setImage:_defaultImage];

  _imageLoaded = NO;

  if (_cacheFlags.cacheSupportsClearing) {
    if (_URL != nil) {
      as_log_verbose(ASImageLoadingLog(), "Clearing cached image for %@ url: %@", self, _URL);
      [_cache clearFetchedImageFromCacheWithURL:_URL];
    }
  }
}

- (void)_cancelImageDownloadWithResumePossibility:(BOOL)storeResume
{
  ASLockScopeSelf();
  [self _locked_cancelImageDownloadWithResumePossibility:storeResume];
}

- (void)_locked_cancelImageDownloadWithResumePossibility:(BOOL)storeResume
{
  ASAssertLocked(__instanceLock__);
  
  if (!_downloadIdentifier) {
    return;
  }

  if (_downloadIdentifier) {
    if (storeResume && _downloaderFlags.downloaderImplementsCancelWithResume) {
      as_log_verbose(ASImageLoadingLog(), "Canceling image download w resume for %@ id: %@", self, _downloadIdentifier);
      [_downloader cancelImageDownloadWithResumePossibilityForIdentifier:_downloadIdentifier];
    } else {
      as_log_verbose(ASImageLoadingLog(), "Canceling image download no resume for %@ id: %@", self, _downloadIdentifier);
      [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
    }
  }
  _downloadIdentifier = nil;
  _cacheSentinel++;
}

- (void)_downloadImageWithCompletion:(void (^)(id <ASImageContainerProtocol> imageContainer, NSError*, id downloadIdentifier, id userInfo))finished
{
  ASPerformBlockOnBackgroundThread(^{
    NSURL *url;
    id downloadIdentifier;
    BOOL cancelAndReattempt = NO;
    ASInterfaceState interfaceState;

    // Below, to avoid performance issues, we're calling downloadImageWithURL without holding the lock. This is a bit ugly because
    // We need to reobtain the lock after and ensure that the task we've kicked off still matches our URL. If not, we need to cancel
    // it and try again.
    {
      ASLockScopeSelf();
      url = self->_URL;
      interfaceState = self->_interfaceState;
    }

    dispatch_queue_t callbackQueue = [self callbackQueue];
    ASImageDownloaderProgress downloadProgress = NULL;
    ASImageDownloaderCompletion completion = ^(id <ASImageContainerProtocol> _Nullable imageContainer, NSError * _Nullable error, id  _Nullable downloadIdentifier, id _Nullable userInfo) {
      if (finished != NULL) {
        finished(imageContainer, error, downloadIdentifier, userInfo);
      }
    };

    if (self->_downloaderFlags.downloaderImplementsDownloadWithPriority
        && ASActivateExperimentalFeature(ASExperimentalImageDownloaderPriority)) {
      /*
        Decide a priority based on the current interface state of this node.
        It can happen that this method was called when the node entered preload state
        but the interface state, at this point, tells us that the node is (going to be) visible.
        If that's the case, we jump to a higher priority directly.
       */
      ASImageDownloaderPriority priority = ASImageDownloaderPriorityWithInterfaceState(interfaceState);

      downloadIdentifier = [self->_downloader downloadImageWithURL:url
                                                          priority:priority
                                                     callbackQueue:callbackQueue
                                                  downloadProgress:downloadProgress
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
      downloadIdentifier = [self->_downloader downloadImageWithURL:url
                                                     callbackQueue:callbackQueue
                                                  downloadProgress:downloadProgress
                                                        completion:completion];
    }
    as_log_verbose(ASImageLoadingLog(), "Downloading image for %@ url: %@", self, url);
  
    {
      ASLockScopeSelf();
      if (ASObjectIsEqual(self->_URL, url)) {
        // The download we kicked off is correct, no need to do any more work.
        self->_downloadIdentifier = downloadIdentifier;
      } else {
        // The URL changed since we kicked off our download task. This shouldn't happen often so we'll pay the cost and
        // cancel that request and kick off a new one.
        cancelAndReattempt = YES;
      }
    }
    
    if (cancelAndReattempt) {
      if (downloadIdentifier != nil) {
        as_log_verbose(ASImageLoadingLog(), "Canceling image download no resume for %@ id: %@", self, downloadIdentifier);
        [self->_downloader cancelImageDownloadForIdentifier:downloadIdentifier];
      }
      [self _downloadImageWithCompletion:finished];
      return;
    }
    
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
  });
}

- (void)_lazilyLoadImageIfNecessary
{
  ASDisplayNodeAssertMainThread();

  [self lock];
    __weak id<ASNetworkImageNodeDelegate> delegate = _delegate;
    BOOL delegateDidStartFetchingData = _delegateFlags.delegateDidStartFetchingData;
    BOOL delegateWillLoadImageFromCache = _delegateFlags.delegateWillLoadImageFromCache;
    BOOL delegateWillLoadImageFromNetwork = _delegateFlags.delegateWillLoadImageFromNetwork;
    BOOL delegateDidLoadImageFromCache = _delegateFlags.delegateDidLoadImageFromCache;
    BOOL isImageLoaded = _imageLoaded;
    NSURL *URL = _URL;
    id currentDownloadIdentifier = _downloadIdentifier;
  [self unlock];
  
  if (!isImageLoaded && URL != nil && currentDownloadIdentifier == nil) {
    if (delegateDidStartFetchingData) {
      [delegate imageNodeDidStartFetchingData:self];
    }
    
    if (URL.isFileURL) {
      dispatch_async(dispatch_get_main_queue(), ^{
        ASLockScopeSelf();
        
        // Bail out if not the same URL anymore
        if (!ASObjectIsEqual(URL, self->_URL)) {
          return;
        }
        
        if (self->_shouldCacheImage) {
          [self _locked__setImage:[UIImage imageNamed:URL.path.lastPathComponent]];
        } else {
          // First try to load the path directly, for efficiency assuming a developer who
          // doesn't want caching is trying to be as minimal as possible.
          auto nonAnimatedImage = [[UIImage alloc] initWithContentsOfFile:URL.path];
          if (nonAnimatedImage == nil) {
            // If we couldn't find it, execute an -imageNamed:-like search so we can find resources even if the
            // extension is not provided in the path.  This allows the same path to work regardless of shouldCacheImage.
            NSString *filename = [[NSBundle mainBundle] pathForResource:URL.path.lastPathComponent ofType:nil];
            if (filename != nil) {
              nonAnimatedImage = [[UIImage alloc] initWithContentsOfFile:filename];
            }
          }

          // If the file may be an animated gif and then created an animated image.
          id<ASAnimatedImageProtocol> animatedImage = nil;
          if (self->_downloaderFlags.downloaderImplementsAnimatedImage) {
            const auto data = [[NSData alloc] initWithContentsOfURL:URL];
            if (data != nil) {
              animatedImage = [self->_downloader animatedImageWithData:data];

              if ([animatedImage respondsToSelector:@selector(isDataSupported:)] && [animatedImage isDataSupported:data] == NO) {
                animatedImage = nil;
              }
            }
          }

          if (animatedImage != nil) {
            [self _locked_setAnimatedImage:animatedImage];
          } else {
            [self _locked__setImage:nonAnimatedImage];
          }
        }

        self->_imageLoaded = YES;

        [self _setCurrentImageQuality:1.0];

        if (self->_delegateFlags.delegateDidLoadImageWithInfo) {
          ASUnlockScope(self);
          const auto info = [[ASNetworkImageLoadInfo alloc] initWithURL:URL sourceType:ASNetworkImageSourceFileURL downloadIdentifier:nil userInfo:nil];
          [delegate imageNode:self didLoadImage:self.image info:info];
        } else if (self->_delegateFlags.delegateDidLoadImage) {
          ASUnlockScope(self);
          [delegate imageNode:self didLoadImage:self.image];
        }
      });
    } else {
      __weak __typeof__(self) weakSelf = self;
      const auto finished = ^(id <ASImageContainerProtocol>imageContainer, NSError *error, id downloadIdentifier, ASNetworkImageSourceType imageSource, id userInfo) {
        ASPerformBlockOnBackgroundThread(^{
          __typeof__(self) strongSelf = weakSelf;
          if (strongSelf == nil) {
            return;
          }
          
          as_log_verbose(ASImageLoadingLog(), "Downloaded image for %@ img: %@ url: %@", self, [imageContainer asdk_image], URL);
          
          // Grab the lock for the rest of the block
          ASLockScope(strongSelf);
          
          //Getting a result back for a different download identifier, download must not have been successfully canceled
          if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
            return;
          }
          
          //No longer in preload range, no point in setting the results (they won't be cleared in exit preload range)
          if (ASInterfaceStateIncludesPreload(strongSelf->_interfaceState) == NO) {
            strongSelf->_downloadIdentifier = nil;
            strongSelf->_cacheSentinel++;
            return;
          }
          
          UIImage *newImage;
          if (imageContainer != nil) {
            [strongSelf _setCurrentImageQuality:1.0];
            NSData *animatedImageData = [imageContainer asdk_animatedImageData];
            if (animatedImageData && strongSelf->_downloaderFlags.downloaderImplementsAnimatedImage) {
              id animatedImage = [strongSelf->_downloader animatedImageWithData:animatedImageData];
              [strongSelf _locked_setAnimatedImage:animatedImage];
            } else {
              newImage = [imageContainer asdk_image];
              [strongSelf _locked__setImage:newImage];
            }
            strongSelf->_imageLoaded = YES;
          }
          
          strongSelf->_downloadIdentifier = nil;
          strongSelf->_cacheSentinel++;
          
          void (^calloutBlock)(ASNetworkImageNode *inst);
          
          if (newImage) {
            if (strongSelf->_delegateFlags.delegateDidLoadImageWithInfo) {
              calloutBlock = ^(ASNetworkImageNode *strongSelf) {
                const auto info = [[ASNetworkImageLoadInfo alloc] initWithURL:URL sourceType:imageSource downloadIdentifier:downloadIdentifier userInfo:userInfo];
                [delegate imageNode:strongSelf didLoadImage:newImage info:info];
              };
            } else if (strongSelf->_delegateFlags.delegateDidLoadImage) {
              calloutBlock = ^(ASNetworkImageNode *strongSelf) {
                [delegate imageNode:strongSelf didLoadImage:newImage];
              };
            }
          } else if (error && strongSelf->_delegateFlags.delegateDidFailWithError) {
            calloutBlock = ^(ASNetworkImageNode *strongSelf) {
              [delegate imageNode:strongSelf didFailWithError:error];
            };
          }
          
          if (calloutBlock) {
            if (ASNetworkImageNode.useMainThreadDelegateCallbacks) {
              ASPerformBlockOnMainThread(^{
                if (auto strongSelf = weakSelf) {
                  calloutBlock(strongSelf);
                }
              });
            } else {
              calloutBlock(strongSelf);
            }
          }
        });
      };

      // As the _cache and _downloader is only set once in the intializer we don't have to use a
      // lock in here
      if (_cache != nil) {
        NSInteger cacheSentinel = ASLockedSelf(++_cacheSentinel);

        as_log_verbose(ASImageLoadingLog(), "Decaching image for %@ url: %@", self, URL);
        
        ASImageCacherCompletion completion = ^(id <ASImageContainerProtocol> imageContainer) {
          // If the cache sentinel changed, that means this request was cancelled.
          if (ASLockedSelf(self->_cacheSentinel != cacheSentinel)) {
            return;
          }
          
          if ([imageContainer asdk_image] == nil && self->_downloader != nil) {
            if (delegateWillLoadImageFromNetwork) {
              [delegate imageNodeWillLoadImageFromNetwork:self];
            }
            [self _downloadImageWithCompletion:^(id<ASImageContainerProtocol> imageContainer, NSError *error, id downloadIdentifier, id userInfo) {
              finished(imageContainer, error, downloadIdentifier, ASNetworkImageSourceDownload, userInfo);
            }];
          } else {
            if (delegateDidLoadImageFromCache) {
              [delegate imageNodeDidLoadImageFromCache:self];
            }
            as_log_verbose(ASImageLoadingLog(), "Decached image for %@ img: %@ url: %@", self, [imageContainer asdk_image], URL);
            finished(imageContainer, nil, nil, ASNetworkImageSourceAsynchronousCache, nil);
          }
        };
        
        if (delegateWillLoadImageFromCache) {
          [delegate imageNodeWillLoadImageFromCache:self];
        }
        [_cache cachedImageWithURL:URL
                     callbackQueue:[self callbackQueue]
                        completion:completion];
      } else {
        if (delegateWillLoadImageFromNetwork) {
          [delegate imageNodeWillLoadImageFromNetwork:self];
        }
        [self _downloadImageWithCompletion:^(id<ASImageContainerProtocol> imageContainer, NSError *error, id downloadIdentifier, id userInfo) {
          finished(imageContainer, error, downloadIdentifier, ASNetworkImageSourceDownload, userInfo);
        }];
      }
    }
  }
}

#pragma mark - ASDisplayNode+Subclasses

- (void)displayDidFinish
{
  [super displayDidFinish];
  
  id<ASNetworkImageNodeDelegate> delegate = nil;
  
  {
    ASLockScopeSelf();
    if (_delegateFlags.delegateDidFinishDecoding && self.layer.contents != nil) {
      /* We store the image quality in _currentImageQuality whenever _image is set. On the following displayDidFinish, we'll know that
       _currentImageQuality is the quality of the image that has just finished rendering. In order for this to be accurate, we
       need to be sure we are on main thread when we set _currentImageQuality. Otherwise, it is possible for _currentImageQuality
       to be modified at a point where it is too late to cancel the main thread's previous display (the final sentinel check has passed), 
       but before the displayDidFinish of the previous display pass is called. In this situation, displayDidFinish would be called and we
       would set _renderedImageQuality to the new _currentImageQuality, but the actual quality of the rendered image should be the previous 
       value stored in _currentImageQuality. */

      _renderedImageQuality = _currentImageQuality;
      
      // Assign the delegate to be used
      delegate = _delegate;
    }
  }
  
  if (delegate != nil) {
    [delegate imageNodeDidFinishDecoding:self];
  }
}

@end

#endif
