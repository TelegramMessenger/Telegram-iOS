#import <UIKit/UIKit.h>

@class TGLocationPallete;

@interface TGLocationPinView : UIView

@property (nonatomic, strong) TGLocationPallete *pallete;
@property (nonatomic, assign, getter=isPinRaised) bool pinRaised;
- (void)setPinRaised:(bool)raised animated:(bool)animated completion:(void (^)(void))completion;

@end
