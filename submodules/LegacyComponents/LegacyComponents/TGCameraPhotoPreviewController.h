#import <LegacyComponents/TGOverlayController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class PGCameraShotMetadata;
@class PGPhotoEditorValues;
@class TGSuggestionContext;

@interface TGCameraPhotoPreviewController : TGOverlayController

@property (nonatomic, assign) bool allowCaptions;

@property (nonatomic, copy) CGRect(^beginTransitionIn)(void);
@property (nonatomic, copy) CGRect(^beginTransitionOut)(CGRect referenceFrame);

@property (nonatomic, copy) void(^finishedTransitionIn)(void);

@property (nonatomic, copy) void (^photoEditorShown)(void);
@property (nonatomic, copy) void (^photoEditorHidden)(void);

@property (nonatomic, copy) void(^retakePressed)(void);
@property (nonatomic, copy) void(^sendPressed)(TGOverlayController *controller, UIImage *resultImage, NSString *caption, NSArray *entities, NSArray *stickers, NSNumber *timer);

@property (nonatomic, strong) TGSuggestionContext *suggestionContext;
@property (nonatomic, assign) bool shouldStoreAssets;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, assign) bool hasSilentPosting;
@property (nonatomic, assign) bool hasSchedule;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image metadata:(PGCameraShotMetadata *)metadata recipientName:(NSString *)recipientName saveCapturedMedia:(bool)saveCapturedMedia saveEditedPhotos:(bool)saveEditedPhotos;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image metadata:(PGCameraShotMetadata *)metadata recipientName:(NSString *)recipientName backButtonTitle:(NSString *)backButtonTitle doneButtonTitle:(NSString *)doneButtonTitle saveCapturedMedia:(bool)saveCapturedMedia saveEditedPhotos:(bool)saveEditedPhotos;


@end
