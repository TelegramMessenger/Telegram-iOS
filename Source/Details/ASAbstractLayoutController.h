//
//  ASAbstractLayoutController.h
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

#import <AsyncDisplayKit/ASLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

FOUNDATION_EXPORT ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferHorizontal(ASScrollDirection scrollDirection, ASRangeTuningParameters rangeTuningParameters);

FOUNDATION_EXPORT ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferVertical(ASScrollDirection scrollDirection, ASRangeTuningParameters rangeTuningParameters);

FOUNDATION_EXPORT CGRect CGRectExpandToRangeWithScrollableDirections(CGRect rect, ASRangeTuningParameters tuningParameters, ASScrollDirection scrollableDirections, ASScrollDirection scrollDirection);

ASDISPLAYNODE_EXTERN_C_END

@interface ASAbstractLayoutController : NSObject <ASLayoutController>

@end

@interface ASAbstractLayoutController (Unavailable)

- (NSHashTable *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType __unavailable;

- (void)allIndexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSHashTable * _Nullable * _Nullable)displaySet preloadSet:(NSHashTable * _Nullable * _Nullable)preloadSet __unavailable;

@end

NS_ASSUME_NONNULL_END
