#import <LegacyComponents/LegacyComponents.h>
#import <LegacyComponents/TGMenuSheetButtonItemView.h>
#import <SSignalKit/SSignalKit.h>

@class TGUser;
@class TGMessage;

@interface TGLocationLiveSessionItemView : TGMenuSheetButtonItemView

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer remaining:(SSignal *)remaining action:(void (^)(void))action;

@end
