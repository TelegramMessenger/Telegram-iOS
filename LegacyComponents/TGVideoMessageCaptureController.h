#import <LegacyComponents/LegacyComponents.h>

@class TGVideoEditAdjustments;

@interface TGVideoMessageCaptureControllerAssets : NSObject

@property (nonatomic, strong, readonly) UIImage *sendImage;
@property (nonatomic, strong, readonly) UIImage *slideToCancelImage;
@property (nonatomic, strong, readonly) UIImage *actionDelete;

- (instancetype)initWithSendImage:(UIImage *)sendImage slideToCancelImage:(UIImage *)slideToCancelImage actionDelete:(UIImage *)actionDelete;

@end

@interface TGVideoMessageCaptureController : TGOverlayController

@property (nonatomic, copy) id (^requestActivityHolder)();
@property (nonatomic, copy) void (^micLevel)(CGFloat level);
@property (nonatomic, copy) void(^finishedWithVideo)(NSURL *videoURL, UIImage *previewImage, NSUInteger fileSize, NSTimeInterval duration, CGSize dimensions, id liveUploadData, TGVideoEditAdjustments *adjustments);
@property (nonatomic, copy) void(^onDismiss)(bool isAuto);
@property (nonatomic, copy) void(^onStop)(void);
@property (nonatomic, copy) void(^onCancel)(void);
@property (nonatomic, copy) void(^didDismiss)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assets:(TGVideoMessageCaptureControllerAssets *)assets transitionInView:(UIView *(^)())transitionInView parentController:(TGViewController *)parentController controlsFrame:(CGRect)controlsFrame isAlreadyLocked:(bool (^)(void))isAlreadyLocked liveUploadInterface:(id<TGLiveUploadInterface>)liveUploadInterface;
- (void)buttonInteractionUpdate:(CGPoint)value;
- (void)setLocked;

- (void)complete;
- (void)dismiss;
- (bool)stop;

+ (void)clearStartImage;

+ (void)requestCameraAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock;
+ (void)requestMicrophoneAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock;

@end
