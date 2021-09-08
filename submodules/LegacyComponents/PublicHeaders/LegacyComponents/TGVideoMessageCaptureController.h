#import <LegacyComponents/LegacyComponents.h>

@class TGVideoEditAdjustments;
@class TGModernConversationInputMicPallete;

@interface TGVideoMessageCaptureControllerAssets : NSObject

@property (nonatomic, strong, readonly) UIImage *sendImage;
@property (nonatomic, strong, readonly) UIImage *slideToCancelImage;
@property (nonatomic, strong, readonly) UIImage *actionDelete;

- (instancetype)initWithSendImage:(UIImage *)sendImage slideToCancelImage:(UIImage *)slideToCancelImage actionDelete:(UIImage *)actionDelete;

@end

@interface TGVideoMessageCaptureController : TGOverlayController

@property (nonatomic, strong) TGModernConversationInputMicPallete *pallete;

@property (nonatomic, copy) id (^requestActivityHolder)();
@property (nonatomic, copy) void (^micLevel)(CGFloat level);
@property (nonatomic, copy) void (^onDuration)(NSTimeInterval duration);
@property (nonatomic, copy) void(^finishedWithVideo)(NSURL *videoURL, UIImage *previewImage, NSUInteger fileSize, NSTimeInterval duration, CGSize dimensions, id liveUploadData, TGVideoEditAdjustments *adjustments, bool, int32_t);
@property (nonatomic, copy) void(^onDismiss)(bool isAuto, bool isCancelled);
@property (nonatomic, copy) void(^onStop)(void);
@property (nonatomic, copy) void(^onCancel)(void);
@property (nonatomic, copy) void(^didDismiss)(void);
@property (nonatomic, copy) void(^displaySlowmodeTooltip)(void);
@property (nonatomic, copy) void (^presentScheduleController)(void (^)(int32_t));
    
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assets:(TGVideoMessageCaptureControllerAssets *)assets transitionInView:(UIView *(^)(void))transitionInView parentController:(TGViewController *)parentController controlsFrame:(CGRect)controlsFrame isAlreadyLocked:(bool (^)(void))isAlreadyLocked liveUploadInterface:(id<TGLiveUploadInterface>)liveUploadInterface pallete:(TGModernConversationInputMicPallete *)pallete slowmodeTimestamp:(int32_t)slowmodeTimestamp slowmodeView:(UIView *(^)(void))slowmodeView canSendSilently:(bool)canSendSilently canSchedule:(bool)canSchedule reminder:(bool)reminder;
    
- (void)buttonInteractionUpdate:(CGPoint)value;
- (void)setLocked;

- (CGRect)frameForSendButton;

- (void)complete;
- (void)dismiss:(bool)cancelled;
- (bool)stop;

+ (void)clearStartImage;

+ (void)requestCameraAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock;
+ (void)requestMicrophoneAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock;

- (UIView *)extractVideoContent;
- (void)hideVideoContent;

@end
