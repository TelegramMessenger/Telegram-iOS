/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde, Peter Steinberger.
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

#if HOCKEYSDK_FEATURE_UPDATES

#import "HockeySDKPrivate.h"
#import <QuartzCore/QuartzCore.h>
#import "BITHockeyHelper.h"
#import "BITAppVersionMetaInfo.h"
#import "BITAppStoreHeader.h"
#import "BITWebTableViewCell.h"
#import "BITStoreButton.h"

#import "BITUpdateManagerPrivate.h"
#import "BITUpdateViewControllerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"


#define kWebCellIdentifier @"PSWebTableViewCell"
#define kAppStoreViewHeight 99

@interface BITUpdateViewController ()

@property (nonatomic) BOOL kvoRegistered;
@property (nonatomic) BOOL showAllVersions;
@property (nonatomic, strong) BITAppStoreHeader *appStoreHeader;
@property (nonatomic, strong) BITStoreButton *appStoreButton;
@property (nonatomic, strong) id popOverController;
@property (nonatomic, strong) NSMutableArray *cells;
@property (nonatomic) BITEnvironment appEnvironment;

@end

@implementation BITUpdateViewController

#pragma mark - Private

- (UIColor *)backgroundColor {
  return BIT_RGBCOLOR(255, 255, 255);
}

- (void)restoreStoreButtonStateAnimated:(BOOL)animated {
  if (self.appEnvironment == BITEnvironmentAppStore) {
    [self setAppStoreButtonState:AppStoreButtonStateOffline animated:animated];
  } else if ([self.updateManager isUpdateAvailable]) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:animated];
  } else {
    [self setAppStoreButtonState:AppStoreButtonStateCheck animated:animated];
  }
}

- (void)updateAppStoreHeader {
  BITUpdateManager *strongManager = self.updateManager;
  BITAppVersionMetaInfo *appVersion = strongManager.newestAppVersion;
  self.appStoreHeader.headerText = appVersion.name;
  self.appStoreHeader.subHeaderText = strongManager.companyName;
}

- (void)appDidBecomeActive {
  if (self.appStoreButtonState == AppStoreButtonStateInstalling) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:YES];
  } else if (![self.updateManager isCheckInProgress]) {
    [self restoreStoreButtonStateAnimated:YES];
  }
}

- (UIImage *)addGlossToImage:(UIImage *)image {
  UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);
  
  [image drawAtPoint:CGPointZero];
  UIImage *iconGradient = bit_imageNamed(@"IconGradient.png", BITHOCKEYSDK_BUNDLE);
  [iconGradient drawInRect:CGRectMake(0, 0, image.size.width, image.size.height) blendMode:kCGBlendModeNormal alpha:0.5];
  
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return result;
}

#define kMinPreviousVersionButtonHeight 50
- (void)realignPreviousVersionButton {
  
  // manually collect actual table height size
  NSUInteger tableViewContentHeight = 0;
  for (int i=0; i < [self tableView:self.tableView numberOfRowsInSection:0]; i++) {
    tableViewContentHeight += [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
  }
  tableViewContentHeight += self.tableView.tableHeaderView.frame.size.height;
  tableViewContentHeight += self.navigationController.navigationBar.frame.size.height;
  tableViewContentHeight += [UIApplication sharedApplication].statusBarFrame.size.height;
  
  NSUInteger footerViewSize = kMinPreviousVersionButtonHeight;
  NSUInteger frameHeight = (NSUInteger)self.view.frame.size.height;
  if(tableViewContentHeight < frameHeight && (frameHeight - tableViewContentHeight > 100)) {
    footerViewSize = frameHeight - tableViewContentHeight;
  }
  
  // update footer view
  if(self.tableView.tableFooterView) {
    CGRect frame = self.tableView.tableFooterView.frame;
    frame.size.height = footerViewSize;
    self.tableView.tableFooterView.frame = frame;
  }
}

- (void)changePreviousVersionButtonBackground:(id)sender {
  [(UIButton *)sender setBackgroundColor:BIT_RGBCOLOR(245, 245, 245)];
}

- (void)changePreviousVersionButtonBackgroundHighlighted:(id)sender {
  [(UIButton *)sender setBackgroundColor:BIT_RGBCOLOR(245, 245, 245)];
}

- (UIImage *)gradientButtonHighlightImage {
  CGFloat width = 10;
  CGFloat height = 70;
  
  CGSize size = CGSizeMake(width, height);
  UIGraphicsBeginImageContextWithOptions(size, NO, 0);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
  
  NSArray *colors = [NSArray arrayWithObjects:(id)BIT_RGBCOLOR(69, 127, 247).CGColor, (id)BIT_RGBCOLOR(58, 68, 233).CGColor, nil];
  CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace((__bridge CGColorRef)[colors objectAtIndex:0]), (__bridge CFArrayRef)colors, (CGFloat[2]){0, 1});
  CGPoint top = CGPointMake(width / 2, 0);
  CGPoint bottom = CGPointMake(width / 2, height);
  CGContextDrawLinearGradient(context, gradient, top, bottom, 0);
  
  UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
  
  CGGradientRelease(gradient);
  CGColorSpaceRelease(colorspace);
  UIGraphicsEndImageContext();
  
  return theImage;
}

