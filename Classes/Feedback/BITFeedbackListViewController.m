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
#import "BITFeedbackListViewController.h"
#import "BITFeedbackListViewCell.h"
#import "BITFeedbackComposeViewController.h"
#import "BITFeedbackUserDataViewController.h"
#import "BITFeedbackMessage.h"

#import "BITHockeyHelper.h"


@interface BITFeedbackListViewController () <BITFeedbackUserDataDelegate>
@property (nonatomic, assign) BITFeedbackManager *manager;
@property (nonatomic, retain) UITableView *tableView;

@property (nonatomic, retain) NSDateFormatter *lastUpdateDateFormatter;
@end

@implementation BITFeedbackListViewController

- (id)init {
  if ((self = [super init])) {
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    
    self.lastUpdateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[self.lastUpdateDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[self.lastUpdateDateFormatter setTimeStyle:NSDateFormatterShortStyle];
		self.lastUpdateDateFormatter.locale = [NSLocale currentLocale];
  }
  return self;
}


- (void)dealloc {
  [_tableView release], _tableView = nil;
  [_lastUpdateDateFormatter release]; _lastUpdateDateFormatter = nil;
  
  [super dealloc];
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateList)
                                               name:BITHockeyFeedbackMessagesUpdated
                                             object:nil];
  
  self.title = BITHockeyLocalizedString(@"HockeyFeedbackListTitle");
  
  self.tableView = [[[UITableView alloc] initWithFrame:self.view.bounds] autorelease];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
  [self.tableView setBackgroundColor:[UIColor colorWithRed:0.82 green:0.84 blue:0.84 alpha:1]];
  [self.tableView setSeparatorColor:[UIColor colorWithRed:0.79 green:0.79 blue:0.79 alpha:1]];
  [self.view addSubview:self.tableView];
  
  self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                          target:self
                                                                                          action:@selector(reloadList)] autorelease];
  
}

- (void)viewDidUnload {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesUpdated object:nil];
  
  [super viewDidUnload];
}

- (void)reloadList {
  [self.manager updateMessagesList];
}

- (void)updateList {
  CGSize contentSize = self.tableView.contentSize;
  CGPoint contentOffset = self.tableView.contentOffset;
  
  [self.tableView reloadData];
  if (self.tableView.contentSize.height > contentSize.height)
    [self.tableView setContentOffset:CGPointMake(contentOffset.x, self.tableView.contentSize.height - contentSize.height + contentOffset.y) animated:NO];
  
  [self.tableView flashScrollIndicators];
}

- (void)viewWillAppear:(BOOL)animated {
  self.manager.currentFeedbackListViewController = self;
  
  [super viewWillAppear:animated];
  
  [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
  self.manager.currentFeedbackListViewController = nil;
  
  [super viewWillDisappear:animated];
}


#pragma mark - Private methods

- (void)setUserDataAction:(id)sender {
  BITFeedbackUserDataViewController *userController = [[[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
  userController.delegate = self;
  
  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:userController] autorelease];
  
  [self.navigationController presentModalViewController:navController animated:YES];
}

- (void)newFeedbackAction:(id)sender {
  BITFeedbackComposeViewController *composeController = [[[BITFeedbackComposeViewController alloc] init] autorelease];
  
  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:composeController] autorelease];
  
  [self.navigationController presentModalViewController:navController animated:YES];
}


#pragma mark - BITFeedbackUserDataDelegate

-(void)userDataUpdateCancelled {
  [self.navigationController dismissModalViewControllerAnimated:YES];
}

