#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface TGLocationCurrentLocationCell : UITableViewCell

@property (nonatomic, weak) UIImageView *edgeView;

- (void)configureForCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;
- (void)configureForCustomLocationWithAddress:(NSString *)address;
- (void)configureForLiveLocationWithAccuracy:(CLLocationAccuracy)accuracy;
- (void)configureForStopLiveLocation;

@end

extern NSString *const TGLocationCurrentLocationCellKind;
extern const CGFloat TGLocationCurrentLocationCellHeight;
