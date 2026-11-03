#import <UIKit/UIKit.h>

@interface TGKeyCommand : NSObject <NSCopying>

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *input;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;

- (UIKeyCommand *)UIKeyCommand;

+ (TGKeyCommand *)keyCommandWithTitle:(NSString *)title input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags;
+ (TGKeyCommand *)keyCommandWithUIKeyCommand:(UIKeyCommand *)uiKeyCommand;
+ (TGKeyCommand *)keyCommandForSystemActionSelector:(SEL)selector;

@end
