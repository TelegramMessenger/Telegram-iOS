//
//  ASVideoPlayerNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#ifndef MINIMAL_ASDK
#if TARGET_OS_IOS

#import <AsyncDisplayKit/ASVideoPlayerNode.h>

#if AS_USE_VIDEO
#if TARGET_OS_IOS

#import <AVFoundation/AVFoundation.h>

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASDefaultPlaybackButton.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASThread.h>

static void *ASVideoPlayerNodeContext = &ASVideoPlayerNodeContext;

@interface ASVideoPlayerNode() <ASVideoNodeDelegate, ASVideoPlayerNodeDelegate>
{
  __weak id<ASVideoPlayerNodeDelegate> _delegate;

  struct {
    unsigned int delegateNeededDefaultControls:1;
    unsigned int delegateCustomControls:1;
    unsigned int delegateSpinnerTintColor:1;
    unsigned int delegateSpinnerStyle:1;
    unsigned int delegatePlaybackButtonTint:1;
    unsigned int delegateFullScreenButtonImage:1;
    unsigned int delegateScrubberMaximumTrackTintColor:1;
    unsigned int delegateScrubberMinimumTrackTintColor:1;
    unsigned int delegateScrubberThumbTintColor:1;
    unsigned int delegateScrubberThumbImage:1;
    unsigned int delegateTimeLabelAttributes:1;
    unsigned int delegateTimeLabelAttributedString:1;
    unsigned int delegateLayoutSpecForControls:1;
    unsigned int delegateVideoNodeDidPlayToTime:1;
    unsigned int delegateVideoNodeWillChangeState:1;
    unsigned int delegateVideoNodeShouldChangeState:1;
    unsigned int delegateVideoNodePlaybackDidFinish:1;
    unsigned int delegateDidTapVideoPlayerNode:1;
    unsigned int delegateDidTapFullScreenButtonNode:1;
    unsigned int delegateVideoPlayerNodeDidSetCurrentItem:1;
    unsigned int delegateVideoPlayerNodeDidStallAtTimeInterval:1;
    unsigned int delegateVideoPlayerNodeDidStartInitialLoading:1;
    unsigned int delegateVideoPlayerNodeDidFinishInitialLoading:1;
    unsigned int delegateVideoPlayerNodeDidRecoverFromStall:1;
  } _delegateFlags;
  
  // The asset passed in the initializer will be assigned as pending asset. As soon as the first
  // preload state happened all further asset handling is made by using the asset of the backing
  // video node
  AVAsset *_pendingAsset;
  
  // The backing video node. Ideally this is the source of truth and the video player node should
  // not handle anything related to asset management
  ASVideoNode *_videoNode;

  NSArray *_neededDefaultControls;

  NSMutableDictionary *_cachedControls;

  ASDefaultPlaybackButton *_playbackButtonNode;
  ASButtonNode *_fullScreenButtonNode;
  ASTextNode  *_elapsedTextNode;
  ASTextNode  *_durationTextNode;
  ASDisplayNode *_scrubberNode;
  ASStackLayoutSpec *_controlFlexGrowSpacerSpec;
  ASDisplayNode *_spinnerNode;

  BOOL _isSeeking;
  CMTime _duration;

  BOOL _controlsDisabled;

  BOOL _shouldAutoPlay;
  BOOL _shouldAutoRepeat;
  BOOL _muted;
  int32_t _periodicTimeObserverTimescale;
  NSString *_gravity;

  BOOL _shouldAggressivelyRecoverFromStall;

  UIColor *_defaultControlsColor;
}

@end

@implementation ASVideoPlayerNode

@dynamic placeholderImageURL;

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }

  [self _initControlsAndVideoNode];

  return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset
{
  if (!(self = [self init])) {
    return nil;
  }
  
  _pendingAsset = asset;
  
  return self;
}

- (instancetype)initWithURL:(NSURL *)URL
{
  return [self initWithAsset:[AVAsset assetWithURL:URL]];
}

- (instancetype)initWithAsset:(AVAsset *)asset videoComposition:(AVVideoComposition *)videoComposition audioMix:(AVAudioMix *)audioMix
{
  if (!(self = [self initWithAsset:asset])) {
    return nil;
  }
  
  _videoNode.videoComposition = videoComposition;
  _videoNode.audioMix = audioMix;

  return self;
}

