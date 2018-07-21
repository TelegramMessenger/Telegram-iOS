//
//  ASHighlightOverlayLayer.h
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

#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASHighlightOverlayLayer : CALayer

/**
 @summary Initializes with CGRects for the highlighting, in the targetLayer's coordinate space.

 @desc This is the designated initializer.

 @param rects Array containing CGRects wrapped in NSValue.
 @param targetLayer The layer that the rects are relative to.  The rects will be translated to the receiver's coordinate space when rendering.
 */
- (instancetype)initWithRects:(NSArray<NSValue *> *)rects targetLayer:(nullable CALayer *)targetLayer;

/**
 @summary Initializes with CGRects for the highlighting, in the receiver's coordinate space.

 @param rects Array containing CGRects wrapped in NSValue.
 */
- (instancetype)initWithRects:(NSArray<NSValue *> *)rects;

@property (nullable, nonatomic) __attribute__((NSObject)) CGColorRef highlightColor;
@property (nonatomic, weak) CALayer *targetLayer;

@end

@interface CALayer (ASHighlightOverlayLayerSupport)

/**
 @summary Set to YES to indicate to a sublayer that this is where highlight overlay layers (for pressed states) should
 be added so that the highlight won't be clipped by a neighboring layer.
 */
@property (nonatomic, setter=as_setAllowsHighlightDrawing:) BOOL as_allowsHighlightDrawing;

@end

NS_ASSUME_NONNULL_END
