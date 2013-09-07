//
//  BITAuthenticationViewController.m
//  HockeySDK
//
//  Created by Stephan Diederich on 08.08.13.
//
//

#import "BITAuthenticationViewController.h"
#import "BITAuthenticator_Private.h"
#import "HockeySDKPrivate.h"
#import "HockeySDK.h"
#import "BITHockeyAppClient.h"

@interface BITAuthenticationViewController ()<UITextFieldDelegate> {
  UIStatusBarStyle _statusBarStyle;
}

@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>)delegate {
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerTitle");
    _delegate = delegate;
    _showsCancelButton = YES;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.tableView setScrollEnabled:NO];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  _statusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];

  [self updateCancelButton];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                         target:self
                                                                                         action:@selector(saveAction:)];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
  
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton {
  if(_showsCancelButton != showsCancelButton) {
    _showsCancelButton = showsCancelButton;
    [self updateCancelButton];
  }
}

- (void) updateCancelButton {
  if(self.showsCancelButton) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(dismissAction:)];
  } else {
    self.navigationItem.leftBarButtonItem = nil;
  }
}

#pragma mark - UIViewController Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if (![self.email length] || !BITValidateEmail(self.email))
    return NO;
  
  return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSInteger rows = 1;
  
  if ([self requirePassword]) rows ++;
  
  return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  if (section == 0) {
    return BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerDataDescription");
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"InputCell";
  
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor whiteColor];
    
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, self.view.frame.size.width - 110 - 35, 30)];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
      textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    textField.adjustsFontSizeToFitWidth = YES;
    textField.textColor = [UIColor blackColor];
    textField.backgroundColor = [UIColor lightGrayColor];
    
    if (0 == [indexPath row]) {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailPlaceholder");
      textField.text = self.email;
      
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
    textField.textAlignment = kBITTextLabelAlignmentLeft;
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
- (void)dismissAction:(id)sender {
  [self.delegate authenticationViewControllerDidCancel:self];
}

- (void)saveAction:(id)sender {
  [self setLoginUIEnabled:NO];
  
  __weak typeof(self) weakSelf = self;
  [self.delegate authenticationViewController:self
                handleAuthenticationWithEmail:self.email
                                     password:self.password
                                   completion:^(BOOL succeeded, NSError *error) {
                                     if(succeeded) {
                                       //controller should dismiss us shortly..
                                     } else {
                                       UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                                           message:error.localizedDescription
                                                                                          delegate:nil
                                                                                 cancelButtonTitle:BITHockeyLocalizedString(@"OK")
                                                                                 otherButtonTitles:nil];
                                       [alertView show];
                                       typeof(self) strongSelf = weakSelf;
                                       [strongSelf setLoginUIEnabled:YES];
                                     }
                                   }];
}

- (void) setLoginUIEnabled:(BOOL) enabled {
  self.navigationItem.rightBarButtonItem.enabled = !enabled;
  self.tableView.userInteractionEnabled = !enabled;
}

@end
