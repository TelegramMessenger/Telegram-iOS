/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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
  UIStatusBarStyle _statusBarStyle;
}

@property (nonatomic, weak) BITFeedbackManager *manager;
@property (nonatomic, strong) UITextView *textView;

@property (nonatomic, strong) NSString *text;

@end


@implementation BITFeedbackComposeViewController {
  BOOL _blockUserDataScreen;  
}


#pragma mark - NSObject

- (id)init {
  self = [super init];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyFeedbackComposeTitle");
    _blockUserDataScreen = NO;
    _delegate = nil;
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;

    _text = nil;
  }
  
  return self;
}


#pragma mark - Public

- (void)prepareWithItems:(NSArray *)items {
  for (id item in items) {
    if ([item isKindOfClass:[NSString class]]) {
      self.text = [(self.text ? self.text : @"") stringByAppendingFormat:@"%@%@", (self.text ? @" " : @""), item];
    } else if ([item isKindOfClass:[NSURL class]]) {
      self.text = [(self.text ? self.text : @"") stringByAppendingFormat:@"%@%@", (self.text ? @" " : @""), [(NSURL *)item absoluteString]];
    } else {
      BITHockeyLog(@"Unknown item type %@", item);
    }
  }
}


#pragma mark - Keyboard

- (void)keyboardWasShown:(NSNotification*)aNotification {
  NSDictionary* info = [aNotification userInfo];
  CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
  
  CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
      frame.size.height -= kbSize.height;
    else
      frame.size.height -= kbSize.width;
  } else {
    CGSize windowSize = [[UIScreen mainScreen] bounds].size;
    CGFloat windowHeight = windowSize.height - 20;
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
      CGFloat modalGap = (windowHeight - self.view.bounds.size.height) / 2;
      frame.size.height = windowHeight - navBarHeight - modalGap - kbSize.height;
    } else {
      windowHeight = windowSize.width - 20;
      CGFloat modalGap = 0.0f;
      if (windowHeight - kbSize.width < self.view.bounds.size.height) {
        modalGap = 30;
      } else {
        modalGap = (windowHeight - self.view.bounds.size.height) / 2;
      }
      frame.size.height = windowSize.width - navBarHeight - modalGap - kbSize.width;
    }
  }
  [self.textView setFrame:frame];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
  CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
  [self.textView setFrame:frame];
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.view.backgroundColor = [UIColor whiteColor];
  
  // Do any additional setup after loading the view.
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                         target:self
                                                                                         action:@selector(dismissAction:)];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeSend")
                                                                             style:UIBarButtonItemStyleDone
                                                                            target:self
                                                                            action:@selector(sendAction:)];

  // message input textfield
  self.textView = [[UITextView alloc] initWithFrame:self.view.frame];
  self.textView.font = [UIFont systemFontOfSize:17];
  self.textView.delegate = self;
  self.textView.backgroundColor = [UIColor whiteColor];
  self.textView.returnKeyType = UIReturnKeyDefault;
  self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:self.textView];
}

- (void)viewWillAppear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWasShown:)
                                               name:UIKeyboardDidShowNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWillBeHidden:)
                                               name:UIKeyboardWillHideNotification object:nil];

  self.manager.currentFeedbackComposeViewController = self;
  
  [super viewWillAppear:animated];
  
  _statusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
  
  [self.textView setFrame:self.view.frame];

  if (_text) {
    self.textView.text = _text;
    self.navigationItem.rightBarButtonItem.enabled = YES;
  } else {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  
  if ([self.manager askManualUserDataAvailable] &&
      ([self.manager requireManualUserDataMissing] ||
       ![self.manager didAskUserData])
      ) {
    if (!_blockUserDataScreen)
      [self setUserDataAction];
  } else {
    [self.textView becomeFirstResponder];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
  
  self.manager.currentFeedbackComposeViewController = nil;
  
	[super viewWillDisappear:animated];

  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}


#pragma mark - UIViewController Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}


#pragma mark - Private methods

- (void)dismiss {
  if (self.delegate && [self.delegate respondsToSelector:@selector(feedbackComposeViewControllerDidFinish:)]) {
    [self.delegate feedbackComposeViewControllerDidFinish:self];
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)setUserDataAction {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:userController];
  navController.navigationBar.barStyle = [self.manager barStyle];
  navController.navigationBar.tintColor = [self.manager tintColor];
  navController.modalPresentationStyle = UIModalPresentationFormSheet;
  
  [self presentViewController:navController animated:YES completion:nil];
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
  _blockUserDataScreen = YES;
  
  if ([self.manager requireManualUserDataMissing]) {
    if ([self.navigationController respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
      [self.navigationController dismissViewControllerAnimated:YES
                                                    completion:^(void) {
                                                      [self dismissViewControllerAnimated:YES completion:nil];
                                                    }];
    } else {
      [self dismissViewControllerAnimated:YES completion:nil];
      [self performSelector:@selector(dismissAction:) withObject:nil afterDelay:0.4];
    }
  } else {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)userDataUpdateFinished {
  [self.manager saveMessages];
  
  [self.navigationController dismissViewControllerAnimated:YES completion:nil];
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

