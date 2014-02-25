//
//  BITImageAnnotationViewController.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 14.02.14.
//
//

#import "BITImageAnnotationViewController.h"
#import "BITImageAnnotation.h"
#import "BITRectangleImageAnnotation.h"

@interface BITImageAnnotationViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UISegmentedControl *editingControls;
@property (nonatomic, strong) NSMutableArray *objects;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;

@property (nonatomic) CGPoint panStart;
@property (nonatomic,strong) BITImageAnnotation *currentAnnotation;

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
  
  
  [self.view addSubview:self.imageView];
  self.imageView.frame = self.view.bounds;
  
  
  self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
  
  [self.tapRecognizer requireGestureRecognizerToFail:self.panRecognizer];
  
  [self.view addGestureRecognizer:self.tapRecognizer];
  [self.view addGestureRecognizer:self.panRecognizer];
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc ] initWithTitle:@"Discard" style:UIBarButtonItemStyleBordered target:self action:@selector(discard:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc ] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(save:)];

	// Do any additional setup after loading the view.
}

-(void)editingAction:(id)sender {
  
}

- (BITImageAnnotation *)annotationForCurrentMode {
  if (self.editingControls.selectedSegmentIndex == 0){
    return [[BITRectangleImageAnnotation alloc] initWithFrame:CGRectZero];
  } else {
    return [[BITImageAnnotation alloc] initWithFrame:CGRectZero];
  }
}

#pragma mark - Actions

- (void)discard:(id)sender {
  [self.delegate annotationControllerDidCancel:self];
  [self dismissModalViewControllerAnimated:YES];
}

- (void)save:(id)sender {
  UIImage *image = [self extractImage];
  [self.delegate annotationController:self didFinishWithImage:image];
  [self dismissModalViewControllerAnimated:YES];
}

- (UIImage *)extractImage {
  UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, YES, 0.0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  [self.view.layer renderInContext:ctx];
  UIImage *renderedImageOfMyself = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return renderedImageOfMyself;
}

#pragma mark - Gesture Handling

- (void)panned:(UIPanGestureRecognizer *)gestureRecognizer {
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
    self.currentAnnotation = [self annotationForCurrentMode];
    
    [self.view insertSubview:self.currentAnnotation aboveSubview:self.imageView];
    self.panStart = [gestureRecognizer locationInView:self.imageView];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged){
    CGPoint bla = [gestureRecognizer translationInView:self.imageView];
    self.currentAnnotation.frame = CGRectMake(self.panStart.x, self.panStart.y, bla.x, bla.y);
  }
  
}

-(void)tapped:(UITapGestureRecognizer *)gestureRecognizer {
  
  
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
