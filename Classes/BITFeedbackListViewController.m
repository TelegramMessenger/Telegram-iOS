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

#define DEFAULT_TEXTCOLOR BIT_RGBCOLOR(75, 75, 75)

#define BORDER_COLOR BIT_RGBCOLOR(215, 215, 215)


@interface BITFeedbackListViewController () <BITFeedbackUserDataDelegate, BITFeedbackComposeViewControllerDelegate, BITAttributedLabelDelegate, BITFeedbackListViewCellDelegate>

@property (nonatomic, weak) BITFeedbackManager *manager;
@property (nonatomic, strong) NSDateFormatter *lastUpdateDateFormatter;
@property (nonatomic) BOOL userDataComposeFlow;
@property (nonatomic, strong) NSArray *cachedPreviewItems;
@property (nonatomic, strong) NSOperationQueue *thumbnailQueue;
@property (nonatomic) NSInteger deleteButtonSection;
@property (nonatomic) NSInteger userButtonSection;
@property (nonatomic) NSInteger numberOfSectionsBeforeRotation;
@property (nonatomic) NSInteger numberOfMessagesBeforeRotation;

@end


@implementation BITFeedbackListViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
  if ((self = [super initWithStyle:style])) {
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    
    _deleteButtonSection = -1;
    self.userButtonSection = -1;
    _userDataComposeFlow = NO;
    
    _numberOfSectionsBeforeRotation = -1;
    _numberOfMessagesBeforeRotation = -1;
    
    
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

  if ([UIRefreshControl class]) {
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reloadList) forControlEvents:UIControlEventValueChanged];
  } else {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(reloadList)];
  }
}

