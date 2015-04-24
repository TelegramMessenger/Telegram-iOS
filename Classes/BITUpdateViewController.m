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


@implementation BITUpdateViewController {
  BOOL _kvoRegistered;
  BOOL _showAllVersions;
  BITAppStoreHeader *_appStoreHeader;
  BITStoreButton *_appStoreButton;
  
  id _popOverController;
  
  NSMutableArray *_cells;
  
  BOOL _isAppStoreEnvironment;
}


#pragma mark - Private

- (UIColor *)backgroundColor {
  if ([self.updateManager isPreiOS7Environment]) {
    return BIT_RGBCOLOR(235, 235, 235);
  } else {
    return BIT_RGBCOLOR(255, 255, 255);
  }
}

- (void)restoreStoreButtonStateAnimated:(BOOL)animated {
  if (_isAppStoreEnvironment) {
    [self setAppStoreButtonState:AppStoreButtonStateOffline animated:animated];
  } else if ([_updateManager isUpdateAvailable]) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:animated];
  } else {
    [self setAppStoreButtonState:AppStoreButtonStateCheck animated:animated];
  }
}

- (void)updateAppStoreHeader {
  BITAppVersionMetaInfo *appVersion = _updateManager.newestAppVersion;
  _appStoreHeader.headerText = appVersion.name;
  _appStoreHeader.subHeaderText = _updateManager.companyName;
}

