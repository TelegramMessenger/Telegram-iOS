#import <UIKit/UIKit.h>

@interface BITAlertAction : UIAlertAction

+ (UIAlertAction * _Nonnull)actionWithTitle:(nullable NSString *)title style:(UIAlertActionStyle)style handler:(void (^_Nullable)(UIAlertAction *_Nonnull))handler;

- (void)invokeAction;

@end
