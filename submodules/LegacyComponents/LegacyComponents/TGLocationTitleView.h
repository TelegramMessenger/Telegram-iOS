#import <UIKit/UIKit.h>

@interface TGLocationTitleView : UIView

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *address;

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, assign) CGFloat backButtonWidth;
@property (nonatomic, assign) CGFloat actionsButtonWidth;

@end
