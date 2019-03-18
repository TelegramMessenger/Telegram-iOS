//
//  ASImageNode+AnimatedImage.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASImageNode.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASImageNode+Private.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageProtocols.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASNetworkImageNode.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASWeakProxy.h>

#define ASAnimatedImageDebug  0

#ifndef MINIMAL_ASDK
@interface ASNetworkImageNode (Private)
- (void)_locked_setDefaultImage:(UIImage *)image;
@end
#endif


@implementation ASImageNode (AnimatedImage)

#pragma mark - GIF support

- (void)setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  ASLockScopeSelf();
  [self _locked_setAnimatedImage:animatedImage];
}

- (void)_locked_setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  ASAssertLocked(__instanceLock__);

  if (ASObjectIsEqual(_animatedImage, animatedImage) && (animatedImage == nil || animatedImage.playbackReady)) {
    return;
  }
  
  __block id <ASAnimatedImageProtocol> previousAnimatedImage = _animatedImage;
  
  _animatedImage = animatedImage;
  
  if (animatedImage != nil) {
    __weak ASImageNode *weakSelf = self;
    if ([animatedImage respondsToSelector:@selector(setCoverImageReadyCallback:)]) {
      animatedImage.coverImageReadyCallback = ^(UIImage *coverImage) {
        // In this case the lock is already gone we have to call the unlocked version therefore
        [weakSelf setCoverImageCompleted:coverImage];
      };
    }
    
    animatedImage.playbackReadyCallback = ^{
      // In this case the lock is already gone we have to call the unlocked version therefore
      [weakSelf setShouldAnimate:YES];
    };
    if (animatedImage.playbackReady) {
      [self _locked_setShouldAnimate:YES];
    }
  } else {
    // Clean up after ourselves.
    
    // Don't bother using a `_locked` version for setting contnst as it should be pretty safe calling it with
    // reaquire the lock and would add overhead to introduce this version
    self.contents = nil;
    [self _locked_setCoverImage:nil];
  }

  // Push calling subclass to the next runloop cycle
  // We have to schedule the block on the common modes otherwise the tracking mode will not be included and it will
  // not fire e.g. while scrolling down
  CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^(void) {
    [self animatedImageSet:animatedImage previousAnimatedImage:previousAnimatedImage];

    // Animated image can take while to dealloc, do it off the main queue
    if (previousAnimatedImage != nil) {
      ASPerformBackgroundDeallocation(&previousAnimatedImage);
    }
  });
  // Don't need to wakeup the runloop as the current is already running
  // CFRunLoopWakeUp(runLoop); // Should not be necessary
}

- (void)animatedImageSet:(id <ASAnimatedImageProtocol>)newAnimatedImage previousAnimatedImage:(id <ASAnimatedImageProtocol>)previousAnimatedImage
{
  // Subclass hook should not be called with the lock held
  ASAssertUnlocked(__instanceLock__);
  
  // Subclasses may override
}

- (id <ASAnimatedImageProtocol>)animatedImage
{
  ASLockScopeSelf();
  return _animatedImage;
}

- (void)setAnimatedImagePaused:(BOOL)animatedImagePaused
{
  ASLockScopeSelf();

  _animatedImagePaused = animatedImagePaused;

  [self _locked_setShouldAnimate:!animatedImagePaused];
}

- (BOOL)animatedImagePaused
{
  ASLockScopeSelf();
  return _animatedImagePaused;
}

- (void)setCoverImageCompleted:(UIImage *)coverImage
{
  if (ASInterfaceStateIncludesDisplay(self.interfaceState)) {
    ASLockScopeSelf();
    [self _locked_setCoverImageCompleted:coverImage];
  }
}

- (void)_locked_setCoverImageCompleted:(UIImage *)coverImage
{
  ASAssertLocked(__instanceLock__);
  
  _displayLinkLock.lock();
  BOOL setCoverImage = (_displayLink == nil) || _displayLink.paused;
  _displayLinkLock.unlock();
  
  if (setCoverImage) {
    [self _locked_setCoverImage:coverImage];
  }
}

