#import <UIKit/UIKit.h>

@interface TGWarpedView : UIImageView

- (void)transformToFitQuadTopLeft:(CGPoint)tl topRight:(CGPoint)tr bottomLeft:(CGPoint)bl bottomRight:(CGPoint)br;

@end
