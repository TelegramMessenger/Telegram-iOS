#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDInlineTextFormatting.h"

NS_ASSUME_NONNULL_BEGIN

/// The face the trait pass DERIVES bold and italic from.
///
/// Exported so a host can choose it. `baseFontForAttributes:` reads this key FIRST; without it the
/// base is recovered by stripping bold/italic off `NSFontAttributeName`. Writing a monospace face
/// here is how a host makes an inline-code run monospaced in a way that SURVIVES trait toggles —
/// the resolver then derives bold and italic on top of that face instead of on top of the body font.
///
/// This is the engine's own mechanism, not a back door: the resolver writes this key itself
/// (`attributesByApplyingTraits:`, `attributesByApplyingDefaultFont:`) for exactly the same purpose.
FOUNDATION_EXPORT NSAttributedStringKey const IDInlineTextBaseFontAttributeName;

@interface IDInlineTextStyleResolver : NSObject

- (instancetype)initWithDefaultFont:(UIFont *)font NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSAttributedString *)importAttributedString:
    (NSAttributedString *)attributedString;
- (IDInlineTextTraits)traitsInAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes;
- (NSDictionary<NSAttributedStringKey, id> *)
    attributesByApplyingTraits:(IDInlineTextTraits)traits
                  toAttributes:
                      (NSDictionary<NSAttributedStringKey, id> *)attributes;


- (NSDictionary<NSAttributedStringKey, id> *)
    attributesByApplyingDefaultFont:(UIFont *)font
                          textColor:(UIColor *)textColor
                       toAttributes:
                           (NSDictionary<NSAttributedStringKey, id> *)
                               attributes;

@end

NS_ASSUME_NONNULL_END

#endif