- (void)_initControlsAndVideoNode
{
  _defaultControlsColor = [UIColor whiteColor];
  _cachedControls = [[NSMutableDictionary alloc] init];
  
  _videoNode = [[ASVideoNode alloc] init];
  _videoNode.delegate = self;
  [self addSubnode:_videoNode];
}

#pragma mark - Setter / Getter

- (void)setAssetURL:(NSURL *)assetURL
{
  ASDisplayNodeAssertMainThread();
  
  self.asset = [AVAsset assetWithURL:assetURL];
}

- (NSURL *)assetURL
{
  NSURL *url = nil;
  {
    ASLockScopeSelf();
    if ([_pendingAsset isKindOfClass:AVURLAsset.class]) {
      url = ((AVURLAsset *)_pendingAsset).URL;
    }
  }
  
  return url ?: _videoNode.assetURL;
}

- (void)setAsset:(AVAsset *)asset
{
  ASDisplayNodeAssertMainThread();

  [self lock];
  
  // Clean out pending asset
  _pendingAsset = nil;
  
  // Set asset based on interface state
  if ((ASInterfaceStateIncludesPreload(self.interfaceState))) {
    // Don't hold the lock while accessing the subnode
    [self unlock];
    _videoNode.asset = asset;
    return;
  }
  
  _pendingAsset = asset;
  [self unlock];
}

- (AVAsset *)asset
{
  return ASLockedSelf(_pendingAsset) ?: _videoNode.asset;
}

#pragma mark - ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  [self createControls];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  AVAsset *pendingAsset = nil;
  {
    ASLockScopeSelf();
    pendingAsset = _pendingAsset;
    _pendingAsset = nil;
  }

  // If we enter preload state we apply the pending asset to load to the video node so it can start and fetch the asset
  if (pendingAsset != nil && _videoNode.asset != pendingAsset) {
    _videoNode.asset = pendingAsset;
  }
}

- (BOOL)supportsLayerBacking
{
  return NO;
}

#pragma mark - UI

- (void)createControls
{
  {
    ASLockScopeSelf();

    if (_controlsDisabled) {
      return;
    }

    if (_neededDefaultControls == nil) {
      _neededDefaultControls = [self createDefaultControlElementArray];
    }

    if (_cachedControls == nil) {
      _cachedControls = [[NSMutableDictionary alloc] init];
    }

    for (id object in _neededDefaultControls) {
      ASVideoPlayerNodeControlType type = (ASVideoPlayerNodeControlType)[object integerValue];
      switch (type) {
        case ASVideoPlayerNodeControlTypePlaybackButton:
          [self _locked_createPlaybackButton];
          break;
        case ASVideoPlayerNodeControlTypeElapsedText:
          [self _locked_createElapsedTextField];
          break;
        case ASVideoPlayerNodeControlTypeDurationText:
          [self _locked_createDurationTextField];
          break;
        case ASVideoPlayerNodeControlTypeScrubber:
          [self _locked_createScrubber];
          break;
        case ASVideoPlayerNodeControlTypeFullScreenButton:
          [self _locked_createFullScreenButton];
          break;
        case ASVideoPlayerNodeControlTypeFlexGrowSpacer:
          [self _locked_createControlFlexGrowSpacer];
          break;
        default:
          break;
      }
    }

    if (_delegateFlags.delegateCustomControls && _delegateFlags.delegateLayoutSpecForControls) {
      NSDictionary *customControls = [_delegate videoPlayerNodeCustomControls:self];
      std::vector<ASDisplayNode *> subnodes;
      for (id key in customControls) {
        id node = customControls[key];
        if (![node isKindOfClass:[ASDisplayNode class]]) {
          continue;
        }

        subnodes.push_back(node);
        [_cachedControls setObject:node forKey:key];
      }
      
      {
        ASUnlockScope(self);
        for (ASDisplayNode *subnode : subnodes) {
          [self addSubnode:subnode];
        }
      }
    }
  }

  ASPerformBlockOnMainThread(^{
    [self setNeedsLayout];
  });
}

