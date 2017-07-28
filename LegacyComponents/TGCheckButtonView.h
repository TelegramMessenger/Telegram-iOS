#import <UIKit/UIKit.h>

typedef enum
{
    TGCheckButtonStyleDefault,
    TGCheckButtonStyleDefaultBlue,
    TGCheckButtonStyleBar,
    TGCheckButtonStyleMedia,
    TGCheckButtonStyleGallery,
    TGCheckButtonStyleShare
} TGCheckButtonStyle;

@interface TGCheckButtonView : UIButton

- (instancetype)initWithStyle:(TGCheckButtonStyle)style;

- (void)setSelected:(bool)selected animated:(bool)animated;
- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump;

@end
