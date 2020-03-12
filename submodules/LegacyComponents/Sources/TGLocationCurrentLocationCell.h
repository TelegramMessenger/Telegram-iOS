#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <SSignalKit/SSignalKit.h>

@class TGMessage;
@class TGLocationPallete;

@interface TGLocationCurrentLocationCell : UITableViewCell

@property (nonatomic, strong) TGLocationPallete *pallete;
@property (nonatomic, weak) UIImageView *edgeView;

- (void)configureForCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy;
- (void)configureForCustomLocationWithAddress:(NSString *)address;
- (void)configureForGroupLocationWithAddress:(NSString *)address;
- (void)configureForLiveLocationWithAccuracy:(CLLocationAccuracy)accuracy;
- (void)configureForStopWithMessage:(TGMessage *)message remaining:(SSignal *)remaining;

@end

extern NSString *const TGLocationCurrentLocationCellKind;
extern const CGFloat TGLocationCurrentLocationCellHeight;