- (void)startLoadingIndicator {
  if ([UIRefreshControl class]) {
    [self.refreshControl beginRefreshing];
  } else {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
}

- (void)stopLoadingIndicator {
  if ([UIRefreshControl class]) {
    [self.refreshControl endRefreshing];
  } else {
    self.navigationItem.rightBarButtonItem.enabled = YES;
  }
}

- (BOOL)isRefreshingWithNewControl {
  if ([UIRefreshControl class]) {
    return [self.refreshControl isRefreshing];
  }
  return NO;
}

- (void)reloadList {
  [self startLoadingIndicator];
  
  [self.manager updateMessagesList];
}

- (void)updateList {
  dispatch_async(dispatch_get_main_queue(), ^{
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
  });
}

- (void)viewDidAppear:(BOOL)animated {
  if (self.userDataComposeFlow) {
    self.userDataComposeFlow = NO;
  }
  BITFeedbackManager *strongManager = self.manager;
  strongManager.currentFeedbackListViewController = self;
  
  [strongManager updateMessagesListIfRequired];
  
  if ([strongManager numberOfMessages] == 0 &&
      [strongManager askManualUserDataAvailable] &&
      [strongManager requireManualUserDataMissing] &&
      ![strongManager didAskUserData]
      ) {
    self.userDataComposeFlow = YES;
    
    if ([strongManager showFirstRequiredPresentationModal]) {
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

- (void)setUserDataAction:(id) __unused sender {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:userController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)newFeedbackAction:(id) __unused sender {
  BITFeedbackManager *strongManager = self.manager;
  BITFeedbackComposeViewController *composeController = [strongManager feedbackComposeViewController];
  
  UINavigationController *navController = [strongManager customNavigationControllerWithRootViewController:composeController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

- (void)deleteAllMessages {
  [self.manager deleteAllMessages];
  [self refreshPreviewItems];
  
  [self.tableView reloadData];
}

- (void)deleteAllMessagesAction:(id) __unused sender {
  NSString *title = BITHockeyLocalizedString(@"HockeyFeedbackListButtonDeleteAllMessages");
  NSString *message = BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllTitle");
  UIAlertControllerStyle controllerStyle = UIAlertControllerStyleAlert;
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    controllerStyle = UIAlertControllerStyleActionSheet;
    title = BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllTitle");
    message = nil;
  }
  __weak typeof(self) weakSelf = self;
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                           message:message
                                                                    preferredStyle:controllerStyle];
  UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllCancel")
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction __unused *action) {}];
  [alertController addAction:cancelAction];
  UIAlertAction* deleteAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListDeleteAllDelete")
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction __unused *action) {
                                                         typeof(self) strongSelf = weakSelf;
                                                         [strongSelf deleteAllMessages];
                                                       }];
  [alertController addAction:deleteAction];
  [self presentViewController:alertController animated:YES completion:nil];
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
  BITFeedbackManager *strongManager = self.manager;
  [strongManager saveMessages];
  [self refreshPreviewItems];
  
  if (self.userDataComposeFlow) {
    if ([strongManager showFirstRequiredPresentationModal]) {
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
  BITFeedbackManager *strongManager = self.manager;
  if (self.userDataComposeFlow) {
    if ([strongManager showFirstRequiredPresentationModal]) {
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
  id strongDelegate = strongManager.delegate;
  if ([strongDelegate respondsToSelector:@selector(feedbackComposeViewController:didFinishWithResult:)]) {
    [strongDelegate feedbackComposeViewController:composeViewController didFinishWithResult:composeResult];
  }
}


#pragma mark - UIViewController Rotation

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  self.numberOfSectionsBeforeRotation = [self numberOfSectionsInTableView:self.tableView];
  self.numberOfMessagesBeforeRotation = [self.manager numberOfMessages];
  [self.tableView reloadData];
  [self.tableView beginUpdates];
  [self.tableView endUpdates];
  
  self.numberOfSectionsBeforeRotation = -1;
  self.numberOfMessagesBeforeRotation = -1;
  [self.tableView reloadData];
  
  [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}
#pragma clang diagnostic pop

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
  return UIInterfaceOrientationMaskAll;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *) __unused tableView {
  if (self.numberOfSectionsBeforeRotation >= 0)
    return self.numberOfSectionsBeforeRotation;
  
  NSInteger sections = 2;
  self.deleteButtonSection = -1;
  self.userButtonSection = -1;
  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager isManualUserDataAvailable] || [strongManager didAskUserData]) {
    self.userButtonSection = sections;
    sections++;
  }
  
  if ([strongManager numberOfMessages] > 0) {
    self.deleteButtonSection = sections;
    sections++;
  }
  
  return sections;
}

- (NSInteger)tableView:(UITableView *) __unused tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) {
    if (self.numberOfMessagesBeforeRotation >= 0)
      return self.numberOfMessagesBeforeRotation;
    return [self.manager numberOfMessages];
  } else {
    return 1;
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    return 30;
  }
  return [super tableView:tableView heightForHeaderInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    BITFeedbackManager *strongManager = self.manager;
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 30.0)];
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 5.0, self.view.frame.size.width - (CGFloat)32.0, 25.0)];
    textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                      [strongManager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[strongManager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
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
  BITFeedbackManager *strongManager = self.manager;
  if (indexPath.section == 0 && indexPath.row == 1) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LastUpdateIdentifier];
    
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LastUpdateIdentifier];
      cell.textLabel.font = [UIFont systemFontOfSize:10];
      cell.textLabel.textColor = DEFAULT_TEXTCOLOR;
      cell.accessoryType = UITableViewCellAccessoryNone;
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    cell.textLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
    cell.textLabel.text = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListLastUpdated"),
                           [strongManager lastCheck] ? [self.lastUpdateDateFormatter stringFromDate:[strongManager lastCheck]] : BITHockeyLocalizedString(@"HockeyFeedbackListNeverUpdated")];
    
    return cell;
  } else if (indexPath.section == 0 || indexPath.section >= 2) {
    UITableViewCell *cell = nil;
    
    NSString *identifier = nil;
    if (indexPath.section == 0) {
      identifier = ButtonTopIdentifier;
    } else if (indexPath.section == self.userButtonSection) {
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
      cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    
    // Set accessibilityTraits to UIAccessibilityTraitNone to make sure we're not setting the trait to an incorrect type for recycled cells.
    cell.textLabel.accessibilityTraits = UIAccessibilityTraitNone;
    
    // button
    NSString *titleString = nil;
    
    UIColor *titleColor = BIT_RGBCOLOR(35, 111, 251);
    if ([self.view respondsToSelector:@selector(tintColor)]){
      titleColor = self.view.tintColor;
    }
    if (indexPath.section == 0) {
      cell.textLabel.accessibilityTraits = UIAccessibilityTraitButton;
      if ([strongManager numberOfMessages] == 0) {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonWriteFeedback");
      } else {
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonWriteResponse");
      }
    } else if (indexPath.section == self.userButtonSection) {
      if ([strongManager requireUserName] == BITFeedbackUserDataElementRequired ||
          ([strongManager requireUserName] == BITFeedbackUserDataElementOptional && [strongManager userName] != nil)
          ) {
        cell.textLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
        titleString = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataWithName"), [strongManager userName] ?: @"-"];
      } else if ([strongManager requireUserEmail] == BITFeedbackUserDataElementRequired ||
                 ([strongManager requireUserEmail] == BITFeedbackUserDataElementOptional && [strongManager userEmail] != nil)
                 ) {
        cell.textLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
        titleString = [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataWithEmail"), [strongManager userEmail] ?: @"-"];
      } else if ([strongManager requireUserName] == BITFeedbackUserDataElementOptional) {
        cell.textLabel.accessibilityTraits = UIAccessibilityTraitButton;
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataSetName");
      } else {
        cell.textLabel.accessibilityTraits = UIAccessibilityTraitButton;
        titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonUserDataSetEmail");
      }
    } else {
      cell.textLabel.accessibilityTraits = UIAccessibilityTraitButton;
      titleString = BITHockeyLocalizedString(@"HockeyFeedbackListButtonDeleteAllMessages");
      titleColor = BIT_RGBCOLOR(251, 35, 35);
    }

    cell.textLabel.text = titleString;
    cell.textLabel.textColor = titleColor;

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

    BITFeedbackMessage *message = [strongManager messageAtIndex:indexPath.row];
    cell.message = message;
    cell.labelText.delegate = self;
    cell.labelText.userInteractionEnabled = YES;
    cell.delegate = self;
    [cell setAttachments:message.previewableAttachments];
    
    for (BITFeedbackMessageAttachment *attachment in message.attachments){
      if (attachment.needsLoadingFromURL && !attachment.isLoading){
        attachment.isLoading = YES;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:(NSURL *)[NSURL URLWithString:attachment.sourceURL]];
        __weak typeof (self) weakSelf = self;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler: ^(NSData *data, NSURLResponse __unused *response, NSError *error) {
                                                  typeof (self) strongSelf = weakSelf;

                                                  [session finishTasksAndInvalidate];

                                                  [strongSelf handleResponseForAttachment:attachment responseData:data error:error];
                                                }];
        [task resume];
      }
    }

    if (indexPath.row != 0) {
      UIView *lineView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, 1)];
      lineView1.backgroundColor = BORDER_COLOR;
      lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [cell addSubview:lineView1];
    }
    
    return cell;
  }
}

