//
//  BWHockeyViewController.m
//
//  Created by Andreas Linde on 8/17/10.
//  Copyright 2010-2011 Andreas Linde, Peter Steinberger. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <QuartzCore/QuartzCore.h>
#import "NSString+HockeyAdditions.h"
#import "BWHockeyViewController.h"
#import "BWHockeyManager.h"
#import "BWGlobal.h"
#import "UIImage+HockeyAdditions.h"
#import "PSAppStoreHeader.h"
#import "PSWebTableViewCell.h"
#import "BWHockeySettingsViewController.h"

#define BW_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define kWebCellIdentifier @"PSWebTableViewCell"
#define kAppStoreViewHeight 90

@interface BWHockeyViewController ()
// updates the whole view
- (void)showPreviousVersionAction;
- (void)redrawTableView;
@property (nonatomic, assign) AppStoreButtonState appStoreButtonState;
- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState animated:(BOOL)animated;
@end


@implementation BWHockeyViewController

@synthesize appStoreButtonState = appStoreButtonState_;
@synthesize hockeyManager = hockeyManager_;
@synthesize modal = modal_;
@synthesize modalAnimated = modalAnimated_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark private

- (void)restoreStoreButtonStateAnimated_:(BOOL)animated {
  if ([self.hockeyManager isAppStoreEnvironment]) {
    [self setAppStoreButtonState:AppStoreButtonStateOffline animated:animated];
  } else if ([self.hockeyManager isUpdateAvailable]) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:animated];
  } else {
    [self setAppStoreButtonState:AppStoreButtonStateCheck animated:animated];
  }
}

- (void)updateAppStoreHeader_ {
  BWApp *app = self.hockeyManager.app;
  appStoreHeader_.headerLabel = app.name;
  appStoreHeader_.middleHeaderLabel = [app versionString];
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  [formatter setDateStyle:NSDateFormatterMediumStyle];
  NSMutableString *subHeaderString = [NSMutableString string];
  if (app.date) {
    [subHeaderString appendString:[formatter stringFromDate:app.date]];
  }
  if (app.size) {
    if ([subHeaderString length]) {
      [subHeaderString appendString:@" - "];
    }
    [subHeaderString appendString:app.sizeInMB];
  }
  appStoreHeader_.subHeaderLabel = subHeaderString;
}

- (void)appDidBecomeActive_ {
  if (self.appStoreButtonState == AppStoreButtonStateInstalling) {
    [self setAppStoreButtonState:AppStoreButtonStateUpdate animated:YES];
  } else if (![self.hockeyManager isCheckInProgress]) {
    [self restoreStoreButtonStateAnimated_:YES];
  }
}

- (void)openSettings:(id)sender {
  BWHockeySettingsViewController *settings = [[[BWHockeySettingsViewController alloc] init] autorelease];
  
  Class popoverControllerClass = NSClassFromString(@"UIPopoverController");
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && popoverControllerClass) {
    if (popOverController_ == nil) {
      popOverController_ = [[popoverControllerClass alloc] initWithContentViewController:settings];
    }
    if ([popOverController_ contentViewController].view.window) {
      [popOverController_ dismissPopoverAnimated:YES];
    }else {
      [popOverController_ setPopoverContentSize: CGSizeMake(320, 440)];
      [popOverController_ presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem
                                 permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    }
  } else {
    
    BW_IF_3_2_OR_GREATER(
                         settings.modalTransitionStyle = UIModalTransitionStylePartialCurl;
                         [self presentModalViewController:settings animated:YES];
                         )
    BW_IF_PRE_3_2(
                  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:settings] autorelease];
                  navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                  [self presentModalViewController:navController animated:YES];
                  )
  }
}

- (UIImage *)addGlossToImage_:(UIImage *)image {
  BW_IF_IOS4_OR_GREATER(UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);)
  BW_IF_PRE_IOS4(UIGraphicsBeginImageContext(image.size);)
  
  [image drawAtPoint:CGPointZero];
  UIImage *iconGradient = [UIImage bw_imageNamed:@"IconGradient.png" bundle:kHockeyBundleName];
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
  [(UIButton *)sender setBackgroundColor:BW_RGBCOLOR(183,183,183)];
}

- (void)changePreviousVersionButtonBackgroundHighlighted:(id)sender {
  [(UIButton *)sender setBackgroundColor:BW_RGBCOLOR(183,183,183)];
}

