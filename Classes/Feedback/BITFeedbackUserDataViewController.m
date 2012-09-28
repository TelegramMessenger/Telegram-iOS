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

#import "BITFeedbackUserDataViewController.h"


@interface BITFeedbackUserDataViewController ()
@property (nonatomic, assign) BITFeedbackManager *manager;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@end


@implementation BITFeedbackUserDataViewController


- (id)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyFeedbackUserDataTitle");
    
    _delegate = nil;
    
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    _name = @"";
    _email = @"";
  }
  return self;
}

- (void)dealloc {
  [_name release], _name = nil;
  [_email release], _email = nil;
  
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self.tableView setScrollEnabled:NO];
   
	// Do any additional setup after loading the view.
  self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                         target:self
                                                                                         action:@selector(dismissAction:)] autorelease];
  
  self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                          target:self
                                                                                          action:@selector(saveAction:)] autorelease];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  if ([self.manager userName])
    self.name = [self.manager userName];

  if ([self.manager userEmail])
    self.email = [self.manager userEmail];
  
  [self.manager updateDidAskUserData];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Private methods

- (BOOL)allRequiredFieldsEntered {
  if ([self.manager requireUserName] == BITFeedbackUserDataElementRequired && [self.name length] == 0)
    return NO;

  if ([self.manager requireUserEmail] == BITFeedbackUserDataElementRequired && [self.email length] == 0)
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

- (void)dismissAction:(id)sender {
  [self.delegate userDataUpdateCancelled];
}

- (void)saveAction:(id)sender {
  
  if ([self.manager requireUserName]) {
    [self.manager setUserName:self.name];
  }
  
  if ([self.manager requireUserEmail]) {
    [self.manager setUserEmail:self.email];
  }
  
  [self.delegate userDataUpdateFinished];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSInteger rows = 0;
  
  if ([self.manager requireUserName] != BITFeedbackUserDataElementDontShow)
    rows ++;

  if ([self.manager requireUserEmail] != BITFeedbackUserDataElementDontShow)
    rows ++;

  return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  if (section == 0) {
    return BITHockeyLocalizedString(@"HockeyFeedbackUserDataDescription");
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"InputCell";
  
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor whiteColor];
    
    UITextField *textField = [[[UITextField alloc] initWithFrame:CGRectMake(110, 10, 185, 30)] autorelease];
    textField.adjustsFontSizeToFitWidth = YES;
    textField.textColor = [UIColor blackColor];
    textField.backgroundColor = [UIColor lightGrayColor];
    
    if ([indexPath row] == 0 && [self.manager requireUserName] != BITFeedbackUserDataElementDontShow) {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyFeedbackUserDataNamePlaceHolder");
      textField.text = self.name;
      
      textField.keyboardType = UIKeyboardTypeDefault;
      if ([self.manager requireUserEmail])
        textField.returnKeyType = UIReturnKeyNext;
      else
        textField.returnKeyType = UIReturnKeyDone;
      [textField addTarget:self action:@selector(userNameEntered:) forControlEvents:UIControlEventEditingChanged];
      [textField becomeFirstResponder];
    } else {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyFeedbackUserDataEmailPlaceholder");
      textField.text = self.email;
      
      textField.keyboardType = UIKeyboardTypeEmailAddress;
      textField.returnKeyType = UIReturnKeyDone;
      [textField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
      if (![self.manager requireUserName])
        [textField becomeFirstResponder];
    } 
    
    textField.backgroundColor = [UIColor whiteColor];
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.textAlignment = UITextAlignmentLeft;
    textField.delegate = self;
    textField.tag = indexPath.row;
    
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [textField setEnabled: YES];
    
    [cell addSubview:textField];
  }
  
  if ([indexPath row] == 0 && [self.manager requireUserName] != BITFeedbackUserDataElementDontShow) {
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
