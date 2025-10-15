#import <LegacyComponents/LegacyComponents.h>
#import "TGPhotoAvatarPreviewController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

#import "PGPhotoEditor.h"
#import "PGPhotoEditorView.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>

#import <LegacyComponents/TGPhotoEditorController.h>
#import "TGPhotoEditorPreviewView.h"
#import <LegacyComponents/TGPhotoAvatarCropView.h>

#import "TGMediaPickerGalleryVideoScrubber.h"
#import <LegacyComponents/TGModernGalleryVideoView.h>


#import <LegacyComponents/TGPhotoPaintStickersContext.h>

#import "TGPhotoDrawingController.h"

const CGFloat TGPhotoAvatarPreviewPanelSize = 96.0f;
const CGFloat TGPhotoAvatarPreviewLandscapePanelSize = TGPhotoAvatarPreviewPanelSize + 40.0f;

@interface TGPhotoAvatarPreviewController ()
{
    bool _dismissingToCamera;
    bool _appeared;
    UIImage *_imagePendingLoad;
    UIView *_snapshotView;
    UIImage *_snapshotImage;
    
    UIView *_wrapperView;
    
    __weak TGPhotoAvatarCropView *_cropView;
    
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    UIView *_portraitWrapperBackgroundView;
    UIView *_landscapeWrapperBackgroundView;

    UIView *_portraitToolControlView;
    UIView *_landscapeToolControlView;
    UILabel *_coverLabel;
    
    TGModernButton *_cancelButton;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIView<TGPhotoSolidRoundedButtonView> *_doneButton;
    
    bool _wasPlayingBeforeCropping;
    
    bool _scheduledTransitionIn;
    
    bool _isForum;
    bool _isSuggestion;
    bool _isSuggesting;
    NSString *_senderName;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoAvatarPreviewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView isForum:(bool)isForum isSuggestion:(bool)isSuggestion isSuggesting:(bool)isSuggesting senderName:(NSString *)senderName {
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        _isForum = isForum;
        _isSuggestion = isSuggestion;
        _isSuggesting = isSuggesting;
        _senderName = senderName;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    [_previewView performTransitionInWithCompletion:^{}];
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    __weak TGPhotoAvatarPreviewController *weakSelf = self;
    void(^interactionBegan)(void) = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.isVideoPlaying != nil) {
            strongSelf->_wasPlayingBeforeCropping =  strongSelf.isVideoPlaying() || strongSelf->_wasPlayingBeforeCropping;
        }
            