- (void)showHidePreviousVersionsButton {
  BOOL multipleVersionButtonNeeded = [self.hockeyManager.apps count] > 1 && !showAllVersions_;
  
  if(multipleVersionButtonNeeded) {
    // align at the bottom if tableview is small
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kMinPreviousVersionButtonHeight)];
    footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    footerView.backgroundColor = BW_RGBCOLOR(200, 202, 204);
    UIButton *footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    BW_IF_IOS4_OR_GREATER(
                          //footerButton.layer.shadowOffset = CGSizeMake(-2, 2);
                          footerButton.layer.shadowColor = [[UIColor blackColor] CGColor];
                          footerButton.layer.shadowRadius = 2.0f;
                          )
    footerButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [footerButton setTitle:BWHockeyLocalize(@"HockeyShowPreviousVersions") forState:UIControlStateNormal];
    [footerButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [footerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [footerButton setBackgroundImage:[UIImage bw_imageNamed:@"buttonHighlight.png" bundle:kHockeyBundleName] forState:UIControlStateHighlighted];
    footerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [footerButton addTarget:self action:@selector(showPreviousVersionAction) forControlEvents:UIControlEventTouchUpInside];
    footerButton.frame = CGRectMake(0, kMinPreviousVersionButtonHeight-44, self.view.frame.size.width, 44);
    footerButton.backgroundColor = BW_RGBCOLOR(183,183,183);
    [footerView addSubview:footerButton];
    self.tableView.tableFooterView = footerView;
    [self realignPreviousVersionButton];
    [footerView release];
  } else {
    self.tableView.tableFooterView = nil;
    self.tableView.backgroundColor = BW_RGBCOLOR(200, 202, 204);
  }
}

- (void)configureWebCell:(PSWebTableViewCell *)cell forApp_:(BWApp *)app {
  // create web view for a version
  NSString *installed = @"";
  if ([app.version isEqualToString:[self.hockeyManager currentAppVersion]]) {
    installed = [NSString stringWithFormat:@"<span style=\"float:%@;text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\"><b>%@</b></span>", [app isEqual:self.hockeyManager.app] ? @"left" : @"right", BWHockeyLocalize(@"HockeyInstalled")];
  }
  
  if ([app isEqual:self.hockeyManager.app]) {
    if ([app.notes length] > 0) {
      installed = [NSString stringWithFormat:@"<p>&nbsp;%@</p>", installed];
      cell.webViewContent = [NSString stringWithFormat:@"%@%@", installed, app.notes];
    } else {
      cell.webViewContent = [NSString stringWithFormat:@"<div style=\"min-height:200px;vertical-align:middle;text-align:center;text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\">%@</div>", BWHockeyLocalize(@"HockeyNoReleaseNotesAvailable")];
    }
  } else {
    cell.webViewContent = [NSString stringWithFormat:@"<p><b style=\"text-shadow:rgba(255,255,255,0.6) 1px 1px 0px;\">%@</b>%@<br/><small>%@</small></p><p>%@</p>", [app versionString], installed, [app dateString], [app notesOrEmptyString]];
  }
  cell.cellBackgroundColor = BW_RGBCOLOR(200, 202, 204);
  
  [cell addWebView];
  // hack
  cell.textLabel.text = @"";
  
  [cell addObserver:self forKeyPath:@"webViewSize" options:0 context:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (id)init:(BWHockeyManager *)newHockeyManager modal:(BOOL)newModal {
  if ((self = [super initWithStyle:UITableViewStylePlain])) {
    self.hockeyManager = newHockeyManager;
    self.modal = newModal;
    self.modalAnimated = YES;
    self.title = BWHockeyLocalize(@"HockeyUpdateScreenTitle");
    
    if ([self.hockeyManager shouldShowUserSettings]) {
      self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage bw_imageNamed:@"gear.png" bundle:kHockeyBundleName]
                                                                                 style:UIBarButtonItemStyleBordered
                                                                                target:self
                                                                                action:@selector(openSettings:)] autorelease];
    }
    
    cells_ = [[NSMutableArray alloc] initWithCapacity:5];
    popOverController_ = nil;
  }
  return self;
}

- (id)init {
	return [self init:[BWHockeyManager sharedHockeyManager] modal:NO];
}

