#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDRichTextPosition.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextRange : UITextRange <NSCopying>
@property(nonatomic, strong, readonly) IDRichTextPosition *start;
@property(nonatomic, strong, readonly) IDRichTextPosition *end;

- (instancetype)initWithStart:(IDRichTextPosition *)start
                           end:(IDRichTextPosition *)end;
@end

NS_ASSUME_NONNULL_END

#endif
