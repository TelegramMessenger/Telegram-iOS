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
#import "BITHockeyHelper.h"

#import "BITFeedbackUserDataViewController.h"
#import "BITFeedbackManagerPrivate.h"

@interface BITFeedbackUserDataViewController () {
}

@property (nonatomic, weak) BITFeedbackManager *manager;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@end


@implementation BITFeedbackUserDataViewController


- (instancetype)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    _delegate = nil;
    
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    _name = @"";
    _email = @"";
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = BITHockeyLocalizedString(@"HockeyFeedbackUserDataTitle");
  
  [self.tableView setScrollEnabled:NO];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Do any additional setup after loading the view.
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(dismissAction:)];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                         target:self
                                                                                         action:@selector(saveAction:)];

  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager userName])
    self.name = [strongManager userName];

  if ([strongManager userEmail])
    self.email = [strongManager userEmail];
  
  [strongManager updateDidAskUserData];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - UIViewController Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
  return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager requireUserName] == BITFeedbackUserDataElementRequired && [self.name length] == 0)
    return NO;

  if ([strongManager requireUserEmail] == BITFeedbackUserDataElementRequired && [self.email length] == 0)
    return NO;

  if ([self.email length] > 0 && !bit_validateEmail(self.email))
    return NO;
  
  return YES;
}

- (void)userNameEntered:(id)sender {
  self.name = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)userEmailEntered:(id)sender {
  self.email = [(UITextField *)sender text];

  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)dismissAction:(id) __unused sender {
  [self.delegate userDataUpdateCancelled];
}

- (void)saveAction:(id) __unused sender {
  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager requireUserName]) {
    [strongManager setUserName:self.name];
  }
  
  if ([strongManager requireUserEmail]) {
    [strongManager setUserEmail:self.email];
  }
  
  [self.delegate userDataUpdateFinished];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *) __unused tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *) __unused tableView numberOfRowsInSection:(NSInteger) __unused section {
  NSInteger rows = 0;
  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager requireUserName] != BITFeedbackUserDataElementDontShow)
    rows ++;

  if ([strongManager requireUserEmail] != BITFeedbackUserDataElementDontShow)
    rows ++;

  return rows;
}

- (NSString *)tableView:(UITableView *) __unused tableView titleForFooterInSection:(NSInteger)section {
  if (section == 0) {
    return BITHockeyLocalizedString(@"HockeyFeedbackUserDataDescription");
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *) __unused tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"InputCell";
  BITFeedbackManager *strongManager = self.manager;
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor whiteColor];
    
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(110, 11, self.view.frame.size.width - 110 - 35, 24)];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
      textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    textField.adjustsFontSizeToFitWidth = YES;
    textField.textColor = [UIColor blackColor];
    textField.backgroundColor = [UIColor lightGrayColor];

    if ([indexPath row] == 0 && [strongManager requireUserName] != BITFeedbackUserDataElementDontShow) {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyFeedbackUserDataNamePlaceHolder");
      textField.text = self.name;
      if (strongManager.requireUserName == BITFeedbackUserDataElementRequired) {
        textField.accessibilityHint = BITHockeyLocalizedString(@"HockeyAccessibilityHintRequired");
      }
      
      textField.keyboardType = UIKeyboardTypeDefault;
      if ([strongManager requireUserEmail])
        textField.returnKeyType = UIReturnKeyNext;
      else
        textField.returnKeyType = UIReturnKeyDone;
      textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
      [textField addTarget:self action:@selector(userNameEntered:) forControlEvents:UIControlEventEditingChanged];
      [textField becomeFirstResponder];
    } else {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyFeedbackUserDataEmailPlaceholder");
      textField.text = self.email;
      if (strongManager.requireUserEmail == BITFeedbackUserDataElementRequired) {
        textField.accessibilityHint = BITHockeyLocalizedString(@"HockeyAccessibilityHintRequired");
      }
      
      textField.keyboardType = UIKeyboardTypeEmailAddress;
      textField.returnKeyType = UIReturnKeyDone;
      textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
      [textField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
      if (![strongManager requireUserName])
        [textField becomeFirstResponder];
    } 
    
    textField.backgroundColor = [UIColor whiteColor];
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.textAlignment = NSTextAlignmentLeft;
    textField.delegate = self;
    textField.tag = indexPath.row;
    
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [textField setEnabled: YES];
    
    [cell addSubview:textField];
  }
  
  if ([indexPath row] == 0 && [strongManager requireUserName] != BITFeedbackUserDataElementDontShow) {
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyFeedbackUserDataName");
  } else {
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyFeedbackUserDataEmail");
  }
  
  return cell;    
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  NSInteger nextTag = textField.tag + 1;
  
  UIResponder* nextResponder = [self.view viewWithTag:nextTag];
  if (nextResponder) {
    [nextResponder becomeFirstResponder];
  } else {
    if ([self allRequiredFieldsEntered]) {
      if ([textField isFirstResponder])
        [textField resignFirstResponder];
      
      [self saveAction:nil];
    }
  }
  return NO; 
}


@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
