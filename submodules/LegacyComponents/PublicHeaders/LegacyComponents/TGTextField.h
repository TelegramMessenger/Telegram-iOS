#import <UIKit/UIKit.h>

@interface TGTextField : UITextField

@property (nonatomic) CGFloat editingRectOffset;

@property (nonatomic, strong) UIColor *placeholderColor;
@property (nonatomic, strong) UIFont *placeholderFont;
@property (nonatomic) CGFloat placeholderOffset;

@property (nonatomic) CGFloat leftInset;
@property (nonatomic) CGFloat rightInset;

@property (nonatomic, copy) void (^movedToWindow)();
@property (nonatomic, copy) void (^deleteBackwardEmpty)();

@property (nonatomic, assign) bool clearAllOnNextBackspace;

@end
