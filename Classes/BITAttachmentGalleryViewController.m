//
//  BITAttachmentGalleryViewController.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 06.03.14.
//
//

#import "BITAttachmentGalleryViewController.h"

#import "BITFeedbackMessage.h"
#import "BITFeedbackMessageAttachment.h"

@interface BITAttachmentGalleryViewController ()<UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray *imageViews;
@property (nonatomic, strong) NSArray *extractedAttachments;
@property (nonatomic) NSInteger currentIndex;
@property (nonatomic) NSInteger loadedImageIndex;
@property (nonatomic, strong) UITapGestureRecognizer *tapognizer;

@end

@implementation BITAttachmentGalleryViewController

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
  self.automaticallyAdjustsScrollViewInsets = NO;
  self.navigationController.navigationBar.translucent = YES;
  self.edgesForExtendedLayout = YES;
  self.extendedLayoutIncludesOpaqueBars = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close:)];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
  
  
  self.currentIndex = 0;
  
  [self extractUsableAttachments];
  [self setupScrollView];
  
  [self layoutViews];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  

  
  self.tapognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  [self.view addGestureRecognizer:self.tapognizer];

}
- (void)setupScrollView {
  self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
  self.view.autoresizesSubviews = NO;
  [self.view addSubview:self.scrollView];
  self.scrollView.delegate = self;
  self.scrollView.pagingEnabled = YES;
  self.scrollView.backgroundColor = [UIColor groupTableViewBackgroundColor];
  self.scrollView.bounces = NO;
  
  
  NSMutableArray *imageviews = [NSMutableArray new];
  
  for (int i = 0; i<3; i++){
    UIImageView *newImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [imageviews addObject:newImageView];
    newImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:newImageView];
  }
  
  self.imageViews = imageviews;
  
}

- (void)extractUsableAttachments {
  NSMutableArray *extractedOnes = [NSMutableArray new];
  
  for (BITFeedbackMessage *message in self.messages){
    for (BITFeedbackMessageAttachment *attachment in message.attachments){
      if ([attachment imageRepresentation]){
        [extractedOnes addObject:attachment];
      }
    }
  }
  
  self.extractedAttachments = extractedOnes;
  
  [self layoutViews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  NSInteger newIndex = self.scrollView.contentOffset.x / self.scrollView.frame.size.width;
  if (newIndex!=self.currentIndex){
    self.currentIndex = newIndex;
    // requeue elements.
    NSInteger baseIndex = MAX(0,self.currentIndex-1);
    [self layoutViews];

    
  }
}

- (void)layoutViews {
  
  self.scrollView.frame = self.view.bounds;
  self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.view.bounds) * self.extractedAttachments.count, CGRectGetHeight(self.view.bounds));

  NSInteger baseIndex = MAX(0,self.currentIndex-1);
  NSInteger z = baseIndex;
  for ( NSInteger i = baseIndex; i < MIN(baseIndex+2, self.extractedAttachments.count);i++ ){
    UIImageView *imageView = self.imageViews[z];
    BITFeedbackMessageAttachment *attachment = self.extractedAttachments[i];
    imageView.image =[attachment imageRepresentation];
    imageView.frame = [self frameForItemAtIndex:i];
    z++;
  }

  
}

- (BOOL)prefersStatusBarHidden {
  return self.navigationController.navigationBarHidden;
}

- (void)close:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)share:(id)sender {
  BITFeedbackMessageAttachment *attachment = self.extractedAttachments[self.currentIndex];

  UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObjects:attachment.originalFilename, attachment.imageRepresentation  , nil] applicationActivities:nil];
  [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)tapped:(UITapGestureRecognizer *)tapRecognizer {
  if (self.navigationController.navigationBarHidden){
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
  } else {
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];

  }
}

- (CGRect)frameForItemAtIndex:(NSInteger)index {
  return CGRectMake(index * CGRectGetWidth(self.scrollView.frame), 0, CGRectGetWidth(self.scrollView.frame), CGRectGetHeight(self.scrollView.frame));
}

@end
