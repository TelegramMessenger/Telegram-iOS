#import <LegacyComponents/LegacyComponents.h>

@interface TGPhotoVideoEditor : NSObject

+ (void)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController image:(UIImage *)image video:(NSURL *)video didFinishWithImage:(void (^)(UIImage *image))didFinishWithImage didFinishWithVideo:(void (^)(UIImage *image, NSURL *url, TGVideoEditAdjustments *adjustments))didFinishWithVideo dismissed:(void (^)(void))dismissed;

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSString *)caption entities:(NSArray *)entities withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item recipientName:(NSString *)recipientName stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed;

@end
