#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGViewController;
@class TGMenuSheetController;

@interface TGSecretTimerMenu : NSObject

+ (TGMenuSheetController *)presentInParentController:(TGViewController *)parentController context:(id<LegacyComponentsContext>)context dark:(bool)dark description:(NSString *)description values:(NSArray *)values value:(NSNumber *)value completed:(void (^)(NSNumber *))completed dismissed:(void (^)(void))dismissed sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect;

+ (NSArray *)secretMediaTimerValues;

@end
