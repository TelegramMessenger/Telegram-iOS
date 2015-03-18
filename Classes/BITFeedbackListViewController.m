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
#import "BITFeedbackManager.h"
#import "BITFeedbackListViewController.h"
#import "BITFeedbackListViewCell.h"
#import "BITFeedbackComposeViewController.h"
#import "BITFeedbackUserDataViewController.h"
#import "BITFeedbackMessage.h"
#import "BITFeedbackMessageAttachment.h"
#import "BITAttributedLabel.h"

#import "BITHockeyBaseManagerPrivate.h"

#import "BITHockeyHelper.h"
#import <QuartzCore/QuartzCore.h>
#import <QuickLook/QuickLook.h>


#define DEFAULT_BACKGROUNDCOLOR BIT_RGBCOLOR(245, 245, 245)
#define DEFAULT_BACKGROUNDCOLOR_OS7 BIT_RGBCOLOR(255, 255, 255)
#define DEFAULT_TEXTCOLOR BIT_RGBCOLOR(75, 75, 75)

#define BUTTON_BORDERCOLOR BIT_RGBCOLOR(175, 175, 175)
#define BUTTON_BACKGROUNDCOLOR BIT_RGBCOLOR(225, 225, 225)
#define BUTTON_TEXTCOLOR BIT_RGBCOLOR(58, 58, 58)
#define BUTTON_TEXTCOLOR_SHADOW BIT_RGBCOLOR(255, 255, 255)

#define BUTTON_DELETE_BORDERCOLOR BIT_RGBCOLOR(61, 61, 61)
#define BUTTON_DELETE_BACKGROUNDCOLOR BIT_RGBCOLOR(225, 0, 0)
#define BUTTON_DELETE_TEXTCOLOR BIT_RGBCOLOR(240, 240, 240)
#define BUTTON_DELETE_TEXTCOLOR_SHADOW BIT_RGBCOLOR(125, 0, 0)

#define BORDER_COLOR BIT_RGBCOLOR(215, 215, 215)


@interface BITFeedbackListViewController () <BITFeedbackUserDataDelegate, BITFeedbackComposeViewControllerDelegate, BITAttributedLabelDelegate, BITFeedbackListViewCellDelegate>

@property (nonatomic, weak) BITFeedbackManager *manager;
@property (nonatomic, strong) NSDateFormatter *lastUpdateDateFormatter;
@property (nonatomic) BOOL userDataComposeFlow;
@property (nonatomic, strong) NSArray *cachedPreviewItems;
@property (nonatomic, strong) NSOperationQueue *thumbnailQueue;

@end


@implementation BITFeedbackListViewController {
  NSInteger _deleteButtonSection;
  NSInteger _userButtonSection;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
  if ((self = [super initWithStyle:style])) {
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    
    _deleteButtonSection = -1;
    _userButtonSection = -1;
    _userDataComposeFlow = NO;
    
    _lastUpdateDateFormatter = [[NSDateFormatter alloc] init];
		[_lastUpdateDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[_lastUpdateDateFormatter setTimeStyle:NSDateFormatterShortStyle];
		_lastUpdateDateFormatter.locale = [NSLocale currentLocale];
    
    _thumbnailQueue = [NSOperationQueue new];
  }
  return self;
}


- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesLoadingStarted object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:BITHockeyFeedbackMessagesLoadingFinished object:nil];
  
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showDelayedUserDataViewController) object:nil];
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(startLoadingIndicator)
                                               name:BITHockeyFeedbackMessagesLoadingStarted
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateList)
                                               name:BITHockeyFeedbackMessagesLoadingFinished
                                             object:nil];
  
  self.title = BITHockeyLocalizedString(@"HockeyFeedbackListTitle");
  
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
  if ([self.manager isPreiOS7Environment]) {
    [self.tableView setBackgroundColor:[UIColor colorWithRed:0.82 green:0.84 blue:0.84 alpha:1]];
    [self.tableView setSeparatorColor:[UIColor colorWithRed:0.79 green:0.79 blue:0.79 alpha:1]];
  } else {
    //    [self.tableView setBackgroundColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1]];
  }
  
  if ([self.manager isPreiOS7Environment]) {
    self.view.backgroundColor = DEFAULT_BACKGROUNDCOLOR;
  } else {
    //    self.view.backgroundColor = DEFAULT_BACKGROUNDCOLOR_OS7;
  }
  
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reloadList) forControlEvents:UIControlEventValueChanged];
  } else {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(reloadList)];
  }
}

