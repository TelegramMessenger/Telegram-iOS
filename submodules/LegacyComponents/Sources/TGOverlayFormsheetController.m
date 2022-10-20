#import "TGOverlayFormsheetController.h"

#import <LegacyComponents/LegacyComponents.h>

const CGSize TGOverlayFormsheetControllerReferenceSize = { 540.0f, 620.0f };

@interface TGOverlayFormsheetController ()
{
    UIControl *_dimView;
    UIView *_wrapperView;
    UIView *_contentView;
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGOverlayFormsheetController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context contentController:(UIViewController *)viewController
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _viewController = viewController;
        [self addChildViewController:viewController];
        
        _dimView = [[UIControl alloc] initWithFrame:self.view.frame];
        _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _dimView.backgroundColor = [UIColor colorWithRed:0.027451f green:0.0431373f blue:0.0666667f alpha:0.5f];
        [self.view addSubview:_dimView];
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, TGOverlayFormsheetControllerReferenceSize.width, TGOverlayFormsheetControllerReferenceSize.height)];
        _wrapperView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        [self.view addSubview:_wrapperView];
        
        _contentView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
        _contentView.backgroundColor = [UIColor whiteColor];
        _contentView.clipsToBounds = true;
        _contentView.layer.cornerRadius = 6.0f;
        [_wrapperView addSubview:_contentView];
        
        [self setContentController:viewController];
    }
    return self;
}

- (void)setContentController:(UIViewController *)viewController
{
    if (viewController.presentingViewController != nil)
        return;
    
    [self addChildViewController:viewController];
    
    viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    viewController.view.frame = CGRectMake(0, 0, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    [_contentView addSubview:viewController.view];
}

- (void)animateInWithCompletion:(void (^)(void))completion
{
    CGRect targetFrame = _wrapperView.frame;
    _wrapperView.frame = CGRectMake(_wrapperView.frame.origin.x, self.view.frame.size.height, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    
    _wrapperView.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:(7 << 16) animations:^
    {
        _wrapperView.frame = targetFrame;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
        
        _wrapperView.layer.shouldRasterize = false;
    }];
}

- (void)animateOutWithCompletion:(void (^)(void))completion
{
    _wrapperView.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:(7 << 16) animations:^
    {
        _dimView.alpha = 0.0f;
        _wrapperView.frame = CGRectMake(_wrapperView.frame.origin.x, self.view.frame.size.height, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    } completion:^(__unused BOOL finished)
    {
        _wrapperView.layer.shouldRasterize = false;
        if (completion != nil)
            completion();
    }];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (void)updateLayout:(UIInterfaceOrientation)__unused orientation
{
    CGSize referenceSize = [_context fullscreenBounds].size;
    _wrapperView.frame = CGRectMake((referenceSize.width - _wrapperView.frame.size.width) / 2, (referenceSize.height - _wrapperView.frame.size.height) / 2, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
}

@end
