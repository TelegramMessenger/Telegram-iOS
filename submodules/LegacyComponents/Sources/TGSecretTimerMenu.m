#import "TGSecretTimerMenu.h"

#import "LegacyComponentsInternal.h"

#import "TGMenuSheetController.h"

#import "TGMenuSheetTitleItemView.h"
#import "TGMenuSheetButtonItemView.h"
#import "TGSecretTimerPickerItemView.h"

@implementation TGSecretTimerMenu

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context dark:(bool)dark description:(NSString *)description values:(NSArray *)values value:(NSNumber *)value completed:(void (^)(NSNumber *))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect
{
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:context dark:dark];
    controller.forceFullScreen = true;
    controller.dismissesByOutsideTap = true;
    controller.hasSwipeGesture = true;
    controller.narrowInLandscape = true;
    controller.sourceRect = sourceRect;
    controller.permittedArrowDirections = (UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown);
    controller.willDismiss = ^(__unused bool manual)
    {
        if (dismissed != nil)
            dismissed();
    };
    
    NSMutableArray *itemViews = [[NSMutableArray alloc] init];
    if (description.length > 0)
    {
        TGMenuSheetTitleItemView *titleItem = [[TGMenuSheetTitleItemView alloc] initWithTitle:nil subtitle:description];
        [itemViews addObject:titleItem];
    }
    
    TGSecretTimerPickerItemView *timerItem = [[TGSecretTimerPickerItemView alloc] initWithValues:values value:value];
    [itemViews addObject:timerItem];
    
    __weak TGMenuSheetController *weakController = controller;
    __weak TGSecretTimerPickerItemView *weakTimerItem = timerItem;
    TGMenuSheetButtonItemView *doneItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Done") type:TGMenuSheetButtonTypeSend fontSize:20.0 action:^
    {
        __strong TGSecretTimerPickerItemView *strongTimerItem = weakTimerItem;
        if (strongTimerItem != nil)
        {
            NSNumber *value = strongTimerItem.value;
            completed(value);
        }
        
        __strong TGMenuSheetController *strongController = weakController;
        [strongController dismissAnimated:true];
    }];
    [itemViews addObject:doneItem];
    
    [controller setItemViews:itemViews animated:false];
    [controller presentInViewController:(UIViewController *)parentController sourceView:sourceView animated:true];
    
    return controller;
}

+ (NSArray *)secretMediaTimerValues
{
    NSMutableArray *timerValues = [[NSMutableArray alloc] init];
    for (int i = 0; i < 20; i++)
    {
        [timerValues addObject:@(i)];
    }
    for (int i = 20; i <= 60; i += 5)
    {
        [timerValues addObject:@(i)];
    }
    return timerValues;
}

@end
