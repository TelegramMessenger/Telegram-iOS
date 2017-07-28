#import <LegacyComponents/TGPhotoEditorButton.h>

typedef enum
{
    TGPhotoEditorNoneTab        = 0,
    TGPhotoEditorCropTab        = 1 << 0,
    TGPhotoEditorToolsTab       = 1 << 1,
    TGPhotoEditorRotateTab      = 1 << 3,
    TGPhotoEditorPaintTab       = 1 << 4,
    TGPhotoEditorStickerTab     = 1 << 5,
    TGPhotoEditorTextTab        = 1 << 6,
    TGPhotoEditorQualityTab     = 1 << 7,
    TGPhotoEditorEraserTab      = 1 << 8,
    TGPhotoEditorMirrorTab      = 1 << 9,
    TGPhotoEditorAspectRatioTab = 1 << 10,
    TGPhotoEditorBlurTab        = 1 << 11,
    TGPhotoEditorCurvesTab      = 1 << 12,
    TGPhotoEditorTintTab        = 1 << 13,
    TGPhotoEditorTimerTab       = 1 << 14
} TGPhotoEditorTab;

typedef enum
{
    TGPhotoEditorBackButtonBack,
    TGPhotoEditorBackButtonCancel
} TGPhotoEditorBackButton;

typedef enum
{
    TGPhotoEditorDoneButtonSend,
    TGPhotoEditorDoneButtonCheck
} TGPhotoEditorDoneButton;

@interface TGPhotoToolbarView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, readonly) UIButton *doneButton;

@property (nonatomic, copy) void(^cancelPressed)(void);
@property (nonatomic, copy) void(^donePressed)(void);

@property (nonatomic, copy) void(^doneLongPressed)(id sender);

@property (nonatomic, copy) void(^tabPressed)(TGPhotoEditorTab tab);

@property (nonatomic, readonly) CGRect cancelButtonFrame;

- (instancetype)initWithBackButton:(TGPhotoEditorBackButton)backButton doneButton:(TGPhotoEditorDoneButton)doneButton solidBackground:(bool)solidBackground;

- (void)transitionInAnimated:(bool)animated;
- (void)transitionInAnimated:(bool)animated transparent:(bool)transparent;
- (void)transitionOutAnimated:(bool)animated;
- (void)transitionOutAnimated:(bool)animated transparent:(bool)transparent hideOnCompletion:(bool)hideOnCompletion;

- (void)setDoneButtonEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsEnabled:(bool)enabled animated:(bool)animated;
- (void)setEditButtonsHidden:(bool)hidden animated:(bool)animated;
- (void)setEditButtonsHighlighted:(TGPhotoEditorTab)buttons;
- (void)setEditButtonsDisabled:(TGPhotoEditorTab)buttons;

@property (nonatomic, readonly) TGPhotoEditorTab currentTabs;
- (void)setToolbarTabs:(TGPhotoEditorTab)tabs animated:(bool)animated;

- (void)setActiveTab:(TGPhotoEditorTab)tab;

- (void)setInfoString:(NSString *)string;

- (TGPhotoEditorButton *)buttonForTab:(TGPhotoEditorTab)tab;

@end
