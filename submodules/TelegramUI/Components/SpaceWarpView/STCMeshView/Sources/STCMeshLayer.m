/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <STCMeshView/STCMeshLayer.h>

static const CFTimeInterval STCMeshLayerTotalInstanceDelay = 10000000.0;
static NSString *const STCMeshLayerBoundsAnimationKey = @"STCMeshLayerBoundsAnimation";
static NSString *const STCMeshLayerTransformAnimationKey = @"STCMeshLayerTransformAnimation";
static NSString *const STCMeshLayerPositionAnimationKey = @"STCMeshLayerPositionAnimation";
static NSString *const STCMeshLayerAnchorPointAnimationKey = @"STCMeshLayerAnchorPointAnimation";
static NSString *const STCMeshLayerInstanceDelayAnimationKey = @"STCMeshLayerInstanceDelayAnimation";

@implementation STCMeshLayer {
    CAReplicatorLayer *_wrapperLayer;
    CALayer *_contentLayer;

    CGRect *_instanceBounds;
    CATransform3D *_instanceTransforms;
    CGPoint *_instancePositions;
    CGPoint *_instanceAnchorPoints;
}

#pragma mark - Lifecycle

- (instancetype)init
{
    if ((self = [super init])) {
        self.wrapperLayer = [[CAReplicatorLayer alloc] init];
        self.contentLayer = [[CALayer alloc] init];
    }

    return self;
}

- (void)dealloc
{
    free(_instanceTransforms);
    _instanceTransforms = NULL;
    free(_instanceBounds);
    _instanceBounds = NULL;
}

- (void)layoutSublayers
{
    [super layoutSublayers];

    _wrapperLayer.frame = self.bounds;
    _contentLayer.frame = _wrapperLayer.bounds;
    [self _updateMeshAnimations];
}

#pragma mark - Properties

@dynamic instanceDelay;

@dynamic instanceTransform;

- (void)setInstanceCount:(NSInteger)instanceCount
{
    if (instanceCount != self.instanceCount) {
        [super setInstanceCount:instanceCount];

        free(_instanceTransforms);
        _instanceTransforms = NULL;
        free(_instanceBounds);
        _instanceBounds = NULL;

        [self setNeedsLayout];
    }
}

- (CATransform3D *)instanceTransforms
{
    CATransform3D *instanceTransforms = _instanceTransforms;

    return instanceTransforms;
}

- (void)setInstanceTransforms:(CATransform3D *)instanceTransforms
{
    free(_instanceTransforms);
    _instanceTransforms = NULL;

    if (instanceTransforms != NULL) {
        _instanceTransforms = calloc(sizeof(CATransform3D), self.instanceCount);
        memcpy(_instanceTransforms, instanceTransforms, self.instanceCount * sizeof(CATransform3D));
    }

    [self setNeedsLayout];
}

- (CGPoint *)instancePositions
{
  CGPoint *instancePositions = _instancePositions;

  return instancePositions;
}

- (void)setInstancePositions:(CGPoint *)instancePositions
{
  free(_instancePositions);
  _instancePositions = NULL;

  if (instancePositions != NULL) {
    _instancePositions = calloc(sizeof(CGPoint), self.instanceCount);
    memcpy(_instancePositions, instancePositions, self.instanceCount * sizeof(CGPoint));
  }

  [self setNeedsLayout];
}

- (CGPoint *)instanceAnchorPoints
{
  CGPoint *instanceAnchorPoints = _instanceAnchorPoints;

  return instanceAnchorPoints;
}

- (void)setInstanceAnchorPoints:(CGPoint *)instanceAnchorPoints
{
  free(_instanceAnchorPoints);
  _instanceAnchorPoints = NULL;

  if (instanceAnchorPoints != NULL) {
    _instanceAnchorPoints = calloc(sizeof(CGPoint), self.instanceCount);
    memcpy(_instanceAnchorPoints, instanceAnchorPoints, self.instanceCount * sizeof(CGPoint));
  }

  [self setNeedsLayout];
}

- (CGRect *)instanceBounds
{
    CGRect *instanceBounds = _instanceBounds;

    return instanceBounds;
}

- (void)setInstanceBounds:(CGRect *)instanceBounds
{
    free(_instanceBounds);
    _instanceBounds = NULL;

    if (instanceBounds != NULL) {
        _instanceBounds = calloc(sizeof(CGRect), self.instanceCount);
        memcpy(_instanceBounds, instanceBounds, self.instanceCount * sizeof(CGRect));
    }

    [self setNeedsLayout];
}

- (CALayer *)contentLayer
{
    CALayer *contentLayer = _contentLayer;

    return contentLayer;
}

- (void)setContentLayer:(CALayer *)contentLayer
{
    if (contentLayer != _contentLayer) {
        if (_contentLayer != nil) {
            [_contentLayer removeFromSuperlayer];
        }

        _contentLayer = contentLayer;

        if (_contentLayer != nil) {
            [_wrapperLayer addSublayer:_contentLayer];
        }
    }
}

- (CAReplicatorLayer *)wrapperLayer
{
    CAReplicatorLayer *wrapperLayer = _wrapperLayer;

    return wrapperLayer;
}

