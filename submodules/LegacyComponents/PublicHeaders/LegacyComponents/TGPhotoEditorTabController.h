#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorController.h>

@protocol TGMediaEditAdjustments;

@interface TGPhotoEditorTabController : TGViewController
{
    bool _dismissing;
    UIView *_transitionView;
    bool _noTransitionToSnapshot;
    
    bool _animateScale;
}

@property (nonatomic, weak) id<TGMediaEditableItem> item;
@property (nonatomic, assign) TGPhotoEditorControllerIntent intent;
@property (nonatomic, assign) CGFloat toolbarLandscapeSize;
@property (nonatomic, assign) bool initialAppearance;
@property (nonatomic, assign) bool transitionInProgress;
@property (nonatomic, assign) bool transitionInPending;
@property (nonatomic, assign) CGFloat transitionSpeed;
@property (nonatomic, readonly) bool dismissing;

@property (nonatomic, copy) UIView *(^beginTransitionIn)(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView);
@property (nonatomic, copy) void(^finishedTransitionIn)(void);
@property (nonatomic, copy) UIView *(^beginTransitionOut)(CGRect *referenceFrame, UIView **parentView);
@property (nonatomic, copy) void(^finishedTransitionOut)(void);

@property (nonatomic, copy) void (^valuesChanged)(void);

@property (nonatomic, copy) void (^tabsChanged)(void);

@property (nonatomic, copy) bool (^isVideoPlaying)();
@property (nonatomic, copy) void (^controlVideoPlayback)(bool);
@property (nonatomic, copy) void (^controlVideoSeek)(NSTimeInterval);
@property (nonatomic, copy) void (^controlVideoEndTime)(NSTimeInterval);

@property (nonatomic, assign) TGPhotoEditorTab availableTabs;

@property (nonatomic, assign) TGPhotoEditorTab switchingFromTab;
@property (nonatomic, assign) TGPhotoEditorTab switchingToTab;

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion;
- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion;

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)parentView noTransitionView:(bool)noTransitionView;
- (void)prepareTransitionOutSaving:(bool)saving;

- (void)prepareForCustomTransitionOut;
- (void)finishCustomTransitionOut;

- (void)animateTransitionIn;
- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame;
- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)toFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion;
- (void)_finishedTransitionInWithView:(UIView *)transitionView;

- (CGRect)transitionOutReferenceFrame;
- (UIView *)transitionOutReferenceView;
- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation;

- (CGSize)referenceViewSize;

- (UIView *)snapshotView;

- (id)currentResultRepresentation;

- (void)handleTabAction:(TGPhotoEditorTab)tab;

- (bool)isDismissAllowed;

- (bool)hasOnScreenNavigation;
- (UIInterfaceOrientation)effectiveOrientation;
- (UIInterfaceOrientation)effectiveOrientation:(UIInterfaceOrientation)orientation;

- (void)_updateTabs;
- (TGPhotoEditorTab)activeTab;
- (TGPhotoEditorTab)highlightedTabs;

- (bool)presentedForAvatarCreation;

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation;

+ (TGPhotoEditorTab)highlightedButtonsForEditorValues:(id<TGMediaEditAdjustments>)editorValues forAvatar:(bool)forAvatar;

@end

extern const CGFloat TGPhotoEditorPanelSize;
extern const CGFloat TGPhotoEditorToolbarSize;
