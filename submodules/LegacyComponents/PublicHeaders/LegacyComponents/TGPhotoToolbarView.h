#import <LegacyComponents/TGPhotoEditorButton.h>
#import <LegacyComponents/TGPhotoToolbarViewProtocol.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoToolbarView : UIView <TGPhotoToolbarViewProtocol>

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, assign) CGFloat bottomInset;

@property (nonatomic, readonly) UIButton *doneButton;

@property (nonatomic, copy) void(^cancelPressed)(void);
@property (nonatomic, copy) void(^donePressed)(void);

@property (nonatomic, copy) void(^doneLongPressed)(id sender);

@property (nonatomic, copy) void(^tabPressed)(TGPhotoEditorTab tab);

@property (nonatomic, readonly) CGRect cancelButtonFrame;
@property (nonatomic, readonly) CGRect doneButtonFrame;

@property (nonatomic, assign) TGPhotoEditorBackButton backButtonType;
@property (nonatomic, assign) TGPhotoEditorDoneButton doneButtonType;

@property (nonatomic, assign) int64_t sendPaidMessageStars;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context backButton:(TGPhotoEditorBackButton)backButton doneButton:(TGPhotoEditorDoneButton)doneButton solidBackground:(bool)solidBackground stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext;

- (void)transitionInAnimated:(bool)animated;
- (void)transitionInAnimated:(bool)animated transparent:(bool)transparent;
- (void)transitionOutAnimated:(bool)animated;
- (void)transitionOutAnimated:(bool)animated transparent:(bool)transparent hideOnCompletion:(bool)hideOnCompletion;

- (void)setDoneButtonEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsHidden:(bool)hidden animated:(bool)animated;
- (void)setEditButtonsHighlighted:(TGPhotoEditorTab)buttons;
- (void)setEditButtonsDisabled:(TGPhotoEditorTab)buttons;

- (void)setCenterButtonsHidden:(bool)hidden animated:(bool)animated;
- (void)setAllButtonsHidden:(bool)hidden animated:(bool)animated;
- (void)setCancelDoneButtonsHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, readonly) TGPhotoEditorTab currentTabs;
- (void)setToolbarTabs:(TGPhotoEditorTab)tabs animated:(bool)animated;

- (void)setActiveTab:(TGPhotoEditorTab)tab;

- (void)setQualityButtonIsPhoto:(bool)isPhoto highQuality:(bool)highQuality videoPreset:(NSInteger)videoPreset;
- (void)setTimerButtonValue:(NSInteger)value;

- (void)setInfoString:(NSString *)string;

- (UIView *)viewForTab:(TGPhotoEditorTab)tab;
- (TGPhotoEditorButton *)buttonForTab:(TGPhotoEditorTab)tab;

@end
