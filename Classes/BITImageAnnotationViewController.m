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
#import "BITArrowImageAnnotation.h"
#import "BITBlurImageAnnotation.h"

@interface BITImageAnnotationViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UISegmentedControl *editingControls;
@property (nonatomic, strong) NSMutableArray *objects;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;

@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) CGPoint panStart;
@property (nonatomic,strong) BITImageAnnotation *currentAnnotation;

@property (nonatomic) BOOL isDrawing;

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
  
  self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
  
  self.editingControls = [[UISegmentedControl alloc] initWithItems:@[@"Rectangle", @"Arrow", @"Blur"]];
  
  self.navigationItem.titleView = self.editingControls;

  
  self.objects = [NSMutableArray new];
  
  [self.editingControls addTarget:self action:@selector(editingAction:) forControlEvents:UIControlEventTouchUpInside];
  [self.editingControls setSelectedSegmentIndex:0];
  
  self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  
  self.imageView.clipsToBounds = YES;
    
  self.imageView.image = self.image;
  self.imageView.contentMode = UIViewContentModeScaleToFill;
  
  
  [self.view addSubview:self.imageView];
  self.imageView.frame = self.view.bounds;
  
  self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
  
  [self.tapRecognizer requireGestureRecognizerToFail:self.panRecognizer];
  
  [self.imageView addGestureRecognizer:self.tapRecognizer];
  [self.imageView addGestureRecognizer:self.panRecognizer];
  
  self.imageView.userInteractionEnabled = YES;
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc ] initWithTitle:@"Discard" style:UIBarButtonItemStyleBordered target:self action:@selector(discard:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc ] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(save:)];
  
  CGFloat heightScaleFactor = self.view.frame.size.height / self.image.size.height;
  CGFloat widthScaleFactor = self.view.frame.size.width / self.image.size.width;
  
  CGFloat factor = MIN(heightScaleFactor, widthScaleFactor);
  self.scaleFactor = factor;
  CGSize scaledImageSize = CGSizeMake(self.image.size.width * factor, self.image.size.height * factor);
  
  self.imageView.frame = CGRectMake(self.view.frame.size.width/2 - scaledImageSize.width/2, self.view.frame.size.height/2 - scaledImageSize.height/2, scaledImageSize.width, scaledImageSize.height);


	// Do any additional setup after loading the view.
}

-(void)editingAction:(id)sender {
  
}

- (BITImageAnnotation *)annotationForCurrentMode {
  if (self.editingControls.selectedSegmentIndex == 0){
    return [[BITRectangleImageAnnotation alloc] initWithFrame:CGRectZero];
  } else if(self.editingControls.selectedSegmentIndex==1){
    return [[BITArrowImageAnnotation alloc] initWithFrame:CGRectZero];
  } else {
    return [[BITBlurImageAnnotation alloc] initWithFrame:CGRectZero];
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
  UIGraphicsBeginImageContextWithOptions(self.image.size, YES, 0.0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  [self.image drawInRect:CGRectMake(0, 0, self.image.size.width, self.image.size.height)];
  CGContextScaleCTM(ctx,1.0/self.scaleFactor,1.0f/self.scaleFactor);
  
  // Drawing all the annotations onto the final image.
  for (BITImageAnnotation *annotation in self.objects){
    CGContextTranslateCTM(ctx, annotation.frame.origin.x, annotation.frame.origin.y);
    [annotation.layer renderInContext:ctx];
    CGContextTranslateCTM(ctx,-1 * annotation.frame.origin.x,-1 *  annotation.frame.origin.y);
  }

  UIImage *renderedImageOfMyself = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return renderedImageOfMyself;
}

#pragma mark - Gesture Handling

- (void)panned:(UIPanGestureRecognizer *)gestureRecognizer {
  if ([self.editingControls selectedSegmentIndex] != UISegmentedControlNoSegment || self.isDrawing ){
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
    self.currentAnnotation = [self annotationForCurrentMode];
    [self.objects addObject:self.currentAnnotation];
    self.currentAnnotation.sourceImage = self.image;
    [self.imageView insertSubview:self.currentAnnotation aboveSubview:self.imageView];
    self.panStart = [gestureRecognizer locationInView:self.imageView];
    
    [self.editingControls setSelectedSegmentIndex:UISegmentedControlNoSegment];
    self.isDrawing = YES;
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged){
    CGPoint bla = [gestureRecognizer locationInView:self.imageView];
    self.currentAnnotation.frame = CGRectMake(self.panStart.x, self.panStart.y, bla.x - self.panStart.x, bla.y - self.panStart.y);
    self.currentAnnotation.movedDelta = CGSizeMake(bla.x - self.panStart.x, bla.y - self.panStart.y);
    self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];
  } else {
    self.currentAnnotation = nil;
    self.isDrawing = NO;
  }
  } else {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
    // find and possibly move an existing annotation.
    BITImageAnnotation *selectedAnnotation = (BITImageAnnotation *)[self.view hitTest:[gestureRecognizer locationInView:self.view] withEvent:nil];
    
    if ([self.objects indexOfObject:selectedAnnotation] != NSNotFound){
        self.currentAnnotation = selectedAnnotation;
    }
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged && self.currentAnnotation){
      CGPoint delta = [gestureRecognizer translationInView:self.view];
      
      CGRect annotationFrame = self.currentAnnotation.frame;
      annotationFrame.origin.x += delta.x;
      annotationFrame.origin.y += delta.y;
      self.currentAnnotation.frame = annotationFrame;
      
      [gestureRecognizer setTranslation:CGPointZero inView:self.view];
      
    } else {
      self.currentAnnotation = nil;
    }
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
