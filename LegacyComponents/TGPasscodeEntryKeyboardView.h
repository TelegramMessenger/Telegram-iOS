#import <UIKit/UIKit.h>

#import "TGPasscodeBackground.h"

@interface TGPasscodeEntryKeyboardView : UIView

@property (nonatomic, copy) void (^characterEntered)(NSString *);

- (void)setBackground:(id<TGPasscodeBackground>)background;

@end
