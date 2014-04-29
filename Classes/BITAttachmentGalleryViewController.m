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
@property (nonatomic, strong) NSMutableDictionary *images;

@end

@implementation BITAttachmentGalleryViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
  self.navigationController.navigationBar.translucent = YES;
  self.navigationController.navigationBar.opaque = NO;
#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_6_1
  self.automaticallyAdjustsScrollViewInsets = NO;
  self.edgesForExtendedLayout = YES;
  self.extendedLayoutIncludesOpaqueBars = YES;
#endif
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close:)];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
  
  
  self.currentIndex = 0;
  
  [self extractUsableAttachments];
  [self setupScrollView];
  
  self.view.frame = UIScreen.mainScreen.applicationFrame;
  
  
  
  self.tapognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
  [self.view addGestureRecognizer:self.tapognizer];
}

-(void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  // Hide the navigation bar and stuff initially.
  [self tapped:nil];
  
  if (self.preselectedAttachment){
    NSInteger indexOfSelectedAttachment = [self.extractedAttachments indexOfObject:self.preselectedAttachment];
    if (indexOfSelectedAttachment != NSNotFound){
      self.currentIndex = indexOfSelectedAttachment;
      self.scrollView.contentOffset = CGPointMake(self.scrollView.frame.size.width * self.currentIndex, 0);
    }
  }
  
  self.images = [NSMutableDictionary new];
  [self layoutViews];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self.images removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  [self.images removeAllObjects];
}

- (BOOL)prefersStatusBarHidden {
  return self.navigationController.navigationBarHidden;
}

#pragma mark - Scroll View Content/Layout

- (void)setupScrollView {
  self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
  CGRect frame = self.scrollView.frame;
  
  frame.origin.y = self.scrollView.frame.size.height - [[UIScreen mainScreen] bounds].size.height;
  
  self.scrollView.frame = frame;
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
}


- (void)layoutViews {
  CGPoint savedOffset = self.scrollView.contentOffset;
  
  self.scrollView.delegate = nil;
  self.scrollView.frame = self.view.bounds;
  self.scrollView.contentSize = CGSizeMake( [[UIScreen mainScreen] bounds].size.width * self.extractedAttachments.count, [[UIScreen mainScreen] bounds].size.height);
  self.scrollView.delegate = self;
  self.scrollView.contentInset = UIEdgeInsetsZero;
  self.scrollView.autoresizesSubviews = NO;
  self.scrollView.contentOffset = savedOffset;
  
  
  NSInteger baseIndex = MAX(0,self.currentIndex-1);
  NSInteger z = baseIndex;
  for ( NSInteger i = baseIndex; i < MIN(baseIndex+2, self.extractedAttachments.count);i++ ){
    UIImageView *imageView = self.imageViews[z%self.imageViews.count];
    BITFeedbackMessageAttachment *attachment = self.extractedAttachments[i];
    imageView.image = [self imageForAttachment:attachment];
    imageView.frame = [self frameForItemAtIndex:i];
    z++;
  }
  
  CGRect frame = self.scrollView.frame;
  
  frame.origin.y = self.scrollView.frame.size.height - [[UIScreen mainScreen] bounds].size.height;
  
  self.scrollView.frame = frame;
  
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  NSInteger newIndex = self.scrollView.contentOffset.x / self.scrollView.frame.size.width;
  if (newIndex!=self.currentIndex){
    self.currentIndex = newIndex;
    [self layoutViews];
  }
}

#pragma mark - IBActions

- (void)close:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)share:(id)sender {
  BITFeedbackMessageAttachment *attachment = self.extractedAttachments[self.currentIndex];

  UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObjects:attachment.originalFilename, attachment.imageRepresentation  , nil] applicationActivities:nil];
  [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - UIGestureRecognizer

- (void)tapped:(UITapGestureRecognizer *)tapRecognizer {
  if (self.navigationController.navigationBar.alpha == 0 || self.navigationController.navigationBarHidden ){
    
    [UIView animateWithDuration:0.35f animations:^{
      
      if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
      } else {
        self.navigationController.navigationBar.alpha = 1.0;
      }
      
      [[UIApplication sharedApplication] setStatusBarHidden:NO];
      
    } completion:^(BOOL finished){
      [self layoutViews];
    }];
  } else {
    [UIView animateWithDuration:0.35f animations:^{
      
      if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
      } else {
        self.navigationController.navigationBar.alpha = 0.0;
      }
      
      [[UIApplication sharedApplication] setStatusBarHidden:YES];
      
    } completion:^(BOOL finished){
       [self layoutViews];
    }];
  }
  
 
}

#pragma mark - Layout Helpers

- (CGRect)frameForItemAtIndex:(NSInteger)index {
  return CGRectMake(index * [[UIScreen mainScreen] bounds].size.width, 0, [[UIScreen mainScreen] bounds].size.width,    [[UIScreen mainScreen] bounds].size.height);
}

- (UIImage *)imageForAttachment:(BITFeedbackMessageAttachment *)attachment {
  UIImage *cachedObject = self.images[@([self.extractedAttachments indexOfObject:attachment])];
  
  if (!cachedObject){
    cachedObject = [attachment imageRepresentation];
    self.images[@([self.extractedAttachments indexOfObject:attachment])] = cachedObject;
  }
  
  return cachedObject;
}

@end
