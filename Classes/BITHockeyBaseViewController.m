/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BITHockeyBaseViewController.h"
#import "HockeySDKPrivate.h"


@implementation BITHockeyBaseViewController {
  BOOL _modal;
  UIStatusBarStyle _statusBarStyle;
}


- (instancetype)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    _modalAnimated = YES;
    _modal = NO;
  }
  return self;
}

- (instancetype)initWithStyle:(UITableViewStyle)style modal:(BOOL)modal {
  self = [self initWithStyle:style];
  if (self) {
    _modal = modal;
    
    //might be better in viewDidLoad, but to workaround rdar://12214613 and as it doesn't
    //hurt, we do it here
    if (_modal) {
      self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                            target:self
                                                                                            action:@selector(onDismissModal:)];
    }
  }
  return self;
}

- (instancetype)initWithModalStyle:(BOOL)modal {
  self = [self initWithStyle:UITableViewStylePlain modal:modal];
  return self;
}


#pragma mark - View lifecycle

- (void)onDismissModal:(id)sender {
  if (_modal) {
    UIViewController *presentingViewController = [self presentingViewController];
    
    // If there is no presenting view controller just remove view
    if (presentingViewController && self.modalAnimated) {
      [presentingViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
      [self.navigationController.view removeFromSuperview];
    }
  } else {
    [self.navigationController popViewControllerAnimated:YES];
  }
  
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}


- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  _statusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
  if ([self.navigationController.navigationBar.tintColor isEqual:BIT_RGBCOLOR(25, 25, 25)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
    [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent];
#else
    [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
#endif
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  if ([self.navigationController.navigationBar.tintColor isEqual:BIT_RGBCOLOR(25, 25, 25)]) {
    [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
  }
}


#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  BOOL shouldAutorotate;
  
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    shouldAutorotate = (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
                        interfaceOrientation == UIInterfaceOrientationLandscapeRight ||
                        interfaceOrientation == UIInterfaceOrientationPortrait);
  } else {
    shouldAutorotate = YES;
  }
  
  return shouldAutorotate;
}


#pragma mark - Modal presentation


@end