- (void)dealloc {
  [self viewDidUnload];
  for (UITableViewCell *cell in cells_) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  [cells_ release];
  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark View lifecycle

- (void)onAction:(id)sender {
  if (self.modal) {
    // Note that as of 5.0, parentViewController will no longer return the presenting view controller
    SEL presentingViewControllerSelector = NSSelectorFromString(@"presentingViewController");
    UIViewController *presentingViewController = nil;
    if ([self respondsToSelector:presentingViewControllerSelector]) {
      presentingViewController = [self performSelector:presentingViewControllerSelector];
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
  
  [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle_];
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
  [dnc addObserver:self selector:@selector(appDidBecomeActive_) name:UIApplicationDidBecomeActiveNotification object:nil];
  
  // hook into manager with kvo!
  [self.hockeyManager addObserver:self forKeyPath:@"checkInProgress" options:0 context:nil];
  [self.hockeyManager addObserver:self forKeyPath:@"isUpdateURLOffline" options:0 context:nil];
  [self.hockeyManager addObserver:self forKeyPath:@"updateAvailable" options:0 context:nil];
  [self.hockeyManager addObserver:self forKeyPath:@"apps" options:0 context:nil];
  kvoRegistered_ = YES;
  
  self.tableView.backgroundColor = BW_RGBCOLOR(200, 202, 204);
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  UIView *topView = [[[UIView alloc] initWithFrame:CGRectMake(0, -(600-kAppStoreViewHeight), self.view.frame.size.width, 600)] autorelease];
  topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  topView.backgroundColor = BW_RGBCOLOR(140, 141, 142);
  [self.tableView addSubview:topView];
  
  appStoreHeader_ = [[PSAppStoreHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, kAppStoreViewHeight)];
  [self updateAppStoreHeader_];
  
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
    BW_IF_IOS4_OR_GREATER(if ([UIScreen mainScreen].scale == 2.0f) useHighResIcon = YES;)
    
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
    appStoreHeader_.iconImage = [self addGlossToImage_:[UIImage imageNamed:iconString]];
  } else {
    appStoreHeader_.iconImage = [UIImage imageNamed:iconString];
  }
  
  self.tableView.tableHeaderView = appStoreHeader_;
  
  if (self.modal) {
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(onAction:)] autorelease];
  }
  
  PSStoreButton *storeButton = [[[PSStoreButton alloc] initWithPadding:CGPointMake(5, 40)] autorelease];
  storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  storeButton.buttonDelegate = self;
  [self.tableView.tableHeaderView addSubview:storeButton];
  storeButton.buttonData = [PSStoreButtonData dataWithLabel:@"" colors:[PSStoreButton appStoreGrayColor] enabled:NO];
  self.appStoreButtonState = AppStoreButtonStateCheck;
  [storeButton alignToSuperview];
  appStoreButton_ = [storeButton retain];
}

- (void)viewWillAppear:(BOOL)animated {
  if ([self.hockeyManager isAppStoreEnvironment])
    self.appStoreButtonState = AppStoreButtonStateOffline;
  self.hockeyManager.currentHockeyViewController = self;
  [super viewWillAppear:animated];
  statusBarStyle_ = [[UIApplication sharedApplication] statusBarStyle];
  [[UIApplication sharedApplication] setStatusBarStyle:(self.navigationController.navigationBar.barStyle == UIBarStyleDefault) ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque];
  [self redrawTableView];
}

- (void)viewWillDisappear:(BOOL)animated {
  self.hockeyManager.currentHockeyViewController = nil;
  //if the popover is still visible, dismiss it
  [popOverController_ dismissPopoverAnimated:YES];
  [super viewWillDisappear:animated];
  [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle_];
}