- (NSArray *)createDefaultControlElementArray
{
  if (_delegateFlags.delegateNeededDefaultControls) {
    return [_delegate videoPlayerNodeNeededDefaultControls:self];
  }

  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton),
            @(ASVideoPlayerNodeControlTypeElapsedText),
            @(ASVideoPlayerNodeControlTypeScrubber),
            @(ASVideoPlayerNodeControlTypeDurationText) ];
}

- (void)removeControls
{
  NSMutableDictionary *cachedControls = nil;
  {
    ASLockScope(self);
  
    // Grab the cached controls for removing it
    cachedControls = [_cachedControls copy];
    [self _locked_cleanCachedControls];
  }

  for (ASDisplayNode *node in [cachedControls objectEnumerator]) {
    [node removeFromSupernode];
  }
}

- (void)_locked_cleanCachedControls
{
  [_cachedControls removeAllObjects];

  _playbackButtonNode = nil;
  _fullScreenButtonNode = nil;
  _elapsedTextNode = nil;
  _durationTextNode = nil;
  _scrubberNode = nil;
}

- (void)_locked_createPlaybackButton
{
  ASAssertLocked(__instanceLock__);
  
  if (_playbackButtonNode == nil) {
    _playbackButtonNode = [[ASDefaultPlaybackButton alloc] init];
    _playbackButtonNode.style.preferredSize = CGSizeMake(16.0, 22.0);

    if (_delegateFlags.delegatePlaybackButtonTint) {
      _playbackButtonNode.tintColor = [_delegate videoPlayerNodePlaybackButtonTint:self];
    } else {
      _playbackButtonNode.tintColor = _defaultControlsColor;
    }

    if (_videoNode.playerState == ASVideoNodePlayerStatePlaying) {
      _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePause;
    }

    [_playbackButtonNode addTarget:self action:@selector(didTapPlaybackButton:) forControlEvents:ASControlNodeEventTouchUpInside];
    [_cachedControls setObject:_playbackButtonNode forKey:@(ASVideoPlayerNodeControlTypePlaybackButton)];
  }

  {
    ASUnlockScope(self);
    [self addSubnode:_playbackButtonNode];
  }
}

- (void)_locked_createFullScreenButton
{
  ASAssertLocked(__instanceLock__);
  
  if (_fullScreenButtonNode == nil) {
    _fullScreenButtonNode = [[ASButtonNode alloc] init];
    _fullScreenButtonNode.style.preferredSize = CGSizeMake(16.0, 22.0);
    
    if (_delegateFlags.delegateFullScreenButtonImage) {
      [_fullScreenButtonNode setImage:[_delegate videoPlayerNodeFullScreenButtonImage:self] forState:UIControlStateNormal];
    }

    [_fullScreenButtonNode addTarget:self action:@selector(didTapFullScreenButton:) forControlEvents:ASControlNodeEventTouchUpInside];
    [_cachedControls setObject:_fullScreenButtonNode forKey:@(ASVideoPlayerNodeControlTypeFullScreenButton)];
  }
  
  {
    ASUnlockScope(self);
    [self addSubnode:_fullScreenButtonNode];
  }
}

- (void)_locked_createElapsedTextField
{
  ASAssertLocked(__instanceLock__);
  
  if (_elapsedTextNode == nil) {
    _elapsedTextNode = [[ASTextNode alloc] init];
    _elapsedTextNode.attributedText = [self timeLabelAttributedStringForString:@"00:00"
                                                                  forControlType:ASVideoPlayerNodeControlTypeElapsedText];
    _elapsedTextNode.truncationMode = NSLineBreakByClipping;

    [_cachedControls setObject:_elapsedTextNode forKey:@(ASVideoPlayerNodeControlTypeElapsedText)];
  }
  {
    ASUnlockScope(self);
    [self addSubnode:_elapsedTextNode];
  }
}

