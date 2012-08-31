/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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

#import <QuartzCore/QuartzCore.h>
#import "BITHockeyHelper.h"
#import "BITAppVersionMetaInfo.h"
#import "PSAppStoreHeader.h"
#import "PSWebTableViewCell.h"
#import "PSStoreButton.h"

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"

#import "BITUpdateManagerPrivate.h"
#import "BITUpdateViewControllerPrivate.h"


#define BIT_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define kWebCellIdentifier @"PSWebTableViewCell"
#define kAppStoreViewHeight 90


@implementation BITUpdateViewController

@synthesize appStoreButtonState = _appStoreButtonState;
@synthesize modal = _modal;
@synthesize modalAnimated = _modalAnimated;


#pragma mark - Private

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
  _appStoreHeader.headerLabel = appVersion.name;
  _appStoreHeader.middleHeaderLabel = [appVersion versionString];
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  [formatter setDateStyle:NSDateFormatterMediumStyle];
  NSMutableString *subHeaderString = [NSMutableString string];
  if (appVersion.date) {
    [subHeaderString appendString:[formatter stringFromDate:appVersion.date]];
  }
  if (appVersion.size) {
    if ([subHeaderString length]) {
      [subHeaderString appendString:@" - "];
    }
    [subHeaderString appendString:appVersion.sizeInMB];
  }
  _appStoreHeader.subHeaderLabel = subHeaderString;
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
  [(UIButton *)sender setBackgroundColor:BIT_RGBCOLOR(183,183,183)];
}

- (void)changePreviousVersionButtonBackgroundHighlighted:(id)sender {
  [(UIButton *)sender setBackgroundColor:BIT_RGBCOLOR(183,183,183)];
}

- (void)showHidePreviousVersionsButton {
  BOOL multipleVersionButtonNeeded = [_updateManager.appVersions count] > 1 && !_showAllVersions;
  
  if(multipleVersionButtonNeeded) {
    // align at the bottom if tableview is small
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kMinPreviousVersionButtonHeight)];
    footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    footerView.backgroundColor = BIT_RGBCOLOR(200, 202, 204);
    UIButton *footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    //footerButton.layer.shadowOffset = CGSizeMake(-2, 2);
    footerButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    footerButton.layer.shadowRadius = 2.0f;
    footerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [footerButton setTitle:BITHockeyLocalizedString(@"UpdateShowPreviousVersions") forState:UIControlStateNormal];
    [footerButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [footerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [footerButton setBackgroundImage:bit_imageNamed(@"buttonHighlight.png", BITHOCKEYSDK_BUNDLE) forState:UIControlStateHighlighted];
    footerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [footerButton addTarget:self action:@selector(showPreviousVersionAction) forControlEvents:UIControlEventTouchUpInside];
    footerButton.frame = CGRectMake(0, kMinPreviousVersionButtonHeight-44, self.view.frame.size.width, 44);
    footerButton.backgroundColor = BIT_RGBCOLOR(183,183,183);
    [footerView addSubview:footerButton];
    self.tableView.tableFooterView = footerView;
    [self realignPreviousVersionButton];
    [footerView release];
  } else {
    self.tableView.tableFooterView = nil;
    self.tableView.backgroundColor = BIT_RGBCOLOR(200, 202, 204);
  }
}

- (void)configureWebCell:(PSWebTableViewCell *)cell forAppVersion:(BITAppVersionMetaInfo *)appVersion {
  // create web view for a version
  NSString *installed = @"";
  if ([appVersion.version isEqualToString:[_updateManager currentAppVersion]]) {
    installed = [NSString stringWithFormat:@"<span style=\"float:%@;text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\"><b>%@</b></span>", [appVersion isEqual:_updateManager.newestAppVersion] ? @"left" : @"right", BITHockeyLocalizedString(@"UpdateInstalled")];
  }
  
  if ([appVersion isEqual:_updateManager.newestAppVersion]) {
    if ([appVersion.notes length] > 0) {
      installed = [NSString stringWithFormat:@"<p>&nbsp;%@</p>", installed];
      cell.webViewContent = [NSString stringWithFormat:@"%@%@", installed, appVersion.notes];
    } else {
      cell.webViewContent = [NSString stringWithFormat:@"<div style=\"min-height:200px;vertical-align:middle;text-align:center;text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\">%@</div>", BITHockeyLocalizedString(@"UpdateNoReleaseNotesAvailable")];
    }
  } else {
    cell.webViewContent = [NSString stringWithFormat:@"<p><b style=\"text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\">%@</b>%@<br/><small>%@</small></p><p>%@</p>", [appVersion versionString], installed, [appVersion dateString], [appVersion notesOrEmptyString]];
  }
  cell.cellBackgroundColor = BIT_RGBCOLOR(200, 202, 204);
  
  [cell addWebView];
  // hack
  cell.textLabel.text = @"";
  
  [cell addObserver:self forKeyPath:@"webViewSize" options:0 context:nil];
}


