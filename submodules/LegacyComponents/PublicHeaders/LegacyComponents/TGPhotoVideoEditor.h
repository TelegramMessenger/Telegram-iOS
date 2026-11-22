#import <UIKit/UIKit.h>

#import <LegacyComponents/TGPhotoPaintStickersContext.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@class TGModernGalleryController;

typedef void (^ _Nonnull TGPhotoVideoEditorSchedulePickerCompletion)(int32_t time, bool silentPosting);
typedef void (^ _Nonnull TGPhotoVideoEditorSchedulePicker)(bool media, TGPhotoVideoEditorSchedulePickerCompletion _Nonnull done);
typedef void (^ _Nonnull TGPhotoVideoEditorCompletion)(id<TGMediaEditableItem> _Nonnull item, TGMediaEditingContext * _Nonnull editingContext, bool silentPosting, int32_t scheduleTime);

@interface TGPhotoVideoEditor : NSObject

+ (void)presentWithContext:(id<LegacyComponentsContext> _Nonnull)context parentController:(TGViewController * _Nonnull)parentController image:(UIImage * _Nullable)image video:(NSURL * _Nullable)video stickersContext:(id<TGPhotoPaintStickersContext> _Nullable)stickersContext transitionView:(UIView * _Nullable)transitionView senderName:(NSString * _Nullable)senderName didFinishWithImage:(void (^ _Nullable)(UIImage * _Nonnull image))didFinishWithImage didFinishWithVideo:(void (^ _Nullable)(UIImage * _Nonnull image, NSURL * _Nonnull url, TGVideoEditAdjustments * _Nullable adjustments))didFinishWithVideo dismissed:(void (^ _Nonnull)(void))dismissed;

+ (TGModernGalleryController * _Nonnull)controllerWithContext:(id<LegacyComponentsContext> _Nonnull)context caption:(NSAttributedString * _Nonnull)caption withItem:(id<TGMediaEditableItem, TGMediaSelectableItem> _Nonnull)item paint:(bool)paint adjustments:(bool)adjustments recipientName:(NSString * _Nonnull)recipientName stickersContext:(id<TGPhotoPaintStickersContext> _Nullable)stickersContext fromRect:(CGRect)fromRect mainSnapshot:(UIView * _Nullable)mainSnapshot snapshots:(NSArray * _Nonnull)snapshots immediate:(bool)immediate activateInput:(bool)activateInput isGif:(bool)isGif hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder presentSchedulePicker:(TGPhotoVideoEditorSchedulePicker _Nonnull)presentSchedulePicker appeared:(void (^ _Nonnull)(void))appeared completion:(TGPhotoVideoEditorCompletion _Nonnull)completion dismissed:(void (^ _Nonnull)(void))dismissed;

+ (void)presentWithContext:(id<LegacyComponentsContext> _Nonnull)context controller:(TGViewController * _Nonnull)controller caption:(NSAttributedString * _Nonnull)caption withItem:(id<TGMediaEditableItem, TGMediaSelectableItem> _Nonnull)item paint:(bool)paint adjustments:(bool)adjustments recipientName:(NSString * _Nonnull)recipientName stickersContext:(id<TGPhotoPaintStickersContext> _Nullable)stickersContext fromRect:(CGRect)fromRect mainSnapshot:(UIView * _Nullable)mainSnapshot snapshots:(NSArray * _Nonnull)snapshots immediate:(bool)immediate activateInput:(bool)activateInput isGif:(bool)isGif hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder presentSchedulePicker:(TGPhotoVideoEditorSchedulePicker _Nonnull)presentSchedulePicker appeared:(void (^ _Nonnull)(void))appeared completion:(TGPhotoVideoEditorCompletion _Nonnull)completion dismissed:(void (^ _Nonnull)(void))dismissed;

+ (void)presentEditorWithContext:(id<LegacyComponentsContext> _Nonnull)context controller:(TGViewController * _Nonnull)controller withItem:(id<TGMediaEditableItem> _Nonnull)item cropRect:(CGRect)cropRect adjustments:(id<TGMediaEditAdjustments> _Nullable)adjustments referenceView:(UIView * _Nonnull)referenceView completion:(void (^ _Nonnull)(UIImage * _Nonnull image, id<TGMediaEditAdjustments> _Nullable adjustments))completion fullSizeCompletion:(void (^ _Nonnull)(UIImage * _Nonnull image))fullSizeCompletion beginTransitionOut:(void (^ _Nullable)(bool saving))beginTransitionOut finishTransitionOut:(void (^ _Nullable)(void))finishTransitionOut;

@end
