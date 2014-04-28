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
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"

typedef NS_ENUM(NSInteger, BITImageAnnotationViewControllerInteractionMode) {
  BITImageAnnotationViewControllerInteractionModeNone,
  BITImageAnnotationViewControllerInteractionModeDraw,
  BITImageAnnotationViewControllerInteractionModeMove
};

@interface BITImageAnnotationViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UISegmentedControl *editingControls;
@property (nonatomic, strong) NSMutableArray *objects;

@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;

@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) CGPoint panStart;
@property (nonatomic,strong) BITImageAnnotation *currentAnnotation;

@property (nonatomic) BITImageAnnotationViewControllerInteractionMode currentInteraction;

@property (nonatomic) CGRect pinchStartingFrame;

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
  
  NSArray *icons = @[@"Rectangle.png", @"Arrow.png", @"Blur.png"];
  
  self.editingControls = [[UISegmentedControl alloc] initWithItems:@[@"Rectangle", @"Arrow", @"Blur"]];
  int i=0;
  for (NSString *imageName in icons){
    [self.editingControls setImage:bit_imageNamed(imageName, BITHOCKEYSDK_BUNDLE) forSegmentAtIndex:i++];
  }
  
  [self.editingControls setSegmentedControlStyle:UISegmentedControlStyleBar];
  
  self.navigationItem.titleView = self.editingControls;
  
  self.objects = [NSMutableArray new];
  
  [self.editingControls addTarget:self action:@selector(editingAction:) forControlEvents:UIControlEventTouchUpInside];
  [self.editingControls setSelectedSegmentIndex:0];
  
  self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  
  self.imageView.clipsToBounds = YES;
  
  self.imageView.image = self.image;
  self.imageView.contentMode = UIViewContentModeScaleToFill;
  
  
  [self.view addSubview:self.imageView];
  // Erm.
  self.imageView.frame = [UIScreen mainScreen].bounds;
  
  self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
  self.pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinched:)];
  self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  
  [self.imageView addGestureRecognizer:self.pinchRecognizer];
  [self.imageView addGestureRecognizer:self.panRecognizer];
  [self.view addGestureRecognizer:self.tapRecognizer];
  
  self.imageView.userInteractionEnabled = YES;
  
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc ] initWithImage:bit_imageNamed(@"Cancel.png", BITHOCKEYSDK_BUNDLE) landscapeImagePhone:bit_imageNamed(@"Cancel.png", BITHOCKEYSDK_BUNDLE) style:UIBarButtonItemStyleBordered target:self action:@selector(discard:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc ] initWithImage:bit_imageNamed(@"Ok.png", BITHOCKEYSDK_BUNDLE) landscapeImagePhone:bit_imageNamed(@"Ok.png", BITHOCKEYSDK_BUNDLE) style:UIBarButtonItemStyleBordered target:self action:@selector(save:)];

  [self fitImageViewFrame];
}

- (BOOL)prefersStatusBarHidden {
  return self.navigationController.navigationBarHidden;
}


- (void)fitImageViewFrame {
  CGFloat heightScaleFactor = self.view.frame.size.height / self.image.size.height;
  CGFloat widthScaleFactor = self.view.frame.size.width / self.image.size.width;
  
  CGFloat factor = MIN(heightScaleFactor, widthScaleFactor);
  self.scaleFactor = factor;
  CGSize scaledImageSize = CGSizeMake(self.image.size.width * factor, self.image.size.height * factor);
  
  self.imageView.frame = CGRectMake(self.view.frame.size.width/2 - scaledImageSize.width/2, self.view.frame.size.height/2 - scaledImageSize.height/2, scaledImageSize.width, scaledImageSize.height);
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
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)save:(id)sender {
  UIImage *image = [self extractImage];
  [self.delegate annotationController:self didFinishWithImage:image];
  [self dismissViewControllerAnimated:YES completion:nil];
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

#pragma mark - UIGestureRecognizers

- (void)panned:(UIPanGestureRecognizer *)gestureRecognizer {
  BITImageAnnotation *annotationAtLocation = (BITImageAnnotation *)[self.view hitTest:[gestureRecognizer locationInView:self.view] withEvent:nil];
  
  if (![annotationAtLocation isKindOfClass:[BITImageAnnotation class]]){
    annotationAtLocation = nil;
  }
  
  // determine the interaction mode if none is set so far.
  
  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeNone){
    if (annotationAtLocation){
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeMove;
    } else if ([self canDrawNewAnnotation]){
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeDraw;
    }
  }
  
  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeNone){
    return;
  }
  

  if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeDraw){
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
      self.currentAnnotation = [self annotationForCurrentMode];
      [self.objects addObject:self.currentAnnotation];
      self.currentAnnotation.sourceImage = self.image;
      
      if (self.imageView.subviews.count > 0 && [self.currentAnnotation isKindOfClass:[BITBlurImageAnnotation class]]){
        [self.imageView insertSubview:self.currentAnnotation belowSubview:[self firstAnnotationThatIsNotBlur]];
      } else {
        [self.imageView addSubview:self.currentAnnotation];
      }
      
      self.panStart = [gestureRecognizer locationInView:self.imageView];
      
     // [self.editingControls setSelectedSegmentIndex:UISegmentedControlNoSegment];
      
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged){
      CGPoint bla = [gestureRecognizer locationInView:self.imageView];
      self.currentAnnotation.frame = CGRectMake(self.panStart.x, self.panStart.y, bla.x - self.panStart.x, bla.y - self.panStart.y);
      self.currentAnnotation.movedDelta = CGSizeMake(bla.x - self.panStart.x, bla.y - self.panStart.y);
      self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];
      [self.currentAnnotation setNeedsLayout];
      [self.currentAnnotation layoutIfNeeded];
    } else {
      [self.currentAnnotation setSelected:NO];
      self.currentAnnotation = nil;
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeNone;
    }
  } else if (self.currentInteraction == BITImageAnnotationViewControllerInteractionModeMove){
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
      // find and possibly move an existing annotation.

      
      if ([self.objects indexOfObject:annotationAtLocation] != NSNotFound){
        self.currentAnnotation = annotationAtLocation;
        [annotationAtLocation setSelected:YES];
      }
      
      
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged && self.currentAnnotation){
      CGPoint delta = [gestureRecognizer translationInView:self.view];
      
      CGRect annotationFrame = self.currentAnnotation.frame;
      annotationFrame.origin.x += delta.x;
      annotationFrame.origin.y += delta.y;
      self.currentAnnotation.frame = annotationFrame;
      self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];

      [self.currentAnnotation setNeedsLayout];
      [self.currentAnnotation layoutIfNeeded];
      
      [gestureRecognizer setTranslation:CGPointZero inView:self.view];
      
    } else {
      self.currentAnnotation = nil;
      [annotationAtLocation setSelected:NO];
      self.currentInteraction = BITImageAnnotationViewControllerInteractionModeNone;


    }
  }
}

