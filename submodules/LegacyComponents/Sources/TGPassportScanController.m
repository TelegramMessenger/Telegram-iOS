#import "TGPassportScanController.h"
#import "TGPassportScanView.h"

#import "LegacyComponentsInternal.h"

@interface TGPassportScanController ()
{
    TGPassportScanControllerTheme *_theme;
    
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;
    
    UIView *_topFadeView;
    UIView *_bottomFadeView;
    UIView *_centerFadeView;
    TGPassportScanView *_scanView;
}
@end

@implementation TGPassportScanController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context theme:(TGPassportScanControllerTheme *)theme
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _theme = theme;
        
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)]];
    }
    return self;
}

- (void)cancelButtonPressed
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = _theme.backgroundColor;
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.font = TGBoldSystemFontOfSize(23.0f);
    _titleLabel.numberOfLines = 0;
    _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _titleLabel.textColor = _theme.textColor;
    _titleLabel.text = TGLocalized(@"Passport.ScanPassport");
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_titleLabel];
    
    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.backgroundColor = [UIColor clearColor];
    _descriptionLabel.font = TGSystemFontOfSize(17.0f);
    _descriptionLabel.numberOfLines = 0;
    _descriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _descriptionLabel.textColor = _theme.textColor;
    _descriptionLabel.textAlignment = NSTextAlignmentCenter;
    _descriptionLabel.text = TGLocalized(@"Passport.ScanPassportHelp");
    [self.view addSubview:_descriptionLabel];
    
    __weak TGPassportScanController *weakSelf = self;
    _scanView = [[TGPassportScanView alloc] init];
    _scanView.finishedWithMRZ = ^(TGPassportMRZ *mrz)
    {
        __strong TGPassportScanController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf finishWithMRZ:mrz];
    };
    [self.view addSubview:_scanView];
    
    _topFadeView = [[UIView alloc] init];
    _topFadeView.backgroundColor = UIColorRGBA(0x000000, 0.4f);
    [self.view addSubview:_topFadeView];
    
    _bottomFadeView = [[UIView alloc] init];
    _bottomFadeView.backgroundColor = UIColorRGBA(0x000000, 0.4f);
    [self.view addSubview:_bottomFadeView];
    
    _centerFadeView = [[UIView alloc] init];
    _centerFadeView.alpha = 0.0f;
    _centerFadeView.backgroundColor = UIColorRGBA(0x000000, 0.4f);
    [self.view addSubview:_centerFadeView];
}

- (void)finishWithMRZ:(TGPassportMRZ *)mrz
{
    UILabel *label = [[UILabel alloc] init];
    label.font = TGFixedSystemFontOfSize(17.0f);
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 3;
    label.text = mrz.mrz;
    [label sizeToFit];
    if (label.frame.size.width > self.view.frame.size.width - 20.0f)
    {
        label.font = TGFixedSystemFontOfSize(16.0f);
        [label sizeToFit];
    }
    label.center = CGPointMake(self.view.frame.size.width / 2.0f, CGRectGetMaxY(_centerFadeView.frame) - label.frame.size.height / 2.0f - 50.0f);
    [self.view addSubview:label];
    
    label.alpha = 0.0f;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        label.alpha = 1.0f;
        _centerFadeView.alpha = 1.0f;
    }];
    
    TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
    {
        if (self.finishedWithMRZ != nil)
            self.finishedWithMRZ(mrz);
        [self cancelButtonPressed];
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_scanView start];
    
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:true];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [_scanView stop];
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:false];
}

- (void)manualButtonPressed
{
    if (self.finishedWithMRZ != nil)
        self.finishedWithMRZ(nil);
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGFloat inset = 30.0f;
    CGSize textSize = [_titleLabel.attributedText boundingRectWithSize:CGSizeMake(self.view.frame.size.width - inset, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:NULL].size;
    textSize.width = CGCeil(textSize.width);
    textSize.height = CGCeil(textSize.height);
    
    CGFloat scanHeight = MIN(475.0f, self.view.frame.size.height - textSize.height - 64.0f - 160.0f);
    _scanView.frame = CGRectMake(0.0f, 64.0f, self.view.frame.size.width, scanHeight);
    
    CGFloat documentFrameHeight = self.view.frame.size.width * 0.704f;
    CGFloat documentTopEdge = CGRectGetMidY(_scanView.frame) - documentFrameHeight / 2.0f;
    CGFloat documentBottomEdge = CGRectGetMidY(_scanView.frame) + documentFrameHeight / 2.0f;

    _topFadeView.frame = CGRectMake(0.0f, CGRectGetMinY(_scanView.frame), self.view.frame.size.width, documentTopEdge - CGRectGetMinY(_scanView.frame));
    _bottomFadeView.frame = CGRectMake(0.0f, documentBottomEdge, self.view.frame.size.width, CGRectGetMaxY(_scanView.frame) - documentBottomEdge);
    _centerFadeView.frame = CGRectMake(0.0f, CGRectGetMaxY(_topFadeView.frame), self.view.frame.size.width, CGRectGetMinY(_bottomFadeView.frame) - CGRectGetMaxY(_topFadeView.frame));
    
    UIEdgeInsets safeAreaInset = self.calculatedSafeAreaInset;
    CGFloat textPanelHeight = self.view.frame.size.height - 64.0f - scanHeight - safeAreaInset.bottom;
    
    CGSize descriptionSize = [_descriptionLabel.attributedText boundingRectWithSize:CGSizeMake(self.view.frame.size.width - inset, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:NULL].size;
    descriptionSize.width = CGCeil(descriptionSize.width);
    descriptionSize.height = CGCeil(descriptionSize.height);

    _titleLabel.frame = CGRectMake(TGScreenPixelFloor((self.view.frame.size.width - textSize.width) / 2.0f), TGScreenPixelFloor(CGRectGetMaxY(_scanView.frame) + (textPanelHeight - textSize.height - 12.0f - descriptionSize.height) / 2.0f), textSize.width, textSize.height);
    
    _descriptionLabel.frame = CGRectMake(round((self.view.frame.size.width - descriptionSize.width) / 2.0f), CGRectGetMaxY(_titleLabel.frame) + 12.0f, descriptionSize.width, descriptionSize.height);
}

- (BOOL)shouldAutorotate
{
    return false;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

@end

@implementation TGPassportScanControllerTheme

- (instancetype)initWithBackgroundColor:(UIColor *)backgroundColor textColor:(UIColor *)textColor
{
    self = [super init];
    if (self != nil)
    {
        _backgroundColor = backgroundColor;
        _textColor = textColor;
    }
    return self;
}

@end