- (void)startLoadingIndicator {
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    [self.refreshControl beginRefreshing];
  } else {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
}

- (void)stopLoadingIndicator {
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    [self.refreshControl endRefreshing];
  } else {
    self.navigationItem.rightBarButtonItem.enabled = YES;
  }
}

- (BOOL)isRefreshingWithNewControl {
  id refreshClass = NSClassFromString(@"UIRefreshControl");
  if (refreshClass) {
    return [self.refreshControl isRefreshing];
  }
  return NO;
}

- (void)reloadList {
  [self startLoadingIndicator];
  
  [self.manager updateMessagesList];
}

- (void)updateList {
  CGSize contentSize = self.tableView.contentSize;
  CGPoint contentOffset = self.tableView.contentOffset;
  
  [self refreshPreviewItems];
  [self.tableView reloadData];
  
  if (contentSize.height > 0 &&
      self.tableView.contentSize.height > self.tableView.frame.size.height &&
      self.tableView.contentSize.height > contentSize.height &&
      ![self isRefreshingWithNewControl])
    [self.tableView setContentOffset:CGPointMake(contentOffset.x, self.tableView.contentSize.height - contentSize.height + contentOffset.y) animated:NO];
  
  [self stopLoadingIndicator];
  
  [self.tableView flashScrollIndicators];
}

