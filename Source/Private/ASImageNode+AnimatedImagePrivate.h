//
//  ASImageNode+AnimatedImagePrivate.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASThread.h>

extern NSString *const ASAnimatedImageDefaultRunLoopMode;

@interface ASImageNode ()
{
  ASDN::Mutex _displayLinkLock;
  id <ASAnimatedImageProtocol> _animatedImage;
  BOOL _animatedImagePaused;
  NSString *_animatedImageRunLoopMode;
  CADisplayLink *_displayLink;
  NSUInteger _lastSuccessfulFrameIndex;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
}

@property (nonatomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

@interface ASImageNode (AnimatedImagePrivate)

- (void)_locked_setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage;

@end


@interface ASImageNode (AnimatedImageInvalidation)

- (void)invalidateAnimatedImage;

@end