- (void)showHidePreviousVersionsButton {
  BOOL multipleVersionButtonNeeded = [self.updateManager.appVersions count] > 1 && !self.showAllVersions;
  
  if(multipleVersionButtonNeeded) {
    // align at the bottom if tableview is small
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kMinPreviousVersionButtonHeight)];
    footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    footerView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
    UIView *lineView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 1)];
    lineView1.backgroundColor = BIT_RGBCOLOR(214, 214, 214);
    lineView1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [footerView addSubview:lineView1];
    UIView *lineView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 1, self.view.frame.size.width, 1)];
    lineView2.backgroundColor = BIT_RGBCOLOR(221, 221, 221);
    lineView2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [footerView addSubview:lineView2];
    UIView *lineView3 = [[UIView alloc] initWithFrame:CGRectMake(0, 1, self.view.frame.size.width, 1)];
    lineView3.backgroundColor = BIT_RGBCOLOR(255, 255, 255);
    lineView3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [footerView addSubview:lineView3];
    UIButton *footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    //footerButton.layer.shadowOffset = CGSizeMake(-2, 2);
    footerButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    footerButton.layer.shadowRadius = 2.0;
    footerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [footerButton setTitle:BITHockeyLocalizedString(@"UpdateShowPreviousVersions") forState:UIControlStateNormal];
    [footerButton setTitleColor:BIT_RGBCOLOR(61, 61, 61) forState:UIControlStateNormal];
    [footerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [footerButton setBackgroundImage:[self gradientButtonHighlightImage] forState:UIControlStateHighlighted];
    footerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [footerButton addTarget:self action:@selector(showPreviousVersionAction) forControlEvents:UIControlEventTouchUpInside];
    footerButton.frame = CGRectMake(0, kMinPreviousVersionButtonHeight-44, self.view.frame.size.width, 44);
    footerButton.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
    [footerView addSubview:footerButton];
    self.tableView.tableFooterView = footerView;
    [self realignPreviousVersionButton];
  } else {
    self.tableView.tableFooterView = nil;
    self.tableView.backgroundColor = [self backgroundColor];
  }
}

- (void)configureWebCell:(BITWebTableViewCell *)cell forAppVersion:(BITAppVersionMetaInfo *)appVersion {
  // create web view for a version
  NSMutableString *dateAndSizeString = [NSMutableString string];
  if (appVersion.date) {
    [dateAndSizeString appendString:[appVersion dateString]];
  }
  if (appVersion.size) {
    if ([dateAndSizeString length]) {
      [dateAndSizeString appendString:@" - "];
    }
    [dateAndSizeString appendString:appVersion.sizeInMB];
  }
  
  NSString *installed = @"";
  BITUpdateManager *strongManager = self.updateManager;
  if ([appVersion.version isEqualToString:[strongManager currentAppVersion]]) {
    installed = [NSString stringWithFormat:@"<span style=\"float:right;\"><b>%@</b></span>", BITHockeyLocalizedString(@"UpdateInstalled")];
  }
  
  if ([appVersion isEqual:strongManager.newestAppVersion]) {
    if ([appVersion.notes length] > 0) {
      cell.webViewContent = [NSString stringWithFormat:@"<p><b>%@</b>%@<br/><small>%@</small></p><p>%@</p>", [appVersion versionString], installed, dateAndSizeString, appVersion.notes];
    } else {
      cell.webViewContent = [NSString stringWithFormat:@"<div style=\"min-height:130px;vertical-align:middle;text-align:center;\">%@</div>", BITHockeyLocalizedString(@"UpdateNoReleaseNotesAvailable")];
    }
  } else {
    cell.webViewContent = [NSString stringWithFormat:@"<p><b>%@</b>%@<br/><small>%@</small></p><p>%@</p>", [appVersion versionString], installed, dateAndSizeString, [appVersion notesOrEmptyString]];
  }
  cell.cellBackgroundColor = [self backgroundColor];
  [cell addWebView];
  // hack
  cell.textLabel.text = @"";
  
  [cell addObserver:self forKeyPath:@"webViewSize" options:0 context:nil];
}


