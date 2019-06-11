//
//  RMRootViewController.h
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 11/06/14.
//  Copyright (c) 2014 Learn OpenGL ES. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RMIntroViewController.h"
#import "RMLoginViewController.h"

@interface RMRootViewController : UIViewController
{
    RMIntroViewController *_introVC;
    RMLoginViewController *_loginVC;
    
}

- (void)startButtonPress;


@end