- (void)appDidBecomeActive {
  if (self.appStoreButtonState == AppStoreButtonStateInstalling) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:YES];
  } else if (![_updateManager isCheckInProgress]) {
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
  if (![self.updateManager isPreiOS7Environment]) {
    tableViewContentHeight += self.navigationController.navigationBar.frame.size.height;
    tableViewContentHeight += [UIApplication sharedApplication].statusBarFrame.size.height;
  }
  
  NSUInteger footerViewSize = kMinPreviousVersionButtonHeight;
  NSUInteger frameHeight = self.view.frame.size.height;
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
  BOOL multipleVersionButtonNeeded = [_updateManager.appVersions count] > 1 && !_showAllVersions;
  
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
    footerButton.layer.shadowRadius = 2.0f;
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
  if ([appVersion.version isEqualToString:[_updateManager currentAppVersion]]) {
    installed = [NSString stringWithFormat:@"<span style=\"float:right;\"><b>%@</b></span>", BITHockeyLocalizedString(@"UpdateInstalled")];
  }
  
  if ([appVersion isEqual:_updateManager.newestAppVersion]) {
    if ([appVersion.notes length] > 0) {
      cell.webViewContent = [NSString stringWithFormat:@"<p><b>%@</b>%@<br/><small>%@</small></p><p>%@</p>", [appVersion versionString], installed, dateAndSizeString, appVersion.notes];
    } else {
      if ([self.updateManager isPreiOS7Environment]) {
        cell.webViewContent = [NSString stringWithFormat:@"<div style=\"min-height:200px;vertical-align:middle;text-align:center;\">%@</div>", BITHockeyLocalizedString(@"UpdateNoReleaseNotesAvailable")];
      } else {
        cell.webViewContent = [NSString stringWithFormat:@"<div style=\"min-height:130px;vertical-align:middle;text-align:center;\">%@</div>", BITHockeyLocalizedString(@"UpdateNoReleaseNotesAvailable")];
      }
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

- (instancetype)initWithStyle:(UITableViewStyle)style {
  if ((self = [super initWithStyle:UITableViewStylePlain])) {
    _updateManager = [BITHockeyManager sharedHockeyManager].updateManager ;
    _isAppStoreEnvironment = [BITHockeyManager sharedHockeyManager].isAppStoreEnvironment;

    self.title = BITHockeyLocalizedString(@"UpdateScreenTitle");
    
    _cells = [[NSMutableArray alloc] initWithCapacity:5];
    _popOverController = nil;
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // test if KVO's are registered. if class is destroyed before it was shown(viewDidLoad) no KVOs are registered.
  if (_kvoRegistered) {
    [_updateManager removeObserver:self forKeyPath:@"checkInProgress"];
    [_updateManager removeObserver:self forKeyPath:@"isUpdateURLOffline"];
    [_updateManager removeObserver:self forKeyPath:@"updateAvailable"];
    [_updateManager removeObserver:self forKeyPath:@"appVersions"];
    _kvoRegistered = NO;
  }
  
  for (UITableViewCell *cell in _cells) {
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
  [_updateManager addObserver:self forKeyPath:@"checkInProgress" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"isUpdateURLOffline" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"updateAvailable" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"appVersions" options:0 context:nil];
  _kvoRegistered = YES;
  
  self.tableView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, -(600-kAppStoreViewHeight), self.view.frame.size.width, 600)];
  topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  topView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  [self.tableView addSubview:topView];
  
  _appStoreHeader = [[BITAppStoreHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kAppStoreViewHeight)];
  if ([self.updateManager isPreiOS7Environment]) {
    _appStoreHeader.style = BITAppStoreHeaderStyleDefault;
  } else {
    _appStoreHeader.style = BITAppStoreHeaderStyleOS7;
  }
  [self updateAppStoreHeader];
  
  NSString *iconFilename = bit_validAppIconFilename([NSBundle mainBundle], [NSBundle mainBundle]);
  if (iconFilename) {
    BOOL addGloss = YES;
    NSNumber *prerendered = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIPrerenderedIcon"];
    if (prerendered) {
      addGloss = ![prerendered boolValue];
    }
    
    if (addGloss && [self.updateManager isPreiOS7Environment]) {
      _appStoreHeader.iconImage = [self addGlossToImage:[UIImage imageNamed:iconFilename]];
    } else {
      _appStoreHeader.iconImage = [UIImage imageNamed:iconFilename];
    }
  }
  
  self.tableView.tableHeaderView = _appStoreHeader;
  
  BITStoreButtonStyle buttonStyle = BITStoreButtonStyleDefault;
  if (![self.updateManager isPreiOS7Environment]) {
    buttonStyle = BITStoreButtonStyleOS7;
  }
  BITStoreButton *storeButton = [[BITStoreButton alloc] initWithPadding:CGPointMake(5, 58) style:buttonStyle];
  storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  storeButton.buttonDelegate = self;
  [self.tableView.tableHeaderView addSubview:storeButton];
  storeButton.buttonData = [BITStoreButtonData dataWithLabel:@"" enabled:NO];
  [storeButton alignToSuperview];
  _appStoreButton = storeButton;
  self.appStoreButtonState = AppStoreButtonStateCheck;
}

- (void)viewWillAppear:(BOOL)animated {
  if (_isAppStoreEnvironment) {
    self.appStoreButtonState = AppStoreButtonStateOffline;
  } else if (self.mandatoryUpdate) {
    self.navigationItem.leftBarButtonItem = nil;
  }
  _updateManager.currentHockeyViewController = self;
  [super viewWillAppear:animated];
  [self redrawTableView];
}

- (void)viewWillDisappear:(BOOL)animated {
  _updateManager.currentHockeyViewController = nil;
  //if the popover is still visible, dismiss it
  [_popOverController dismissPopoverAnimated:YES];
  [super viewWillDisappear:animated];
}

- (void)redrawTableView {
  [self restoreStoreButtonStateAnimated:NO];
  [self updateAppStoreHeader];
  
  // clean up and remove any pending observers
  for (UITableViewCell *cell in _cells) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  [_cells removeAllObjects];
  
  int i = 0;
  BOOL breakAfterThisAppVersion = NO;
  for (BITAppVersionMetaInfo *appVersion in _updateManager.appVersions) {
    i++;
    
    // only show the newer version of the app by default, if we don't show all versions
    if (!_showAllVersions) {
      if ([appVersion.version isEqualToString:[_updateManager currentAppVersion]]) {
        if (i == 1) {
          breakAfterThisAppVersion = YES;
        } else {
          break;
        }
      }
    }
    
    BITWebTableViewCell *cell = [[BITWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier];
    [self configureWebCell:cell forAppVersion:appVersion];
    [_cells addObject:cell];
    
    if (breakAfterThisAppVersion) break;
  }
  
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}

- (void)showPreviousVersionAction {
  _showAllVersions = YES;
  BOOL showAllPending = NO;
  
  for (BITAppVersionMetaInfo *appVersion in _updateManager.appVersions) {
    if (!showAllPending) {
      if ([appVersion.version isEqualToString:[_updateManager currentAppVersion]]) {            
        showAllPending = YES;
        if (appVersion == _updateManager.newestAppVersion) {
          continue; // skip this version already if it the latest version is the installed one
        }
      } else {
        continue; // skip already shown
      }
    }
    
    BITWebTableViewCell *cell = [[BITWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier];
    [self configureWebCell:cell forAppVersion:appVersion];
    [_cells addObject:cell];
  }
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat rowHeight = 0;
  
  if ([_cells count] > (NSUInteger)indexPath.row) {
    BITWebTableViewCell *cell = [_cells objectAtIndex:indexPath.row];
    rowHeight = cell.webViewSize.height;
  }
  
  if ([_updateManager.appVersions count] > 1 && !_showAllVersions) {
    self.tableView.backgroundColor = BIT_RGBCOLOR(245, 245, 245);
  }
  
  if (rowHeight == 0) {
    rowHeight = indexPath.row == 0 ? 250 : 44; // fill screen on startup
    self.tableView.backgroundColor = [self backgroundColor];
  }
  
  return rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSInteger cellCount = [_cells count];
  return cellCount;
}


#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  // only make changes if we are visible
  if(self.view.window) {
    if ([keyPath isEqualToString:@"webViewSize"]) {
      [self.tableView reloadData];
      [self realignPreviousVersionButton];
    } else if ([keyPath isEqualToString:@"checkInProgress"]) {
      if (_updateManager.isCheckInProgress) {
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
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if ([_cells count] > (NSUInteger)indexPath.row) {
    return [_cells objectAtIndex:indexPath.row];
  } else {
    BITHockeyLog(@"Warning: cells_ and indexPath do not match? forgot calling redrawTableView?");
  }
  return nil;
}


#pragma mark - Rotation

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
  // update all cells
  [_cells makeObjectsPerformSelector:@selector(addWebView)];
}


#pragma mark - PSAppStoreHeaderDelegate

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState {
  [self setAppStoreButtonState:anAppStoreButtonState animated:NO];
}

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState animated:(BOOL)animated {
  _appStoreButtonState = anAppStoreButtonState;
  
  switch (anAppStoreButtonState) {
    case AppStoreButtonStateOffline:
      [_appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonOffline") enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateCheck:
      [_appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonCheck") enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateSearching:
      [_appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonSearching") enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateUpdate:
      [_appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonUpdate") enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateInstalling:
      [_appStoreButton setButtonData:[BITStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonInstalling") enabled:NO] animated:animated];
      break;
    default:
      break;
  }
}

- (void)storeButtonFired:(BITStoreButton *)button {
  switch (_appStoreButtonState) {
    case AppStoreButtonStateCheck:
      [_updateManager checkForUpdateShowFeedback:YES];
      break;
    case AppStoreButtonStateUpdate:
      if ([_updateManager initiateAppDownload]) {
        [self setAppStoreButtonState:AppStoreButtonStateInstalling animated:YES];
      };
      break;
    default:
      break;
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