- (void)_locked_createDurationTextField
{
  ASAssertLocked(__instanceLock__);
  
  if (_durationTextNode == nil) {
    _durationTextNode = [[ASTextNode alloc] init];
    _durationTextNode.attributedText = [self timeLabelAttributedStringForString:@"00:00"
                                                                   forControlType:ASVideoPlayerNodeControlTypeDurationText];
    _durationTextNode.truncationMode = NSLineBreakByClipping;

    [_cachedControls setObject:_durationTextNode forKey:@(ASVideoPlayerNodeControlTypeDurationText)];
  }
  [self updateDurationTimeLabel];
  {
    ASUnlockScope(self);
    [self addSubnode:_durationTextNode];
  }
}

- (void)_locked_createScrubber
{
  ASAssertLocked(__instanceLock__);
  
  if (_scrubberNode == nil) {
    __weak __typeof__(self) weakSelf = self;
    _scrubberNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull {
      __typeof__(self) strongSelf = weakSelf;
      
      UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
      slider.minimumValue = 0.0;
      slider.maximumValue = 1.0;

      if (_delegateFlags.delegateScrubberMinimumTrackTintColor) {
        slider.minimumTrackTintColor  = [strongSelf.delegate videoPlayerNodeScrubberMinimumTrackTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberMaximumTrackTintColor) {
        slider.maximumTrackTintColor  = [strongSelf.delegate videoPlayerNodeScrubberMaximumTrackTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberThumbTintColor) {
        slider.thumbTintColor  = [strongSelf.delegate videoPlayerNodeScrubberThumbTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberThumbImage) {
        UIImage *thumbImage = [strongSelf.delegate videoPlayerNodeScrubberThumbImage:strongSelf];
        [slider setThumbImage:thumbImage forState:UIControlStateNormal];
      }


      [slider addTarget:strongSelf action:@selector(beginSeek) forControlEvents:UIControlEventTouchDown];
      [slider addTarget:strongSelf action:@selector(endSeek) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
      [slider addTarget:strongSelf action:@selector(seekTimeDidChange:) forControlEvents:UIControlEventValueChanged];

      return slider;
    }];

    _scrubberNode.style.flexShrink = 1;

    [_cachedControls setObject:_scrubberNode forKey:@(ASVideoPlayerNodeControlTypeScrubber)];
  }
  {
    ASUnlockScope(self);
    [self addSubnode:_scrubberNode];
  }
}

- (void)_locked_createControlFlexGrowSpacer
{
  ASAssertLocked(__instanceLock__);
  
  if (_controlFlexGrowSpacerSpec == nil) {
    _controlFlexGrowSpacerSpec = [[ASStackLayoutSpec alloc] init];
    _controlFlexGrowSpacerSpec.style.flexGrow = 1.0;
  }

  [_cachedControls setObject:_controlFlexGrowSpacerSpec forKey:@(ASVideoPlayerNodeControlTypeFlexGrowSpacer)];
}

- (void)updateDurationTimeLabel
{
  if (!_durationTextNode) {
    return;
  }
  NSString *formattedDuration = [self timeStringForCMTime:_duration forTimeLabelType:ASVideoPlayerNodeControlTypeDurationText];
  _durationTextNode.attributedText = [self timeLabelAttributedStringForString:formattedDuration forControlType:ASVideoPlayerNodeControlTypeDurationText];
}

- (void)updateElapsedTimeLabel:(NSTimeInterval)seconds
{
  if (!_elapsedTextNode) {
    return;
  }
  NSString *formattedElapsed = [self timeStringForCMTime:CMTimeMakeWithSeconds( seconds, _videoNode.periodicTimeObserverTimescale ) forTimeLabelType:ASVideoPlayerNodeControlTypeElapsedText];
  _elapsedTextNode.attributedText = [self timeLabelAttributedStringForString:formattedElapsed forControlType:ASVideoPlayerNodeControlTypeElapsedText];
}

- (NSAttributedString*)timeLabelAttributedStringForString:(NSString*)string forControlType:(ASVideoPlayerNodeControlType)controlType
{
  NSDictionary *options;
  if (_delegateFlags.delegateTimeLabelAttributes) {
    options = [_delegate videoPlayerNodeTimeLabelAttributes:self timeLabelType:controlType];
  } else {
    options = @{
                NSFontAttributeName : [UIFont systemFontOfSize:12.0],
                NSForegroundColorAttributeName: _defaultControlsColor
                };
  }


  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:options];

  return attributedString;
}

#pragma mark - ASVideoNodeDelegate
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState
{
  if (_delegateFlags.delegateVideoNodeWillChangeState) {
    [_delegate videoPlayerNode:self willChangeVideoNodeState:state toVideoNodeState:toState];
  }

  if (toState == ASVideoNodePlayerStateReadyToPlay) {
    _duration = _videoNode.currentItem.duration;
    [self updateDurationTimeLabel];
  }

  if (toState == ASVideoNodePlayerStatePlaying) {
    _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePause;
    [self removeSpinner];
  } else if (toState != ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying && toState != ASVideoNodePlayerStateReadyToPlay) {
    _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePlay;
  }

  if (toState == ASVideoNodePlayerStateLoading || toState == ASVideoNodePlayerStateInitialLoading) {
    [self showSpinner];
  }

  if (toState == ASVideoNodePlayerStateReadyToPlay || toState == ASVideoNodePlayerStatePaused || toState == ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying) {
    [self removeSpinner];
  }
}

- (BOOL)videoNode:(ASVideoNode *)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state
{
  if (_delegateFlags.delegateVideoNodeShouldChangeState) {
    return [_delegate videoPlayerNode:self shouldChangeVideoNodeStateTo:state];
  }
  return YES;
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval
{
  if (_delegateFlags.delegateVideoNodeDidPlayToTime) {
    [_delegate videoPlayerNode:self didPlayToTime:_videoNode.player.currentTime];
  }

  if (_isSeeking) {
    return;
  }

  if (_elapsedTextNode) {
    [self updateElapsedTimeLabel:timeInterval];
  }

  if (_scrubberNode) {
    [(UISlider*)_scrubberNode.view setValue:( timeInterval / CMTimeGetSeconds(_duration) ) animated:NO];
  }
}

- (void)videoDidPlayToEnd:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoNodePlaybackDidFinish) {
    [_delegate videoPlayerNodeDidPlayToEnd:self];
  }
}

- (void)didTapVideoNode:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateDidTapVideoPlayerNode) {
    [_delegate didTapVideoPlayerNode:self];
  } else {
    [self togglePlayPause];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didSetCurrentItem:(AVPlayerItem *)currentItem
{
  if (_delegateFlags.delegateVideoPlayerNodeDidSetCurrentItem) {
    [_delegate videoPlayerNode:self didSetCurrentItem:currentItem];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didStallAtTimeInterval:(NSTimeInterval)timeInterval
{
  if (_delegateFlags.delegateVideoPlayerNodeDidStallAtTimeInterval) {
    [_delegate videoPlayerNode:self didStallAtTimeInterval:timeInterval];
  }
}

- (void)videoNodeDidStartInitialLoading:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidStartInitialLoading) {
    [_delegate videoPlayerNodeDidStartInitialLoading:self];
  }
}

- (void)videoNodeDidFinishInitialLoading:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidFinishInitialLoading) {
    [_delegate videoPlayerNodeDidFinishInitialLoading:self];
  }
}

