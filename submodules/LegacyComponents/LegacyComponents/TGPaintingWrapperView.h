#import <UIKit/UIKit.h>

@interface TGPaintingWrapperView : UIView

@property (nonatomic, copy) bool (^shouldReceiveTouch)(void);

@end
