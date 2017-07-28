#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol TGPasscodeBackground <NSObject>

- (instancetype)initWithSize:(CGSize)size;

- (CGSize)size;
- (UIImage *)backgroundImage;
- (UIImage *)foregroundImage;

@end