        strongSelf.controlVideoPlayback(false);
    };
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
        
        if (strongSelf->_wasPlayingBeforeCropping) {
            strongSelf.controlVideoPlayback(true);
        }
    };
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoAvatarCropView *cropView = [[TGPhotoAvatarCropView alloc] initWithOriginalSize:photoEditor.originalSize screenSize:[self referenceViewSize] fullPreviewView:_fullPreviewView fullPaintingView:_fullPaintingView fullEntitiesView:_fullEntitiesView square:_isForum];
    _cropView = cropView;
    [_cropView setCropRect:photoEditor.cropRect];
    [_cropView setCropOrientation:photoEditor.cropOrientation];
    [_cropView setCropMirrored:photoEditor.cropMirrored];
    _cropView.tapped = ^{
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.togglePlayback != nil)
             strongSelf.togglePlayback();
    };
    _cropView.croppingChanged = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        photoEditor.cropRect = strongSelf->_cropView.cropRect;
        photoEditor.cropOrientation = strongSelf->_cropView.cropOrientation;
        photoEditor.cropMirrored = strongSelf->_cropView.cropMirrored;
        
        if (strongSelf.croppingChanged != nil)
            strongSelf.croppingChanged();
    };
    if (_snapshotView != nil)
    {
        [_cropView setSnapshotView:_snapshotView];
        _snapshotView = nil;
    }
    else if (_snapshotImage != nil)
    {
        [_cropView setSnapshotImage:_snapshotImage];
        _snapshotImage = nil;
    }
    _cropView.interactionBegan = interactionBegan;
    _cropView.interactionEnded = interactionEnded;
    [_wrapperView addSubview:cropView];
    
    _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_portraitToolsWrapperView];
    
    if (self.item.isVideo) {
        _portraitWrapperBackgroundView = [[UIView alloc] initWithFrame:_portraitToolsWrapperView.bounds];
        _portraitWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _portraitWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _portraitWrapperBackgroundView.userInteractionEnabled = false;
        [_portraitToolsWrapperView addSubview:_portraitWrapperBackgroundView];

        _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        [_wrapperView addSubview:_landscapeToolsWrapperView];
        
        _landscapeWrapperBackgroundView = [[UIView alloc] initWithFrame:_landscapeToolsWrapperView.bounds];
        _landscapeWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _landscapeWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _landscapeWrapperBackgroundView.userInteractionEnabled = false;
        [_landscapeToolsWrapperView addSubview:_landscapeWrapperBackgroundView];
                
        [_portraitToolsWrapperView addSubview:_scrubberView];
        
        _coverLabel = [[UILabel alloc] init];
        _coverLabel.alpha = 0.7f;
        _coverLabel.backgroundColor = [UIColor clearColor];
        _coverLabel.font = TGSystemFontOfSize(14.0f);
        _coverLabel.textColor = [UIColor whiteColor];
        _coverLabel.text = _isSuggesting ? TGLocalized(@"PhotoEditor.SelectCoverFrameSuggestion") : TGLocalized(@"PhotoEditor.SelectCoverFrame");
        [_coverLabel sizeToFit];
        [_portraitToolsWrapperView addSubview:_coverLabel];
        
        [_wrapperView addSubview:_dotImageView];
    }
    
    if (_isSuggestion) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(17.0f);
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.text = self.item.isVideo ? TGLocalized(@"Conversation.SuggestedVideoTitle") : TGLocalized(@"Conversation.SuggestedPhotoTitle");
        [_titleLabel sizeToFit];
        [_wrapperView addSubview:_titleLabel];
        
        NSMutableAttributedString *subtitle = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:self.item.isVideo ? TGLocalized(@"Conversation.SuggestedVideoTextExpanded") : TGLocalized(@"Conversation.SuggestedPhotoTextExpanded"), _senderName]];
        [subtitle addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, subtitle.string.length)];
        [subtitle addAttribute:NSFontAttributeName value:TGSystemFontOfSize(15.0f) range:NSMakeRange(0, subtitle.string.length)];
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineSpacing = 5.0f;
        [subtitle addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, subtitle.string.length)];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.attributedText = subtitle;
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.numberOfLines = 2;
        if (!self.item.isVideo) {
            [_wrapperView addSubview:_subtitleLabel];
        }
        
        if (!self.item.isVideo) {
            _cancelButton = [[TGModernButton alloc] init];
            [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
            _cancelButton.titleLabel.font = TGSystemFontOfSize(17.0);
            [_cancelButton sizeToFit];
            [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_wrapperView addSubview:_cancelButton];
            
            if (_stickersContext != nil) {
                _doneButton = [_stickersContext solidRoundedButton:self.item.isVideo ? TGLocalized(@"PhotoEditor.SetAsMyVideo") : TGLocalized(@"PhotoEditor.SetAsMyPhoto") action:^{
                    __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (strongSelf.donePressed != nil)
                        strongSelf.donePressed();
                }];
                [_wrapperView addSubview:_doneButton];
            }
        }
    }
}

- (void)cancelButtonPressed {
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_appeared)
        return;
    
    if (self.initialAppearance && self.skipTransitionIn)
    {
        [self _finishedTransitionInWithView:nil];
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
    }
    else
    {
        [self transitionIn];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _appeared = true;
    
    if (_imagePendingLoad != nil)
        [_cropView setImage:_imagePendingLoad];
}

