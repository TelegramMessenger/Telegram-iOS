/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <STCMeshView/STCMeshView.h>
#import <STCMeshView/STCMeshLayer.h>

@interface _STCMeshViewReplicatorView : UIView

@property (nonatomic, readonly, retain) CAReplicatorLayer  *layer;

@end

@implementation _STCMeshViewReplicatorView

- (CAReplicatorLayer *)layer
{
    return (CAReplicatorLayer *)[super layer];
}

+ (Class)layerClass
{
    return [CAReplicatorLayer class];
}

@end

@implementation STCMeshView {
    _STCMeshViewReplicatorView *_wrapperView;
}

- (STCMeshLayer *)layer
{
    return (STCMeshLayer *)[super layer];
}

+ (Class)layerClass
{
    return [STCMeshLayer class];
}

- (NSInteger)instanceCount
{
    return self.layer.instanceCount;
}

- (void)setInstanceCount:(NSInteger)instanceCount
{
    self.layer.instanceCount = instanceCount;
}

- (CATransform3D *)instanceTransforms
{
    return self.layer.instanceTransforms;
}

- (void)setInstanceTransforms:(CATransform3D *)instanceTransforms
{
    self.layer.instanceTransforms = instanceTransforms;
}

- (CGRect *)instanceBounds
{
    return self.layer.instanceBounds;
}

- (void)setInstanceBounds:(CGRect *)instanceBounds
{
    self.layer.instanceBounds = instanceBounds;
}

- (CGPoint *)instancePositions
{
    return self.layer.instancePositions;
}

- (void)setInstancePositions:(CGPoint *)instancePositions
{
    self.layer.instancePositions = instancePositions;
}

- (CGPoint *)instanceAnchorPoints
{
  return self.layer.instanceAnchorPoints;
}

- (void)setInstanceAnchorPoints:(CGPoint *)instanceAnchorPoints
{
  self.layer.instanceAnchorPoints = instanceAnchorPoints;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _wrapperView = [[_STCMeshViewReplicatorView alloc] init];
        [self addSubview:_wrapperView];
        self.layer.wrapperLayer = _wrapperView.layer;

        self.contentView = [[UIView alloc] init];
    }

    return self;
}

- (void)setContentView:(UIView *)contentView
{
    if (contentView != _contentView) {
        if (_contentView != nil) {
            [_contentView removeFromSuperview];
        }

        if (contentView != nil) {
            [_wrapperView addSubview:contentView];
        }

        _contentView = contentView;
        self.layer.contentLayer = _contentView.layer;
    }
}

@end
