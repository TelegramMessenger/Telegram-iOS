#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGStaticBackdropAreaData : NSObject

@property (nonatomic, strong) UIImage *background;
@property (nonatomic) CGRect mappedRect;
@property (nonatomic) CGFloat luminance;

- (instancetype)initWithBackground:(UIImage *)background;
- (instancetype)initWithBackground:(UIImage *)background mappedRect:(CGRect)mappedRect;

- (void)drawRelativeToImageRect:(CGRect)imageRect;

@end
