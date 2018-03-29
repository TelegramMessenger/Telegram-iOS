#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;

@interface TGPassportAttachMenu : NSObject

+ (TGMenuSheetController *)presentWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController menuController:(TGMenuSheetController *)menuController title:(NSString *)title uploadAction:(void (^)(SSignal *))uploadAction sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect barButtonItem:(UIBarButtonItem *)barButtonItem;

@end
