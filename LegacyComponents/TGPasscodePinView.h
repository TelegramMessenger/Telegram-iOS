#import <UIKit/UIKit.h>

#import "TGPasscodeBackground.h"

@interface TGPasscodePinView : UIView

- (void)setBackground:(id<TGPasscodeBackground>)background;

- (void)setCharacterCount:(NSUInteger)characterCount maxCharacterCount:(NSUInteger)maxCharacterCount;

@end
