#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextRange ()

- (IDRichTextPosition *)id_storedStart;
- (IDRichTextPosition *)id_storedEnd;

@end

NS_ASSUME_NONNULL_END

#endif