- (void)viewDidAppear:(BOOL)animated {
  if (self.userDataComposeFlow) {
    self.userDataComposeFlow = NO;
  }
  self.manager.currentFeedbackListViewController = self;
  
  [self.manager updateMessagesListIfRequired];
  
  if ([self.manager numberOfMessages] == 0 &&
      [self.manager askManualUserDataAvailable] &&
      [self.manager requireManualUserDataMissing] &&
      ![self.manager didAskUserData]
      ) {
    self.userDataComposeFlow = YES;
    
    if ([self.manager showFirstRequiredPresentationModal]) {
      [self setUserDataAction:nil];
    } else {
      // In case of presenting the feedback in a UIPopoverController it appears
      // that the animation is not yet finished (though it should) and pushing
      // the user data view on top of the navigation stack right away will
      // cause the following warning to appear in the console:
      // "nested push animation can result in corrupted navigation bar"
      [self performSelector:@selector(showDelayedUserDataViewController) withObject:nil afterDelay:0.0];
    }
  } else {
    [self.tableView reloadData];
  }
  
  [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  self.manager.currentFeedbackListViewController = nil;
  
  [super viewWillDisappear:animated];
}


#pragma mark - Private methods

- (void)showDelayedUserDataViewController {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  [self.navigationController pushViewController:userController animated:YES];
}

- (void)setUserDataAction:(id)sender {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:userController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)newFeedbackAction:(id)sender {
  BITFeedbackComposeViewController *composeController = [self.manager feedbackComposeViewController];
  
  UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:composeController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)deleteAllMessages {
  [_manager deleteAllMessages];
  [self refreshPreviewItems];
  
  [self.tableView reloadData];
}

- (void)deleteAllMessagesAction:(id)sender {
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    UIActionSheet *deleteAction = [[UIActionSheet alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllTitle")
                                                              delegate:self
                                                     cancelButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllCancel")
                                                destructiveButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllDelete")
                                                     otherButtonTitles:nil
                                   ];
    [deleteAction setTag:0];
    [deleteAction setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    [deleteAction showInView:[self viewForShowingActionSheetOnPhone]];
  } else {
    UIAlertView *deleteAction = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListButtonDeleteAllMessages")
                                                           message:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllTitle")
                                                          delegate:self
                                                 cancelButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllCancel")
                                                 otherButtonTitles:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllDelete"), nil];
    
    [deleteAction setTag:0];
    [deleteAction show];
  }
}

- (UIView*) viewForShowingActionSheetOnPhone {
  //find the topmost presented view controller
  //and use its view
  UIViewController* topMostPresentedViewController = self.view.window.rootViewController;
  while(topMostPresentedViewController.presentedViewController) {
    topMostPresentedViewController = topMostPresentedViewController.presentedViewController;
  }
  UIView* view = topMostPresentedViewController.view;
  
  if(nil == view) {
    //hope for the best. Should work
    //on simple view(controller) hierarchies
    view = self.view;
  }
  
  return view;
}

#pragma mark - BITFeedbackUserDataDelegate

-(void)userDataUpdateCancelled {
  if (self.userDataComposeFlow) {
    if ([self.manager showFirstRequiredPresentationModal]) {
      __weak typeof(self) weakSelf = self;
      [self dismissViewControllerAnimated:YES completion:^(void){
        typeof(self) strongSelf = weakSelf;
        [strongSelf.tableView reloadData];
      }];
    } else {
      [self.navigationController popToViewController:self animated:YES];
    }
  } else {
    [self dismissViewControllerAnimated:YES completion:^(void){}];
  }
}

-(void)userDataUpdateFinished {
  [self.manager saveMessages];
  [self refreshPreviewItems];
  
  if (self.userDataComposeFlow) {
    if ([self.manager showFirstRequiredPresentationModal]) {
      __weak typeof(self) weakSelf = self;
      [self dismissViewControllerAnimated:YES completion:^(void){
        typeof(self) strongSelf = weakSelf;
        [strongSelf newFeedbackAction:nil];
      }];
    } else {
      BITFeedbackComposeViewController *composeController = [[BITFeedbackComposeViewController alloc] init];
      composeController.delegate = self;
      
      [self.navigationController pushViewController:composeController animated:YES];
    }
  } else {
    [self dismissViewControllerAnimated:YES completion:^(void){}];
  }
}


#pragma mark - BITFeedbackComposeViewControllerDelegate

- (void)feedbackComposeViewController:(BITFeedbackComposeViewController *)composeViewController
                  didFinishWithResult:(BITFeedbackComposeResult)composeResult {
  if (self.userDataComposeFlow) {
    if ([self.manager showFirstRequiredPresentationModal]) {
      __weak typeof(self) weakSelf = self;
      [self dismissViewControllerAnimated:YES completion:^(void){
        typeof(self) strongSelf = weakSelf;
        [strongSelf.tableView reloadData];
      }];
    } else {
      [self.navigationController popToViewController:self animated:YES];
    }
  } else {
    [self dismissViewControllerAnimated:YES completion:^(void){}];
  }
  
  if (self.manager.delegate &&
      [self.manager.delegate respondsToSelector:@selector(feedbackComposeViewController:didFinishWithResult:)]) {
    [self.manager.delegate feedbackComposeViewController:composeViewController didFinishWithResult:composeResult];
  } else if (self.manager.delegate && [self.manager.delegate respondsToSelector:@selector(feedbackComposeViewControllerDidFinish:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    [self.manager.delegate feedbackComposeViewControllerDidFinish:composeViewController];
#pragma clang diagnostic pop
  }
}


#pragma mark - UIViewController Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  [self.tableView beginUpdates];
  [self.tableView endUpdates];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  NSInteger sections = 2;
  _deleteButtonSection = -1;
  _userButtonSection = -1;
  
  if ([self.manager isManualUserDataAvailable] || [self.manager didAskUserData]) {
    _userButtonSection = sections;
    sections++;
  }
  
  if ([self.manager numberOfMessages] > 0) {
    _deleteButtonSection = sections;
    sections++;
  }
  
  return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) {
    return [self.manager numberOfMessages];
  } else {
    return 1;
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  if (![self.manager isPreiOS7Environment]) {
    if (section == 0) {
      return 30;
    }
  }
  
  return [super tableView:tableView heightForHeaderInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  if (![self.manager isPreiOS7Environment] && section == 0) {
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 30.0f)];
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 5.0f, self.view.frame.size.width - 32.0f, 25.0f)];
    textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                      [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
    textLabel.font = [UIFont systemFontOfSize:10];
    textLabel.textColor = DEFAULT_TEXTCOLOR;
    [containerView addSubview:textLabel];
    
    return containerView;
  }
  
  return [super tableView:tableView viewForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"MessageCell";
  static NSString *LastUpdateIdentifier = @"LastUpdateCell";
  static NSString *ButtonTopIdentifier = @"ButtonTopCell";
  static NSString *ButtonBottomIdentifier = @"ButtonBottomCell";
  static NSString *ButtonDeleteIdentifier = @"ButtonDeleteCell";
  
  if (indexPath.section == 0 && indexPath.row == 1 && ![self.manager isPreiOS7Environment]) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LastUpdateIdentifier];
    
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LastUpdateIdentifier];
      cell.textLabel.font = [UIFont systemFontOfSize:10];
      cell.textLabel.textColor = DEFAULT_TEXTCOLOR;
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.textAlignment = kBITTextLabelAlignmentCenter;
    }
    
    cell.textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                           [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
    
    return cell;
  } else if (indexPath.section == 0 || indexPath.section >= 2) {
    CGFloat topGap = 0.0f;
    
    UITableViewCell *cell = nil;
    
    NSString *identifier = nil;
    
    if (indexPath.section == 0) {
      identifier = ButtonTopIdentifier;
    } else if (indexPath.section == _userButtonSection) {
      identifier = ButtonBottomIdentifier;
    } else {
      identifier = ButtonDeleteIdentifier;
    }
    
    cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
      
      cell.textLabel.font = [UIFont systemFontOfSize:14];
      cell.textLabel.numberOfLines = 0;
      cell.accessoryType = UITableViewCellAccessoryNone;
      
      if ([self.manager isPreiOS7Environment]) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
      } else {
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
      }
    }
    
    // button
    NSString *titleString = nil;
    SEL actionSelector = nil;
    
    UIColor *titleColor = BIT_RGBCOLOR(35, 111, 251);
    if ([self.view respondsToSelector:@selector(tintColor)]){
      titleColor = self.view.tintColor;
    }
    
    UIButton *button = nil;
    if ([self.manager isPreiOS7Environment]) {
      button = [UIButton buttonWithType:UIButtonTypeCustom];
      button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      UIImage *stretchableButton = [bit_imageNamed(@"buttonRoundedRegular.png", BITHOCKEYSDK_BUNDLE) stretchableImageWithLeftCapWidth:10 topCapHeight:0];
      UIImage *stretchableHighlightedButton = [bit_imageNamed(@"buttonRoundedRegularHighlighted.png", BITHOCKEYSDK_BUNDLE) stretchableImageWithLeftCapWidth:10 topCapHeight:0];
      [button setBackgroundImage:stretchableButton forState:UIControlStateNormal];
      [button setBackgroundImage:stretchableHighlightedButton forState:UIControlStateHighlighted];
      
      [[button titleLabel] setShadowOffset:CGSizeMake(0, 1)];
      [[button titleLabel] setFont:[UIFont boldSystemFontOfSize:14.0]];
      
      [button setTitleColor:BUTTON_TEXTCOLOR forState:UIControlStateNormal];
      [button setTitleShadowColor:BUTTON_TEXTCOLOR_SHADOW forState:UIControlStateNormal];
    }
    
    if (indexPath.section == 0) {
      topGap = 22;
      if ([self.manager numberOfMessages] == 0) {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonWriteFeedback");
      } else {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonWriteResponse");
      }
      actionSelector = @selector(newFeedbackAction:);
    } else if (indexPath.section == _userButtonSection) {
      topGap = 6.0f;
      if ([self.manager requireUserName] == BITFeedbackUserDataElementRequired ||
          ([self.manager requireUserName] == BITFeedbackUserDataElementOptional && [self.manager userName] != nil)
          ) {
        titleString = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataWithName"), [self.manager userName] ?: @"-"];
      } else if ([self.manager requireUserEmail] == BITFeedbackUserDataElementRequired ||
                 ([self.manager requireUserEmail] == BITFeedbackUserDataElementOptional && [self.manager userEmail] != nil)
                 ) {
        titleString = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataWithEmail"), [self.manager userEmail] ?: @"-"];
      } else if ([self.manager requireUserName] == BITFeedbackUserDataElementOptional) {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataSetName");
      } else {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataSetEmail");
      }
      actionSelector = @selector(setUserDataAction:);
    } else {
      topGap = 0.0f;
      if ([self.manager isPreiOS7Environment]) {
        [[button titleLabel] setShadowOffset:CGSizeMake(0, -1)];
        UIImage *stretchableDeleteButton = [bit_imageNamed(@"buttonRoundedDelete.png", BITHOCKEYSDK_BUNDLE) stretchableImageWithLeftCapWidth:10 topCapHeight:0];
        UIImage *stretchableDeleteHighlightedButton = [bit_imageNamed(@"buttonRoundedDeleteHighlighted.png", BITHOCKEYSDK_BUNDLE) stretchableImageWithLeftCapWidth:10 topCapHeight:0];
        [button setBackgroundImage:stretchableDeleteButton forState:UIControlStateNormal];
        [button setBackgroundImage:stretchableDeleteHighlightedButton forState:UIControlStateHighlighted];
        
        [button setTitleColor:BUTTON_DELETE_TEXTCOLOR forState:UIControlStateNormal];
        [button setTitleShadowColor:BUTTON_DELETE_TEXTCOLOR_SHADOW forState:UIControlStateNormal];
      }
      
      titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonDeleteAllMessages");
      titleColor = BIT_RGBCOLOR(251, 35, 35);
      actionSelector = @selector(deleteAllMessagesAction:);
    }
    
    if ([self.manager isPreiOS7Environment]) {
      if (titleString)
        [button setTitle:titleString forState:UIControlStateNormal];
      if (actionSelector)
        [button addTarget:self action:actionSelector forControlEvents:UIControlEventTouchUpInside];
      
      [button setFrame: CGRectMake( 10.0f, topGap + 12.0f, cell.frame.size.width - 20.0f, 42.0f)];
      [cell addSubview:button];
    } else {
      cell.textLabel.text = titleString;
      cell.textLabel.textColor = titleColor;
    }
    
    if ([self.manager isPreiOS7Environment]) {
      // status label or shadow lines
      if (indexPath.section == 0) {
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 6, cell.frame.size.width, 28)];
        
        statusLabel.font = [UIFont systemFontOfSize:10];
        statusLabel.textColor = DEFAULT_TEXTCOLOR;
        statusLabel.textAlignment = kBITTextLabelAlignmentCenter;
        if ([self.manager isPreiOS7Environment]) {
          statusLabel.backgroundColor = DEFAULT_BACKGROUNDCOLOR;
        } else {
          statusLabel.backgroundColor = DEFAULT_BACKGROUNDCOLOR_OS7;
        }
        statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        statusLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                            [self.manager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[self.manager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
        
        [cell addSubview:statusLabel];
      } else if (indexPath.section == 2) {
        UIView *lineView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, 1)];
        lineView1.backgroundColor = BORDER_COLOR;
        lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell addSubview:lineView1];
      }
    }
    
    return cell;
  } else {
    BITFeedbackListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell) {
      cell = [[BITFeedbackListViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.row == 0 || indexPath.row % 2 == 0) {
      cell.backgroundStyle = BITFeedbackListViewCellBackgroundStyleAlternate;
    } else {
      cell.backgroundStyle = BITFeedbackListViewCellBackgroundStyleNormal;
    }
    
    if ([self.manager isPreiOS7Environment]) {
      cell.style = BITFeedbackListViewCellPresentationStyleDefault;
    } else {
      cell.style = BITFeedbackListViewCellPresentationStyleOS7;
    }
    
    BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
    cell.message = message;
    cell.labelText.delegate = self;
    cell.labelText.userInteractionEnabled = YES;
    cell.delegate = self;
    [cell setAttachments:message.previewableAttachments];
    
    for (BITFeedbackMessageAttachment *attachment in message.attachments){
      if (attachment.needsLoadingFromURL && !attachment.isLoading){
        attachment.isLoading = YES;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:attachment.sourceURL]];
        [NSURLConnection sendAsynchronousRequest:request queue:self.thumbnailQueue completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *err) {
          attachment.isLoading = NO;
          if (responseData.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [attachment replaceData:responseData];
              [[NSNotificationCenter defaultCenter] postNotificationName:kBITFeedbackUpdateAttachmentThumbnail object:attachment];
              [[BITHockeyManager sharedHockeyManager].feedbackManager saveMessages];
            });
          }
        }];
      }
    }
    
    if (
        [self.manager isPreiOS7Environment] ||
        (![self.manager isPreiOS7Environment] && indexPath.row != 0)
        ) {
      UIView *lineView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, 1)];
      lineView1.backgroundColor = BORDER_COLOR;
      lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [cell addSubview:lineView1];
    }
    
    return cell;
  }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 1)
    return YES;
  
  return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
    BOOL messageHasAttachments = ([message attachments].count > 0);
    
    if ([_manager deleteMessageAtIndex:indexPath.row]) {
      if ([_manager numberOfMessages] > 0) {
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
      } else {
        [tableView reloadData];
      }
      
      if (messageHasAttachments) {
        [self refreshPreviewItems];
      }
    }
  }
}