- (BOOL)shouldAutorotate
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && !_cropView.isTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared && !_cropView.isTracking && !_cropView.isAnimating;
}

#pragma mark -

- (void)setImage:(UIImage *)image
{
    if (_dismissing && !_switching)
        return;
        
    if (!_appeared)
    {
        _imagePendingLoad = image;
        return;
    }
        
    [_cropView setImage:image];
}

- (void)setSnapshotImage:(UIImage *)snapshotImage
{
    _snapshotImage = snapshotImage;
    [_cropView _replaceSnapshotImage:snapshotImage];
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    _snapshotView = snapshotView;
}

#pragma mark - Transition

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)parentView noTransitionView:(bool)noTransitionView
{
    [super prepareTransitionInWithReferenceView:referenceView referenceFrame:referenceFrame parentView:parentView noTransitionView:noTransitionView];
    
    if (self.initialAppearance && self.fromCamera)
        [self.view insertSubview:_transitionView belowSubview:_wrapperView];
}

- (void)animateTransitionIn {
    if (self.initialAppearance) {
        [super animateTransitionIn];
        return;
    } else {
        _animateScale = true;
        
        [self transitEntities:_previewView];
        
        [super animateTransitionIn];
    }
}

+ (CGRect)fittedCropRect:(CGRect)cropRect originalSize:(CGSize)originalSize fitSize:(CGSize)fitSize {
    CGSize fittedOriginalSize = TGScaleToSize(originalSize, fitSize);
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    
    CGSize size = fittedOriginalSize;
    
    return CGRectMake(-cropRect.origin.x * scale, -cropRect.origin.y * scale, size.width, size.height);
}

- (void)transitEntities:(UIView *)parentView {
    UIView *containerView = [[UIView alloc] init];
    [parentView addSubview:containerView];
    
    containerView.frame = CGRectMake(0.0, 0.0, _fullEntitiesView.frame.size.width, _fullEntitiesView.frame.size.height);
    [containerView addSubview:_fullEntitiesView];
    
    CGFloat paintingScale = _fullEntitiesView.frame.size.width / _photoEditor.originalSize.width;
    _fullEntitiesView.frame = CGRectMake(-_photoEditor.cropRect.origin.x * paintingScale, -_photoEditor.cropRect.origin.y * paintingScale, _fullEntitiesView.frame.size.width, _fullEntitiesView.frame.size.height);
        
    CGFloat cropScale = 1.0;
    if (_photoEditor.originalSize.width > _photoEditor.originalSize.height) {
        cropScale = _photoEditor.originalSize.height / _photoEditor.cropRect.size.height;
    } else {
        cropScale = _photoEditor.originalSize.width / _photoEditor.cropRect.size.width;
    }
    
    UIImageOrientation imageOrientation = _photoEditor.cropOrientation;
    if ([parentView isKindOfClass:[TGPhotoEditorPreviewView class]])
        imageOrientation = UIImageOrientationUp;
    
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(imageOrientation));
    if ([parentView isKindOfClass:[TGPhotoEditorPreviewView class]] && _photoEditor.cropMirrored) {
        rotationTransform = CGAffineTransformMakeScale(-1.0, 1.0);
    }
    CGFloat scale = parentView.frame.size.width / _fullEntitiesView.frame.size.width;
    containerView.transform = CGAffineTransformScale(rotationTransform, scale * cropScale, scale * cropScale);
    containerView.frame = CGRectMake(0.0, 0.0, parentView.frame.size.width, parentView.frame.size.height);
}

