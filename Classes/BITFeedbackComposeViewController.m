/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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


#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITFeedbackManagerPrivate.h"
#import "BITFeedbackComposeViewController.h"
#import "BITFeedbackUserDataViewController.h"

#import "BITHockeyHelper.h"


@interface BITFeedbackComposeViewController () <BITFeedbackUserDataDelegate> {
  BOOL blockUserDataScreen;
}

@property (nonatomic, assign) BITFeedbackManager *manager;
@property (nonatomic, retain) UITextView *textView;

- (void)setUserDataAction;

@end



@implementation BITFeedbackComposeViewController

- (id)init {
  self = [super init];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyFeedbackComposeTitle");
    blockUserDataScreen = NO;
    _delegate = nil;
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
  }
  return self;
}


- (id)initWithDelegate:(id<BITFeedbackComposeViewControllerDelegate>)delegate {
  self = [self init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.view.backgroundColor = [UIColor whiteColor];
  CGFloat yPos = 0;
  
  // when being used inside an activity, we don't have a navigation controller embedded
  if (!self.navigationController) {
    UINavigationBar *navigationBar = [[[UINavigationBar alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, 44)] autorelease];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:navigationBar];
    [navigationBar sizeToFit];
    yPos = navigationBar.frame.size.height;

    UIBarButtonItem *cancelItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                 target:self
                                                                                 action:@selector(dismissAction:)] autorelease];
    
    UIBarButtonItem *saveItem = [[[UIBarButtonItem alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeSend")
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(sendAction:)] autorelease];

    UINavigationItem *navigationItem = [[[UINavigationItem alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeTitle")] autorelease];
    navigationItem.leftBarButtonItem = cancelItem;
    navigationItem.rightBarButtonItem = saveItem;
    [navigationBar pushNavigationItem:navigationItem animated:NO];
  } else {
    // Do any additional setup after loading the view.
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                           target:self
                                                                                           action:@selector(dismissAction:)] autorelease];
    
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeSend")
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(sendAction:)] autorelease];
  }
  
  // message input textfield
  CGRect frame = CGRectZero;
  
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    frame = CGRectMake(0, yPos, self.view.bounds.size.width, 200-yPos);
  } else {
    frame = CGRectMake(0, yPos, self.view.bounds.size.width, self.view.bounds.size.height-yPos);
  }
  self.textView = [[[UITextView alloc] initWithFrame:frame] autorelease];
  self.textView.font = [UIFont systemFontOfSize:17];
  self.textView.delegate = self;
  self.textView.backgroundColor = [UIColor whiteColor];
  self.textView.returnKeyType = UIReturnKeyDefault;
  self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:self.textView];
}

- (void)viewWillAppear:(BOOL)animated {
  self.manager.currentFeedbackComposeViewController = self;
  
  [super viewWillAppear:animated];
  
  self.navigationItem.rightBarButtonItem.enabled = NO;

  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  
  if ([self.manager askManualUserDataAvailable] &&
      ([self.manager requireManualUserDataMissing] ||
       ![self.manager didAskUserData])
      ) {
    if (!blockUserDataScreen)
      [self setUserDataAction];
  } else {
    [self.textView becomeFirstResponder];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  self.manager.currentFeedbackComposeViewController = nil;
  
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}


#pragma mark - Private methods

- (void)dismiss {
  if (self.delegate && [self.delegate respondsToSelector:@selector(feedbackComposeViewControllerDidFinish:)]) {
    [self.delegate feedbackComposeViewControllerDidFinish:self];
  } else {
    [self dismissModalViewControllerAnimated:YES];
  }
}

- (void)setUserDataAction {
  BITFeedbackUserDataViewController *userController = [[[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
  userController.delegate = self;
  
  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:userController] autorelease];
  
  [self.navigationController presentModalViewController:navController animated:YES];
}

- (void)dismissAction:(id)sender {
  [self dismiss];
}

- (void)sendAction:(id)sender {
  if ([self.textView isFirstResponder])
    [self.textView resignFirstResponder];
  
  NSString *text = self.textView.text;
  
  [self.manager submitMessageWithText:text];
  
  [self dismiss];
}


#pragma mark - CNSFeedbackUserDataDelegate

- (void)userDataUpdateCancelled {
  blockUserDataScreen = YES;
  
  if ([self.manager requireManualUserDataMissing]) {
    if ([self.navigationController respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
      [self.navigationController dismissViewControllerAnimated:YES
                                                    completion:^(void) {
                                                      [self dismissModalViewControllerAnimated:YES];
                                                    }];
    } else {
      [self dismissModalViewControllerAnimated:YES];
      [self performSelector:@selector(dismissAction:) withObject:nil afterDelay:0.4];
    }
  } else {
    [self.navigationController dismissModalViewControllerAnimated:YES];
  }
}

- (void)userDataUpdateFinished {
  [self.manager saveMessages];
  
  [self.navigationController dismissModalViewControllerAnimated:YES];
}


#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
  NSUInteger newLength = [textView.text length];
  if (newLength == 0) {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  } else {
    self.navigationItem.rightBarButtonItem.enabled = YES;
  }
}


@end

