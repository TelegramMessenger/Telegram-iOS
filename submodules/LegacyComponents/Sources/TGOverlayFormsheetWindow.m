#import "TGOverlayFormsheetWindow.h"

#import "LegacyComponentsInternal.h"
#import "TGViewController.h"

#import "TGOverlayFormsheetController.h"


@interface TGOverlayFormsheetWindow ()
{
    __weak TGViewController *_parentController;
    UIViewController *_contentController;
    
    SMetaDisposable *_sizeClassDisposable;
    UIUserInterfaceSizeClass _sizeClass;
    
    id<LegacyComponentsOverlayWindowManager> _manager;
    bool _managedIsHidden;
}
@end

@implementation TGOverlayFormsheetWindow

- (instancetype)initWithManager:(id<LegacyComponentsOverlayWindowManager>)manager parentController:(TGViewController *)parentController contentController:(UIViewController *)contentController
{
    self = [super initWithFrame:[[manager context] fullscreenBounds]];
    if (self != nil)
    {
        _manager = manager;
        self.windowLevel = parentController.view.window.windowLevel + 0.0001f;
        self.backgroundColor = [UIColor clearColor];
        
        _parentController = parentController;
        [parentController.associatedWindowStack addObject:self];
        
        _contentController = contentController;
        
        [_manager bindController:_contentController];
    }
    return self;
}

- (void)dealloc
{
    [_sizeClassDisposable dispose];
}

- (BOOL)isHidden {
    return _managedIsHidden;
}

- (void)setHidden:(BOOL)hidden {
    if ([_manager managesWindow]) {
        if (![super isHidden]) {
            [super setHidden:true];
        }
        
        if (_managedIsHidden != hidden) {
            _managedIsHidden = hidden;
            [_manager setHidden:hidden window:self];
        }
    } else {
        [super setHidden:hidden];
        
        if (!hidden) {
            [[[LegacyComponentsGlobals provider] applicationWindows].firstObject endEditing:true];
        }
    }
}

- (void)showAnimated:(bool)animated
{
    if ([self contentController].parentViewController != _parentController)
    {
        [[self contentController] removeFromParentViewController];
        [[self.contentController view] removeFromSuperview];
        
        [_parentController presentViewController:[self contentController] animated:animated completion:nil];
        //self.hidden = true;
    }
}

- (void)_dismiss
{
    TGViewController *parentController = _parentController;
    [parentController.associatedWindowStack removeObject:self];
    [_manager setHidden:true window:self];
    //self.hidden = true;
}

- (void)dismissAnimated:(bool)animated
{
    if (animated)
    {
        [[self controller] animateOutWithCompletion:^
        {
            [self _dismiss];
        }];
    }
    else
    {
        [self _dismiss];
    }
}

- (UIViewController *)contentController
{
    if ([self controller] != nil)
        return [self controller].viewController;
    else
        return _contentController;
}

- (TGOverlayFormsheetController *)controller
{
    return  (TGOverlayFormsheetController *)self.rootViewController;
}
         
@end