- (void)setWrapperLayer:(CAReplicatorLayer *)wrapperLayer
{
    if (wrapperLayer != _wrapperLayer) {
        if (_contentLayer != nil) {
            [_contentLayer removeFromSuperlayer];
        }

        if (_wrapperLayer != nil) {
            [_wrapperLayer removeFromSuperlayer];
        }

        _wrapperLayer = wrapperLayer;

        if (_wrapperLayer != nil) {
            _wrapperLayer.masksToBounds = YES;
            _wrapperLayer.instanceCount = 2;
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGColorRef hiddenColor = CGColorCreate(colorSpace, (CGFloat []){ 1.0, 1.0, 1.0, 0.0 });
            _wrapperLayer.instanceColor = hiddenColor;
            CGColorRelease(hiddenColor);
            CGColorSpaceRelease(colorSpace);
            _wrapperLayer.instanceAlphaOffset = 1.0;
            [self addSublayer:_wrapperLayer];
        }

        if (_contentLayer != nil) {
            [_wrapperLayer addSublayer:_contentLayer];
        }

        [self setNeedsLayout];
    }
}

#pragma mark - Internal Methods

- (CGRect)_boundsAtIndex:(NSUInteger)index
{
    CGRect bounds = CGRectZero;

    if (_instanceBounds != NULL) {
        bounds = _instanceBounds[index];
    }

    return bounds;
}

- (CATransform3D)_transformAtIndex:(NSUInteger)index
{
    CATransform3D transform = CATransform3DIdentity;

    if (_instanceTransforms != NULL) {
        transform = _instanceTransforms[index];
    }

    return transform;
}

- (CGPoint)_positionAtIndex:(NSUInteger)index
{
  CGPoint position = CGPointZero;

  if (_instancePositions != NULL) {
    position = _instancePositions[index];
  }

  return position;
}

- (CGPoint)_anchorPointAtIndex:(NSUInteger)index
{
  CGPoint anchorPoint = CGPointMake(0.0, 0.0);

  if (_instanceAnchorPoints != NULL) {
    anchorPoint = _instanceAnchorPoints[index];
  }

  return anchorPoint;
}

- (void)_updateMeshAnimations
{
    [_wrapperLayer removeAllAnimations];

    super.instanceDelay = -STCMeshLayerTotalInstanceDelay / self.instanceCount;

    CAKeyframeAnimation *boundsAnimation = [CAKeyframeAnimation animationWithKeyPath:@"bounds"];
    boundsAnimation.calculationMode = kCAAnimationDiscrete;
    boundsAnimation.duration = STCMeshLayerTotalInstanceDelay;
    boundsAnimation.removedOnCompletion = NO;
    NSMutableArray *boundsValues = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.instanceCount; i++) {
        CGRect bounds = [self _boundsAtIndex:i];
        NSValue *boundsValue = [NSValue valueWithBytes:&bounds objCType:@encode(CGRect)];
        [boundsValues addObject:boundsValue];
    }
    boundsAnimation.values = boundsValues;
    [_wrapperLayer addAnimation:boundsAnimation forKey:STCMeshLayerBoundsAnimationKey];

    CAKeyframeAnimation *transformAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    transformAnimation.calculationMode = kCAAnimationDiscrete;
    transformAnimation.duration = STCMeshLayerTotalInstanceDelay;
    transformAnimation.removedOnCompletion = NO;
    NSMutableArray *transformValues = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.instanceCount; i++) {
        CATransform3D transform = [self _transformAtIndex:i];
        NSValue *transformValue = [NSValue valueWithCATransform3D:transform];
        [transformValues addObject:transformValue];
    }
    transformAnimation.values = transformValues;
    [_wrapperLayer addAnimation:transformAnimation forKey:STCMeshLayerTransformAnimationKey];

    CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    positionAnimation.calculationMode = kCAAnimationDiscrete;
    positionAnimation.duration = STCMeshLayerTotalInstanceDelay;
    positionAnimation.removedOnCompletion = NO;
    NSMutableArray *positionValues = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.instanceCount; i++) {
      CGPoint position = [self _positionAtIndex:i];
      NSValue *positionValue = [NSValue valueWithBytes:&position objCType:@encode(CGPoint)];
      [positionValues addObject:positionValue];
    }
    positionAnimation.values = positionValues;
    [_wrapperLayer addAnimation:positionAnimation forKey:STCMeshLayerPositionAnimationKey];

    CAKeyframeAnimation *anchorPointAnimation = [CAKeyframeAnimation animationWithKeyPath:@"anchorPoint"];
    anchorPointAnimation.calculationMode = kCAAnimationDiscrete;
    anchorPointAnimation.duration = STCMeshLayerTotalInstanceDelay;
    anchorPointAnimation.removedOnCompletion = NO;
    NSMutableArray *anchorPointValues = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.instanceCount; i++) {
      CGPoint anchorPoint = [self _anchorPointAtIndex:i];
      NSValue *anchorPointValue = [NSValue valueWithBytes:&anchorPoint objCType:@encode(CGPoint)];
      [anchorPointValues addObject:anchorPointValue];
    }
    anchorPointAnimation.values = anchorPointValues;
    [_wrapperLayer addAnimation:anchorPointAnimation forKey:STCMeshLayerAnchorPointAnimationKey];

    CAKeyframeAnimation *timeAnimation = [CAKeyframeAnimation animationWithKeyPath:@"instanceDelay"];
    timeAnimation.calculationMode = kCAAnimationDiscrete;
    timeAnimation.duration = STCMeshLayerTotalInstanceDelay;
    timeAnimation.removedOnCompletion = NO;
    NSMutableArray *timeValues = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.instanceCount; i++) {
        CFTimeInterval delay = -super.instanceDelay * i;
        [timeValues addObject:@(delay)];
    }
    timeAnimation.values = timeValues;
    [_wrapperLayer addAnimation:timeAnimation forKey:STCMeshLayerInstanceDelayAnimationKey];
}

@end
