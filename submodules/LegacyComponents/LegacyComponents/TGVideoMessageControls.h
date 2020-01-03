#import <UIKit/UIKit.h>
#import <LegacyComponents/TGVideoMessageScrubber.h>

@class TGVideoMessageCaptureControllerAssets;
@class TGModernConversationInputMicPallete;

@interface TGVideoMessageControls : UIView

@property (nonatomic, readonly) TGVideoMessageScrubber *scrubberView;

@property (nonatomic, assign) CGFloat controlsHeight;
@property (nonatomic, copy) void (^positionChanged)(void);
@property (nonatomic, copy) void (^cancel)(void);
@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) bool (^sendPressed)(void);
@property (nonatomic, copy) bool (^sendLongPressed)(void);

@property (nonatomic, copy) bool(^isAlreadyLocked)(void);

@property (nonatomic, assign) bool positionChangeAvailable;

@property (nonatomic, strong) TGModernConversationInputMicPallete *pallete;

@property (nonatomic, weak) id<TGVideoMessageScrubberDelegate, TGVideoMessageScrubberDataSource> parent;

- (instancetype)initWithFrame:(CGRect)frame assets:(TGVideoMessageCaptureControllerAssets *)assets slowmodeTimestamp:(int32_t)slowmodeTimestamp slowmodeView:(UIView *(^)(void))slowmodeView;

- (void)captureStarted;
- (void)recordingStarted;
- (void)setShowRecordingInterface:(bool)show velocity:(CGFloat)velocity;
- (void)buttonInteractionUpdate:(CGPoint)value;
- (void)setLocked;
- (void)setStopped;

- (void)showScrubberView;

- (void)setDurationString:(NSString *)string;

- (CGRect)frameForSendButton;

@end