#pragma mark - Init

- (id)init:(BITUpdateManager *)newUpdateManager modal:(BOOL)newModal {
  if ((self = [super initWithStyle:UITableViewStylePlain])) {
    self.updateManager = newUpdateManager;
    self.modal = newModal;
    self.modalAnimated = YES;
    self.title = BITHockeyLocalizedString(@"UpdateScreenTitle");
    
    _isAppStoreEnvironment = [BITHockeyManager sharedHockeyManager].isAppStoreEnvironment;
        
    _cells = [[NSMutableArray alloc] initWithCapacity:5];
    _popOverController = nil;
    
    //might be better in viewDidLoad, but to workaround rdar://12214613 and as it doesn't
    //hurt, we do it here
    if (self.modal) {
      self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(onAction:)] autorelease];
    }
  }
  return self;
}

- (id)init {
	return [self init:[BITHockeyManager sharedHockeyManager].updateManager modal:NO];
}

- (void)dealloc {
  [self viewDidUnload];
  for (UITableViewCell *cell in _cells) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  [_cells release];
  [super dealloc];
}


#pragma mark - View lifecycle

- (void)onAction:(id)sender {
  if (self.modal) {
    // Note that as of 5.0, parentViewController will no longer return the presenting view controller
    SEL presentingViewControllerSelector = NSSelectorFromString(@"presentingViewController");
    UIViewController *presentingViewController = nil;
    if ([self respondsToSelector:presentingViewControllerSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
      presentingViewController = [self performSelector:presentingViewControllerSelector];
#pragma clang diagnostic pop
    }
    else {
      presentingViewController = [self parentViewController];
    }
    
    // If there is no presenting view controller just remove view
    if (presentingViewController && self.modalAnimated) {
      [presentingViewController dismissModalViewControllerAnimated:YES];
    }
    else {
      [self.navigationController.view removeFromSuperview];
    }
  }
  else {
    [self.navigationController popViewControllerAnimated:YES];
  }
  
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}

- (CAGradientLayer *)backgroundLayer {
  UIColor *colorOne	= [UIColor colorWithWhite:0.9 alpha:1.0];
  UIColor *colorTwo	= [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.85 alpha:1.0];
  UIColor *colorThree	= [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.7 alpha:1.0];
  UIColor *colorFour	= [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.4 alpha:1.0];
  
  NSArray *colors     = [NSArray arrayWithObjects:(id)colorOne.CGColor, colorTwo.CGColor, colorThree.CGColor, colorFour.CGColor, nil];
  
  NSNumber *stopOne	= [NSNumber numberWithFloat:0.0];
  NSNumber *stopTwo	= [NSNumber numberWithFloat:0.02];
  NSNumber *stopThree = [NSNumber numberWithFloat:0.99];
  NSNumber *stopFour  = [NSNumber numberWithFloat:1.0];
  
  NSArray *locations  = [NSArray arrayWithObjects:stopOne, stopTwo, stopThree, stopFour, nil];
  
  CAGradientLayer *headerLayer = [CAGradientLayer layer];
  //headerLayer.frame = CGRectMake(0.0, 0.0, 320.0, 77.0);
  headerLayer.colors = colors;
  headerLayer.locations = locations;
  
  return headerLayer;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  // add notifications only to loaded view
  NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
  [dnc addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
  
  // hook into manager with kvo!
  [_updateManager addObserver:self forKeyPath:@"checkInProgress" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"isUpdateURLOffline" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"updateAvailable" options:0 context:nil];
  [_updateManager addObserver:self forKeyPath:@"apps" options:0 context:nil];
  _kvoRegistered = YES;
  
  self.tableView.backgroundColor = BIT_RGBCOLOR(200, 202, 204);
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  UIView *topView = [[[UIView alloc] initWithFrame:CGRectMake(0, -(600-kAppStoreViewHeight), self.view.frame.size.width, 600)] autorelease];
  topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  topView.backgroundColor = BIT_RGBCOLOR(140, 141, 142);
  [self.tableView addSubview:topView];
  
  _appStoreHeader = [[PSAppStoreHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kAppStoreViewHeight)];
  [self updateAppStoreHeader];
  
  NSString *iconString = nil;
  NSArray *icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFiles"];
  if (!icons) {
    icons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
    if ((icons) && ([icons isKindOfClass:[NSDictionary class]])) {
      icons = [icons valueForKeyPath:@"CFBundlePrimaryIcon.CFBundleIconFiles"];
    }
    
    if (!icons) {
      iconString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
      if (!iconString) {
        iconString = @"Icon.png";
      }
    }
  } 
  
  if (icons) {
    BOOL useHighResIcon = NO;
    if ([UIScreen mainScreen].scale == 2.0f) useHighResIcon = YES;
    
    for(NSString *icon in icons) {
      iconString = icon;
      UIImage *iconImage = [UIImage imageNamed:icon];
      
      if (iconImage.size.height == 57 && !useHighResIcon) {
        // found!
        break;
      }
      if (iconImage.size.height == 114 && useHighResIcon) {
        // found!
        break;
      }
    }
  }
  
  BOOL addGloss = YES;
  NSNumber *prerendered = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIPrerenderedIcon"];
  if (prerendered) {
    addGloss = ![prerendered boolValue];
  }
  
  if (addGloss) {
    _appStoreHeader.iconImage = [self addGlossToImage:[UIImage imageNamed:iconString]];
  } else {
    _appStoreHeader.iconImage = [UIImage imageNamed:iconString];
  }
  
  self.tableView.tableHeaderView = _appStoreHeader;
  
  PSStoreButton *storeButton = [[[PSStoreButton alloc] initWithPadding:CGPointMake(5, 40)] autorelease];
  storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  storeButton.buttonDelegate = self;
  [self.tableView.tableHeaderView addSubview:storeButton];
  storeButton.buttonData = [PSStoreButtonData dataWithLabel:@"" colors:[PSStoreButton appStoreGrayColor] enabled:NO];
  [storeButton alignToSuperview];
  _appStoreButton = [storeButton retain];
  self.appStoreButtonState = AppStoreButtonStateCheck;
}

- (void)viewWillAppear:(BOOL)animated {
  if (_isAppStoreEnvironment)
    self.appStoreButtonState = AppStoreButtonStateOffline;
  _updateManager.currentHockeyViewController = self;
  [super viewWillAppear:animated];
  _statusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
  [self redrawTableView];
}

- (void)viewWillDisappear:(BOOL)animated {
  _updateManager.currentHockeyViewController = nil;
  //if the popover is still visible, dismiss it
  [_popOverController dismissPopoverAnimated:YES];
  [super viewWillDisappear:animated];
  [[UIApplication sharedApplication] setStatusBarStyle:_statusBarStyle];
}

- (void)redrawTableView {
  [self restoreStoreButtonStateAnimated:NO];
  [self updateAppStoreHeader];
  
  // clean up and remove any pending overservers
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
    
    PSWebTableViewCell *cell = [[[PSWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier] autorelease];
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
    
    PSWebTableViewCell *cell = [[[PSWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier] autorelease];
    [self configureWebCell:cell forAppVersion:appVersion];
    [_cells addObject:cell];
  }
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}

- (void)viewDidUnload {
  [_appStoreHeader release]; _appStoreHeader = nil;
  [_popOverController release], _popOverController = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // test if KVO's are registered. if class is destroyed before it was shown(viewDidLoad) no KVOs are registered.
  if (_kvoRegistered) {
    [_updateManager removeObserver:self forKeyPath:@"checkInProgress"];
    [_updateManager removeObserver:self forKeyPath:@"isUpdateURLOffline"];
    [_updateManager removeObserver:self forKeyPath:@"updateAvailable"];
    [_updateManager removeObserver:self forKeyPath:@"apps"];
    _kvoRegistered = NO;
  }
  
  [super viewDidUnload];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat rowHeight = 0;
  
  if ([_cells count] > (NSUInteger)indexPath.row) {
    PSWebTableViewCell *cell = [_cells objectAtIndex:indexPath.row];
    rowHeight = cell.webViewSize.height;
  }
  
  if ([_updateManager.appVersions count] > 1 && !_showAllVersions) {
    self.tableView.backgroundColor = BIT_RGBCOLOR(183, 183, 183);
  }
  
  if (rowHeight == 0) {
    rowHeight = indexPath.row == 0 ? 250 : 44; // fill screen on startup
    self.tableView.backgroundColor = BIT_RGBCOLOR(200, 202, 204);
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
    } else if ([keyPath isEqualToString:@"apps"]) {
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  BOOL shouldAutorotate;
  
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    shouldAutorotate = (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
                        interfaceOrientation == UIInterfaceOrientationLandscapeRight ||
                        interfaceOrientation == UIInterfaceOrientationPortrait);
  } else {
    shouldAutorotate = YES;
  }
  
  return shouldAutorotate;
}

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
      [_appStoreButton setButtonData:[PSStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonOffline") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateCheck:
      [_appStoreButton setButtonData:[PSStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonCheck") colors:[PSStoreButton appStoreGreenColor] enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateSearching:
      [_appStoreButton setButtonData:[PSStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonSearching") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateUpdate:
      [_appStoreButton setButtonData:[PSStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonUpdate") colors:[PSStoreButton appStoreBlueColor] enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateInstalling:
      [_appStoreButton setButtonData:[PSStoreButtonData dataWithLabel:BITHockeyLocalizedString(@"UpdateButtonInstalling") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    default:
      break;
  }
}

- (void)storeButtonFired:(PSStoreButton *)button {
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
