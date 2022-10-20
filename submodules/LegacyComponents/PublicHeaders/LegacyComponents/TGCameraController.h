#import <AVFoundation/AVFoundation.h>
#import <LegacyComponents/TGOverlayControllerWindow.h>
#import <LegacyComponents/TGOverlayController.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@class PGCamera;
@class TGCameraPreviewView;
@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGVideoEditAdjustments;

@protocol TGPhotoPaintStickersContext;

typedef enum {
    TGCameraControllerGenericIntent,
    TGCameraControllerPassportIntent,
    TGCameraControllerPassportIdIntent,
    TGCameraControllerPassportMultipleIntent,
    TGCameraControllerAvatarIntent,
    TGCameraControllerSignupAvatarIntent,
    TGCameraControllerGenericPhotoOnlyIntent
} TGCameraControllerIntent;

@interface TGCameraControllerWindow : TGOverlayControllerWindow

@end

@interface TGCameraController : TGOverlayController

@property (nonatomic, assign) bool liveUploadEnabled;
@property (nonatomic, assign) bool shouldStoreCapturedAssets;

@property (nonatomic, assign) bool allowCaptions;
@property (nonatomic, assign) bool allowCaptionEntities;
@property (nonatomic, assign) bool allowGrouping;
@property (nonatomic, assign) bool inhibitDocumentCaptions;
@property (nonatomic, assign) bool inhibitMultipleCapture;
@property (nonatomic, assign) bool inhibitMute;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, assign) bool hasSilentPosting;
@property (nonatomic, assign) bool hasSchedule;
@property (nonatomic, assign) bool reminder;
@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;
@property (nonatomic, assign) bool shortcut;

@property (nonatomic, strong) NSAttributedString *forcedCaption;

@property (nonatomic, strong) NSString *recipientName;

@property (nonatomic, copy) void(^finishedWithResults)(TGOverlayController *controller, TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem, bool silentPosting, int32_t scheduleTime);
@property (nonatomic, copy) void(^finishedWithPhoto)(TGOverlayController *controller, UIImage *resultImage, NSAttributedString *caption, NSArray *stickers, NSNumber *timer);
@property (nonatomic, copy) void(^finishedWithVideo)(TGOverlayController *controller, NSURL *videoURL, UIImage *previewImage, NSTimeInterval duration, CGSize dimensions, TGVideoEditAdjustments *adjustments, NSAttributedString *caption, NSArray *stickers, NSNumber *timer);

@property (nonatomic, copy) void(^recognizedQRCode)(NSString *code);

@property (nonatomic, copy) void(^finishedTransitionIn)(void);

@property (nonatomic, copy) CGRect(^beginTransitionOut)(void);
@property (nonatomic, copy) void(^finishedTransitionOut)(void);
@property (nonatomic, copy) void(^customPresentOverlayController)(TGOverlayController *(^)(id<LegacyComponentsContext>));

@property (nonatomic, copy) void (^presentScheduleController)(bool, void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia intent:(TGCameraControllerIntent)intent;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia camera:(PGCamera *)camera previewView:(TGCameraPreviewView *)previewView intent:(TGCameraControllerIntent)intent;

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem storeAssets:(bool)storeAssets saveEditedPhotos:(bool)saveEditedPhotos descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *))descriptionGenerator;

- (void)beginTransitionInFromRect:(CGRect)rect;
- (void)_dismissTransitionForResultController:(TGOverlayController *)resultController;
- (void)beginTransitionOutWithVelocity:(CGFloat)velocity;

+ (UIInterfaceOrientation)_interfaceOrientationForDeviceOrientation:(UIDeviceOrientation)orientation;

+ (UIImage *)startImage;
+ (void)generateStartImageWithImage:(UIImage *)frameImage;

@end