- (void)transitionIn
{
    if (_portraitToolsWrapperView.frame.size.height < FLT_EPSILON) {
        _scheduledTransitionIn = true;
        return;
    }
    
    _scrubberView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    _scrubberView.layer.shouldRasterize = true;
    
    [_cropView animateTransitionIn];
    
    _cancelButton.alpha = 0.0f;
    _titleLabel.alpha = 0.0f;
    _subtitleLabel.alpha = 0.0f;
    _doneButton.alpha = 0.0f;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _cancelButton.alpha = 1.0f;
        _titleLabel.alpha = 1.0f;
        _subtitleLabel.alpha = 1.0f;
        _doneButton.alpha = 1.0f;
        
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
        _dotImageView.alpha = 1.0f;
        _dotMarkerView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        _scrubberView.layer.shouldRasterize = false;
    }];
        
    if (!self.initialAppearance) {
        switch (self.effectiveOrientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                    _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
                break;
                
            case UIInterfaceOrientationLandscapeRight:
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                    _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
                break;
                
            default:
            {
                CGFloat offset = _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f;
                CGAffineTransform initialDotImageViewTransform = _dotImageView.transform;
                _dotImageView.transform = CGAffineTransformTranslate(initialDotImageViewTransform, 0.0, offset * 4.444);
                _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, offset);
                
                [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
                {
                    _portraitToolsWrapperView.transform = CGAffineTransformIdentity;
                    _dotImageView.transform = initialDotImageViewTransform;
                } completion:nil];
            }
                break;
        }
    }
}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    if (!saving && self.fromCamera) {
        _dismissingToCamera = true;
        _noTransitionToSnapshot = true;
        
        _fullPreviewView.frame = [_fullPreviewView.superview convertRect:_fullPreviewView.frame toView:self.view];
        [self.view insertSubview:_fullPreviewView belowSubview:_wrapperView];
        [_cropView hideImageForCustomTransition];
    }
    
    [super transitionOutSaving:saving completion:completion];
}

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion
{
    if (switching) {
        _dismissing = true;
    }
    
    if (!self.fromCamera || switching) {
        [self.view insertSubview:_previewView belowSubview:_wrapperView];
        _previewView.frame = [_wrapperView convertRect:_cropView.frame toView:self.view];
    }
    
    [_cropView animateTransitionOut];
    
    if (switching)
    {
        _switching = true;
                        
        UIInterfaceOrientation orientation = self.effectiveOrientation;
        
        CGRect cropRectFrame = [_cropView cropRectFrameForView:self.view];
        CGSize referenceSize = [self referenceViewSizeForOrientation:orientation];
        CGRect referenceBounds = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
        CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:referenceBounds toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
        
        if (self.switchingToTab == TGPhotoEditorPaintTab)
        {
            containerFrame = [TGPhotoDrawingController photoContainerFrameForParentViewFrame:referenceBounds toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
        }
        
        CGSize fittedSize = TGScaleToSize(cropRectFrame.size, containerFrame.size);
        CGRect targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        CGFloat targetCropViewScale = targetFrame.size.width / _cropView.frame.size.width;
        CGRect targetCropViewFrame = [self.view convertRect:targetFrame toView:_wrapperView];
        
        _previewView.alpha = 0.0;
    
        [_cropView closeCurtains];
        
        [self transitEntities:_cropView.clipView];
        
        CGAffineTransform initialTransform = _previewView.transform;
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews animations:^
        {
            CGFloat scale = targetFrame.size.width / _previewView.frame.size.width;
            _previewView.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
            _previewView.transform = CGAffineTransformScale(initialTransform, scale, scale);
            
            _cropView.center = CGPointMake(CGRectGetMidX(targetCropViewFrame), CGRectGetMidY(targetCropViewFrame));
            _cropView.transform = CGAffineTransformMakeScale(targetCropViewScale, targetCropViewScale);
        } completion:^(__unused BOOL finished)
        {
            _fullEntitiesView.frame = CGRectMake(0, 0, _fullEntitiesView.frame.size.width, _fullEntitiesView.frame.size.height);
            _previewView.transform = initialTransform;
            _previewView.frame = targetFrame;
            [_cropView removeFromSuperview];
            _previewView.alpha = 1.0;
            if (self.finishedTransitionOut != nil)
                self.finishedTransitionOut();
            
            if (completion != nil)
                completion();
        }];
    } else {
        if (self.fromCamera)
            _previewView.alpha = 0.0f;
    }
    
    switch (self.effectiveOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        default:
        {
            CGFloat offset = _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f;
            CGAffineTransform initialDotImageViewTransform = _dotImageView.transform;
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, offset);
                _dotImageView.transform = CGAffineTransformTranslate(initialDotImageViewTransform, 0.0, offset * 4.444);
            } completion:^(__unused BOOL finished) {
                _dotImageView.transform = initialDotImageViewTransform;
            }];
        }
            break;
    }
    
    _cancelButton.modernHighlight = false;
    [UIView animateWithDuration:0.2f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        _dotImageView.alpha = 0.0f;
        _dotMarkerView.alpha = 0.0f;
        _cancelButton.alpha = 0.0f;
        _titleLabel.alpha = 0.0f;
        _subtitleLabel.alpha = 0.0f;
        _doneButton.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (!switching) {
            [_cropView removeFromSuperview];
            if (completion != nil)
                completion();
        }
    }];
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
    
    UIView *previewView = self.previewView;
    if (_dismissingToCamera) {
        previewView = _fullPreviewView;
    } else {
        [self.previewView prepareForTransitionOut];
    }
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    
    if (saving && CGRectIsNull(targetFrame))
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = previewView.frame;
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2, (self.view.frame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        if (parentView != nil)
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
    
    if (!self.initialAppearance) {
        [_fullEntitiesView.superview removeFromSuperview];
        _fullEntitiesView.frame = CGRectMake(0, 0, _fullEntitiesView.frame.size.width, _fullEntitiesView.frame.size.height);
        [_cropView attachEntitiesView];
    }
    
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {
    } else {
        [transitionView removeFromSuperview];
    }
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = true;
    [previewView performTransitionInIfNeeded];
    
    if (!self.initialAppearance)
        [_cropView openCurtains];
    [_cropView transitionInFinishedFromCamera:(self.fromCamera && self.initialAppearance)];
        
    PGPhotoEditor *photoEditor = self.photoEditor;
    [photoEditor processAnimated:false completion:nil];
}

