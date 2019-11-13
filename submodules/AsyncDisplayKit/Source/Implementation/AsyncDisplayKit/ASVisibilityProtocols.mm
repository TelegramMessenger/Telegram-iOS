//
//  ASVisibilityProtocols.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASVisibilityProtocols.h>

ASLayoutRangeMode ASLayoutRangeModeForVisibilityDepth(NSUInteger visibilityDepth)
{
  if (visibilityDepth == 0) {
    return ASLayoutRangeModeFull;
  } else if (visibilityDepth == 1) {
    return ASLayoutRangeModeMinimum;
  } else if (visibilityDepth == 2) {
    return ASLayoutRangeModeVisibleOnly;
  }
  return ASLayoutRangeModeLowMemory;
}