- (void)videoNodeDidRecoverFromStall:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidRecoverFromStall) {
    [_delegate videoPlayerNodeDidRecoverFromStall:self];
  }
}

#pragma mark - Actions
- (void)togglePlayPause
{
  if (_videoNode.playerState == ASVideoNodePlayerStatePlaying) {
    [_videoNode pause];
  } else {
    [_videoNode play];
  }
}

- (void)showSpinner
{
  ASLockScopeSelf();

  if (!_spinnerNode) {
    __weak __typeof__(self) weakSelf = self;
    _spinnerNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      __typeof__(self) strongSelf = weakSelf;
      UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] init];
      spinnnerView.backgroundColor = [UIColor clearColor];

      if (_delegateFlags.delegateSpinnerTintColor) {
        spinnnerView.color = [_delegate videoPlayerNodeSpinnerTint:strongSelf];
      } else {
        spinnnerView.color = _defaultControlsColor;
      }
      
      if (_delegateFlags.delegateSpinnerStyle) {
        spinnnerView.activityIndicatorViewStyle = [_delegate videoPlayerNodeSpinnerStyle:strongSelf];
      }
      
      return spinnnerView;
    }];
    _spinnerNode.style.preferredSize = CGSizeMake(44.0, 44.0);
    
    const auto spinnerNode = _spinnerNode;
    {
      ASUnlockScope(self);
      [self addSubnode:spinnerNode];
      [self setNeedsLayout];
    }
  }
  [(UIActivityIndicatorView *)_spinnerNode.view startAnimating];
}

