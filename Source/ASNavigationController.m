//
//  ASNavigationController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//
#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASNavigationController.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@implementation ASNavigationController
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
  
  if (viewControllerIndex == self.viewControllers.count - 1) {
    //view controller is at the top, just return our own visibility depth.
    return [self visibilityDepth];
  } else if (viewControllerIndex == 0) {
    //view controller is the root view controller. Can be accessed by holding the back button.
    return [self visibilityDepth] + 1;
  }
  
  return [self visibilityDepth] + self.viewControllers.count - 1 - viewControllerIndex;
}

#pragma mark - UIKit overrides

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  as_activity_create_for_scope("Pop multiple from ASNavigationController");
  NSArray *viewControllers = [super popToViewController:viewController animated:animated];
  as_log_info(ASNodeLog(), "Popped %@ to %@, removing %@", self, viewController, ASGetDescriptionValueString(viewControllers));

  [self visibilityDepthDidChange];
  return viewControllers;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
  as_activity_create_for_scope("Pop to root of ASNavigationController");
  NSArray *viewControllers = [super popToRootViewControllerAnimated:animated];
  as_log_info(ASNodeLog(), "Popped view controllers %@ from %@", ASGetDescriptionValueString(viewControllers), self);

  [self visibilityDepthDidChange];
  return viewControllers;
}

- (void)setViewControllers:(NSArray *)viewControllers
{
  // NOTE: As of now this method calls through to setViewControllers:animated: so no need to log/activity here.
  
  [super setViewControllers:viewControllers];
  [self visibilityDepthDidChange];
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
  as_activity_create_for_scope("Set view controllers of ASNavigationController");
  as_log_info(ASNodeLog(), "Set view controllers of %@ to %@ animated: %d", self, ASGetDescriptionValueString(viewControllers), animated);
  [super setViewControllers:viewControllers animated:animated];
  [self visibilityDepthDidChange];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  as_activity_create_for_scope("Push view controller on ASNavigationController");
  as_log_info(ASNodeLog(), "Pushing %@ onto %@", viewController, self);
  [super pushViewController:viewController animated:animated];
  [self visibilityDepthDidChange];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
  as_activity_create_for_scope("Pop view controller from ASNavigationController");
  UIViewController *viewController = [super popViewControllerAnimated:animated];
  as_log_info(ASNodeLog(), "Popped %@ from %@", viewController, self);
  [self visibilityDepthDidChange];
  return viewController;
}

@end

#endif