- (void)_finishedTransitionIn
{
//    [_cropView animateTransitionIn];
    [_cropView transitionInFinishedFromCamera:true];
    
    if (self.finishedTransitionIn) {
        self.finishedTransitionIn();
        self.finishedTransitionIn = nil;
    }
}

- (void)prepareForCustomTransitionOut
{
    [_cropView hideImageForCustomTransition];
    [_cropView animateTransitionOutSwitching:false];
    
    _cancelButton.modernHighlight = false;
    [_cancelButton.layer removeAllAnimations];
    
    _previewView.hidden = true;
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        _dotImageView.alpha = 0.0f;
        _titleLabel.alpha = 0.0f;
        _subtitleLabel.alpha = 0.0f;
        _cancelButton.alpha = 0.0f;
        _doneButton.alpha = 0.0f;
    } completion:nil];
}

- (void)finishCustomTransitionOut
{
    [_cropView removeFromSuperview];
}

- (CGRect)transitionOutReferenceFrame
{
    if (_dismissingToCamera) {
        return [_fullPreviewView.superview convertRect:_fullPreviewView.frame toView:self.view];
    } else {
        return [_wrapperView convertRect:_cropView.frame toView:self.view];
    }
}

- (UIView *)transitionOutReferenceView
{
    if (_dismissingToCamera) {
        return _fullPreviewView;
    } else {
        return _previewView;
    }
}

