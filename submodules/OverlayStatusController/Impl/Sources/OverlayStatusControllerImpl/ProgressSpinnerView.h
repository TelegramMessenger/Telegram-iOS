#import <UIKit/UIKit.h>

@interface ProgressSpinnerView : UIView

@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light;

- (void)setProgress;
- (void)setSucceed;

@end