- (void)redrawTableView {
  [self restoreStoreButtonStateAnimated_:NO];
  [self updateAppStoreHeader_];
  
  // clean up and remove any pending overservers
  for (UITableViewCell *cell in cells_) {
    [cell removeObserver:self forKeyPath:@"webViewSize"];
  }
  [cells_ removeAllObjects];
  
  int i = 0;
  BOOL breakAfterThisApp = NO;
  for (BWApp *app in self.hockeyManager.apps) {
    i++;
    
    // only show the newer version of the app by default, if we don't show all versions
    if (!showAllVersions_) {
      if ([app.version isEqualToString:[self.hockeyManager currentAppVersion]]) {
        if (i == 1) {
          breakAfterThisApp = YES;
        } else {
          break;
        }
      }
    }
    
    PSWebTableViewCell *cell = [[[PSWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier] autorelease];
    [self configureWebCell:cell forApp_:app];
    [cells_ addObject:cell];
    
    if (breakAfterThisApp) break;
  }
  
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}

- (void)showPreviousVersionAction {
  showAllVersions_ = YES;
  BOOL showAllPending = NO;
  
  for (BWApp *app in self.hockeyManager.apps) {
    if (!showAllPending) {
      if ([app.version isEqualToString:[self.hockeyManager currentAppVersion]]) {            
        showAllPending = YES;
        if (app == self.hockeyManager.app) {
          continue; // skip this version already if it the latest version is the installed one
        }
      } else {
        continue; // skip already shown
      }
    }
    
    PSWebTableViewCell *cell = [[[PSWebTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kWebCellIdentifier] autorelease];
    [self configureWebCell:cell forApp_:app];
    [cells_ addObject:cell];
  }
  [self.tableView reloadData];
  [self showHidePreviousVersionsButton];
}

- (void)viewDidUnload {
  [appStoreHeader_ release]; appStoreHeader_ = nil;
  [popOverController_ release], popOverController_ = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // test if KVO's are registered. if class is destroyed before it was shown(viewDidLoad) no KVOs are registered.
  if (kvoRegistered_) {
    [self.hockeyManager removeObserver:self forKeyPath:@"checkInProgress"];
    [self.hockeyManager removeObserver:self forKeyPath:@"isUpdateURLOffline"];
    [self.hockeyManager removeObserver:self forKeyPath:@"updateAvailable"];
    [self.hockeyManager removeObserver:self forKeyPath:@"apps"];
    kvoRegistered_ = NO;
  }
  
  [super viewDidUnload];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat rowHeight = 0;
  
  if ([cells_ count] > (NSUInteger)indexPath.row) {
    PSWebTableViewCell *cell = [cells_ objectAtIndex:indexPath.row];
    rowHeight = cell.webViewSize.height;
  }
  
  if ([self.hockeyManager.apps count] > 1 && !showAllVersions_) {
    self.tableView.backgroundColor = BW_RGBCOLOR(183, 183, 183);
  }
  
  if (rowHeight == 0) {
    rowHeight = indexPath.row == 0 ? 250 : 44; // fill screen on startup
    self.tableView.backgroundColor = BW_RGBCOLOR(200, 202, 204);
  }
  
  return rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSInteger cellCount = [cells_ count];
  return cellCount;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  // only make changes if we are visible
  if(self.view.window) {
    if ([keyPath isEqualToString:@"webViewSize"]) {
      [self.tableView reloadData];
      [self realignPreviousVersionButton];
    } else if ([keyPath isEqualToString:@"checkInProgress"]) {
      if (self.hockeyManager.isCheckInProgress) {
        [self setAppStoreButtonState:AppStoreButtonStateSearching animated:YES];
      }else {
        [self restoreStoreButtonStateAnimated_:YES];
      }
    } else if ([keyPath isEqualToString:@"isUpdateURLOffline"]) {
      [self restoreStoreButtonStateAnimated_:YES];
    } else if ([keyPath isEqualToString:@"updateAvailable"]) {
      [self restoreStoreButtonStateAnimated_:YES];
    } else if ([keyPath isEqualToString:@"apps"]) {
      [self redrawTableView];
    }
  }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if ([cells_ count] > (NSUInteger)indexPath.row) {
    return [cells_ objectAtIndex:indexPath.row];
  } else {
    BWHockeyLog(@"Warning: cells_ and indexPath do not match? forgot calling redrawTableView?");
  }
  return nil;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Rotation

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
  [cells_ makeObjectsPerformSelector:@selector(addWebView)];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PSAppStoreHeaderDelegate

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState {
  [self setAppStoreButtonState:anAppStoreButtonState animated:NO];
}

- (void)setAppStoreButtonState:(AppStoreButtonState)anAppStoreButtonState animated:(BOOL)animated {
  appStoreButtonState_ = anAppStoreButtonState;
  
  switch (anAppStoreButtonState) {
    case AppStoreButtonStateOffline:
      [appStoreButton_ setButtonData:[PSStoreButtonData dataWithLabel:BWHockeyLocalize(@"HockeyButtonOffline") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateCheck:
      [appStoreButton_ setButtonData:[PSStoreButtonData dataWithLabel:BWHockeyLocalize(@"HockeyButtonCheck") colors:[PSStoreButton appStoreGreenColor] enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateSearching:
      [appStoreButton_ setButtonData:[PSStoreButtonData dataWithLabel:BWHockeyLocalize(@"HockeyButtonSearching") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    case AppStoreButtonStateUpdate:
      [appStoreButton_ setButtonData:[PSStoreButtonData dataWithLabel:BWHockeyLocalize(@"HockeyButtonUpdate") colors:[PSStoreButton appStoreBlueColor] enabled:YES] animated:animated];
      break;
    case AppStoreButtonStateInstalling:
      [appStoreButton_ setButtonData:[PSStoreButtonData dataWithLabel:BWHockeyLocalize(@"HockeyButtonInstalling") colors:[PSStoreButton appStoreGrayColor] enabled:NO] animated:animated];
      break;
    default:
      break;
  }
}

- (void)storeButtonFired:(PSStoreButton *)button {
  switch (appStoreButtonState_) {
    case AppStoreButtonStateCheck:
      [self.hockeyManager checkForUpdateShowFeedback:YES];
      break;
    case AppStoreButtonStateUpdate:
      if ([self.hockeyManager initiateAppDownload]) {
        [self setAppStoreButtonState:AppStoreButtonStateInstalling animated:YES];
      };
      break;
    default:
      break;
  }
}

@end
