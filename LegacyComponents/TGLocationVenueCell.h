#import <UIKit/UIKit.h>

@class TGLocationVenue;

@interface TGLocationVenueCell : UITableViewCell

- (void)configureWithVenue:(TGLocationVenue *)venue;

+ (UIImage *)circleImage;

@end

extern NSString *const TGLocationVenueCellKind;
extern const CGFloat TGLocationVenueCellHeight;
