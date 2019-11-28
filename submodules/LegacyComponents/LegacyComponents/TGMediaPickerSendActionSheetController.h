#import <LegacyComponents/TGOverlayController.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGMediaPickerSendActionSheetController : TGOverlayController

@property (nonatomic, copy) void (^send)(void);
@property (nonatomic, copy) void (^sendSilently)(void);
@property (nonatomic, copy) void (^schedule)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context sendButtonFrame:(CGRect)sendButtonFrame canSendSilently:(bool)canSendSilently canSchedule:(bool)canSchedule reminder:(bool)reminder;

@end

NS_ASSUME_NONNULL_END
