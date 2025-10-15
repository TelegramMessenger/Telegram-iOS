#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;

typedef enum
{
    TGPassportAttachIntentDefault,
    TGPassportAttachIntentIdentityCard,
    TGPassportAttachIntentSelfie,
    TGPassportAttachIntentMultiple
} TGPassportAttachIntent;

@interface TGPassportAttachMenu : NSObject

+ (TGMenuSheetController *)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController menuController:(TGMenuSheetController *)menuController title:(NSString *)title intent:(TGPassportAttachIntent)intent uploadAction:(void (^)(SSignal *, void (^)(void)))uploadAction sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect barButtonItem:(UIBarButtonItem *)barButtonItem;

@end
