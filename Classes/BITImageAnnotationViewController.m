//
//  BITImageAnnotationViewController.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 14.02.14.
//
//

#import "BITImageAnnotationViewController.h"

@interface BITImageAnnotationViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UISegmentedControl *editingControls;
@property (nonatomic, strong) NSMutableArray *layers;

@end

@implementation BITImageAnnotationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.editingControls = [[UISegmentedControl alloc] initWithItems:@[@"Arrow", @"Rect", @"Blur"]];
  
  self.navigationItem.titleView = self.editingControls;
  
  [self.editingControls addTarget:self action:@selector(editingAction:) forControlEvents:UIControlEventTouchUpInside];
  
  self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  
  self.imageView.image = self.image;
  self.imageView.contentMode = UIViewContentModeScaleAspectFit;
	// Do any additional setup after loading the view.
}

-(void)editingAction:(id)sender {
  
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