- (void)removeSpinner
{
  ASDisplayNode *spinnerNode = nil;
  {
    ASLockScopeSelf();
    if (!_spinnerNode) {
      return;
    }
    
    spinnerNode = _spinnerNode;
    _spinnerNode = nil;
  }

  [spinnerNode removeFromSupernode];
}

- (void)didTapPlaybackButton:(ASControlNode*)node
{
  [self togglePlayPause];
}

- (void)didTapFullScreenButton:(ASButtonNode*)node
{
  if (_delegateFlags.delegateDidTapFullScreenButtonNode) {
    [_delegate didTapFullScreenButtonNode:node];
  }
}

- (void)beginSeek
{
  _isSeeking = YES;
}

- (void)endSeek
{
  _isSeeking = NO;
}

- (void)seekTimeDidChange:(UISlider*)slider
{
  CGFloat percentage = slider.value * 100;
  [self seekToTime:percentage];
}

#pragma mark - Public API
- (void)seekToTime:(CGFloat)percentComplete
{
  CGFloat seconds = ( CMTimeGetSeconds(_duration) * percentComplete ) / 100;

  [self updateElapsedTimeLabel:seconds];
  [_videoNode.player seekToTime:CMTimeMakeWithSeconds(seconds, _videoNode.periodicTimeObserverTimescale)];

  if (_videoNode.playerState != ASVideoNodePlayerStatePlaying) {
    [self togglePlayPause];
  }
}

- (void)play
{
  [_videoNode play];
}

- (void)pause
{
  [_videoNode pause];
}

- (BOOL)isPlaying
{
  return [_videoNode isPlaying];
}

- (void)resetToPlaceholder
{
  [_videoNode resetToPlaceholder];
}

- (NSArray *)controlsForLayoutSpec
{
  NSMutableArray *controls = [[NSMutableArray alloc] initWithCapacity:_cachedControls.count];

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]];
  }
  
  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeFullScreenButton) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeFullScreenButton) ]];
  }

  return controls;
}


#pragma mark - Layout

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGSize maxSize = constrainedSize.max;

  // Prevent crashes through if infinite width or height
  if (isinf(maxSize.width) || isinf(maxSize.height)) {
    ASDisplayNodeAssert(NO, @"Infinite width or height in ASVideoPlayerNode");
    maxSize = CGSizeZero;
  }

  _videoNode.style.preferredSize = maxSize;

  ASLayoutSpec *layoutSpec;
  if (_delegateFlags.delegateLayoutSpecForControls) {
    layoutSpec = [_delegate videoPlayerNodeLayoutSpec:self forControls:_cachedControls forMaximumSize:maxSize];
  } else {
    layoutSpec = [self defaultLayoutSpecThatFits:maxSize];
  }

  NSMutableArray *children = [[NSMutableArray alloc] init];

  if (_spinnerNode) {
    ASCenterLayoutSpec *centerLayoutSpec = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:_spinnerNode];
    centerLayoutSpec.style.preferredSize = maxSize;
    [children addObject:centerLayoutSpec];
  }

  ASOverlayLayoutSpec *overlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_videoNode overlay:layoutSpec];
  overlaySpec.style.preferredSize = maxSize;
  [children addObject:overlaySpec];

  return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:children];
}

- (ASLayoutSpec *)defaultLayoutSpecThatFits:(CGSize)maxSize
{
  _scrubberNode.style.preferredSize = CGSizeMake(maxSize.width, 44.0);

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.style.flexGrow = 1.0;

  ASStackLayoutSpec *controlbarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                            spacing:10.0
                                                                     justifyContent:ASStackLayoutJustifyContentStart
                                                                         alignItems:ASStackLayoutAlignItemsCenter
                                                                           children: [self controlsForLayoutSpec] ];
  controlbarSpec.style.alignSelf = ASStackLayoutAlignSelfStretch;

  UIEdgeInsets insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

  ASInsetLayoutSpec *controlbarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlbarSpec];

  controlbarInsetSpec.style.alignSelf = ASStackLayoutAlignSelfStretch;

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:0.0
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStart
                                                                                children:@[spacer,controlbarInsetSpec]];

  return mainVerticalStack;
}