- (void)setCoverImage:(UIImage *)coverImage
{
  ASLockScopeSelf();
  [self _locked_setCoverImage:coverImage];
}

- (void)_locked_setCoverImage:(UIImage *)coverImage
{
  ASAssertLocked(__instanceLock__);
  
  //If we're a network image node, we want to set the default image so
  //that it will correctly be restored if it exits the range.
#ifndef MINIMAL_ASDK
  if ([self isKindOfClass:[ASNetworkImageNode class]]) {
    [(ASNetworkImageNode *)self _locked_setDefaultImage:coverImage];
  } else if (_displayLink == nil || _displayLink.paused == YES) {
    [self _locked_setImage:coverImage];
  }
#endif
}

- (NSString *)animatedImageRunLoopMode
{
  AS::MutexLocker l(_displayLinkLock);
  return _animatedImageRunLoopMode;
}

- (void)setAnimatedImageRunLoopMode:(NSString *)runLoopMode
{
  AS::MutexLocker l(_displayLinkLock);

  if (runLoopMode == nil) {
    runLoopMode = ASAnimatedImageDefaultRunLoopMode;
  }

  if (_displayLink != nil) {
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:_animatedImageRunLoopMode];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:runLoopMode];
  }
  _animatedImageRunLoopMode = [runLoopMode copy];
}

- (void)setShouldAnimate:(BOOL)shouldAnimate
{
  ASLockScopeSelf();
  [self _locked_setShouldAnimate:shouldAnimate];
}

- (void)_locked_setShouldAnimate:(BOOL)shouldAnimate
{
  ASAssertLocked(__instanceLock__);
  
  // This test is explicitly done and not ASPerformBlockOnMainThread as this would perform the block immediately
  // on main if called on main thread and we have to call methods locked or unlocked based on which thread we are on
  if (ASDisplayNodeThreadIsMain()) {
    if (shouldAnimate) {
      [self _locked_startAnimating];
    } else {
      [self _locked_stopAnimating];
    }
  } else {
    // We have to dispatch to the main thread and call the regular methods as the lock is already gone if the
    // block is called
    dispatch_async(dispatch_get_main_queue(), ^{
      if (shouldAnimate) {
        [self startAnimating];
      } else {
        [self stopAnimating];
      }
    });
  }
}

#pragma mark - Animating

- (void)startAnimating
{
  ASDisplayNodeAssertMainThread();

  ASLockScopeSelf();
  [self _locked_startAnimating];
}

- (void)_locked_startAnimating
{
  ASAssertLocked(__instanceLock__);
  
  // It should be safe to call self.interfaceState in this case as it will only grab the lock of the superclass
  if (!ASInterfaceStateIncludesVisible(self.interfaceState)) {
    return;
  }
  
  if (_animatedImagePaused) {
    return;
  }
  
  if (_animatedImage.playbackReady == NO) {
    return;
  }
  
#if ASAnimatedImageDebug
  NSLog(@"starting animation: %p", self);
#endif

  // Get frame interval before holding display link lock to avoid deadlock
  NSUInteger frameInterval = self.animatedImage.frameInterval;
  AS::MutexLocker l(_displayLinkLock);
  if (_displayLink == nil) {
    _playHead = 0;
    _displayLink = [CADisplayLink displayLinkWithTarget:[ASWeakProxy weakProxyWithTarget:self] selector:@selector(displayLinkFired:)];
    _displayLink.frameInterval = frameInterval;
    _lastSuccessfulFrameIndex = NSUIntegerMax;
    
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:_animatedImageRunLoopMode];
  } else {
    _displayLink.paused = NO;
  }
}

- (void)stopAnimating
{
  ASDisplayNodeAssertMainThread();
  
  ASLockScopeSelf();
  [self _locked_stopAnimating];
}

