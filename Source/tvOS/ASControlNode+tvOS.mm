//
//  ASControlNode+tvOS.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#if TARGET_OS_TV
#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASControlNode+Private.h>

@implementation ASControlNode (tvOS)

#pragma mark - tvOS
- (void)_pressDown
{
  [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
    [self setPressedState];
  } completion:^(BOOL finished) {
    if (finished) {
      [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        [self setFocusedState];
      } completion:nil];
    }
  }];
}

- (BOOL)canBecomeFocused
{
  return YES;
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
  return YES;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  //FIXME: This is never valid inside an ASCellNode
  if (context.nextFocusedView && context.nextFocusedView == self.view) {
    //Focused
    [coordinator addCoordinatedAnimations:^{
      [self setFocusedState];
    } completion:nil];
  } else{
    //Not focused
    [coordinator addCoordinatedAnimations:^{
      [self setDefaultFocusAppearance];
    } completion:nil];
  }
}

- (void)setFocusedState
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeMake(2, 10);
  [self applyDefaultShadowProperties: layer];
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1, 1.1);
}

- (void)setPressedState
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeMake(2, 2);
  [self applyDefaultShadowProperties: layer];
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
}

- (void)applyDefaultShadowProperties:(CALayer *)layer
{
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 12.0;
  layer.shadowOpacity = 0.45;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
}

- (void)setDefaultFocusAppearance
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeZero;
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 0;
  layer.shadowOpacity = 0;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
}
@end
#endif
