#import "TGClipboardMenu.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGStringUtils.h>
#import <LegacyComponents/TGMenuSheetController.h>

#import "TGClipboardPreviewItemView.h"

@implementation TGClipboardMenu

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context images:(NSArray *)images hasCaption:(bool)hasCaption hasTimer:(bool)hasTimer recipientName:(NSString *)recipientName completed:(void (^)(TGMediaSelectionContext *selectionContext, TGMediaEditingContext *editingContext, id<TGMediaSelectableItem> currentItem))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect
{
    bool centered = false;
    if (sourceRect == nil)
    {
        centered = true;
        sourceRect = ^CGRect
        {
            return CGRectMake(CGRectGetMidX(sourceView.frame), CGRectGetMidY(sourceView.frame), 0, 0);
        };
    }
    
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:context dark:false];
    __weak TGMenuSheetController *weakController = controller;
    controller.dismissesByOutsideTap = true;
    controller.forceFullScreen = true;
    controller.hasSwipeGesture = true;
    controller.narrowInLandscape = true;
    controller.sourceRect = sourceRect;
    controller.permittedArrowDirections = centered ? 0 : (UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown);
    controller.willDismiss = ^(__unused bool manual)
    {
    };
    controller.didDismiss = ^(__unused bool manual) {
        if (dismissed != nil)
            dismissed();
    };
    
    NSMutableArray *itemViews = [[NSMutableArray alloc] init];
    
    TGClipboardPreviewItemView *previewItem = [[TGClipboardPreviewItemView alloc] initWithContext:context images:images];
    __weak TGClipboardPreviewItemView *weakPreviewItem = previewItem;
    
    previewItem.parentController = parentController;
    previewItem.allowCaptions = hasCaption;
    previewItem.hasTimer = hasTimer;
    previewItem.recipientName = recipientName;
    previewItem.sendPressed = ^(UIImage *currentItem)
    {
        __strong TGClipboardPreviewItemView *strongPreviewItem = weakPreviewItem;
        completed(strongPreviewItem.selectionContext, strongPreviewItem.editingContext, currentItem);
        
        __strong TGMenuSheetController *strongController = weakController;
        [strongController dismissAnimated:true];
    };
    [itemViews addObject:previewItem];
    
    NSString *sendTitle = TGLocalized(@"Clipboard.SendPhoto");
    NSUInteger photosCount = images.count;
    if (photosCount > 1)
    {
        NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendPhoto_" value:photosCount]);
        sendTitle = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", photosCount]];
    }
    
    TGMenuSheetButtonItemView *sendItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:sendTitle type:TGMenuSheetButtonTypeSend fontSize:20.0 action:^
    {
        __strong TGClipboardPreviewItemView *strongPreviewItem = weakPreviewItem;
        completed(strongPreviewItem.selectionContext, strongPreviewItem.editingContext, nil);
        
        __strong TGMenuSheetController *strongController = weakController;
        [strongController dismissAnimated:true];
    }];
    [itemViews addObject:sendItem];
    
    __weak TGMenuSheetButtonItemView *weakSendItem = sendItem;
    previewItem.selectionChanged = ^(NSUInteger count)
    {
        __strong TGMenuSheetButtonItemView *strongSendItem = weakSendItem;
        __strong TGClipboardPreviewItemView *strongPreviewItem = weakPreviewItem;        
        if (count > 0)
        {
            NSString *format = TGLocalized([TGStringUtils integerValueFormat:@"AttachmentMenu.SendPhoto_" value:count]);
            NSString *sendTitle = [NSString stringWithFormat:format, [NSString stringWithFormat:@"%ld", count]];
            [strongSendItem setTitle:sendTitle];
        }
        
        strongSendItem.userInteractionEnabled = count > 0;
        [strongPreviewItem setCollapsed:count == 0 animated:true];
    };
    
    TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        [strongController dismissAnimated:true];
    }];
    [itemViews addObject:cancelItem];
    
    [controller setItemViews:itemViews animated:false];
    
    return controller;

}

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSString *, NSArray *, NSString *))descriptionGenerator
{
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    NSMutableArray *selectedItems = [selectionContext.selectedItems mutableCopy];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    for (UIImage *asset in selectedItems)
    {
        NSString *caption = [editingContext captionForItem:asset];
        NSArray *entities = [editingContext entitiesForItem:asset];
        id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
        NSNumber *timer = [editingContext timerForItem:asset];
        
        SSignal *inlineSignal = [[SSignal single:asset] map:^id(UIImage *image)
        {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"type"] = @"editedPhoto";
            dict[@"image"] = image;
            
            if (timer != nil)
                dict[@"timer"] = timer;
            
            id generatedItem = descriptionGenerator(dict, caption, entities, nil);
            return generatedItem;
        }];
        
        SSignal *assetSignal = inlineSignal;
        SSignal *imageSignal = assetSignal;
        if (editingContext != nil)
        {
            imageSignal = [[[[[editingContext imageSignalForItem:asset withUpdates:true] filter:^bool(id result)
            {
                return result == nil || ([result isKindOfClass:[UIImage class]] && !((UIImage *)result).degraded);
            }] take:1] mapToSignal:^SSignal *(id result)
            {
                if (result == nil)
                {
                    return [SSignal fail:nil];
                }
                else if ([result isKindOfClass:[UIImage class]])
                {
                    UIImage *image = (UIImage *)result;
                    image.edited = true;
                    return [SSignal single:image];
                }
                
                return [SSignal complete];
            }] onCompletion:^
            {
                __strong TGMediaEditingContext *strongEditingContext = editingContext;
                [strongEditingContext description];
            }];
        }
        
        [signals addObject:[[imageSignal map:^NSDictionary *(UIImage *image)
        {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"type"] = @"editedPhoto";
            dict[@"image"] = image;
            
            if (adjustments.paintingData.stickers.count > 0)
                dict[@"stickers"] = adjustments.paintingData.stickers;
            
            if (timer != nil)
                dict[@"timer"] = timer;
            
            id generatedItem = descriptionGenerator(dict, caption, entities, nil);
            return generatedItem;
        }] catch:^SSignal *(__unused id error)
        {
            return inlineSignal;
        }]];
    }
    return signals;
}

@end
