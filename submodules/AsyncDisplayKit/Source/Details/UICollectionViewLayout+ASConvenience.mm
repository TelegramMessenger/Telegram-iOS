//
//  UICollectionViewLayout+ASConvenience.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/UICollectionViewLayout+ASConvenience.h>

#import <UIKit/UICollectionViewFlowLayout.h>

#import <AsyncDisplayKit/ASCollectionViewFlowLayoutInspector.h>

@implementation UICollectionViewLayout (ASLayoutInspectorProviding)

- (id<ASCollectionViewLayoutInspecting>)asdk_layoutInspector
{
  UICollectionViewFlowLayout *flow = ASDynamicCast(self, UICollectionViewFlowLayout);
  if (flow != nil) {
    return [[ASCollectionViewFlowLayoutInspector alloc] initWithFlowLayout:flow];
  } else {
    return [[ASCollectionViewLayoutInspector alloc] init];
  }
}

@end

#endif
