#import <UIKit/UIKit.h>

@interface ProgressWindowController : UIViewController

@property (nonatomic, copy) void (^cancelled)(void);

- (instancetype)init;
- (instancetype)initWithLight:(bool)light;

- (void)show:(bool)animated;
- (void)dismiss:(bool)animated completion:(void (^)(void))completion;
- (void)dismissWithSuccess:(void (^)(void))completion;

- (void)updateLayout;

@end
