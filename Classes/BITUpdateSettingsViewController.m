/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde.
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

#import "BITUpdateSettingsViewController.h"

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"


#define BW_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

@implementation BITUpdateSettingsViewController

@synthesize updateManager = _updateManager;

- (void)dismissSettings {
  [self.navigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - Initialization

- (id)init:(BITUpdateManager *)newUpdateManager {
  if ((self = [super init])) {
    self.updateManager = newUpdateManager;
    self.title = BITHockeySDKLocalizedString(@"UpdateSettingsTitle");
    
    CGRect frame = self.view.frame;
    frame.origin = CGPointZero;
    
    UITableView *tableView_ = [[[UITableView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 260, self.view.frame.size.width, 260) style:UITableViewStyleGrouped] autorelease];
    tableView_.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      self.view.backgroundColor = BW_RGBCOLOR(200, 202, 204);
      tableView_.backgroundColor = BW_RGBCOLOR(200, 202, 204);
    } else {
      tableView_.frame = frame;
      tableView_.autoresizingMask = tableView_.autoresizingMask | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    
    tableView_.delegate = self;
    tableView_.dataSource = self;
    tableView_.clipsToBounds = NO;
    
    [self.view addSubview:tableView_];
    
  }
  return self;
}

- (id)init {
  return [self init:[BITHockeyManager sharedHockeyManager].updateManager];
}


#pragma mark - Table view data source

- (int)numberOfSections {
  int numberOfSections = 1;
  
  if ([_updateManager isAllowUserToDisableSendData]) {
    if ([_updateManager shouldSendUserData]) numberOfSections++;
    if ([_updateManager shouldSendUsageTime]) numberOfSections++;
  }
  
  return numberOfSections;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (section == [self numberOfSections] - 1) {
    return BITHockeySDKLocalizedString(@"UpdateSectionCheckTitle");
  } else {
    return nil;
  }
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
  if (section < [self numberOfSections] - 1) {
    return 66;
  } else return 0;
}


- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
  if ([self numberOfSections] > 1 && section < [self numberOfSections] - 1) {
    UILabel *footer = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 285, 66)] autorelease];
    footer.backgroundColor = [UIColor clearColor];
    footer.numberOfLines = 3;
    footer.textAlignment = UITextAlignmentCenter;
    footer.adjustsFontSizeToFitWidth = YES;
    footer.textColor = [UIColor grayColor];
    footer.font = [UIFont systemFontOfSize:13];
    
    if (section == 0 && [_updateManager isAllowUserToDisableSendData] && [_updateManager shouldSendUserData]) {
      footer.text = BITHockeySDKLocalizedString(@"UpdateSettingsUserDataDescription");
    } else if ([_updateManager isAllowUserToDisableSendData] && section < [self numberOfSections]) {
      footer.text = BITHockeySDKLocalizedString(@"UpdateSettingsUsageDataDescription");
    }
    
    UIView* view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 285, footer.frame.size.height + 6 + 11)] autorelease];
    [view setBackgroundColor:[UIColor clearColor]];
    
    CGRect frame = footer.frame;
    frame.origin.y = 8;
    frame.origin.x = 16;
    frame.size.width = 285;
    footer.frame = frame;
    
    [view addSubview:footer];
    [view sizeToFit];
    
    return view;
  }
  
  return nil;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // Return the number of sections.
  return [self numberOfSections];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  // Return the number of rows in the section.
  if (section == [self numberOfSections] - 1)
    return 3;
  else
    return 1;
}


- (void)sendUserData:(UISwitch *)switcher {
  [_updateManager setUserAllowsSendUserData:switcher.on];
}

- (void)sendUsageData:(UISwitch *)switcher {
  [_updateManager setUserAllowsSendUsageTime:switcher.on];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  static NSString *CheckmarkCellIdentifier = @"CheckmarkCell";
  static NSString *SwitchCellIdentifier = @"SwitchCell";
  
  NSString *requiredIdentifier = nil;
  UITableViewCellStyle cellStyle = UITableViewCellStyleSubtitle;
  
  if ((NSInteger)indexPath.section == [self numberOfSections] - 1) {
    cellStyle = UITableViewCellStyleDefault;
    requiredIdentifier = CheckmarkCellIdentifier;
  } else {
    cellStyle = UITableViewCellStyleValue1;
    requiredIdentifier = SwitchCellIdentifier;
  }
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:requiredIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:requiredIdentifier] autorelease];
  }
  
  cell.accessoryType = UITableViewCellAccessoryNone;
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  
  // Configure the cell...
  if ((NSInteger)indexPath.section == [self numberOfSections] - 1) {
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    // update check selection
    BITUpdateSetting hockeyAutoUpdateSetting = [_updateManager updateSetting];
    if (indexPath.row == 0) {
      // on startup
      cell.textLabel.text = BITHockeySDKLocalizedString(@"UpdateSectionCheckStartup");
      if (hockeyAutoUpdateSetting == BITUpdateCheckStartup) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    } else if (indexPath.row == 1) {
      // daily
      cell.textLabel.text = BITHockeySDKLocalizedString(@"UpdateSectionCheckDaily");
      if (hockeyAutoUpdateSetting == BITUpdateCheckDaily) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    } else {
      // manually
      cell.textLabel.text = BITHockeySDKLocalizedString(@"UpdateSectionCheckManually");
      if (hockeyAutoUpdateSetting == BITUpdateCheckManually) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    }
  } else {
    UISwitch *toggleSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
    
    if (indexPath.section == 0 && [_updateManager shouldSendUserData] && [_updateManager isAllowUserToDisableSendData]) {
      // send user data
      cell.textLabel.text = BITHockeySDKLocalizedString(@"UpdateSettingsUserData");
      [toggleSwitch addTarget:self action:@selector(sendUserData:)
             forControlEvents:UIControlEventValueChanged];
      [toggleSwitch setOn:[_updateManager doesUserAllowsSendUserData]];
      
    } else if ([_updateManager shouldSendUsageTime] && [_updateManager isAllowUserToDisableSendData]) {
      // send usage time
      cell.textLabel.text = BITHockeySDKLocalizedString(@"UpdateSettingsUsageData");
      [toggleSwitch addTarget:self action:@selector(sendUsageData:)
             forControlEvents:UIControlEventValueChanged];
      [toggleSwitch setOn:[_updateManager doesUserAllowsSendUsageTime]];
    }
    
    cell.accessoryView = toggleSwitch;
    
  }
  
  return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  // update check interval selection
  if (indexPath.row == 0) {
    // on startup
    _updateManager.updateSetting = BITUpdateCheckStartup;
  } else if (indexPath.row == 1) {
    // daily
    _updateManager.updateSetting = BITUpdateCheckDaily;
  } else {
    // manually
    _updateManager.updateSetting = BITUpdateCheckManually;
  }
  
  [tableView reloadData];
}


#pragma mark - Memory management

- (void)dealloc {
  [_updateManager release];
  
  [super dealloc];
}


#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  BOOL shouldAutorotate;
  
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    shouldAutorotate = (interfaceOrientation == UIInterfaceOrientationPortrait);
  } else {
    shouldAutorotate = YES;
  }
  
  return shouldAutorotate;
}

@end

