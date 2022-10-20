#import <LegacyComponents/TGPhotoEditorButton.h>

#import <LegacyComponents/LegacyComponentsContext.h>

typedef NS_OPTIONS(NSUInteger, TGPhotoEditorTab) {
    TGPhotoEditorNoneTab        = 0,
    TGPhotoEditorCropTab        = 1 << 0,
    TGPhotoEditorRotateTab      = 1 << 1,
    TGPhotoEditorMirrorTab      = 1 << 2,
    TGPhotoEditorPaintTab       = 1 << 3,
    TGPhotoEditorEraserTab      = 1 << 4,
    TGPhotoEditorStickerTab     = 1 << 5,
    TGPhotoEditorTextTab        = 1 << 6,
    TGPhotoEditorToolsTab       = 1 << 7,
    TGPhotoEditorQualityTab     = 1 << 8,
    TGPhotoEditorTimerTab       = 1 << 9,
    TGPhotoEditorAspectRatioTab = 1 << 10,
    TGPhotoEditorTintTab        = 1 << 11,
    TGPhotoEditorBlurTab        = 1 << 12,
    TGPhotoEditorCurvesTab      = 1 << 13
};

typedef enum
{
    TGPhotoEditorBackButtonBack,
    TGPhotoEditorBackButtonCancel
} TGPhotoEditorBackButton;

typedef enum
{
    TGPhotoEditorDoneButtonSend,
    TGPhotoEditorDoneButtonCheck,
    TGPhotoEditorDoneButtonDone
} TGPhotoEditorDoneButton;

@interface TGPhotoToolbarView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, readonly) UIButton *doneButton;

@property (nonatomic, copy) void(^cancelPressed)(void);
@property (nonatomic, copy) void(^donePressed)(void);

@property (nonatomic, copy) void(^doneLongPressed)(id sender);

@property (nonatomic, copy) void(^tabPressed)(TGPhotoEditorTab tab);

@property (nonatomic, readonly) CGRect cancelButtonFrame;
@property (nonatomic, readonly) CGRect doneButtonFrame;

@property (nonatomic, assign) TGPhotoEditorBackButton backButtonType;
@property (nonatomic, assign) TGPhotoEditorDoneButton doneButtonType;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context backButton:(TGPhotoEditorBackButton)backButton doneButton:(TGPhotoEditorDoneButton)doneButton solidBackground:(bool)solidBackground;

- (void)transitionInAnimated:(bool)animated;
- (void)transitionInAnimated:(bool)animated transparent:(bool)transparent;
- (void)transitionOutAnimated:(bool)animated;
- (void)transitionOutAnimated:(bool)animated transparent:(bool)transparent hideOnCompletion:(bool)hideOnCompletion;

- (void)setDoneButtonEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsHidden:(bool)hidden animated:(bool)animated;
- (void)setEditButtonsHighlighted:(TGPhotoEditorTab)buttons;
- (void)setEditButtonsDisabled:(TGPhotoEditorTab)buttons;

- (void)setAllButtonsHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, readonly) TGPhotoEditorTab currentTabs;
- (void)setToolbarTabs:(TGPhotoEditorTab)tabs animated:(bool)animated;

- (void)setActiveTab:(TGPhotoEditorTab)tab;

- (void)setInfoString:(NSString *)string;

- (TGPhotoEditorButton *)buttonForTab:(TGPhotoEditorTab)tab;

@end
