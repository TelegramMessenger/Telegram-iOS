#import <LegacyComponents/LegacyComponents.h>

@interface TGPhotoVideoEditor : NSObject

+ (void)presentWithContext:(id<LegacyComponentsContext>)context controller:(TGViewController *)controller withItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item recipientName:(NSString *)recipientName completion:(void (^)(id, TGMediaEditingContext *))completion;

@end
