#import "TGPhotoCaptionController.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "PGPhotoEditor.h"
#import "TGPhotoCaptionInputMixin.h"

#import "TGSuggestionContext.h"

#import "TGPhotoEditorController.h"
#import "TGPhotoEditorPreviewView.h"

@interface TGPhotoCaptionController ()
{
    UIView *_wrapperView;
    TGPhotoCaptionInputMixin *_captionMixin;
    NSString *_initialCaption;
    
    bool _transitionedIn;
    CGFloat _keyboardHeight;
    
    bool _appeared;
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoCaptionController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView caption:(NSString *)caption
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _initialCaption = caption;
        
        __weak TGPhotoCaptionController *weakSelf = self;
        _captionMixin = [[TGPhotoCaptionInputMixin alloc] initWithKeyCommandController:[context keyCommandController]];
        _captionMixin.panelParentView = ^UIView *
        {
            __strong TGPhotoCaptionController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            return strongSelf.view;
        };

        _captionMixin.finishedWithCaption = ^(NSString *caption, NSArray *entities)
        {
            __strong TGPhotoCaptionController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_dismissing = true;
            
            if (strongSelf.captionSet != nil)
                strongSelf.captionSet(caption, entities);
            
            if (strongSelf->_keyboardHeight == 0)
                [strongSelf->_captionMixin.inputPanel setCollapsed:true animated:true];
        };
        
        _captionMixin.keyboardHeightChanged = ^(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve)
        {
            __strong TGPhotoCaptionController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_keyboardHeight = keyboardHeight;
            
            if (!strongSelf->_transitionedIn)
            {
                strongSelf.transitionInPending = false;
                strongSelf->_transitionedIn = true;
                [strongSelf animateTransitionInWithDuration:duration curve:animationCurve];
            }
            else
            {
                [UIView animateWithDuration:duration delay:0.0f options:animationCurve animations:^
                {
                    [strongSelf updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
                } completion:nil];
            }
        };
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.interactionEnded = ^{ };
    [self.view addSubview:_previewView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    if (self.initialAppearance || ![_transitionView isKindOfClass:[TGPhotoEditorPreviewView class]])
        previewView.hidden = true;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _captionMixin.suggestionContext = self.suggestionContext;
    [_captionMixin beginEditing];
    
    if (_keyboardHeight == 0 && !_transitionedIn)
    {
        [_captionMixin.inputPanel setCollapsed:true];
        _transitionedIn = true;
        [self animateTransitionInWithDuration:0.25 curve:UIViewAnimationOptionCurveEaseInOut];
        self.transitionInPending = false;
        [_captionMixin.inputPanel setCollapsed:false animated:true];
    }
}

- (void)viewWillAppear:(BOOL)__unused animated
{
    
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))completion
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.interactionEnded = nil;
    
    if (completion != nil)
        completion();
}

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)__unused parentView noTransitionView:(bool)__unused noTransitionView
{
    self.transitionInPending = true;

    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    UIView *transitionViewSuperview = nil;
    UIImage *transitionImage = nil;
    if ([referenceView isKindOfClass:[UIImageView class]])
        transitionImage = ((UIImageView *)referenceView).image;
    
    if (transitionImage != nil)
    {
        _transitionView = [[UIImageView alloc] initWithImage:transitionImage];
        _transitionView.clipsToBounds = true;
        _transitionView.contentMode = UIViewContentModeScaleAspectFill;
        transitionViewSuperview = parentView;
    }
    else
    {
        _transitionView = referenceView;
        transitionViewSuperview = self.view;
    }
    
    _transitionView.frame = referenceFrame;
    [transitionViewSuperview addSubview:_transitionView];

}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    
    if ([self inFormSheet])
        referenceSize = CGSizeMake(540.0f, 620.0f);
    
    CGRect containerFrame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                containerFrame.origin.y + (containerFrame.size.height - fittedSize.height - _keyboardHeight) / 2,
                                fittedSize.width,
                                fittedSize.height);
    
    return toFrame;
}

- (void)animateTransitionInWithDuration:(NSTimeInterval)duration curve:(NSInteger)curve
{
    if ([_transitionView isKindOfClass:[TGPhotoEditorPreviewView class]])
        _transitionView.hidden = false;
    
    self.transitionInProgress = true;
    
    [UIView animateWithDuration:duration delay:0.0f options:curve animations:^
    {
        _transitionView.frame = [self _targetFrameForTransitionInFromFrame:_transitionView.frame];
    } completion:^(__unused BOOL finished)
    {
        self.transitionInProgress = false;
        
        UIView *transitionView = _transitionView;
        _transitionView = nil;
        
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
        
        [self _finishedTransitionInWithView:transitionView];
    }];
}

- (BOOL)shouldAutorotate
{
    return false;
}

- (bool)isDismissAllowed
{
    return _appeared;
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    [previewView prepareForTransitionOut];
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    
    if (saving && CGRectIsNull(targetFrame) && parentView != nil)
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = previewView.frame;
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2,
                                 (self.view.frame.size.height - fittedSize.height) / 2,
                                 fittedSize.width,
                                 fittedSize.height);
        
        [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    }
    
    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    
    NSMutableArray *animations = [NSMutableArray arrayWithArray:@[ previewAnimation, previewAlphaAnimation ]];
    if (snapshotAnimation != nil)
        [animations addObject:snapshotAnimation];
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
     {
         [snapshotView removeFromSuperview];
         
         if (completion != nil)
             completion();
     } whenCompletedAllAnimations:animations];
    
    if (snapshotAnimation != nil)
        [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAlphaAnimation forKey:@"alpha"];
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    [_captionMixin enableDismissal];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = false;
    [previewView performTransitionInIfNeeded];
    
    if (![transitionView isKindOfClass:[TGPhotoEditorPreviewView class]])
        [transitionView removeFromSuperview];
}

- (CGRect)transitionOutReferenceFrame
{
    TGPhotoEditorPreviewView *previewView = _previewView;
    return previewView.frame;
}

- (UIView *)transitionOutReferenceView
{
    return _previewView;
}

- (UIView *)snapshotView
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return [previewView originalSnapshotView];
}

- (id)currentResultRepresentation
{
    return self.photoEditor.currentResultImage;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (void)updateLayout:(UIInterfaceOrientation)__unused orientation
{
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoEditorPanelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view || self.transitionInPending)
        return;
    
    CGRect containerFrame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                   containerFrame.origin.y + (containerFrame.size.height - fittedSize.height - _keyboardHeight) / 2,
                                   fittedSize.width,
                                   fittedSize.height);
    
    [_captionMixin setContentAreaHeight:self.view.frame.size.height];
}

@end
