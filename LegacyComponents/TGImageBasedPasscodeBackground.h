#import "TGPasscodeBackground.h"

@interface TGImageBasedPasscodeBackground : NSObject <TGPasscodeBackground>

- (instancetype)initWithImage:(UIImage *)image size:(CGSize)size;

@end
