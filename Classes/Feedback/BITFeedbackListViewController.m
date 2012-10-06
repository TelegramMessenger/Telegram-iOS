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
#import <QuartzCore/QuartzCore.h>


#define DEFAULT_BACKGROUNDCOLOR BIT_RGBCOLOR(245, 245, 245)
#define DEFAULT_TEXTCOLOR BIT_RGBCOLOR(75, 75, 75)
#define BUTTON_BACKGROUNDCOLOR BIT_RGBCOLOR(225, 225, 225)
#define BUTTON_BORDERCOLOR BIT_RGBCOLOR(175, 175, 175)
#define BUTTON_TEXTCOLOR BIT_RGBCOLOR(58, 58, 58)
#define BUTTON_TEXTCOLOR_SHADOW BIT_RGBCOLOR(175, 175, 175)
#define BORDER_COLOR1 BIT_RGBCOLOR(215, 215, 215)
#define BORDER_COLOR2 BIT_RGBCOLOR(221, 221, 221)
#define BORDER_COLOR3 BIT_RGBCOLOR(255, 255, 255)

@interface BITFeedbackListViewController () <BITFeedbackUserDataDelegate>
@property (nonatomic, assign) BITFeedbackManager *manager;

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
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesUpdated object:nil];

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
  
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
  [self.tableView setBackgroundColor:[UIColor colorWithRed:0.82 green:0.84 blue:0.84 alpha:1]];
  [self.tableView setSeparatorColor:[UIColor colorWithRed:0.79 green:0.79 blue:0.79 alpha:1]];

  self.view.backgroundColor = DEFAULT_BACKGROUNDCOLOR;

  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    self.refreshControl = [[[UIRefreshControl alloc] init] autorelease];
    [self.refreshControl addTarget:self action:@selector(reloadList) forControlEvents:UIControlEventValueChanged];
  } else {
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                            target:self
                                                                                            action:@selector(reloadList)] autorelease];
  }  
}

- (void)reloadList {
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    [self.refreshControl beginRefreshing];
  }
  [self.manager updateMessagesList];
}

- (void)updateList {
  CGSize contentSize = self.tableView.contentSize;
  CGPoint contentOffset = self.tableView.contentOffset;
  
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    [self.refreshControl endRefreshing];
  }
  
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
  navController.modalPresentationStyle = UIModalPresentationFormSheet;
  
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
    return 1;
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
      cell.textLabel.textColor = DEFAULT_TEXTCOLOR;
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.textAlignment = UITextAlignmentCenter;
    }
    
    cell.textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                           [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
    
    return cell;
  } else if (indexPath.section == 0 || indexPath.section == 2) {
    CGFloat topGap = 0.0f;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ButtonIdentifier];
    
    if (!cell) {
      cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ButtonIdentifier] autorelease];
      cell.textLabel.font = [UIFont systemFontOfSize:14];
      cell.textLabel.numberOfLines = 0;
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button.layer setMasksToBounds:YES];
    [button.layer setCornerRadius:10.0f];
    [button.layer setBorderWidth:1];
    [button.layer setBackgroundColor:BUTTON_BACKGROUNDCOLOR.CGColor];
    [button.layer setBorderColor:BUTTON_BORDERCOLOR.CGColor];
    [button.layer setShadowOffset:CGSizeMake(-1, -1)];
    [[button titleLabel] setFont:[UIFont boldSystemFontOfSize:14.0]];
    [button setTitleColor:BUTTON_TEXTCOLOR forState:UIControlStateNormal];
    [button setTitleShadowColor:BUTTON_TEXTCOLOR_SHADOW forState:UIControlStateNormal];
    if (indexPath.section == 0) {
      if ([self.manager numberOfMessages] == 0) {
        [button setTitle:BITHockeyLocalizedString(@"HockeyFeedbackListButonWriteFeedback") forState:UIControlStateNormal];
      } else {
        [button setTitle:BITHockeyLocalizedString(@"HockeyFeedbackListButonWriteResponse") forState:UIControlStateNormal];
      }
      [button addTarget:self action:@selector(newFeedbackAction:) forControlEvents:UIControlEventTouchUpInside];
    } else {
      topGap = 6.0f;
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
    [button setFrame: CGRectMake( 10.0f, topGap + 12.0f, self.view.frame.size.width - 20.0f, 42.0f)];
    
    [cell addSubview:button];
    
    if (indexPath.section == 0) {
      UILabel *statusLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, 59, self.view.frame.size.width, 28)] autorelease];
      
      statusLabel.font = [UIFont systemFontOfSize:10];
      statusLabel.textColor = DEFAULT_TEXTCOLOR;
      statusLabel.textAlignment = UITextAlignmentCenter;
      statusLabel.backgroundColor = DEFAULT_BACKGROUNDCOLOR;
      statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

      statusLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                             [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];

      [cell addSubview:statusLabel];
    } else {
      UIView *lineView1 = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.contentView.bounds.size.width, 1)] autorelease];
      lineView1.backgroundColor = BORDER_COLOR1;
      lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [cell addSubview:lineView1];

      UIView *lineView2 = [[[UIView alloc] initWithFrame:CGRectMake(0, 1, cell.contentView.bounds.size.width, 1)] autorelease];
      lineView2.backgroundColor = BORDER_COLOR2;
      lineView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [cell addSubview:lineView2];

      UIView *lineView3 = [[[UIView alloc] initWithFrame:CGRectMake(0, 2, cell.contentView.bounds.size.width, 1)] autorelease];
      lineView3.backgroundColor = BORDER_COLOR3;
      lineView3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [cell addSubview:lineView3];
    }
    
    return cell;
  } else {
    BITFeedbackListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell) {
      cell = [[[BITFeedbackListViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.row == 0 || indexPath.row % 2 == 0) {
      cell.backgroundStyle = BITFeedbackListViewCellBackgroundStyleAlternate;
    } else {
      cell.backgroundStyle = BITFeedbackListViewCellBackgroundStyleNormal;
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

    UIView *lineView1 = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.contentView.bounds.size.width, 1)] autorelease];
    lineView1.backgroundColor = BORDER_COLOR1;
    lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell addSubview:lineView1];
    
    UIView *lineView2 = [[[UIView alloc] initWithFrame:CGRectMake(0, 1, cell.contentView.bounds.size.width, 1)] autorelease];
    lineView2.backgroundColor = BORDER_COLOR2;
    lineView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell addSubview:lineView2];
    
    UIView *lineView3 = [[[UIView alloc] initWithFrame:CGRectMake(0, 2, cell.contentView.bounds.size.width, 1)] autorelease];
    lineView3.backgroundColor = BORDER_COLOR3;
    lineView3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell addSubview:lineView3];

    return cell;
  }
}


#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 ) {
    return 87;
  }
  if (indexPath.section == 2) {
    return 75;
  }
  
  BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
  if (!message) return 44;
  
  return [BITFeedbackListViewCell heightForRowWithText:message.text tableViewWidth:self.view.frame.size.width];
}

@end