-(void)userDataUpdateFinished {
  [self.manager saveMessages];
  
  [self.navigationController dismissModalViewControllerAnimated:YES];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  NSInteger rows = 2;
  if ([self.manager isManualUserDataAvailable] || [self.manager didAskUserData])
    rows++;
  
  return rows;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return 2;
  } else if (section == 2) {
    return 1;
  } else {
    return [self.manager numberOfMessages];
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"MessageCell";
  static NSString *LastUpdateIdentifier = @"LastUpdateCell";
  static NSString *ButtonIdentifier = @"ButtonCell";
  
  if (indexPath.section == 0 && indexPath.row == 1) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LastUpdateIdentifier];
    
    if (!cell) {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LastUpdateIdentifier] autorelease];
      cell.textLabel.font = [UIFont systemFontOfSize:10];
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.textAlignment = UITextAlignmentCenter;
    }
    
    cell.textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                           [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
    
    return cell;
  } else if (indexPath.section == 0 || indexPath.section == 2) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ButtonIdentifier];
    
    if (!cell) {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ButtonIdentifier] autorelease];
      cell.textLabel.font = [UIFont systemFontOfSize:14];
      cell.textLabel.numberOfLines = 0;
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    if (indexPath.section == 0) {
      if ([self.manager numberOfMessages] == 0) {
        [button setTitle:BITHockeyLocalizedString(@"HockeyFeedbackListButonWriteFeedback") forState:UIControlStateNormal];
      } else {
        [button setTitle:BITHockeyLocalizedString(@"HockeyFeedbackListButonWriteResponse") forState:UIControlStateNormal];
      }
      [button addTarget:self action:@selector(newFeedbackAction:) forControlEvents:UIControlEventTouchUpInside];
    } else {
      NSString *title = @"";
      if ([self.manager requireUserName] == BITFeedbackUserDataElementRequired ||
          ([self.manager requireUserName] == BITFeedbackUserDataElementOptional && [self.manager userName] != nil)
          ) {
        title = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButonUserDataWithName"), [self.manager userName]];
      } else if ([self.manager requireUserEmail] == BITFeedbackUserDataElementRequired ||
                 ([self.manager requireUserEmail] == BITFeedbackUserDataElementOptional && [self.manager userEmail] != nil)
                 ) {
        title = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButonUserDataWithEmail"), [self.manager userEmail]];
      } else if ([self.manager requireUserName] == BITFeedbackUserDataElementOptional) {
        title = BITHockeyLocalizedString(@"HockeyFeedbackListButonUserDataSetName");
      } else {
        title = BITHockeyLocalizedString(@"HockeyFeedbackListButonUserDataSetEmail");
      }
      [button setTitle:title forState:UIControlStateNormal];
      [button addTarget:self action:@selector(setUserDataAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    [button setFrame: CGRectMake( 10.0f, 12.0f, self.view.frame.size.width - 20.0f, 50.0f)];
    
    [cell addSubview:button];
    
    return cell;
  } else {
    BITFeedbackListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell) {
      cell = [[[BITFeedbackListViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
    cell.date = message.date;
    
    if (message.userMessage) {
      cell.style = BITFeedbackListViewCellStyleNormal;
      if ([self.manager requireUserName] == BITFeedbackUserDataElementRequired ||
          ([self.manager requireUserName] == BITFeedbackUserDataElementOptional && [self.manager userName] != nil)
          ) {
        cell.name = [self.manager userName];
      } else {
        cell.name = BITHockeyLocalizedString(@"HockeyFeedbackListMessageUserNameNotSet");
      }
    } else {
      cell.style = BITFeedbackListViewCellStyleRepsonse;
      if (message.name && [message.name length] > 0) {
        cell.name = message.name;
      } else {
        cell.name = BITHockeyLocalizedString(@"HockeyFeedbackListmessageResponseNameNotSet");
      }
    }
    
    if (message.text) {
      cell.text = message.text;
    } else {
      cell.text = @"";
    }
    
    return cell;
  }
}


#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 && indexPath.row == 1) {
    return 28;
  }
  if (indexPath.section == 0 || indexPath.section == 2) {
    return 74;
  }
  
  BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
  if (!message) return 44;
  
  //  BITFeedbackListViewCell *cell = (BITFeedbackListViewCell *)[tableView cellForRowAtIndexPath:indexPath];
  return [BITFeedbackListViewCell heightForRowWithText:message.text tableViewWidth:self.view.frame.size.width];
}

@end
