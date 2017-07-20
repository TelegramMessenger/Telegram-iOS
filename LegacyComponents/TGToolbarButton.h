#import <UIKit/UIKit.h>

@protocol TGBarItemSemantics <NSObject>

- (bool)backSemantics;

@optional

- (float)barButtonsOffset;

@end

typedef enum {
    TGToolbarButtonTypeGeneric = 0,
    TGToolbarButtonTypeBack = 1,
    TGToolbarButtonTypeDone = 2,
    TGToolbarButtonTypeDoneBlack = 3,
    TGToolbarButtonTypeImage = 4,
    TGToolbarButtonTypeDelete = 5,
    TGToolbarButtonTypeCustom = 6
} TGToolbarButtonType;

@interface TGToolbarButton : UIButton <TGBarItemSemantics>

@property (nonatomic) TGToolbarButtonType type;

@property (nonatomic) CGSize touchInset;

@property (nonatomic) int minWidth;
@property (nonatomic) float paddingLeft;
@property (nonatomic) float paddingRight;

@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) UIImage *imageLandscape;
@property (nonatomic, retain) UIImage *imageHighlighted;

@property (nonatomic, retain) UILabel *buttonLabelView;
@property (nonatomic, retain) UIImageView *buttonImageView;

@property (nonatomic) bool isLandscape;
@property (nonatomic) int landscapeOffset;

@property (nonatomic) bool backSemantics;

- (id)initWithType:(TGToolbarButtonType)type;
- (id)initWithCustomImages:(UIImage *)imageNormal imageNormalHighlighted:(UIImage *)imageNormalHighlighted imageLandscape:(UIImage *)imageLandscape imageLandscapeHighlighted:(UIImage *)imageLandscapeHighlighted textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor;

@end
