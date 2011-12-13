//
//  BWHockeySettingsViewController.m
//  HockeyDemo
//
//  Created by Andreas Linde on 3/8/11.
//  Copyright 2011 Andreas Linde. All rights reserved.
//

#import "BWHockeySettingsViewController.h"
#import "BWHockeyManager.h"
#import "BWGlobal.h"

#define BW_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

@implementation BWHockeySettingsViewController

@synthesize hockeyManager = hockeyManager_;

- (void)dismissSettings {
  [self.navigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Initialization

- (id)init:(BWHockeyManager *)newHockeyManager {
  if ((self = [super init])) {
    self.hockeyManager = newHockeyManager;
    self.title = BWHockeyLocalize(@"HockeySettingsTitle");
    
    CGRect frame = self.view.frame;
    frame.origin = CGPointZero;
    
    UITableView *tableView_ = [[[UITableView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 260, self.view.frame.size.width, 260) style:UITableViewStyleGrouped] autorelease];
    tableView_.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    
    BW_IF_3_2_OR_GREATER(
                         if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                           self.view.backgroundColor = BW_RGBCOLOR(200, 202, 204);
                           tableView_.backgroundColor = BW_RGBCOLOR(200, 202, 204);
                         } else {
                           tableView_.frame = frame;
                           tableView_.autoresizingMask = tableView_.autoresizingMask | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
                         }
                         )
    BW_IF_PRE_3_2(
                  self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                          target:self
                                                                                                          action:@selector(dismissSettings)] autorelease];
                  tableView_.frame = frame;
                  tableView_.autoresizingMask = tableView_.autoresizingMask | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
                  )
    
    tableView_.delegate = self;
    tableView_.dataSource = self;
    tableView_.clipsToBounds = NO;
    
    [self.view addSubview:tableView_];
    
  }
  return self;
}

- (id)init {
  return [self init:[BWHockeyManager sharedHockeyManager]];
}

#pragma mark -
#pragma mark Table view data source

- (int)numberOfSections {
  int numberOfSections = 1;
  
  if ([self.hockeyManager isAllowUserToDisableSendData]) {
    if ([self.hockeyManager shouldSendUserData]) numberOfSections++;
    if ([self.hockeyManager shouldSendUsageTime]) numberOfSections++;
  }
  
  return numberOfSections;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (section == [self numberOfSections] - 1) {
    return BWHockeyLocalize(@"HockeySectionCheckTitle");
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
    
    if (section == 0 && [self.hockeyManager isAllowUserToDisableSendData] && [self.hockeyManager shouldSendUserData]) {
      footer.text = BWHockeyLocalize(@"HockeySettingsUserDataDescription");
    } else if ([self.hockeyManager isAllowUserToDisableSendData] && section < [self numberOfSections]) {
      footer.text = BWHockeyLocalize(@"HockeySettingsUsageDataDescription");
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
  [self.hockeyManager setUserAllowsSendUserData:switcher.on];
}

- (void)sendUsageData:(UISwitch *)switcher {
  [self.hockeyManager setUserAllowsSendUsageTime:switcher.on];
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
    HockeyUpdateSetting hockeyAutoUpdateSetting = [[BWHockeyManager sharedHockeyManager] updateSetting];        
    if (indexPath.row == 0) {
      // on startup
      cell.textLabel.text = BWHockeyLocalize(@"HockeySectionCheckStartup");
      if (hockeyAutoUpdateSetting == HockeyUpdateCheckStartup) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    } else if (indexPath.row == 1) {
      // daily
      cell.textLabel.text = BWHockeyLocalize(@"HockeySectionCheckDaily");
      if (hockeyAutoUpdateSetting == HockeyUpdateCheckDaily) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    } else {
      // manually
      cell.textLabel.text = BWHockeyLocalize(@"HockeySectionCheckManually");
      if (hockeyAutoUpdateSetting == HockeyUpdateCheckManually) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    }
  } else {
    UISwitch *toggleSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
    
    if (indexPath.section == 0 && [self.hockeyManager shouldSendUserData] && [self.hockeyManager isAllowUserToDisableSendData]) {
      // send user data
      cell.textLabel.text = BWHockeyLocalize(@"HockeySettingsUserData");
      [toggleSwitch addTarget:self action:@selector(sendUserData:)
             forControlEvents:UIControlEventValueChanged];
      [toggleSwitch setOn:[self.hockeyManager doesUserAllowsSendUserData]];
      
    } else if ([self.hockeyManager shouldSendUsageTime] && [self.hockeyManager isAllowUserToDisableSendData]) {
      // send usage time
      cell.textLabel.text = BWHockeyLocalize(@"HockeySettingsUsageData");
      [toggleSwitch addTarget:self action:@selector(sendUsageData:)
             forControlEvents:UIControlEventValueChanged];
      [toggleSwitch setOn:[self.hockeyManager doesUserAllowsSendUsageTime]];
    }
    
    cell.accessoryView = toggleSwitch;
    
  }
  
  return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  // update check interval selection
  if (indexPath.row == 0) {
    // on startup
    [BWHockeyManager sharedHockeyManager].updateSetting = HockeyUpdateCheckStartup;
  } else if (indexPath.row == 1) {
    // daily
    [BWHockeyManager sharedHockeyManager].updateSetting = HockeyUpdateCheckDaily;
  } else {
    // manually
    [BWHockeyManager sharedHockeyManager].updateSetting = HockeyUpdateCheckManually;
  }
  
  [tableView reloadData];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
  // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
  // For example: self.myOutlet = nil;
}


- (void)dealloc {
  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Rotation

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

