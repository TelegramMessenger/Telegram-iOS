#import <UIKit/UIKit.h>

typedef enum {
    TGPasswordEntryViewStyleDefault,
    TGPasswordEntryViewStyleTranslucent
} TGPasswordEntryViewStyle;

@interface TGPasswordEntryView : UIView

@property (nonatomic, copy) void (^cancel)();
@property (nonatomic, copy) void (^simplePasscodeEntered)();
@property (nonatomic, copy) void (^complexPasscodeEntered)();
@property (nonatomic, copy) void (^passcodeChanged)(NSString *);

- (instancetype)initWithFrame:(CGRect)frame style:(TGPasswordEntryViewStyle)style;

- (void)setTitle:(NSString *)title errorTitle:(NSString *)errorTitle isComplex:(bool)isComplex animated:(bool)animated;
- (void)setErrorTitle:(NSString *)errorTitle;
- (NSString *)passcode;
- (void)resetPasscode;
- (void)becomeFirstResponder;
- (void)updateBackgroundIfNeeded;

@end
