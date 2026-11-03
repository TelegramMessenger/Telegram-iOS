#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import Foundation;

@class NSTextLayoutManager;
@class NSTextRange;
@class UIView;
@class IDUIKitRuntimeCapabilityContract;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT id IDPrivateNewInputControllerWithRichLayoutController(
    id layoutController,
    id delegate);
FOUNDATION_EXPORT IDUIKitRuntimeCapabilityContract *
    IDPrivateRichInputControllerContract(void);
FOUNDATION_EXPORT void IDPrivateRequireRichLayoutController(id layoutController,
                                                             NSString *stage);
FOUNDATION_EXPORT NSString *IDPrivateRichLayoutCompatibilityReport(id layoutController);
FOUNDATION_EXPORT void IDPrivateRequireRichTemporaryLayoutManager(
    NSTextLayoutManager *layoutManager,
    NSString *stage);
FOUNDATION_EXPORT void IDPrivateRichAddTemporaryAttribute(
    NSTextLayoutManager *layoutManager,
    id attribute,
    id value,
    NSTextRange *range,
    NSString *stage);
FOUNDATION_EXPORT void IDPrivateRichRemoveTemporaryAttribute(
    NSTextLayoutManager *layoutManager,
    id attribute,
    NSTextRange *range,
    NSString *stage);
FOUNDATION_EXPORT void IDPrivateRequireRichTemporaryCanvas(UIView *canvas,
                                                            NSString *stage);
FOUNDATION_EXPORT void IDPrivateRichInvalidateTemporaryAttributes(
    UIView *canvas,
    NSTextRange *range,
    NSString *stage);
// Fixture-only diagnostic boundary. Production callers must not inspect or send
// the private cursor callback selector directly.
FOUNDATION_EXPORT void IDPrivateInstallRichCursorTraceForUITesting(id layoutController);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
    IDPrivateCopyRichCursorTraceForUITesting(id layoutController);

NS_ASSUME_NONNULL_END

#endif
