#import "TGMenuSheetItemView.h"

#import "LegacyComponentsInternal.h"

@implementation TGMenuSheetItemView

- (instancetype)initWithType:(TGMenuSheetItemType)type
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _type = type;
    }
    return self;
}

- (void)setDark
{
    
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        self.alpha = hidden ? 0.0f : 1.0f;
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
            self.userInteractionEnabled = !hidden;
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.18 animations:changeBlock completion:completionBlock];
    }
    else
    {
        changeBlock();
        completionBlock(true);
    }
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    
}

- (CGFloat)contentHeightCorrection
{
    return 0;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    return 0;
}

- (bool)passPanOffset:(CGFloat)__unused offset
{
    return true;
}

- (void)requestMenuLayoutUpdate
{
    if (self.layoutUpdateBlock != nil)
        self.layoutUpdateBlock();
}

- (void)_updateHeightAnimated:(bool)animated
{
    if (animated)
    {
        UIViewAnimationOptions options = UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionLayoutSubviews;
        if (iosMajorVersion() >= 7)
            options = options | (7 << 16);
        
        [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^
        {
            [self requestMenuLayoutUpdate];
        } completion:nil];
    }
    else
    {
        [self requestMenuLayoutUpdate];
    }
}

- (void)_didLayoutSubviews
{
}

- (void)_willRotateToInterfaceOrientation:(UIInterfaceOrientation)__unused orientation duration:(NSTimeInterval)__unused duration
{
}

- (void)_didRotateToInterfaceOrientation:(UIInterfaceOrientation)__unused orientation
{
}

- (void)didChangeAbsoluteFrame
{
}

- (void)menuView:(TGMenuSheetView *)__unused menuView willAppearAnimated:(bool)__unused animated
{
}

- (void)menuView:(TGMenuSheetView *)__unused menuView didAppearAnimated:(bool)__unused animated
{
}

- (void)menuView:(TGMenuSheetView *)__unused menuView willDisappearAnimated:(bool)__unused animated
{
}

- (void)menuView:(TGMenuSheetView *)__unused menuView didDisappearAnimated:(bool)__unused animated
{
}

#pragma mark - 

- (UIView *)previewSourceView
{
    return nil;
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)__unused previewingContext viewControllerForLocation:(CGPoint)__unused location
{
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)__unused previewingContext commitViewController:(UIViewController *)__unused viewControllerToCommit
{
}

@end
