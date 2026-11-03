#import <UIKit/UIKit.h>

@interface TGModernButton : UIButton

@property (nonatomic) bool modernHighlight;

@property (nonatomic, strong) UIImage *highlightImage;
@property (nonatomic) bool stretchHighlightImage;
@property (nonatomic, strong) UIColor *highlightBackgroundColor;
@property (nonatomic) UIEdgeInsets backgroundSelectionInsets;
@property (nonatomic) UIEdgeInsets extendedEdgeInsets;
@property (nonatomic) bool fadeDisabled;

@property (nonatomic, copy) void (^highlitedChanged)(bool highlighted);

- (void)setTitleColor:(UIColor *)color;

- (void)_setHighligtedAnimated:(bool)highlighted animated:(bool)animated;

- (CGFloat)stateAlpha;

@end
