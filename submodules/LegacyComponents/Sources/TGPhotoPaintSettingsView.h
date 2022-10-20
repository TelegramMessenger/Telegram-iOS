#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGPaintSwatch;

typedef enum
{
    TGPhotoPaintSettingsViewIconBrushPen,
    TGPhotoPaintSettingsViewIconBrushMarker,
    TGPhotoPaintSettingsViewIconBrushNeon,
    TGPhotoPaintSettingsViewIconBrushArrow,
    TGPhotoPaintSettingsViewIconTextRegular,
    TGPhotoPaintSettingsViewIconTextOutlined,
    TGPhotoPaintSettingsViewIconTextFramed,
    TGPhotoPaintSettingsViewIconMirror
} TGPhotoPaintSettingsViewIcon;

@interface TGPhotoPaintSettingsView : UIView

@property (nonatomic, copy) void (^beganColorPicking)(void);
@property (nonatomic, copy) void (^changedColor)(TGPhotoPaintSettingsView *sender, TGPaintSwatch *swatch);
@property (nonatomic, copy) void (^finishedColorPicking)(TGPhotoPaintSettingsView *sender, TGPaintSwatch *swatch);

@property (nonatomic, copy) void (^eyedropperPressed)(void);
@property (nonatomic, copy) void (^settingsPressed)(void);

@property (nonatomic, readonly) UIButton *settingsButton;

@property (nonatomic, strong) TGPaintSwatch *swatch;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context;

- (void)setIcon:(TGPhotoPaintSettingsViewIcon)icon animated:(bool)animated;
- (void)setHighlighted:(bool)highlighted;

@end

@protocol TGPhotoPaintPanelView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

- (void)present;
- (void)dismissWithCompletion:(void (^)(void))completion;

@end
