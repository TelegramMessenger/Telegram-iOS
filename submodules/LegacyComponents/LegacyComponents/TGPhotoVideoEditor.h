#import <LegacyComponents/LegacyComponents.h>

@interface TGPhotoVideoEditor : NSObject

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller caption:(NSString *)caption entities:(NSArray *)entities withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item recipientName:(NSString *)recipientName completion:(void (^)(id<TGMediaEditableItem>, TGMediaEditingContext *))completion dismissed:(void (^)())dismissed;

@end
