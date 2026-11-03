#import <UIKit/UIKit.h>

typedef enum
{
    TGCameraShutterButtonNormalMode,
    TGCameraShutterButtonVideoMode,
    TGCameraShutterButtonRecordingMode
} TGCameraShutterButtonMode;

@interface TGCameraShutterButton : UIControl

- (void)setButtonMode:(TGCameraShutterButtonMode)mode animated:(bool)animated;
- (void)setEnabled:(bool)enabled animated:(bool)animated;

- (void)setHighlighted:(bool)highlighted animated:(bool)animated;

@end
