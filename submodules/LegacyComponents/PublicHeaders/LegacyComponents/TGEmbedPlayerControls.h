#import <UIKit/UIKit.h>

@class TGModernButton;
@class TGEmbedPlayerState;

typedef enum {
    TGEmbedPlayerControlsTypeNone,
    TGEmbedPlayerControlsTypeSimple,
    TGEmbedPlayerControlsTypeFull
} TGEmbedPlayerControlsType;

typedef enum {
    TGEmbedPlayerWatermarkPositionTopLeft,
    TGEmbedPlayerWatermarkPositionBottomLeft,
    TGEmbedPlayerWatermarkPositionBottomRight
} TGEmbedPlayerWatermarkPosition;

@interface TGEmbedPlayerControls : UIView

@property (nonatomic, copy) void (^panelVisibilityChange)(bool hidden);

@property (nonatomic, copy) void (^playPressed)(void);
@property (nonatomic, copy) void (^pausePressed)(void);
@property (nonatomic, copy) void (^fullscreenPressed)(void);
@property (nonatomic, copy) void (^seekToPosition)(CGFloat position);
@property (nonatomic, copy) void (^pictureInPicturePressed)(void);

@property (nonatomic, assign) TGEmbedPlayerWatermarkPosition watermarkPosition;
@property (nonatomic, strong) UIImage *watermarkImage;
@property (nonatomic, assign) bool watermarkPrerenderedOpacity;
@property (nonatomic, assign) CGPoint watermarkOffset;
@property (nonatomic, copy) void(^watermarkPressed)(void);

- (instancetype)initWithFrame:(CGRect)frame type:(TGEmbedPlayerControlsType)type;

- (void)setWatermarkHidden:(bool)hidden;
- (void)setDisabled;
- (void)hidePlayButton;
- (void)setPictureInPictureHidden:(bool)hidden;

- (void)showLargePlayButton:(bool)force;

- (void)setState:(TGEmbedPlayerState *)state;
- (void)notifyOfPlaybackStart;

- (void)setHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, assign) bool inhibitFullscreenButton;
- (void)setFullscreenButtonHidden:(bool)hidden animated:(bool)animated;

@end
