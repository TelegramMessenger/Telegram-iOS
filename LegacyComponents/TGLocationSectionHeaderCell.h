#import <UIKit/UIKit.h>

@class TGLocationPallete;

@interface TGLocationSectionHeaderCell : UITableViewCell

@property (nonatomic, strong) TGLocationPallete *pallete;

- (void)configureWithTitle:(NSString *)title;

@end

extern NSString *const TGLocationSectionHeaderKind;
extern const CGFloat TGLocationSectionHeaderHeight;
