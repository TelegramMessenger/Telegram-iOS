/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
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

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "BITAuthenticationViewController.h"
#import "BITAuthenticator_Private.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"
#import <tgmath.h>

@interface BITAuthenticationViewController ()<UITextFieldDelegate>

@property (nonatomic, weak) UITextField *emailField;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>)delegate {
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerTitle");
    _delegate = delegate;
  }
  return self;
}

#pragma mark - view lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.tableView setScrollEnabled:NO];
  
  [self updateWebLoginButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [self updateBarButtons];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - Property overrides

- (void) updateBarButtons {
  if(self.showsLoginViaWebButton) {
    self.navigationItem.rightBarButtonItem = nil;
  } else {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(saveAction:)];
  }
}

- (void)setShowsLoginViaWebButton:(BOOL)showsLoginViaWebButton {
  if(_showsLoginViaWebButton != showsLoginViaWebButton) {
    _showsLoginViaWebButton = showsLoginViaWebButton;
    if(self.isViewLoaded) {
      [self.tableView reloadData];
      [self updateBarButtons];
      [self updateWebLoginButton];
    }
  }
}

- (void) updateWebLoginButton {
  if(self.showsLoginViaWebButton) {
    static const CGFloat kFooterHeight = 60.0;
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                                     CGRectGetWidth(self.tableView.bounds),
                                                                     kFooterHeight)];
    UIButton *button = [UIButton buttonWithType:kBITButtonTypeSystem];
    [button setTitle:BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerWebLoginButtonTitle") forState:UIControlStateNormal];
    CGSize buttonSize = [button sizeThatFits:CGSizeMake(CGRectGetWidth(self.tableView.bounds),
                                                        kFooterHeight)];
    button.frame = CGRectMake(floor((CGRectGetWidth(containerView.bounds) - buttonSize.width) / (CGFloat)2.0),
                              floor((kFooterHeight - buttonSize.height) / (CGFloat)2.0),
                              buttonSize.width,
                              buttonSize.height);
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    if ([UIButton instancesRespondToSelector:(NSSelectorFromString(@"setTintColor:"))]) {
      [button setTitleColor:BIT_RGBCOLOR(0, 122, 255) forState:UIControlStateNormal];
    }
    [containerView addSubview:button];
    [button addTarget:self
               action:@selector(handleWebLoginButton:)
     forControlEvents:UIControlEventTouchUpInside];
    self.tableView.tableFooterView = containerView;
  } else {
    self.tableView.tableFooterView = nil;
  }
}

- (IBAction) handleWebLoginButton:(id) __unused sender {
  [self.delegate authenticationViewControllerDidTapWebButton:self];
}

- (void)setEmail:(NSString *)email {
  _email = email;
  if(self.isViewLoaded) {
    self.emailField.text = email;
  }
}

- (void)setTableViewTitle:(NSString *)viewDescription {
  _tableViewTitle = [viewDescription copy];
  if(self.isViewLoaded) {
    [self.tableView reloadData];
  }
}
#pragma mark - UIViewController Rotation

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskAll;
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if (![self.email length] || !bit_validateEmail(self.email))
    return NO;
  
  return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *) __unused tableView {
  return 2;
}

- (NSInteger)tableView:(UITableView *) __unused tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) return 0;
  
  if(self.showsLoginViaWebButton) {
    return 0;
  } else {
    NSInteger rows = 1;
    
    if ([self requirePassword]) rows ++;
    
    return rows;
  }
}

- (NSString *)tableView:(UITableView *) __unused tableView titleForFooterInSection:(NSInteger)section {
  if (section == 0) {
    return self.tableViewTitle;
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *) __unused tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"InputCell";
  
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor whiteColor];
    
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(130, 11, self.view.frame.size.width - 130 - 25, 24)];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
      textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    textField.adjustsFontSizeToFitWidth = YES;
    textField.textColor = [UIColor blackColor];
    textField.backgroundColor = [UIColor lightGrayColor];
    
    if (0 == [indexPath row]) {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailPlaceholder");
      textField.accessibilityHint = BITHockeyLocalizedString(@"HockeyAccessibilityHintRequired");
      textField.text = self.email;
      self.emailField = textField;
      
      textField.keyboardType = UIKeyboardTypeEmailAddress;
      if ([self requirePassword])
        textField.returnKeyType = UIReturnKeyNext;
      else
        textField.returnKeyType = UIReturnKeyDone;
      
      [textField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
      [textField becomeFirstResponder];
    } else {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPasswordPlaceholder");
      textField.text = self.password;
      
      textField.keyboardType = UIKeyboardTypeDefault;
      textField.returnKeyType = UIReturnKeyDone;
      textField.secureTextEntry = YES;
      [textField addTarget:self action:@selector(userPasswordEntered:) forControlEvents:UIControlEventEditingChanged];
    }
    
    textField.backgroundColor = [UIColor whiteColor];
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.textAlignment = NSTextAlignmentLeft;
    textField.delegate = self;
    textField.tag = indexPath.row;
    
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [textField setEnabled: YES];
    
    [cell addSubview:textField];
  }
  
  if (0 == [indexPath row]) {
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailDescription");
  } else {
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPasswordDescription");
  }
  
  return cell;
}


- (void)userEmailEntered:(id)sender {
  self.email = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)userPasswordEntered:(id)sender {
  self.password = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
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

#pragma mark - Actions
- (void)saveAction:(id) __unused sender {
  [self setLoginUIEnabled:NO];
  
  __weak typeof(self) weakSelf = self;
  [self.delegate authenticationViewController:self
                handleAuthenticationWithEmail:self.email
                                     password:self.password
                                   completion:^(BOOL succeeded, NSError *error) {
                                     if(succeeded) {
                                       //controller should dismiss us shortly..
                                     } else {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                         UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                                                                  message:error.localizedDescription
                                                                                                           preferredStyle:UIAlertControllerStyleAlert];
                                         UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"OK")
                                                                                            style:UIAlertActionStyleCancel
                                                                                          handler:^(UIAlertAction __unused *action) {}];
                                         [alertController addAction:okAction];
                                         [self presentViewController:alertController animated:YES completion:nil];
                                         typeof(self) strongSelf = weakSelf;
                                         [strongSelf setLoginUIEnabled:YES];
                                       });
                                     }
                                   }];
}

- (void) setLoginUIEnabled:(BOOL) enabled {
  self.navigationItem.rightBarButtonItem.enabled = enabled;
  self.tableView.userInteractionEnabled = enabled;
}

@end

#endif  /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
