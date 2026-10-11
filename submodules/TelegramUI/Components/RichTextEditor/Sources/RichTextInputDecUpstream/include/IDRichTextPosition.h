#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDRichTextAnchor.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextPosition : UITextPosition <NSCopying>
@property(nonatomic, strong, readonly) IDRichTextAnchor *anchor;
@property(nonatomic, readonly) UITextStorageDirection affinity;
@property(nonatomic, readonly) NSUInteger documentRevision;

- (instancetype)initWithAnchor:(IDRichTextAnchor *)anchor
                       affinity:(UITextStorageDirection)affinity;
@end

NS_ASSUME_NONNULL_END

#endif
