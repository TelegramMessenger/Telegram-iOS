// PORTED VERBATIM (imports aside) from
// /Users/isaac/Documents/InputDec/Tests/IDRichTextLayoutControllerContractProbe.{h,m}
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369.
//
// An `NSProxy` that records every selector forwarded through it and passes the invocation on to the
// real target. Upstream names it after the layout controller it was written to observe, but the
// class is entirely generic (`-initWithTarget:`) and touches no product type — so the name is kept
// for provenance and the probe is used here against any object a suite needs to watch: the private
// `UITextCheckingController`'s client, a delegate, a `UITextInput`.
//
// It matters more here than upstream. Task H1 proved by runtime measurement that
// `-[UITextInputController setDelegate:]` interrogates its delegate ONCE at assignment and caches
// the answers, so a wrong delegate can never be found by reading source. A recording proxy IS the
// instrument for that class of question.

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextLayoutControllerContractProbe : NSProxy
@property(nonatomic, strong, readonly) id target;
@property(nonatomic, copy, readonly) NSArray<NSString *> *recordedSelectors;
- (instancetype)initWithTarget:(id)target;
- (BOOL)recordedSelector:(SEL)selector;
@end

NS_ASSUME_NONNULL_END
