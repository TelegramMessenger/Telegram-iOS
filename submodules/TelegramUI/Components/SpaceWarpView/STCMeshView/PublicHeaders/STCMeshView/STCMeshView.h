/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <STCMeshView/STCMeshLayer.h>

// shows different part of its subviews with different transforms
@interface STCMeshView : UIView

@property (nonatomic, retain, readonly) STCMeshLayer *layer;
@property (nonatomic, retain, readwrite) UIView *contentView; // only subviews added to this are transformed

@property (nonatomic, assign, readwrite) NSInteger instanceCount; // defaults to 1
@property (nonatomic, assign, readwrite) CATransform3D *instanceTransforms; // optional
@property (nonatomic, assign, readwrite) CGRect *instanceBounds; // optional
@property (nonatomic, assign, readwrite) CGPoint *instancePositions; // optional
@property (nonatomic, assign, readwrite) CGPoint *instanceAnchorPoints; // optional

@end
