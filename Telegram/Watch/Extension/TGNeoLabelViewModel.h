#import "TGNeoViewModel.h"
#import <UIKit/UIKit.h>

@interface TGNeoLabelViewModel : TGNeoViewModel

@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) NSDictionary *attributes;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, assign) bool multiline;

- (instancetype)initWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color attributes:(NSDictionary *)attributes;
- (instancetype)initWithAttributedText:(NSAttributedString *)attributedText;

@end
