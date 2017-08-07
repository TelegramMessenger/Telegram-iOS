#import <UIKit/UIKit.h>

@class TGLocationVenue;

@interface TGLocationVenueCell : UITableViewCell

- (void)configureWithVenue:(TGLocationVenue *)venue;

@end

extern NSString *const TGLocationVenueCellKind;
extern const CGFloat TGLocationVenueCellHeight;