#pragma mark - Properties
- (id<ASVideoPlayerNodeDelegate>)delegate
{
  return _delegate;
}

- (void)setDelegate:(id<ASVideoPlayerNodeDelegate>)delegate
{
  if (delegate == _delegate) {
    return;
  }

  _delegate = delegate;
  
  if (_delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.delegateNeededDefaultControls = [_delegate respondsToSelector:@selector(videoPlayerNodeNeededDefaultControls:)];
    _delegateFlags.delegateCustomControls = [_delegate respondsToSelector:@selector(videoPlayerNodeCustomControls:)];
    _delegateFlags.delegateSpinnerTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeSpinnerTint:)];
    _delegateFlags.delegateSpinnerStyle = [_delegate respondsToSelector:@selector(videoPlayerNodeSpinnerStyle:)];
    _delegateFlags.delegateScrubberMaximumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMaximumTrackTint:)];
    _delegateFlags.delegateScrubberMinimumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMinimumTrackTint:)];
    _delegateFlags.delegateScrubberThumbTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbTint:)];
    _delegateFlags.delegateScrubberThumbImage = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbImage:)];
    _delegateFlags.delegateTimeLabelAttributes = [_delegate respondsToSelector:@selector(videoPlayerNodeTimeLabelAttributes:timeLabelType:)];
    _delegateFlags.delegateLayoutSpecForControls = [_delegate respondsToSelector:@selector(videoPlayerNodeLayoutSpec:forControls:forMaximumSize:)];
    _delegateFlags.delegateVideoNodeDidPlayToTime = [_delegate respondsToSelector:@selector(videoPlayerNode:didPlayToTime:)];
    _delegateFlags.delegateVideoNodeWillChangeState = [_delegate respondsToSelector:@selector(videoPlayerNode:willChangeVideoNodeState:toVideoNodeState:)];
    _delegateFlags.delegateVideoNodePlaybackDidFinish = [_delegate respondsToSelector:@selector(videoPlayerNodeDidPlayToEnd:)];
    _delegateFlags.delegateVideoNodeShouldChangeState = [_delegate respondsToSelector:@selector(videoPlayerNode:shouldChangeVideoNodeStateTo:)];
    _delegateFlags.delegateTimeLabelAttributedString = [_delegate respondsToSelector:@selector(videoPlayerNode:timeStringForTimeLabelType:forTime:)];
    _delegateFlags.delegatePlaybackButtonTint = [_delegate respondsToSelector:@selector(videoPlayerNodePlaybackButtonTint:)];
    _delegateFlags.delegateFullScreenButtonImage = [_delegate respondsToSelector:@selector(videoPlayerNodeFullScreenButtonImage:)];
    _delegateFlags.delegateDidTapVideoPlayerNode = [_delegate respondsToSelector:@selector(didTapVideoPlayerNode:)];
    _delegateFlags.delegateDidTapFullScreenButtonNode = [_delegate respondsToSelector:@selector(didTapFullScreenButtonNode:)];
    _delegateFlags.delegateVideoPlayerNodeDidSetCurrentItem = [_delegate respondsToSelector:@selector(videoPlayerNode:didSetCurrentItem:)];
    _delegateFlags.delegateVideoPlayerNodeDidStallAtTimeInterval = [_delegate respondsToSelector:@selector(videoPlayerNode:didStallAtTimeInterval:)];
    _delegateFlags.delegateVideoPlayerNodeDidStartInitialLoading = [_delegate respondsToSelector:@selector(videoPlayerNodeDidStartInitialLoading:)];
    _delegateFlags.delegateVideoPlayerNodeDidFinishInitialLoading = [_delegate respondsToSelector:@selector(videoPlayerNodeDidFinishInitialLoading:)];
    _delegateFlags.delegateVideoPlayerNodeDidRecoverFromStall = [_delegate respondsToSelector:@selector(videoPlayerNodeDidRecoverFromStall:)];
  }
}

