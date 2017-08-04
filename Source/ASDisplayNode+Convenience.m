//
//  ASDisplayNode+Convenience.m
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

#import "ASDisplayNode+Convenience.h"

#import <UIKit/UIViewController.h>

#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASResponderChainEnumerator.h>

@implementation ASDisplayNode (Convenience)

- (__kindof UIViewController *)closestViewController
{
  ASDisplayNodeAssertMainThread();
  
  // Careful not to trigger node loading here.
  if (!self.nodeLoaded) {
    return nil;
  }

  // Get the closest view.
  UIView *view = ASFindClosestViewOfLayer(self.layer);
  // Travel up the responder chain to find a view controller.
  for (UIResponder *responder in [view asdk_responderChainEnumerator]) {
    UIViewController *vc = ASDynamicCast(responder, UIViewController);
    if (vc != nil) {
      return vc;
    }
  }
  return nil;
}

@end
