#import <UIKit/UIKit.h>

@interface TGPaintPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, copy) bool (^shouldRecognizeTap)(void);
@property (nonatomic) NSSet *touches;

@end
