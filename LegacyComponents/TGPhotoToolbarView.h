#import <LegacyComponents/TGPhotoEditorButton.h>

typedef NS_OPTIONS(NSUInteger, TGPhotoEditorTab) {
    TGPhotoEditorNoneTab        = 0,
    TGPhotoEditorCropTab        = 1 << 0,
    TGPhotoEditorStickerTab     = 1 << 1,
    TGPhotoEditorPaintTab       = 1 << 2,
    TGPhotoEditorEraserTab      = 1 << 3,
    TGPhotoEditorTextTab        = 1 << 4,
    TGPhotoEditorToolsTab       = 1 << 5,
    TGPhotoEditorRotateTab      = 1 << 6,
    TGPhotoEditorQualityTab     = 1 << 7,
    TGPhotoEditorTimerTab       = 1 << 8,
    TGPhotoEditorMirrorTab      = 1 << 9,
    TGPhotoEditorAspectRatioTab = 1 << 10,
    TGPhotoEditorTintTab        = 1 << 11,
    TGPhotoEditorBlurTab        = 1 << 12,
    TGPhotoEditorCurvesTab      = 1 << 13,
};

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
