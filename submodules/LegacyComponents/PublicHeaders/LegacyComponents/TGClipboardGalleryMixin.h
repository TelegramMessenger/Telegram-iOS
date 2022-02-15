#import <Foundation/Foundation.h>
#import <LegacyComponents/TGModernGalleryController.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGClipboardGalleryPhotoItem;

@protocol TGPhotoPaintStickersContext;

@interface TGClipboardGalleryMixin : NSObject

@property (nonatomic, copy) void (^itemFocused)(TGClipboardGalleryPhotoItem *);

@property (nonatomic, copy) void (^willTransitionIn)();
@property (nonatomic, copy) void (^willTransitionOut)();
@property (nonatomic, copy) void (^didTransitionOut)();
@property (nonatomic, copy) UIView *(^referenceViewForItem)(TGClipboardGalleryPhotoItem *);

@property (nonatomic, copy) void (^completeWithItem)(TGClipboardGalleryPhotoItem *item, bool silentPosting, int32_t scheduleTime);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, copy) void (^presentScheduleController)(void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image images:(NSArray *)images parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder recipientName:(NSString *)recipientName;

- (void)present;

@end
