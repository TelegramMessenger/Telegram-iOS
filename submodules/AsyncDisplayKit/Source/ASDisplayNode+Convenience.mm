//
//  ASDisplayNode+Convenience.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode+Convenience.h>

#import <UIKit/UIViewController.h>

#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import "ASResponderChainEnumerator.h"

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
