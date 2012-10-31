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

- (id)initWithModalStyle:(BOOL)modal;

@end
