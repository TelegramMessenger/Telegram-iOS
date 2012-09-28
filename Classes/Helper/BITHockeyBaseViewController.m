//
//  CNSHockeyBaseViewController.m
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BITHockeyBaseViewController.h"

@interface BITHockeyBaseViewController ()
@property (nonatomic) BOOL modal;
@property (nonatomic) UIStatusBarStyle statusBarStyle;
@end

@implementation BITHockeyBaseViewController

@synthesize modalAnimated = _modalAnimated;
@synthesize modal = _modal;
@synthesize statusBarStyle = _statusBarStyle;


- (id)init {
  self = [super init];
  if (self) {
    _modalAnimated = YES;
    _modal = NO;
  }
  return self;
}

- (id)initWithModalStyle:(BOOL)modal {
  self = [self init];
  if (self) {
    _modal = modal;
  }
  return self;
}


#pragma mark - View lifecycle

- (void)onDismissModal:(id)sender {
  if (self.modal) {
    // Note that as of 5.0, parentViewController will no longer return the presenting view controller
    SEL presentingViewControllerSelector = NSSelectorFromString(@"presentingViewController");
    UIViewController *presentingViewController = nil;
    if ([self respondsToSelector:presentingViewControllerSelector]) {
      presentingViewController = [self performSelector:presentingViewControllerSelector];
    } else {
      presentingViewController = [self parentViewController];
    }
    
    // If there is no presenting view controller just remove view
    if (presentingViewController && self.modalAnimated) {
      [presentingViewController dismissModalViewControllerAnimated:YES];
    } else {
      [self.navigationController.view removeFromSuperview];
    }
  } else {
    [self.navigationController popViewControllerAnimated:YES];
  }
  
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  if (self.modal) {
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(onDismissModal:)] autorelease];
  }

	// Do any additional setup after loading the view.
}

- (void)viewDidUnload {
  [super viewDidUnload];
  // Release any retained subviews of the main view.
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  _statusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
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
