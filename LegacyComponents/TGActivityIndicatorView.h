#import <UIKit/UIKit.h>

typedef enum {
    TGActivityIndicatorViewStyleSmall = 0,
    TGActivityIndicatorViewStyleLarge = 1,
    TGActivityIndicatorViewStyleSmallWhite = 2
} TGActivityIndicatorViewStyle;

@interface TGActivityIndicatorView : UIImageView

- (id)init;
- (id)initWithStyle:(TGActivityIndicatorViewStyle)style;

@end