- (id)currentResultRepresentation
{
    return [_cropView cropSnapshotView];
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
    
    if (_scheduledTransitionIn) {
        _scheduledTransitionIn = false;
        [self transitionIn];
    }
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return sourceFrame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.effectiveOrientation;
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0.0f hasOnScreenNavigation:self.hasOnScreenNavigation];
    
    CGRect targetFrame = CGRectZero;
    
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    if (self.initialAppearance && (self.fromCamera || !self.skipTransitionIn))
    {
        CGSize referenceSize = fromFrame.size;
        if ([_transitionView isKindOfClass:[UIImageView class]])
            referenceSize = ((UIImageView *)_transitionView).image.size;
        
        CGSize fittedSize = TGScaleToFill(referenceSize, CGSizeMake(diameter, diameter));
        
        targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                 containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                 fittedSize.width, fittedSize.height);
    }
    else
    {
        targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - diameter) / 2,
                                 containerFrame.origin.y + (containerFrame.size.height - diameter) / 2,
                                 diameter, diameter);
    }
    
    return targetFrame;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGRect frame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    return frame;
}

- (void)updateToolViews
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIInterfaceOrientation orientation = self.interfaceOrientation;
#pragma clang diagnostic pop
    if ([self inFormSheet] || TGIsPad())
    {
        _landscapeToolsWrapperView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    CGFloat panelSize = UIInterfaceOrientationIsPortrait(orientation) ? TGPhotoAvatarPreviewPanelSize : TGPhotoAvatarPreviewLandscapePanelSize;
    
    CGFloat panelToolbarPortraitSize = panelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = panelSize + TGPhotoEditorToolbarSize;
        
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:self.hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
            
    CGSize buttonSize = CGSizeMake(MIN(referenceSize.width, referenceSize.height) - 16.0 * 2.0, 50.0f);
    [_doneButton updateWidth:buttonSize.width];
    
    CGSize subtitleSize = [_subtitleLabel sizeThatFits:CGSizeMake(referenceSize.width - 96.0, referenceSize.height)];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);

            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);

            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _titleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - _titleLabel.frame.size.width) / 2.0), 0.0, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            _subtitleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - _subtitleLabel.frame.size.width) / 2.0), screenEdges.bottom + safeAreaInset.bottom, subtitleSize.width, subtitleSize.height);
            
            _cancelButton.frame = CGRectMake(-_cancelButton.frame.size.width, screenEdges.top + floor((44.0 - _cancelButton.frame.size.height) / 2.0), _cancelButton.frame.size.width, _cancelButton.frame.size.height);
            
            _doneButton.frame = CGRectMake(floor((_wrapperView.frame.size.width - buttonSize.width) / 2.0), screenEdges.bottom + safeAreaInset.bottom, buttonSize.width, buttonSize.height);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.top, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _titleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - _titleLabel.frame.size.width) / 2.0), 0.0, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            _subtitleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - _subtitleLabel.frame.size.width) / 2.0), screenEdges.bottom + safeAreaInset.bottom, subtitleSize.width, subtitleSize.height);
            
            _cancelButton.frame = CGRectMake(-_cancelButton.frame.size.width, screenEdges.top + floor((44.0 - _cancelButton.frame.size.height) / 2.0), _cancelButton.frame.size.width, _cancelButton.frame.size.height);
            
            _doneButton.frame = CGRectMake(floor((_wrapperView.frame.size.width - buttonSize.width) / 2.0), screenEdges.bottom + safeAreaInset.bottom, buttonSize.width, buttonSize.height);
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _portraitToolControlView.frame = CGRectMake(0, 0, referenceSize.width, panelSize);
            }];
             
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - TGPhotoAvatarPreviewPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _coverLabel.frame = CGRectMake(floor((_portraitToolsWrapperView.frame.size.width - _coverLabel.frame.size.width) / 2.0), CGRectGetMaxY(_scrubberView.frame) + 6.0, _coverLabel.frame.size.width, _coverLabel.frame.size.height);
            
            _titleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - _titleLabel.frame.size.width) / 2.0), screenEdges.top + floor((44.0 - _titleLabel.frame.size.height) / 2.0), _titleLabel.frame.size.width, _titleLabel.frame.size.height);
            _subtitleLabel.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - subtitleSize.width) / 2.0), screenEdges.bottom - 56.0 - buttonSize.height - subtitleSize.height - 20.0, subtitleSize.width, subtitleSize.height);
            
            _cancelButton.frame = CGRectMake(screenEdges.left + 16.0, screenEdges.top + floor((44.0 - _cancelButton.frame.size.height) / 2.0), _cancelButton.frame.size.width, _cancelButton.frame.size.height);
            
            _doneButton.frame = CGRectMake(screenEdges.left + floor((referenceSize.width - buttonSize.width) / 2.0), screenEdges.bottom - 56.0 - buttonSize.height, buttonSize.width, buttonSize.height);
        }
            break;
    }
}

