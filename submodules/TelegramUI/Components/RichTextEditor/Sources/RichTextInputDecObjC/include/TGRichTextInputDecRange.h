// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "TGRichTextInputDecPosition.h"

NS_ASSUME_NONNULL_BEGIN

/// The ID backend's own `UITextRange` identity object — mirrors the legacy backend's
/// `LegacyTextRange` (`InputBackend/Legacy/LegacyTextPosition.swift`). `start`/`end` are stored
/// VERBATIM, exactly as given to `rangeFrom:to:` — never reordered to `min`/`max` — matching
/// `LegacyTextRange`'s own deliberately-unordered storage (load-bearing for a reversed drag; see
/// `RichTextCanonicalSelection.normalizedRange`). Callers that need a normalized, non-negative
/// `NSRange` go through `TGRichTextInputDecLayoutController`'s `characterRangeForTextRange:`,
/// which does the ordering.
@interface TGRichTextInputDecRange : UITextRange

+ (instancetype)rangeFrom:(TGRichTextInputDecPosition *)start to:(TGRichTextInputDecPosition *)end;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
