//
//  CNSHockeyBaseViewController.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BITHockeyBaseViewController : UITableViewController

@property (nonatomic, readwrite) BOOL modalAnimated;

- (instancetype)initWithModalStyle:(BOOL)modal;
- (instancetype)initWithStyle:(UITableViewStyle)style modal:(BOOL)modal;

@end
