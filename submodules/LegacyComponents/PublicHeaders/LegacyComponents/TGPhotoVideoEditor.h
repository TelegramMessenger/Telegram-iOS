#import <UIKit/UIKit.h>

#import <LegacyComponents/TGPhotoPaintStickersContext.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@interface TGPhotoVideoEditor : NSObject

+ (void)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController image:(UIImage *)image video:(NSURL *)video stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext transitionView:(UIView *)transitionView senderName:(NSString *)senderName didFinishWithImage:(void (^)(UIImage *image))didFinishWithImage didFinishWithVideo:(void (^)(UIImage *image, NSURL *url, TGVideoEditAdjustments *adjustments))didFinishWithVideo dismissed:(void (^)(void))dismissed;

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSAttributedString *)caption withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item paint:(bool)paint adjustments:(bool)adjustments recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext fromRect:(CGRect)fromRect mainSnapshot:(UIView *)mainSnapshot snapshots:(NSArray *)snapshots immediate:(bool)immediate appeared:(void (^)(void))appeared completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed;

+ (void)presentEditorWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller withItem:(id<TGMediaEditableItem>)item cropRect:(CGRect)cropRect adjustments:(id<TGMediaEditAdjustments>)adjustments referenceView:(UIView *)referenceView completion:(void (^)(UIImage *, id<TGMediaEditAdjustments>))completion fullSizeCompletion:(void (^)(UIImage *))fullSizeCompletion beginTransitionOut:(void (^)(bool))beginTransitionOut finishTransitionOut:(void (^)())finishTransitionOut;

@end
