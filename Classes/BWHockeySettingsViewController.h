//
//  BWHockeySettingsViewController.h
//  HockeyDemo
//
//  Created by Andreas Linde on 3/8/11.
//  Copyright 2011 Andreas Linde. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BWHockeyManager;

@interface BWHockeySettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
  BWHockeyManager *hockeyManager_;
}

@property (nonatomic, retain) BWHockeyManager *hockeyManager;

- (id)init:(BWHockeyManager *)newHockeyManager;
- (id)init;

@end
