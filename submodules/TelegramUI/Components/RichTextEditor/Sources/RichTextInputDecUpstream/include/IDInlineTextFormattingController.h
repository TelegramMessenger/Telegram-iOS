#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDInlineTextFormatting.h"

@class IDBlockDocument;
@class IDBlockDocumentChange;
@class IDBlockTextView;
@class IDCanonicalTextStorageAdapter;
@class IDInlineTextStyleResolver;

NS_ASSUME_NONNULL_BEGIN

/// Gated with `IDBlockTextView`, which it takes as its host — a type reference in a
/// signature is enough to require the gate at a lower deployment floor.
API_AVAILABLE(ios(18.4))
@interface IDInlineTextFormattingController : NSObject

- (instancetype)initWithHost:(IDBlockTextView *)host
                    document:(IDBlockDocument *)document
                 textStorage:(IDCanonicalTextStorageAdapter *)textStorage
               styleResolver:(IDInlineTextStyleResolver *)resolver
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)toggleTrait:(IDInlineTextTraits)trait;
- (IDInlineTextTraitState)stateForTrait:(IDInlineTextTraits)trait;
- (IDInlineTextTraits)effectiveInlineTextTraits;

/// Transforms every run's attributes across the current selection, or the typing attributes when the
/// selection is collapsed.
///
/// PER-RUN, because a host's presentation usually derives from what the run already carries — an
/// inline-code run's monospace face has to keep that run's size and its bold/italic, so one uniform
/// dictionary cannot express it. One call is one undo step; doing it as several single-key writes
/// would leave the user undoing a single formatting action several times.
- (void)transformInlineAttributesUsingBlock:
    (NSDictionary<NSAttributedStringKey, id> *(^)(
        NSDictionary<NSAttributedStringKey, id> *attributes))block;

/// Sets a HOST attribute — a key this engine does not own — over the current selection, or on the
/// typing attributes when the selection is collapsed. `nil` removes the key.
- (void)setHostAttributeValue:(nullable id)value
                       forKey:(NSAttributedStringKey)key;

/// The host attribute's value over the current selection; nil when the selection carries none or
/// carries more than one distinct value.
- (nullable id)hostAttributeValueForKey:(NSAttributedStringKey)key;
- (void)documentDidChange:(nullable IDBlockDocumentChange *)change;
- (void)selectionDidChange;

@end

NS_ASSUME_NONNULL_END

#endif
