#import "TGNeoViewModel.h"
#import <UIKit/UIKit.h>

@interface TGNeoImageViewModel : TGNeoViewModel

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *tintColor;

- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor;

@end
