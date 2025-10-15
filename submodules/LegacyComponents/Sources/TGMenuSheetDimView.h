#import <UIKit/UIKit.h>

@class TGMenuSheetView;

@interface TGMenuSheetDimView : UIButton

- (instancetype)initWithActionMenuView:(TGMenuSheetView *)menuView;

- (void)setTheaterMode:(bool)theaterMode animated:(bool)animated;

+ (UIColor *)backgroundColor;
+ (UIColor *)theaterBackgroundColor;

@end
