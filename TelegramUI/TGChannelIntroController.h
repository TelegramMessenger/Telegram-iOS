#import <LegacyComponents/LegacyComponents.h>

@interface TGChannelIntroControllerTheme : NSObject

@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, strong, readonly) UIColor *primaryColor;
@property (nonatomic, strong, readonly) UIColor *secondaryColor;
@property (nonatomic, strong, readonly) UIColor *accentColor;
@property (nonatomic, strong, readonly) UIImage *backArrowImage;
@property (nonatomic, strong, readonly) UIImage *introImage;

- (instancetype)initWithBackgroundColor:(UIColor *)backgroundColor primaryColor:(UIColor *)primaryColor secondaryColor:(UIColor *)secondaryColor accentColor:(UIColor *)accentColor backArrowImage:(UIImage *)backArrowImage introImage:(UIImage *)introImage;

@end

@interface TGChannelIntroController : TGViewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context getLocalizedString:(NSString *(^)(NSString *))getLocalizedString theme:(TGChannelIntroControllerTheme *)theme dismiss:(void (^)(void))dismiss completion:(void (^)(void))completion;

@end
