#import "BITAlertAction.h"

@interface BITAlertAction ()

@property (nonatomic, copy) void (^storedHandler)(UIAlertAction * _Nonnull);

@end

@implementation BITAlertAction

+ (UIAlertAction *)actionWithTitle:(nullable NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *_Nonnull))handler {
  BITAlertAction *action = [super actionWithTitle:title style:style handler:handler];
  action.storedHandler = handler;
  return action;
}

- (void)invokeAction {
  if (self.storedHandler) {
    self.storedHandler(self);
  }
}

@end
