#import <LegacyComponents/LegacyComponents.h>

@class TGPresentation;
@class TGPassportMRZ;

@interface TGPassportScanControllerTheme : NSObject

@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, strong, readonly) UIColor *textColor;

- (instancetype)initWithBackgroundColor:(UIColor *)backgroundColor textColor:(UIColor *)textColor;

@end

@interface TGPassportScanController : TGViewController

@property (nonatomic, copy) void (^finishedWithMRZ)(TGPassportMRZ *);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context theme:(TGPassportScanControllerTheme *)theme;

@end