- (void)handleResponseForAttachment:(BITFeedbackMessageAttachment *)attachment responseData:(NSData *)responseData error:(NSError *) __unused error {
  attachment.isLoading = NO;
  if (responseData.length) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [attachment replaceData:responseData];
      [[NSNotificationCenter defaultCenter] postNotificationName:kBITFeedbackUpdateAttachmentThumbnail object:attachment];
      [[BITHockeyManager sharedHockeyManager].feedbackManager saveMessages];
      [self.tableView reloadData];
    });
  }
}


- (BOOL)tableView:(UITableView *) __unused tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 1)
    return YES;
  
  return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    BITFeedbackManager *strongManager = self.manager;
    BITFeedbackMessage *message = [strongManager messageAtIndex:indexPath.row];
    BOOL messageHasAttachments = ([message attachments].count > 0);
    
    if ([strongManager deleteMessageAtIndex:indexPath.row]) {
      if ([strongManager numberOfMessages] > 0) {
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

- (CGFloat)tableView:(UITableView *) __unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 ) {
    return 44;
  }
  if (indexPath.section >= 2) {
    return 44;
  }
  
  BITFeedbackMessage *message = [self.manager messageAtIndex:indexPath.row];
  if (!message) return 44;
  
  return [BITFeedbackListViewCell heightForRowWithMessage:message tableViewWidth:self.view.frame.size.width];
}