#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewStyle) __unused style {
  if ((self = [super initWithStyle:UITableViewStylePlain])) {
    self.updateManager = [BITHockeyManager sharedHockeyManager].updateManager ;
    self.appEnvironment = [BITHockeyManager sharedHockeyManager].appEnvironment;
    
    self.title = BITHockeyLocalizedString(@"UpdateScreenTitle");
    
    self.cells = [[NSMutableArray alloc] initWithCapacity:5];
    self.popOverController = nil;
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  BITUpdateManager *strongManager = self.updateManager;
  // test if KVO's are registered. if class is destroyed before it was shown(viewDidLoad) no KVOs are registered.
  if (self.kvoRegistered) {
    [strongManager removeObserver:self forKeyPath:@"checkInProgress"];
    [strongManager removeObserver:self forKeyPath:@"isUpdateURLOffline"];
    [strongManager removeObserver:self forKeyPath:@"updateAvailable"];
    [strongManager removeObserver:self forKeyPath:@"appVersions"];
    self.kvoRegistered = NO;
  }
  
  for (UITableViewCell *cell in self.cells) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  // add notifications only to loaded view
  NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
  [dnc addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

  // hook into manager with kvo!
  BITUpdateManager *strongManager = self.updateManager;
  [strongManager addObserver:self forKeyPath:@"checkInProgress" options:0 context:nil];
  [strongManager addObserver:self forKeyPath:@"isUpdateURLOffline" options:0 context:nil];
  [strongManager addObserver:self forKeyPath:@"updateAvailable" options:0 context:nil];
  [strongManager addObserver:self forKeyPath:@"appVersions" options:0 context:nil];
  self.kvoRegistered = YES;
  
  self.tableView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, -(600-kAppStoreViewHeight), self.view.frame.size.width, 600)];
  topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  topView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  [self.tableView addSubview:topView];
  
  self.appStoreHeader = [[BITAppStoreHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kAppStoreViewHeight)];
  [self updateAppStoreHeader];
  
  NSString *iconFilename = bit_validAppIconFilename([NSBundle mainBundle], [NSBundle mainBundle]);
  if (iconFilename) {
    self.appStoreHeader.iconImage = [UIImage imageNamed:iconFilename];
  }
  
  self.tableView.tableHeaderView = self.appStoreHeader;
  
  BITStoreButton *storeButton = [[BITStoreButton alloc] initWithPadding:CGPointMake(5, 58) style:BITStoreButtonStyleOS7];
  storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  storeButton.buttonDelegate = self;
  [self.tableView.tableHeaderView addSubview:storeButton];
  storeButton.buttonData = [BITStoreButtonData dataWithLabel:@"" enabled:NO];
  [storeButton alignToSuperview];
  self.appStoreButton = storeButton;
  self.appStoreButtonState = AppStoreButtonStateCheck;
}

- (void)viewWillAppear:(BOOL)animated {
  if (self.appEnvironment != BITEnvironmentOther) {
    self.appStoreButtonState = AppStoreButtonStateOffline;
  } else if (self.mandatoryUpdate) {
    self.navigationItem.leftBarButtonItem = nil;
  }
  self.updateManager.currentHockeyViewController = self;
  [super viewWillAppear:animated];
  [self redrawTableView];
}

- (void)viewWillDisappear:(BOOL)animated {
  self.updateManager.currentHockeyViewController = nil;
  //if the popover is still visible, dismiss it
  [self.popOverController dismissPopoverAnimated:YES];
  [super viewWillDisappear:animated];
}

- (void)redrawTableView {
  [self restoreStoreButtonStateAnimated:NO];
  [self updateAppStoreHeader];
  
  // clean up and remove any pending observers
  for (UITableViewCell *cell in self.cells) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  [self.cells removeAllObjects];
  
  int i = 0;
  BOOL breakAfterThisAppVersion = NO;
  BITUpdateManager *stronManager = self.updateManager;
  for (BITAppVersionMetaInfo *appVersion in stronManager.appVersions) {
    i++;
    
    // only show the newer version of the app by default, if we don't show all versions
    if (!self.showAllVersions) {
      if ([appVersion.version isEqualToString:[stronManager currentAppVersion]]) {
        if (i == 1) {
          breakAfterThisAppVersion = YES;
        } else {
          break;
        }
      }
    }

    BITWebTableViewCell *cell = [self webCellWithAppVersion:appVersion];
    [self.cells addObject:cell];
    
    if (breakAfterThisAppVersion) break;
  }
  
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}

