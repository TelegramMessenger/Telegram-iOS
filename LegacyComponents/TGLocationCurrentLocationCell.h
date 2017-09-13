#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface TGLocationCurrentLocationCell : UITableViewCell

- (void)configureForCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;
- (void)configureForCustomLocationWithAddress:(NSString *)address;
- (void)configureForLiveLocationWithAccuracy:(CLLocationAccuracy)accuracy;

@end

extern NSString *const TGLocationCurrentLocationCellKind;
extern const CGFloat TGLocationCurrentLocationCellHeight;
