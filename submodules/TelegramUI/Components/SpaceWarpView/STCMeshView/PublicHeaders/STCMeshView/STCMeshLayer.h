/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <QuartzCore/QuartzCore.h>

/* A mesh layer allows individually transforming areas inside its subtree. */

@interface STCMeshLayer : CAReplicatorLayer

/* An array of bounds regions to use for each instance. The length
 * of this array is assumed to match `instanceCount'. Required. */

@property (atomic, assign) CGRect *instanceBounds;

/* An array of positions to use for each instance. The length
 * of this array is assumed to match `instanceCount'. Required. */

@property (atomic, assign) CGPoint *instancePositions;

/* An array of anchor points to use for each instance. The length
 * of this array is assumed to match `instanceCount'. Required. */

@property (atomic, assign) CGPoint *instanceAnchorPoints;

/* An array of transforms to apply to each instance. The length
 * of this array is assumed to match `instanceCount'. Required. */

@property (atomic, assign) CATransform3D *instanceTransforms;

/* Add content to this layer to transform it in the mesh. */

@property (atomic, strong) CALayer *contentLayer;

/* This CAReplicatorLayer property is used internally and is not
 * available for use by clients. Do not set it. */

@property (atomic, assign) CFTimeInterval instanceDelay NS_UNAVAILABLE;

/* This CAReplicatorLayer property is used internally and is not
 * available for use by clients. Do not set it. */

@property (atomic, assign) CATransform3D instanceTransform NS_UNAVAILABLE;

@end

@interface STCMeshLayer (UIViewSupport)

/* The wrapper replicator layer used to preserve a linear timespace. */

@property (atomic, strong) CAReplicatorLayer *wrapperLayer;

@end
