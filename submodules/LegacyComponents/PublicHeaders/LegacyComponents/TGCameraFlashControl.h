#import <UIKit/UIKit.h>
#import <LegacyComponents/PGCamera.h>

@interface TGCameraFlashControl : UIControl

@property (nonatomic, assign) PGCameraFlashMode mode;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, copy) void(^modeChanged)(PGCameraFlashMode mode);

- (void)setFlashUnavailable:(bool)unavailable;
- (void)setFlashActive:(bool)active;

- (void)setHidden:(bool)hidden animated:(bool)animated;

@end

extern const CGFloat TGCameraFlashControlHeight;
