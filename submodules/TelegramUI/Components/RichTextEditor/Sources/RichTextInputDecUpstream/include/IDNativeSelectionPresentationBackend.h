#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDSelectionPresentation.h"

@class IDBlockTextView;

NS_ASSUME_NONNULL_BEGIN

/// Gated with `IDBlockTextView`, which it takes as its host — a type reference in a
/// signature is enough to require the gate at a lower deployment floor.
API_AVAILABLE(ios(18.4))
@interface IDNativeSelectionPresentationBackend : NSObject
    <IDSelectionPresentationBackend>
- (instancetype)initWithHostView:(IDBlockTextView *)hostView
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END

#endif
