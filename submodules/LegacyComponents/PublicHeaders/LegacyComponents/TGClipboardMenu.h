#import <Foundation/Foundation.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@protocol TGMediaSelectableItem;
@protocol TGPhotoPaintStickersContext;

@interface TGClipboardMenu : NSObject

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context images:(NSArray *)images allowGrouping:(bool)allowGrouping hasCaption:(bool)hasCaption hasTimer:(bool)hasTimer hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext presentScheduleController:(void (^)(void(^)(int32_t)))presentScheduleController presentTimerController:(void (^)(void(^)(int32_t)))presentTimerController completed:(void (^)(TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem, bool silentPosting, int32_t scheduleTime))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect;

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSAttributedString *,
                                                                                                                                                                                                                                 NSString *))descriptionGenerator;

@end