- (BITWebTableViewCell *)webCellWithAppVersion:(BITAppVersionMetaInfo *)appVersion {
  BITWebTableViewCell *cell = [[BITWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier];
  [self configureWebCell:cell forAppVersion:appVersion];
  return cell;
}

- (void)showPreviousVersionAction {
  self.showAllVersions = YES;
  BOOL showAllPending = NO;
  BITUpdateManager *strongManager = self.updateManager;
  for (BITAppVersionMetaInfo *appVersion in strongManager.appVersions) {
    if (!showAllPending) {
      if ([appVersion.version isEqualToString:[strongManager currentAppVersion]]) {
        showAllPending = YES;
        if (appVersion == strongManager.newestAppVersion) {
          continue; // skip this version already if it the latest version is the installed one
        }
      } else {
        continue; // skip already shown
      }
    }

    [self.cells addObject:[self webCellWithAppVersion:appVersion]];
  }
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *) __unused tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *) __unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat rowHeight = 0;
  
  if ([self.cells count] > (NSUInteger)indexPath.row) {
    BITWebTableViewCell *cell = [self.cells objectAtIndex:indexPath.row];
    rowHeight = cell.webViewSize.height;
  }
  
  if ([self.updateManager.appVersions count] > 1 && !self.showAllVersions) {
    self.tableView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  }
  
  if (rowHeight == 0) {
    rowHeight = indexPath.row == 0 ? 250 : 44; // fill screen on startup
    self.tableView.backgroundColor = [self backgroundColor];
  }
  
  return rowHeight;
}

- (NSInteger)tableView:(UITableView *) __unused tableView numberOfRowsInSection:(NSInteger) __unused section {
  NSInteger cellCount = [self.cells count];
  return cellCount;
}


#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id) __unused object change:(NSDictionary *) __unused change context:(void *) __unused context {
  // only make changes if we are visible
  if(self.view.window) {
    if ([keyPath isEqualToString:@"webViewSize"]) {
      [self.tableView reloadData];
      [self realignPreviousVersionButton];
    } else if ([keyPath isEqualToString:@"checkInProgress"]) {
      if (self.updateManager.isCheckInProgress) {
        [self setAppStoreButtonState:AppStoreButtonStateSearching animated:YES];
      }else {
        [self restoreStoreButtonStateAnimated:YES];
      }
    } else if ([keyPath isEqualToString:@"isUpdateURLOffline"]) {
      [self restoreStoreButtonStateAnimated:YES];
    } else if ([keyPath isEqualToString:@"updateAvailable"]) {
      [self restoreStoreButtonStateAnimated:YES];
    } else if ([keyPath isEqualToString:@"appVersions"]) {
      [self redrawTableView];
    }
  }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *) __unused tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if ([self.cells count] > (NSUInteger)indexPath.row) {
    return [self.cells objectAtIndex:indexPath.row];
  } else {
    BITHockeyLogWarning(@"Warning: cells_ and indexPath do not match? forgot calling redrawTableView? Returning empty UITableViewCell");
    return [UITableViewCell new];

  }
}


#pragma mark - Rotation

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation) __unused interfaceOrientation duration:(NSTimeInterval) __unused duration {
  // update all cells
  [self.cells makeObjectsPerformSelector:@selector(addWebView)];
}
#pragma clang diagnostic pop

#pragma mark - PSAppStoreHeaderDelegate

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState {
  [self setAppStoreButtonState:anAppStoreButtonState animated:NO];
}

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState animated:(BOOL)animated {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
  _appStoreButtonState = anAppStoreButtonState;
#pragma clang diagnostic pop
  
  switch (anAppStoreButtonState) {
    case AppStoreButtonStateOffline:
      [self.appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonOffline") enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateCheck:
      [self.appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonCheck") enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateSearching:
      [self.appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonSearching") enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateUpdate:
      [self.appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonUpdate") enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateInstalling:
      [self.appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonInstalling") enabled:NO] animated:animated];
      break;
    default:
      break;
  }
}

- (void)storeButtonFired:(BITStoreButton *) __unused button {
  BITUpdateManager *strongManager = self.updateManager;
  switch (self.appStoreButtonState) {
    case AppStoreButtonStateCheck:
      [strongManager checkForUpdateShowFeedback:YES];
      break;
    case AppStoreButtonStateUpdate:
      if ([strongManager initiateAppDownload]) {
        [self setAppStoreButtonState:AppStoreButtonStateInstalling animated:YES];
      };
      break;
    default:
      break;
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
