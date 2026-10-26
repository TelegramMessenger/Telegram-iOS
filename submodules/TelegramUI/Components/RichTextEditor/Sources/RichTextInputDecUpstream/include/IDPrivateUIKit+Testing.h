#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDPrivateUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDPrivateUIKit (IDInteractionAssistantConstructionTesting)

+ (nullable id)newInteractionAssistantWithView:(UIView *)view
                                 assistantClass:(Class)assistantClass;

@end

FOUNDATION_EXPORT id IDPrivateNewInputControllerWithRichLayoutControllerUsingClass(
    id layoutController,
    id delegate,
    Class inputControllerClass);
FOUNDATION_EXPORT BOOL IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
    Class _Nullable keyboardClass);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyInteractionHostTopologyForUITesting(
    UIView *outer,
    UIView * _Nullable inner,
    UIView * _Nullable external);
FOUNDATION_EXPORT void
IDPrivateResetInteractionHostTopologyBaselineForUITesting(
    UIView *outer,
    UIView * _Nullable inner,
    UIView * _Nullable external);
NS_ASSUME_NONNULL_END

#endif