#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 ) {
    if ([self.manager isPreiOS7Environment])
      return 87;
    else
      return 44;
  }
  if (indexPath.section >= 2) {
    if ([self.manager isPreiOS7Environment])
      return 65;
    else
      return 44;
  }
  
  BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
  if (!message) return 44;
  
  return [BITFeedbackListViewCell heightForRowWithMessage:message tableViewWidth:self.view.frame.size.width];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (![self.manager isPreiOS7Environment]) {
    if (indexPath.section == 0) {
      [self newFeedbackAction:self];
    } else if (indexPath.section == _userButtonSection) {
      [self setUserDataAction:self];
    } else if (indexPath.section == _deleteButtonSection) {
      [self deleteAllMessagesAction:self];
    }
  }
}

#pragma mark - BITAttributedLabelDelegate

- (void)attributedLabel:(BITAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    UIActionSheet *linkAction = [[UIActionSheet alloc] initWithTitle:[url absoluteString]
                                                            delegate:self
                                                   cancelButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCancel")
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionOpen"), BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCopy"), nil
                                 ];
    [linkAction setTag:1];
    [linkAction setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    [linkAction showInView:[self viewForShowingActionSheetOnPhone]];
  } else {
    UIAlertView *linkAction = [[UIAlertView alloc] initWithTitle:[url absoluteString]
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCancel")
                                               otherButtonTitles:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionOpen"), BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCopy"), nil
                               ];
    
    [linkAction setTag:1];
    [linkAction show];
  }
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.cancelButtonIndex) {
    return;
  }
  
  if ([alertView tag] == 0) {
    if (buttonIndex == [alertView firstOtherButtonIndex]) {
      [self deleteAllMessages];
    }
  } else {
    if (buttonIndex == [alertView firstOtherButtonIndex]) {
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:alertView.title]];
    } else {
      UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
      pasteboard.URL = [NSURL URLWithString:alertView.title];
    }
  }
}


