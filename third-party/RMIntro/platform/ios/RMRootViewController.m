//
//  RMRootViewController.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 11/06/14.
//  Copyright (c) 2014 Learn OpenGL ES. All rights reserved.
//

#import "RMRootViewController.h"
#import "RMGeometry.h"

@interface RMRootViewController ()

@end

@implementation RMRootViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _introVC = [[RMIntroViewController alloc] init];
        _introVC.view.frame = CGRectChangedOriginY(self.view.frame, 0);
        
        _loginVC = [[RMLoginViewController alloc]init];
        _loginVC.view.frame = CGRectChangedOriginY(self.view.frame, 0);
        
        UIButton *back = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [back setTitle:@"Back" forState:UIControlStateNormal];
        [back setFont:[UIFont systemFontOfSize:24.]];
        [_loginVC.view addSubview:back];
        back.frame= CGRectMake(0, 100, 320, 100);
        [back addTarget:self action:@selector(backButtonPress) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *reset = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [reset setTitle:@"Free Intro Controller" forState:UIControlStateNormal];
        [reset setFont:[UIFont systemFontOfSize:24.]];
        [_loginVC.view addSubview:reset];
        reset.frame= CGRectMake(0, 200, 320, 100);
        [reset addTarget:self action:@selector(resetButtonPress) forControlEvents:UIControlEventTouchUpInside];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view addSubview:_introVC.view];
    
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



- (NSUInteger)supportedInterfaceOrientations
{
    //if (IPAD) {
        return UIInterfaceOrientationMaskAll;
    //}
    //return UIInterfaceOrientationMaskPortrait;
}


- (void)startButtonPress
{
    NSLog(@"startButtonPress");

    [self.view addSubview:_loginVC.view];
    _loginVC.view.frame = CGRectChangedOriginX(_loginVC.view.frame, self.view.frame.size.width);
    
    
    [_introVC stopTimer];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:.3];
    _loginVC.view.frame = CGRectChangedOriginX(_loginVC.view.frame, 0);
    [UIView commitAnimations];
    
}


- (void)backButtonPress
{
    NSLog(@"back");
    
    [_introVC startTimer];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:.3];
    _loginVC.view.frame = CGRectChangedOriginX(_loginVC.view.frame, self.view.bounds.size.width);
    [UIView commitAnimations];
    //[self popViewControllerAnimated:YES];
}

- (void)resetButtonPress
{
    NSLog(@"reset");
    [_introVC.view removeFromSuperview];
    _introVC = nil;
    
    //self.viewControllers = [NSArray arrayWithObject:[self.viewControllers objectAtIndex:1]];
    //[nav popViewControllerAnimated:YES];
}

@end
