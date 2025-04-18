#import <LegacyComponents/TGModernButton.h>

@interface TGModernBarButton : TGModernButton

@property (nonatomic) CGPoint portraitAdjustment;
@property (nonatomic) CGPoint landscapeAdjustment;

@property (nonatomic, strong) UIImage *image;

- (instancetype)initWithImage:(UIImage *)image;

@end
