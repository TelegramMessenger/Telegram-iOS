//
//  UIResponder+AsyncDisplayKit.m
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

#import "UIResponder+AsyncDisplayKit.h"

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASResponderChainEnumerator.h>

@implementation UIResponder (AsyncDisplayKit)

- (__kindof UIViewController *)asdk_associatedViewController
{
  ASDisplayNodeAssertMainThread();
  
  for (UIResponder *responder in [self asdk_responderChainEnumerator]) {
    UIViewController *vc = ASDynamicCast(responder, UIViewController);
    if (vc) {
      return vc;
    }
  }
  return nil;
}

@end

