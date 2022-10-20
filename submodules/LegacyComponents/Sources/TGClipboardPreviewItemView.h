#import <LegacyComponents/LegacyComponents.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@protocol TGPhotoPaintStickersContext;

@interface TGClipboardPreviewItemView : TGMenuSheetItemView

@property (nonatomic, weak) TGViewController *parentController;

@property (nonatomic, assign) bool allowCaptions;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, strong) NSString *recipientName;

@property (nonatomic, assign) bool hasSchedule;
@property (nonatomic, assign) bool hasSilentPosting;
@property (nonatomic, assign) bool reminder;

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, readonly) TGMediaEditingContext *editingContext;
@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;

@property (nonatomic, copy) void (^selectionChanged)(NSUInteger);
@property (nonatomic, copy) void (^sendPressed)(UIImage *currentItem, bool silentPosting, int32_t scheduleTime);

@property (nonatomic, copy) void (^presentScheduleController)(void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context images:(NSArray *)images allowGrouping:(bool)allowGrouping;

- (void)setCollapsed:(bool)collapsed animated:(bool)animated;

@end