- (void)updatePreviewView
{
    CGSize referenceSize = [self referenceViewSize];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view)
        return;
        
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    orientation = [self effectiveOrientation:orientation];
    
    CGSize referenceSize = [self referenceViewSize];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        [_cropView updateCircleImageWithReferenceSize:referenceSize square:_isForum];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - self.view.frame.size.height) / 2, (screenSide - self.view.frame.size.width) / 2, (screenSide + self.view.frame.size.height) / 2, (screenSide + self.view.frame.size.width) / 2);
        
    if (_dismissing)
        return;
    
    [self updatePreviewView];
    [self updateToolViews];
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0.0f hasOnScreenNavigation:self.hasOnScreenNavigation];
    containerFrame = CGRectOffset(containerFrame, screenEdges.left, screenEdges.top);
    
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    _cropView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - diameter) / 2, containerFrame.origin.y + (containerFrame.size.height - diameter) / 2, diameter, diameter);
}

- (TGPhotoEditorTab)availableTabs
{
    TGPhotoEditorTab tabs = TGPhotoEditorRotateTab | TGPhotoEditorMirrorTab | TGPhotoEditorToolsTab;
    if (self.intent != TGPhotoEditorControllerSignupAvatarIntent) {
        tabs |= TGPhotoEditorPaintTab;
    }
    return tabs;
}

- (TGPhotoEditorTab)activeTab
{
    return TGPhotoEditorNoneTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    id<TGMediaEditAdjustments> adjustments = [self.photoEditor exportAdjustments];
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    
    if (adjustments.toolsApplied)
        tabs |= TGPhotoEditorToolsTab;
    if (adjustments.hasPainting)
        tabs |= TGPhotoEditorPaintTab;
    
    return tabs;
}

- (void)handleTabAction:(TGPhotoEditorTab)tab
{
    switch (tab)
    {
        case TGPhotoEditorRotateTab:
        {
            [self rotate];
        }
            break;
            
        case TGPhotoEditorMirrorTab:
        {
            [self mirror];
        }
            break;
                
        default:
            break;
    }
}

#pragma mark - Cropping

- (void)rotate {
    [_cropView rotate90DegreesCCWAnimated:true];
}

- (void)mirror {
    [_cropView mirror];
}

- (void)beginScrubbing:(bool)flash
{
    if (flash) {
        _coverLabel.alpha = 1.0f;
    }
}

- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion
{
    if (flash) {
        [_cropView flash:^{
            TGDispatchAfter(1.0, dispatch_get_main_queue(), ^{
                if (completion()) {
                    [UIView animateWithDuration:0.2 animations:^{
                        _coverLabel.alpha = 0.7f;
                    }];
                    
                    self.controlVideoPlayback(true);
                }
            });
        }];
    } else {
        TGDispatchAfter(1.32, dispatch_get_main_queue(), ^{
            if (completion()) {
                [UIView animateWithDuration:0.2 animations:^{
                    _coverLabel.alpha = 0.7f;
                }];
                
                self.controlVideoPlayback(true);
            }
        });
    }
}

@end
