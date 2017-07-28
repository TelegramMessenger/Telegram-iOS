#import "TGMenuSheetItemView.h"

@interface TGSecretTimerPickerItemView : TGMenuSheetItemView

- (instancetype)initWithValues:(NSArray *)values value:(NSNumber *)value;

@property (nonatomic, readonly) NSNumber *value;

@end
