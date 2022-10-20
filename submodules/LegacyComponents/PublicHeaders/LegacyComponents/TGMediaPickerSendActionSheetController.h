#import <LegacyComponents/TGOverlayController.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGMediaPickerSendActionSheetController : TGOverlayController

@property (nonatomic, copy) void (^send)(void);
@property (nonatomic, copy) void (^sendSilently)(void);
@property (nonatomic, copy) void (^schedule)(void);
@property (nonatomic, copy) void (^sendWithTimer)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context isDark:(bool)isDark sendButtonFrame:(CGRect)sendButtonFrame canSendSilently:(bool)canSendSilently canSchedule:(bool)canSchedule reminder:(bool)reminder hasTimer:(bool)hasTimer;

@end

NS_ASSUME_NONNULL_END
