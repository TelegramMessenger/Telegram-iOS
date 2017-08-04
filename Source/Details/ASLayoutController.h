//
//  ASLayoutController.h
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

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionElement, ASElementMap;

ASDISPLAYNODE_EXTERN_C_BEGIN

struct ASDirectionalScreenfulBuffer {
  CGFloat positiveDirection; // Positive relative to iOS Core Animation layer coordinate space.
  CGFloat negativeDirection;
};
typedef struct ASDirectionalScreenfulBuffer ASDirectionalScreenfulBuffer;

ASDISPLAYNODE_EXTERN_C_END

@protocol ASLayoutController <NSObject>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (NSHashTable<ASCollectionElement *> *)elementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType map:(ASElementMap *)map;

- (void)allElementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSHashTable<ASCollectionElement *> * _Nullable * _Nullable)displaySet preloadSet:(NSHashTable<ASCollectionElement *> * _Nullable * _Nullable)preloadSet map:(ASElementMap *)map;

@optional

@end

NS_ASSUME_NONNULL_END
