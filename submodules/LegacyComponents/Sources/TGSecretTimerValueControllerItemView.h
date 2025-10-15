#import <UIKit/UIKit.h>

@interface TGSecretTimerValueControllerItemView : UIView

- (instancetype)initWithFrame:(CGRect)frame dark:(bool)dark;

@property (nonatomic, strong) NSString *emptyValue;
@property (nonatomic) NSUInteger seconds;

@end