-(void)pinched:(UIPinchGestureRecognizer *)gestureRecognizer {
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan){
    // try to figure out which view we are talking about.
    BITImageAnnotation *candidate = nil;
    BOOL validView = YES;
    
    for ( int i = 0; i<gestureRecognizer.numberOfTouches; i++){
      BITImageAnnotation *newCandidate = (BITImageAnnotation *)[self.view hitTest:[gestureRecognizer locationOfTouch:i inView:self.view] withEvent:nil];
      
      if (![newCandidate isKindOfClass:[BITImageAnnotation class]]){
        newCandidate = nil;
      }
      
      if (candidate == nil){
        candidate = newCandidate;
      } else if (candidate != newCandidate){
        validView = NO;
        break;
      }
    }
    
    if (validView && [candidate resizable]){
      self.currentAnnotation = candidate;
      self.pinchStartingFrame = self.currentAnnotation.frame;
    }
    
  } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged && self.currentAnnotation && gestureRecognizer.numberOfTouches>1){
    CGRect newFrame= (self.pinchStartingFrame);
    NSLog(@"%f", [gestureRecognizer scale]);
    
    // upper point?
    CGPoint point1 = [gestureRecognizer locationOfTouch:0 inView:self.view];
    CGPoint point2 = [gestureRecognizer locationOfTouch:1 inView:self.view];
    
    
    newFrame.origin.x = point1.x;
    newFrame.origin.y = point1.y;
    
    newFrame.origin.x = (point1.x > point2.x) ? point2.x : point1.x;
    newFrame.origin.y = (point1.y > point2.y) ? point2.y : point1.y;
    
    newFrame.size.width = (point1.x > point2.x) ? point1.x - point2.x : point2.x - point1.x;
    newFrame.size.height = (point1.y > point2.y) ? point1.y - point2.y : point2.y - point1.y;

    
    self.currentAnnotation.frame = newFrame;
    self.currentAnnotation.imageFrame = [self.view convertRect:self.imageView.frame toView:self.currentAnnotation];

    // we
    
    
  } else {
    self.currentAnnotation = nil;
  }
}

-(void)tapped:(UIGestureRecognizer *)tapRecognizer {
  if (self.navigationController.navigationBarHidden){
    [UIView animateWithDuration:0.35f animations:^{
      self.navigationController.navigationBar.alpha = 1;
    } completion:^(BOOL finished) {
      [self fitImageViewFrame];
      [self.navigationController setNavigationBarHidden:NO animated:NO];
      [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }];
  } else {
    [UIView animateWithDuration:0.35f animations:^{
      self.navigationController.navigationBar.alpha = 0;

    } completion:^(BOOL finished) {
      [self.navigationController setNavigationBarHidden:YES animated:NO];
      [[UIApplication sharedApplication] setStatusBarHidden:YES];


      [self fitImageViewFrame];
      
    }];    
  }
  
}

#pragma mark - Helpers

-(UIView *)firstAnnotationThatIsNotBlur {
  for (BITImageAnnotation *annotation in self.imageView.subviews){
    if (![annotation isKindOfClass:[BITBlurImageAnnotation class]]){
      return annotation;
    }
  }
  
  return self.imageView;
}

- (BOOL)canDrawNewAnnotation {
  return [self.editingControls selectedSegmentIndex] != UISegmentedControlNoSegment;
}
@end
