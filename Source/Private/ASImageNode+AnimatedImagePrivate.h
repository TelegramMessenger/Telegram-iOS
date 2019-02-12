//
//  ASImageNode+AnimatedImagePrivate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASThread.h>

#define ASAnimatedImageDefaultRunLoopMode NSRunLoopCommonModes

@interface ASImageNode ()
{
#ifndef MINIMAL_ASDK
  ASDN::Mutex _displayLinkLock;
  id <ASAnimatedImageProtocol> _animatedImage;
  BOOL _animatedImagePaused;
  NSString *_animatedImageRunLoopMode;
  CADisplayLink *_displayLink;
  NSUInteger _lastSuccessfulFrameIndex;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
#endif
}

@property (nonatomic) CFTimeInterval lastDisplayLinkFire;

@end

#ifndef MINIMAL_ASDK
@interface ASImageNode (AnimatedImagePrivate)

- (void)_locked_setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage;

@end

@interface ASImageNode (AnimatedImageInvalidation)

- (void)invalidateAnimatedImage;

@end

#endif