- (void)tableView:(UITableView *) __unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0) {
    [self newFeedbackAction:self];
  } else if (indexPath.section == self.userButtonSection) {
    [self setUserDataAction:self];
  } else if (indexPath.section == self.deleteButtonSection) {
    [self deleteAllMessagesAction:self];
  }
}

#pragma mark - BITAttributedLabelDelegate

- (void)attributedLabel:(BITAttributedLabel *) __unused label didSelectLinkWithURL:(NSURL *)url {
  UIAlertControllerStyle controllerStyle = UIAlertControllerStyleAlert;
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    controllerStyle = UIAlertControllerStyleActionSheet;
  }
  UIAlertController *linkAction = [UIAlertController alertControllerWithTitle:[url absoluteString]
                                                                      message:nil
                                                               preferredStyle:controllerStyle];
  UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCancel")
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction __unused *action) {}];
  [linkAction addAction:cancelAction];
  UIAlertAction* openAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionOpen")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction __unused *action) {
                                                       [[UIApplication sharedApplication] openURL:(NSURL*)[NSURL URLWithString:(NSString*)[url absoluteString]]];
                                                     }];
  [linkAction addAction:openAction];
  UIAlertAction* copyAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackListLinkActionCopy")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction __unused *action) {
                                                       UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                                       pasteboard.URL = [NSURL URLWithString:(NSString*)[url absoluteString]];
                                                     }];
  [linkAction addAction:copyAction];
  [self presentViewController:linkAction animated:YES completion:nil];
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
      [[UIApplication sharedApplication] openURL:(NSURL *)[NSURL URLWithString:actionSheet.title]];
    } else {
      UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
      pasteboard.URL = [NSURL URLWithString:actionSheet.title];
    }
  }
}

#pragma mark - ListViewCellDelegate

- (void)listCell:(id) __unused cell didSelectAttachment:(BITFeedbackMessageAttachment *)attachment {
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
  BITFeedbackManager *strongManager = self.manager;
  for (uint i = 0; i < strongManager.numberOfMessages; i++) {
    BITFeedbackMessage *message = [strongManager messageAtIndex:i];
    [collectedAttachments addObjectsFromArray:message.previewableAttachments];
  }
  
  self.cachedPreviewItems = collectedAttachments;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *) __unused controller {
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
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:(NSURL *)[NSURL URLWithString:attachment.sourceURL]];
      
      __weak typeof (self) weakSelf = self;
      NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
      __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

      NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                              completionHandler: ^(NSData *data, NSURLResponse __unused *response, NSError __unused *error) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                  typeof (self) strongSelf = weakSelf;

                                                  [session finishTasksAndInvalidate];

                                                  [strongSelf previewController:blockController updateAttachment:attachment data:data];
                                                });
                                              }];
      [task resume];
      return attachment;
    } else {
      return self.cachedPreviewItems[index];
    }
  }
  
  return [self placeholder];
}

- (void)previewController:(QLPreviewController *)controller updateAttachment:(BITFeedbackMessageAttachment *)attachment data:( NSData *)data {
  attachment.isLoading = NO;
  if (data.length) {
    [attachment replaceData:data];
    [controller reloadData];
    
    [[BITHockeyManager sharedHockeyManager].feedbackManager saveMessages];
  } else {
    [controller reloadData];
  }
}

- (BITFeedbackMessageAttachment *)placeholder {
  UIImage *placeholderImage = bit_imageNamed(@"FeedbackPlaceHolder", BITHOCKEYSDK_BUNDLE);

  BITFeedbackMessageAttachment *placeholder = [BITFeedbackMessageAttachment attachmentWithData:UIImageJPEGRepresentation(placeholderImage, (CGFloat)0.7) contentType:@"image/jpeg"];
  
  return placeholder;
}

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
