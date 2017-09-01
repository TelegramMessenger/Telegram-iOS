#import <UIKit/UIKit.h>
#import <LegacyComponents/TGVideoMessageScrubber.h>

@class TGVideoMessageCaptureControllerAssets;

@interface TGVideoMessageControls : UIView

@property (nonatomic, readonly) TGVideoMessageScrubber *scrubberView;

@property (nonatomic, assign) CGFloat controlsHeight;
@property (nonatomic, copy) void (^positionChanged)(void);
@property (nonatomic, copy) void (^cancel)(void);
@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) void (^sendPressed)(void);

@property (nonatomic, copy) bool(^isAlreadyLocked)(void);

@property (nonatomic, assign) bool positionChangeAvailable;

@property (nonatomic, weak) id<TGVideoMessageScrubberDelegate, TGVideoMessageScrubberDataSource> parent;

- (instancetype)initWithFrame:(CGRect)frame assets:(TGVideoMessageCaptureControllerAssets *)assets;

- (void)captureStarted;
- (void)recordingStarted;
- (void)setShowRecordingInterface:(bool)show velocity:(CGFloat)velocity;
- (void)buttonInteractionUpdate:(CGPoint)value;
- (void)setLocked;
- (void)setStopped;

- (void)showScrubberView;

- (void)setDurationString:(NSString *)string;

@end
