#import <UIKit/UIKit.h>

typedef enum {
    TGMessageImageViewOverlayStyleDefault = 0,
    TGMessageImageViewOverlayStyleAccent = 1,
    TGMessageImageViewOverlayStyleList = 2,
    TGMessageImageViewOverlayStyleIncoming = 3,
    TGMessageImageViewOverlayStyleOutgoing = 4
} TGMessageImageViewOverlayStyle;

@class TGPresentation;

@interface TGMessageImageViewOverlayView : UIView

@property (nonatomic, strong) UIColor *incomingColor;
@property (nonatomic, strong) UIColor *outgoingColor;
@property (nonatomic, strong) UIColor *incomingIconColor;
@property (nonatomic, strong) UIColor *outgoingIconColor;

@property (nonatomic, readonly) CGFloat progress;

- (void)setBlurless:(bool)blurless;
- (void)setRadius:(CGFloat)radius;
- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint;
- (void)setOverlayStyle:(TGMessageImageViewOverlayStyle)overlayStyle;
- (void)setBlurredBackgroundImage:(UIImage *)blurredBackgroundImage;
- (void)setDownload;
- (void)setProgress:(CGFloat)progress animated:(bool)animated;
- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated;
- (void)setProgress:(CGFloat)progress cancelEnabled:(bool)cancelEnabled animated:(bool)animated;
- (void)setProgressAnimated:(CGFloat)progress duration:(NSTimeInterval)duration cancelEnabled:(bool)cancelEnabled;
- (void)setPlay;
- (void)setPlayMedia;
- (void)setPauseMedia;
- (void)setSecret:(bool)isViewed;
- (void)setCompletedAnimated:(bool)animated;
- (void)setNone;

@end
