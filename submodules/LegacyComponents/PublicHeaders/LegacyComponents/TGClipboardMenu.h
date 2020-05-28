#import <Foundation/Foundation.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGSuggestionContext;

@protocol TGMediaSelectableItem;
@protocol TGPhotoPaintStickersContext;

@interface TGClipboardMenu : NSObject

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context images:(NSArray *)images hasCaption:(bool)hasCaption hasTimer:(bool)hasTimer recipientName:(NSString *)recipientName suggestionContext:(TGSuggestionContext *)suggestionContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext completed:(void (^)(TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect;

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSString *, NSArray *, NSString *))descriptionGenerator;

@end
