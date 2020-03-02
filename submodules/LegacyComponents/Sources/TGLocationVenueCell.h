#import <UIKit/UIKit.h>

@class TGLocationVenue;
@class TGLocationPallete;

@interface TGLocationVenueCell : UITableViewCell

@property (nonatomic, strong) TGLocationPallete *pallete;

- (void)configureWithVenue:(TGLocationVenue *)venue;

+ (UIImage *)circleImage;

@end

extern NSString *const TGLocationVenueCellKind;
extern const CGFloat TGLocationVenueCellHeight;
