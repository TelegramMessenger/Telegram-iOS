#import <UIKit/UIKit.h>
#import <LegacyComponents/PGCamera.h>

@interface TGCameraFlashControl : UIControl

@property (nonatomic, assign) PGCameraFlashMode mode;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, copy) void(^becameActive)(void);
@property (nonatomic, copy) void(^modeChanged)(PGCameraFlashMode mode);

- (void)setFlashUnavailable:(bool)unavailable;

- (void)setHidden:(bool)hidden animated:(bool)animated;

- (void)dismissAnimated:(bool)animated;

@end

extern const CGFloat TGCameraFlashControlHeight;
