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

@interface BITAuthenticationViewController ()<UITextFieldDelegate> {
  UIStatusBarStyle _statusBarStyle;
}

@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (id)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerTitle");
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

//TODO: extract from feedbackviewcontroller and move to common place
- (BOOL)validateEmail {
  NSString *emailRegex =
  @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
  @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
  @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
  @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
  @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
  @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
  @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
  NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
  
  return [emailTest evaluateWithObject:self.email];
}

- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if ([self.email length] > 0 && ![self validateEmail])
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
    return BITHockeyLocalizedString(@"HockeyAuthenticationDataDescription");
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
      textField.placeholder = BITHockeyLocalizedString(@"HockeyFeedbackUserDataEmailPlaceholder");
      textField.text = self.email;
      
      textField.keyboardType = UIKeyboardTypeEmailAddress;
      if ([self requirePassword])
        textField.returnKeyType = UIReturnKeyNext;
      else
        textField.returnKeyType = UIReturnKeyDone;
      
      [textField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
      [textField becomeFirstResponder];
    } else {
      textField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerPasswordPlaceHolder");
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
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyFeedbackUserDataEmail");
  } else {
    cell.textLabel.text = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPassword");
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
  [self showLoginUI:YES];
  
  NSString *authenticationEndpoint = @"authenticate";
  __weak typeof (self) weakSelf = self;

  [self.authenticator getPath:authenticationEndpoint
                   completion:^(BITHTTPOperation *operation, id response, NSError *error) {
                     typeof (self) strongSelf = weakSelf;
                     if(nil == response) {
                       //TODO think about alertview messages
                       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                                       message:@"Failed to authenticate"
                                                                      delegate:nil
                                                             cancelButtonTitle:BITHockeyLocalizedString(@"OK")
                                                             otherButtonTitles:nil];
                       [alert show];
                     } else {
                       NSError *authParseError = nil;
                       NSString *authToken = [strongSelf.class authenticationTokenFromReponse:response
                                                                                        error:&authParseError];
                       if(nil == authToken) {
                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                                         message:@"Failed to authenticate"
                                                                        delegate:nil
                                                               cancelButtonTitle:BITHockeyLocalizedString(@"OK")
                                                               otherButtonTitles:nil];
                         [alert show];
                       } else {
                         [strongSelf.delegate authenticationViewController:strongSelf authenticatedWithToken:authToken];
                       }
                     }
                     [self showLoginUI:NO];
                   }];
}

- (void) showLoginUI:(BOOL) enableLoginUI {
  self.navigationItem.rightBarButtonItem.enabled = !enableLoginUI;
  self.tableView.userInteractionEnabled = !enableLoginUI;
}

+ (NSString *) authenticationTokenFromReponse:(id) response error:(NSError **) error {
  NSParameterAssert(response);
  
  NSError *jsonParseError = nil;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:response
                                                  options:0
                                                    error:&jsonParseError];
  if(nil == jsonObject) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidRespone
                               userInfo:(jsonParseError ? @{NSUnderlyingErrorKey : jsonParseError} : nil)];
    }
    return NO;
  }
  if(![jsonObject isKindOfClass:[NSDictionary class]]) {
    if(error) {
      *error = [NSError errorWithDomain:kBITAuthenticatorErrorDomain
                                   code:BITAuthenticatorAPIServerReturnedInvalidRespone
                               userInfo:nil];
    }
    return NO;
  }
  
  //TODO: add proper validation
  return jsonObject[@"authToken"];
}
@end