#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (buttonIndex == actionSheet.cancelButtonIndex) {
    return;
  }
  
  if ([actionSheet tag] == 0) {
    if (buttonIndex == [actionSheet destructiveButtonIndex]) {
      [self deleteAllMessages];
    }
  } else {
    if (buttonIndex == [actionSheet firstOtherButtonIndex]) {
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:actionSheet.title]];
    } else {
      UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
      pasteboard.URL = [NSURL URLWithString:actionSheet.title];
    }
  }
}


#pragma mark - ListViewCellDelegate

- (void)listCell:(id)cell didSelectAttachment:(BITFeedbackMessageAttachment *)attachment {
  QLPreviewController *previewController = [[QLPreviewController alloc] init];
  previewController.dataSource = self;
  
  [self presentViewController:previewController animated:YES completion:nil];
  
  if (self.cachedPreviewItems.count > [self.cachedPreviewItems indexOfObject:attachment]) {
    [previewController setCurrentPreviewItemIndex:[self.cachedPreviewItems indexOfObject:attachment]];
  }
}

- (void)refreshPreviewItems {
  self.cachedPreviewItems = nil;
  NSMutableArray *collectedAttachments = [NSMutableArray new];
  
  for (int i = 0; i < self.manager.numberOfMessages; i++) {
    BITFeedbackMessage *message = [self.manager messageAtIndex:i];
    [collectedAttachments addObjectsFromArray:message.previewableAttachments];
  }
  
  self.cachedPreviewItems = collectedAttachments;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
  if (!self.cachedPreviewItems){
    [self refreshPreviewItems];
  }
  
  return self.cachedPreviewItems.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
  if (index >= 0) {
    __weak QLPreviewController* blockController = controller;
    BITFeedbackMessageAttachment *attachment = self.cachedPreviewItems[index];
    
    if (attachment.needsLoadingFromURL && !attachment.isLoading) {
      attachment.isLoading = YES;
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:attachment.sourceURL]];
      [NSURLConnection sendAsynchronousRequest:request queue:self.thumbnailQueue completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *err) {
        attachment.isLoading = NO;
        if (responseData.length) {
          [attachment replaceData:responseData];
          [blockController reloadData];
          
          [[BITHockeyManager sharedHockeyManager].feedbackManager saveMessages];
        } else {
          [blockController reloadData];
        }
      }];
      
      return attachment;
    } else {
      return self.cachedPreviewItems[index];
    }
  }
  
  return nil;
}

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
