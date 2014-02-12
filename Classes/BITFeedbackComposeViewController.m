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


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "HockeySDKPrivate.h"

#import "BITFeedbackManagerPrivate.h"
#import "BITFeedbackComposeViewController.h"
#import "BITFeedbackUserDataViewController.h"

#import "BITHockeyBaseManagerPrivate.h"

#import "BITHockeyHelper.h"


@interface BITFeedbackComposeViewController () <BITFeedbackUserDataDelegate, UIImagePickerControllerDelegate> {
  UIStatusBarStyle _statusBarStyle;
}

@property (nonatomic, weak) BITFeedbackManager *manager;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIView *contentViewContainer;
@property (nonatomic, strong) UIScrollView *photoScrollView;
@property (nonatomic, strong) NSMutableArray *photoScrollViewImageViews;

@property (nonatomic, strong) NSString *text;

@property (nonatomic, strong) NSMutableArray *photos;

@property (nonatomic, strong) UIView *textAccessoryView;

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
    _photos = [NSMutableArray new];
    _photoScrollViewImageViews = [NSMutableArray new];

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
  [self.contentViewContainer setFrame:frame];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
  CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
  [self.contentViewContainer setFrame:frame];
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
  
  // Container that contains both the textfield and eventually the photo scroll view on the right side
  self.contentViewContainer = [[UIView alloc] initWithFrame:self.view.bounds];
  [self.view addSubview:self.contentViewContainer];
  

  
  // message input textfield
  self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
  self.textView.font = [UIFont systemFontOfSize:17];
  self.textView.delegate = self;
  self.textView.backgroundColor = [UIColor whiteColor];
  self.textView.returnKeyType = UIReturnKeyDefault;
  self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  
  [self.contentViewContainer addSubview:self.textView];
  
  // Add Photo Button + Container that's displayed above the keyboard.
  self.textAccessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 44)];
  self.textAccessoryView.backgroundColor = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f];
  UIButton *addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [addPhotoButton setTitle:@"+ Add Photo" forState:UIControlStateNormal];
  addPhotoButton.frame = CGRectMake(0, 0, 100, 44);
  
  [addPhotoButton addTarget:self action:@selector(addPhotoAction:) forControlEvents:UIControlEventTouchUpInside];
  
  [self.textAccessoryView addSubview:addPhotoButton];
  
  self.textView.inputAccessoryView = self.textAccessoryView;
  
  self.photoScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
  self.photoScrollView.scrollEnabled = YES;
  self.photoScrollView.bounces = YES;
  self.photoScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

  
  [self.contentViewContainer addSubview:self.photoScrollView];
  
  
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
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent];
#else
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
#endif
  
 // [self.textView setFrame:self.view.frame];

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
    // Invoke delayed to fix iOS 7 iPad landscape bug, where this view will be moved if not called delayed
    [self.textView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.0];
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

-(void)refreshPhotoScrollview {
  CGFloat scrollViewWidth = 0;
  
  if (self.photos.count){
    scrollViewWidth = 100;
  }
  
  CGRect textViewFrame = self.textView.frame;
  
  CGRect scrollViewFrame = self.photoScrollView.frame;
  
  BOOL alreadySetup = CGRectGetWidth(scrollViewFrame) == scrollViewWidth;
  
  if (!alreadySetup){
    textViewFrame.size.width -= scrollViewWidth;
    
    // status bar?

    scrollViewFrame = CGRectMake(CGRectGetMaxX(textViewFrame), self.view.frame.origin.y, scrollViewWidth, CGRectGetHeight(textViewFrame));
    self.textView.frame = textViewFrame;
    self.photoScrollView.frame = scrollViewFrame;
    self.photoScrollView.contentInset = self.textView.contentInset;
  }
  
  for (UIView *subview in self.photoScrollView.subviews){
    [subview removeFromSuperview];
  }
  
  if (self.photos.count > self.photoScrollViewImageViews.count){
    NSInteger numberOfViewsToCreate = self.photos.count - self.photoScrollViewImageViews.count;
    for (int i = 0;i<numberOfViewsToCreate;i++){
      UIImageView *newImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
      [self.photoScrollViewImageViews addObject:newImageView];
    }
  }
    
  int index = 0;
  
  CGFloat currentYOffset = 0.0f;
  
  for (UIImage* photo in self.photos){
    UIImageView *imageView = self.photoScrollViewImageViews[index];
    
    // determine the factor by which we scale..
    CGFloat scaleFactor = CGRectGetWidth(self.photoScrollView.frame) / photo.size.width;
    
    CGFloat height = photo.size.height * scaleFactor;
    
    imageView.frame = CGRectInset(CGRectMake(0, currentYOffset, scaleFactor * photo.size.width, height),10,10);
    
    currentYOffset += height;
    
    [self.photoScrollView addSubview:imageView];
    
    imageView.image = photo;
    index++;
  }
  
  [self.photoScrollView setContentSize:CGSizeMake(CGRectGetWidth(self.photoScrollView.frame), currentYOffset)];
  
  
}


#pragma mark - UIViewController Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}


#pragma mark - Private methods

- (void)setUserDataAction {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:userController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - Actions

- (void)dismissAction:(id)sender {
  [self dismissWithResult:BITFeedbackComposeResultCancelled];
}

- (void)sendAction:(id)sender {
  if ([self.textView isFirstResponder])
    [self.textView resignFirstResponder];
  
  NSString *text = self.textView.text;
  
  [self.manager submitMessageWithText:text];
  
  [self dismissWithResult:BITFeedbackComposeResultSubmitted];
}

- (void)dismissWithResult:(BITFeedbackComposeResult) result {
  if(self.delegate && [self.delegate respondsToSelector:@selector(feedbackComposeViewController:didFinishWithResult:)]) {
    [self.delegate feedbackComposeViewController:self didFinishWithResult:result];
  } else if (self.delegate && [self.delegate respondsToSelector:@selector(feedbackComposeViewControllerDidFinish:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    [self.delegate feedbackComposeViewControllerDidFinish:self];
#pragma clang diagnostic pop
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

-(void)addPhotoAction:(id)sender {
  // add photo.
  UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
  pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  pickerController.delegate = self;
  pickerController.editing = NO;
  [self presentModalViewController:pickerController animated:YES];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
  UIImage *pickedImage = info[UIImagePickerControllerOriginalImage];
  
  if (pickedImage){
    [self.photos addObject:pickedImage];
  }
  
  [picker dismissModalViewControllerAnimated:YES];
  [self refreshPhotoScrollview];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  
}

#pragma mark - BITFeedbackUserDataDelegate

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

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
