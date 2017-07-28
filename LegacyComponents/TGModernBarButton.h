#import <LegacyComponents/TGModernButton.h>

@interface TGModernBarButton : TGModernButton

@property (nonatomic) CGPoint portraitAdjustment;
@property (nonatomic) CGPoint landscapeAdjustment;

- (instancetype)initWithImage:(UIImage *)image;

@end
