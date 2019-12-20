#import <Foundation/Foundation.h>

#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>

@class TGViewController;
@class TGMenuSheetController;

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@protocol TGMediaSelectableItem;

@interface TGClipboardMenu : NSObject

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context images:(NSArray *)images hasCaption:(bool)hasCaption hasTimer:(bool)hasTimer recipientName:(NSString *)recipientName defaultVideoPreset:(TGMediaVideoConversionPreset)defaultVideoPreset completed:(void (^)(TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect;

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSString *, NSArray *, NSString *))descriptionGenerator;

@end