- (void)setControlsDisabled:(BOOL)controlsDisabled
{
  if (_controlsDisabled == controlsDisabled) {
    return;
  }
  
  _controlsDisabled = controlsDisabled;

  if (_controlsDisabled && _cachedControls.count > 0) {
    [self removeControls];
  } else if (!_controlsDisabled) {
    [self createControls];
  }
}

- (void)setShouldAutoPlay:(BOOL)shouldAutoPlay
{
  if (_shouldAutoPlay == shouldAutoPlay) {
    return;
  }
  _shouldAutoPlay = shouldAutoPlay;
  _videoNode.shouldAutoplay = _shouldAutoPlay;
}

- (void)setShouldAutoRepeat:(BOOL)shouldAutoRepeat
{
  if (_shouldAutoRepeat == shouldAutoRepeat) {
    return;
  }
  _shouldAutoRepeat = shouldAutoRepeat;
  _videoNode.shouldAutorepeat = _shouldAutoRepeat;
}

- (void)setMuted:(BOOL)muted
{
  if (_muted == muted) {
    return;
  }
  _muted = muted;
  _videoNode.muted = _muted;
}

- (void)setPeriodicTimeObserverTimescale:(int32_t)periodicTimeObserverTimescale
{
  if (_periodicTimeObserverTimescale == periodicTimeObserverTimescale) {
    return;
  }
  _periodicTimeObserverTimescale = periodicTimeObserverTimescale;
  _videoNode.periodicTimeObserverTimescale = _periodicTimeObserverTimescale;
}

- (NSString *)gravity
{
  if (_gravity == nil) {
    _gravity = _videoNode.gravity;
  }
  return _gravity;
}

- (void)setGravity:(NSString *)gravity
{
  if (_gravity == gravity) {
    return;
  }
  _gravity = gravity;
  _videoNode.gravity = _gravity;
}

- (ASVideoNodePlayerState)playerState
{
  return _videoNode.playerState;
}

- (BOOL)shouldAggressivelyRecoverFromStall
{
  return _videoNode.shouldAggressivelyRecoverFromStall;
}

- (void) setPlaceholderImageURL:(NSURL *)placeholderImageURL
{
  _videoNode.URL = placeholderImageURL;
}

- (NSURL*) placeholderImageURL
{
  return _videoNode.URL;
}

- (ASVideoNode*)videoNode
{
  return _videoNode;
}

- (void)setShouldAggressivelyRecoverFromStall:(BOOL)shouldAggressivelyRecoverFromStall
{
  if (_shouldAggressivelyRecoverFromStall == shouldAggressivelyRecoverFromStall) {
    return;
  }
  _shouldAggressivelyRecoverFromStall = shouldAggressivelyRecoverFromStall;
  _videoNode.shouldAggressivelyRecoverFromStall = _shouldAggressivelyRecoverFromStall;
}

#pragma mark - Helpers
- (NSString *)timeStringForCMTime:(CMTime)time forTimeLabelType:(ASVideoPlayerNodeControlType)type
{
  if (!CMTIME_IS_VALID(time)) {
    return @"00:00";
  }
  if (_delegateFlags.delegateTimeLabelAttributedString) {
    return [_delegate videoPlayerNode:self timeStringForTimeLabelType:type forTime:time];
  }

  NSUInteger dTotalSeconds = CMTimeGetSeconds(time);

  NSUInteger dHours = floor(dTotalSeconds / 3600);
  NSUInteger dMinutes = floor(dTotalSeconds % 3600 / 60);
  NSUInteger dSeconds = floor(dTotalSeconds % 3600 % 60);

  NSString *videoDurationText;
  if (dHours > 0) {
    videoDurationText = [NSString stringWithFormat:@"%i:%02i:%02i", (int)dHours, (int)dMinutes, (int)dSeconds];
  } else {
    videoDurationText = [NSString stringWithFormat:@"%02i:%02i", (int)dMinutes, (int)dSeconds];
  }
  return videoDurationText;
}

@end

#endif // TARGET_OS_IOS
#endif

#endif
