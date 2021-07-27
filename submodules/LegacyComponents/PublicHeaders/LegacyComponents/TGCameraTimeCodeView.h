#import <UIKit/UIKit.h>

@interface TGCameraTimeCodeView : UIView

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, copy) NSTimeInterval(^requestedRecordingDuration)(void);

- (void)startRecording;
- (void)stopRecording;
- (void)reset;

- (void)setHidden:(bool)hidden animated:(bool)animated;

@end