- (void)_locked_stopAnimating
{
  ASDisplayNodeAssertMainThread();
  ASAssertLocked(__instanceLock__);
  
#if ASAnimatedImageDebug
  NSLog(@"stopping animation: %p", self);
#endif
  ASDisplayNodeAssertMainThread();
  AS::MutexLocker l(_displayLinkLock);
  _displayLink.paused = YES;
  self.lastDisplayLinkFire = 0;
  
  [_animatedImage clearAnimatedImageCache];
}

#pragma mark - ASDisplayNode

- (void)didEnterVisibleState
{
  ASDisplayNodeAssertMainThread();
  [super didEnterVisibleState];
  
  if (self.animatedImage.coverImageReady) {
    [self setCoverImage:self.animatedImage.coverImage];
  }
  if (self.animatedImage.playbackReady) {
    [self startAnimating];
  }
}

- (void)didExitVisibleState
{
  ASDisplayNodeAssertMainThread();
  [super didExitVisibleState];
  
  [self stopAnimating];
}

- (void)didExitDisplayState
{
  ASDisplayNodeAssertMainThread();
#if ASAnimatedImageDebug
    NSLog(@"exiting display state: %p", self);
#endif
    
  // Check to see if we're an animated image before calling super in case someone
  // decides they want to clear out the animatedImage itself on exiting the display
  // state
  BOOL isAnimatedImage = self.animatedImage != nil;
  [super didExitDisplayState];
  
  // Also clear out the contents we've set to be good citizens, we'll put it back in when we become visible.
  if (isAnimatedImage) {
    self.contents = nil;
    [self setCoverImage:nil];
  }
}

#pragma mark - Display Link Callbacks

- (void)displayLinkFired:(CADisplayLink *)displayLink
{
  ASDisplayNodeAssertMainThread();

  CFTimeInterval timeBetweenLastFire;
  if (self.lastDisplayLinkFire == 0) {
    timeBetweenLastFire = 0;
  } else if (AS_AVAILABLE_IOS_TVOS(10, 10)) {
    timeBetweenLastFire = displayLink.targetTimestamp - displayLink.timestamp;
  } else {
    timeBetweenLastFire = CACurrentMediaTime() - self.lastDisplayLinkFire;
  }
  self.lastDisplayLinkFire = CACurrentMediaTime();
  
  _playHead += timeBetweenLastFire;
  
  while (_playHead > self.animatedImage.totalDuration) {
      // Set playhead to zero to keep from showing different frames on different playthroughs
    _playHead = 0;
    _playedLoops++;
  }
  
  if (self.animatedImage.loopCount > 0 && _playedLoops >= self.animatedImage.loopCount) {
    [self stopAnimating];
    return;
  }
  
  NSUInteger frameIndex = [self frameIndexAtPlayHeadPosition:_playHead];
  if (frameIndex == _lastSuccessfulFrameIndex) {
    return;
  }
  CGImageRef frameImage = [self.animatedImage imageAtIndex:frameIndex];
  
  if (frameImage == nil) {
    //Pause the display link until we get a file ready notification
    displayLink.paused = YES;
    self.lastDisplayLinkFire = 0;
  } else {
    self.contents = (__bridge id)frameImage;
    _lastSuccessfulFrameIndex = frameIndex;
    [self displayDidFinish];
  }
}

- (NSUInteger)frameIndexAtPlayHeadPosition:(CFTimeInterval)playHead
{
  ASDisplayNodeAssertMainThread();
  NSUInteger frameIndex = 0;
  for (NSUInteger durationIndex = 0; durationIndex < self.animatedImage.frameCount; durationIndex++) {
    playHead -= [self.animatedImage durationAtIndex:durationIndex];
    if (playHead < 0) {
      return frameIndex;
    }
    frameIndex++;
  }
  
  return frameIndex;
}

@end

#pragma mark - ASImageNode(AnimatedImageInvalidation)

@implementation ASImageNode(AnimatedImageInvalidation)

- (void)invalidateAnimatedImage
{
  AS::MutexLocker l(_displayLinkLock);
#if ASAnimatedImageDebug
  if (_displayLink) {
    NSLog(@"invalidating display link");
  }
#endif
  [_displayLink invalidate];
  _displayLink = nil;
}

@end

#endif
