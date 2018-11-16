//
//  ASTabBarController.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASTabBarController.h>
#import <AsyncDisplayKit/ASLog.h>

@implementation ASTabBarController
{
  BOOL _parentManagesVisibilityDepth;
  NSInteger _visibilityDepth;
}

ASVisibilityDidMoveToParentViewController;

ASVisibilityViewWillAppear;

ASVisibilityViewDidDisappearImplementation;

ASVisibilitySetVisibilityDepth;

ASVisibilityDepthImplementation;

- (void)visibilityDepthDidChange
{
  for (UIViewController *viewController in self.viewControllers) {
    if ([viewController conformsToProtocol:@protocol(ASVisibilityDepth)]) {
      [(id <ASVisibilityDepth>)viewController visibilityDepthDidChange];
    }
  }
}

- (NSInteger)visibilityDepthOfChildViewController:(UIViewController *)childViewController
{
  NSUInteger viewControllerIndex = [self.viewControllers indexOfObjectIdenticalTo:childViewController];
  if (viewControllerIndex == NSNotFound) {
    //If childViewController is not actually a child, return NSNotFound which is also a really large number.
    return NSNotFound;
  }
  
  if (self.selectedViewController == childViewController) {
    return [self visibilityDepth];
  }
  return [self visibilityDepth] + 1;
}

#pragma mark - UIKit overrides

- (void)setViewControllers:(NSArray<__kindof UIViewController *> *)viewControllers
{
  [super setViewControllers:viewControllers];
  [self visibilityDepthDidChange];
}

- (void)setViewControllers:(NSArray<__kindof UIViewController *> *)viewControllers animated:(BOOL)animated
{
  [super setViewControllers:viewControllers animated:animated];
  [self visibilityDepthDidChange];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
  as_activity_create_for_scope("Set selected index of ASTabBarController");
  as_log_info(ASNodeLog(), "Selected tab %tu of %@", selectedIndex, self);

  [super setSelectedIndex:selectedIndex];
  [self visibilityDepthDidChange];
}

- (void)setSelectedViewController:(__kindof UIViewController *)selectedViewController
{
  as_activity_create_for_scope("Set selected view controller of ASTabBarController");
  as_log_info(ASNodeLog(), "Selected view controller %@ of %@", selectedViewController, self);

  [super setSelectedViewController:selectedViewController];
  [self visibilityDepthDidChange];
}

@end

#endif
