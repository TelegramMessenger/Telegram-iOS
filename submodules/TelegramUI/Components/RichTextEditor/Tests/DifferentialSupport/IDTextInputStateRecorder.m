// NOT VENDORED. Written for Telegram, Task 9c — the replacement for InputDec's own
// `IDTextInputStateRecorder.m`, whose NINE references to `IDBlockTextView` (and force-casts at
// `:219`, `:310`, `:345`) are exactly why it could not be carried over. See `PROVENANCE.md`.
//
// It presents the SAME vendored `@interface`s — `IDTextInputSnapshot`, `IDTextInputStateRecorder`,
// and the two exported normalisation functions — because `IDTextInputTransactionDriver.h` and
// `IDTextInputDifferentialRunner.h` (both vendored) import `IDTextInputStateRecorder.h` directly.
//
// ## What is reproduced verbatim, and why that is not copying
//
// The two exported functions (`IDNormalizedInlineTraitNames`, `IDNormalizedInlineRuns`) and the
// `UITextInputDelegate` recorder are byte-for-byte the origin's. They are coupling-free and they
// DEFINE the normalisation both arms are measured in — a re-derived "equivalent" of them would make
// the two arms speak different dialects while looking identical.
//
// ## The three things this file decides
//
// **1. THE AXIS IS MAPPED, NOT EXCUSED.** The editor's `UITextInput` position axis is SPARSE: a
// top-level paragraph boundary occupies one more slot than the text projection's single "\n" (Task
// 9b: span 51 against a 50-character projection; the second paragraph's first character at offset 20
// / index 19). `selection` is compared by ALL 68 scenarios and 58 of the 68 touch a boundary
// (measured), so excusing the divergence as a named expectation would certify almost nothing while
// reporting green. A systematic offset is a MAP.
//
// The map is one line of public `UITextInput`:
//
//     characterIndex(p) = [[input textInRange:(beginningOfDocument … p)] length]
//
// i.e. *how much text lies before this position* — which is the definition of a character index, and
// which is exactly what `canonical` (the field every scenario compares) is made of. Three properties
// make it the right one rather than merely a working one:
//
//   * It is EXACT for stock by construction: for a `UITextView`, the length of the prefix IS
//     `-offsetFromPosition:toPosition:`. Pinned against ground truth at every position in
//     `test_theMapReproducesOffsetFromPositionOnStock_atEveryPosition`.
//   * It needs NO Telegram type. `DocumentCanvasView+ComposerSelection.swift` already maps this
//     axis onto the chat's flat space and was the ruling's suggested source, but reusing it would
//     have required reaching a Telegram concrete type from here (forbidden) and would have imported
//     the composer's own expansions (custom-emoji alt text, collapsed-quote placeholders) that
//     `text(in:)` does not perform — a second, subtly different axis. Deriving the index from the
//     projection the recorder ALREADY compares keeps `canonical`, `selection`, `markedRange` and
//     `inlineRuns` on one axis by construction.
//   * Both arms run the SAME code. An arm-specific mapper is a place for the two to disagree.
//
// **2. A DECLINED FIELD IS PUBLISHED DATA.** See `IDTelegramRecorderPolicy.h`: absent-from-both
// compares EQUAL in the vendored comparator, so "absent, never defaulted" prevents a false value but
// not a false agreement. Declines are computed from CAPABILITY at every capture and published under
// `IDTelegramSnapshotDeclinesKey`; Task 9d subtracts `IDTelegramDeclinedComparisonFields()` from the
// list it hands the runner.
//
// **3. NO DOWNCAST TO A TELEGRAM CONCRETE TYPE.** Every sample is taken through the public
// `UITextInput` surface, a `-respondsToSelector:` guard, or one of the Swift-supplied provider blocks
// on `IDTelegramHostProvider.h`. The only `isKindOfClass:` checks are against `UITextView` (the stock
// arm, as the original) and `IDTelegramProjectedTextStorage` (our own type, and the capability test
// for `storageMutationTrace`).
#import "IDTextInputStateRecorder.h"

#include <math.h>
#import <objc/message.h>

#import "IDTelegramCharacterAxis.h"
#import "IDTelegramHostProvider.h"
#import "IDTelegramRecorderPolicy.h"

#pragma mark - Normalisation (reproduced VERBATIM from the origin; coupling-free)

NSArray<NSString *> *IDNormalizedInlineTraitNames(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    if ((fontTraits & UIFontDescriptorTraitBold) != 0) {
        [result addObject:@"bold"];
    }
    if ((fontTraits & UIFontDescriptorTraitItalic) != 0) {
        [result addObject:@"italic"];
    }
    if ([attributes[NSUnderlineStyleAttributeName] integerValue] != 0) {
        [result addObject:@"underline"];
    }
    if ([attributes[NSStrikethroughStyleAttributeName] integerValue] != 0) {
        [result addObject:@"strikethrough"];
    }
    return result.copy;
}

NSArray<NSDictionary<NSString *, id> *> *
IDNormalizedInlineRuns(NSTextStorage *storage) {
    if (storage.length == 0) return @[];
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    NSString *string = storage.string;
    NSUInteger runStart = 0;
    NSArray<NSString *> *runTraits = nil;
    for (NSUInteger index = 0; index < storage.length; index += 1) {
        NSArray<NSString *> *traits =
            [string characterAtIndex:index] == '\n'
                ? @[]
                : IDNormalizedInlineTraitNames(
                    [storage attributesAtIndex:index effectiveRange:NULL]);
        if (runTraits == nil) {
            runTraits = traits;
            runStart = index;
            continue;
        }
        if ([runTraits isEqualToArray:traits]) continue;
        [result addObject:@{
            @"range": @{
                @"location": @(runStart),
                @"length": @(index - runStart),
            },
            @"traits": runTraits,
        }];
        runStart = index;
        runTraits = traits;
    }
    [result addObject:@{
        @"range": @{
            @"location": @(runStart),
            @"length": @(storage.length - runStart),
        },
        @"traits": runTraits ?: @[],
    }];
    return result.copy;
}

#pragma mark - The declined-field policy (ours; see IDTelegramRecorderPolicy.h)

NSString *const IDTelegramSnapshotDeclinesKey = @"telegramDeclinedFields";

NSDictionary<NSString *, NSString *> *IDTelegramDeclinedComparisonFieldReasons(void) {
    static NSDictionary<NSString *, NSString *> *reasons;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reasons = @{
            @"storageMutationTrace":
                @"Telegram has no single NSTextStorage (limitation 1). `observedTextStorage` is a "
                @"READ-ONLY PULL PROJECTION whose -refresh swaps its backing outright instead of "
                @"mutating an NSMutableAttributedString, so it can never post "
                @"NSTextStorageDidProcessEditingNotification and the recorder's observer can never "
                @"fire. A trace assembled from our own refresh calls would describe WHEN THE "
                @"RECORDER SAMPLED, not when the editor edited, and would then be compared against "
                @"stock's genuine edit trace as though the two meant the same thing.",
            @"traits":
                @"The contract's `traits` census is all TEN UITextInputTraits members. Every one is "
                @"@optional, UIView implements none, and DocumentCanvasView implements SIX "
                @"(measured 2026-08-24: autocapitalizationType, keyboardType, returnKeyType and "
                @"secureTextEntry are absent). The ten-key dictionary therefore cannot be formed at "
                @"all, and a six-key one is a different measurement wearing the same name. What CAN "
                @"be read is published under `telegramReadableTraits`, and the construction-time "
                @"apply-and-read-back census under `telegramUnappliedTraits`, so the decline costs "
                @"no measurement — only the false comparison.",
        };
    });
    return reasons;
}

NSArray<NSString *> *IDTelegramDeclinedComparisonFields(void) {
    static NSArray<NSString *> *fields;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fields = [IDTelegramDeclinedComparisonFieldReasons().allKeys
            sortedArrayUsingSelector:@selector(compare:)];
    });
    return fields;
}

NSArray<NSString *> *IDTelegramComparableFields(
    NSArray<NSString *> *scenarioComparisonFields) {
    NSSet<NSString *> *declined =
        [NSSet setWithArray:IDTelegramDeclinedComparisonFields()];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (NSString *field in scenarioComparisonFields) {
        if (![declined containsObject:field]) [result addObject:field];
    }
    return result.copy;
}

#pragma mark - Snapshot and delegate recorder (interfaces vendored; bodies reproduced)

@interface IDTextInputSnapshot ()
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *state;
@end

@implementation IDTextInputSnapshot
@end

@interface IDTextInputDelegateRecorder :
    NSObject <UITextInputDelegate>
@property(nonatomic, weak) id<UITextInputDelegate> forwardingDelegate;
@property(nonatomic, strong)
    NSMutableArray<NSString *> *events;
@end

@implementation IDTextInputDelegateRecorder

- (instancetype)init {
    self = [super init];
    if (self != nil) _events = [NSMutableArray array];
    return self;
}

- (void)selectionWillChange:(id<UITextInput>)textInput {
    [self.events addObject:@"selectionWillChange"];
    [self.forwardingDelegate selectionWillChange:textInput];
}

- (void)selectionDidChange:(id<UITextInput>)textInput {
    [self.events addObject:@"selectionDidChange"];
    [self.forwardingDelegate selectionDidChange:textInput];
}

- (void)textWillChange:(id<UITextInput>)textInput {
    [self.events addObject:@"textWillChange"];
    [self.forwardingDelegate textWillChange:textInput];
}

- (void)textDidChange:(id<UITextInput>)textInput {
    [self.events addObject:@"textDidChange"];
    [self.forwardingDelegate textDidChange:textInput];
}

- (void)conversationContext:(UIConversationContext *)context
                  didChange:(id<UITextInput>)textInput {
    [self.events addObject:@"conversationContextDidChange"];
    [self.forwardingDelegate conversationContext:context didChange:textInput];
}

@end

#pragma mark - The recorder

@interface IDTextInputStateRecorder ()

@property(nonatomic, strong) IDTextInputTestHost *host;
@property(nonatomic, strong) IDTextInputDelegateRecorder *delegateRecorder;
@property(nonatomic, strong, nullable) id<UITextInputDelegate> priorDelegate;
@property(nonatomic, strong, nullable) id storageObserver;
@property(nonatomic, strong)
    NSMutableArray<NSDictionary<NSString *, id> *> *storageMutations;
/// The declines of the capture in progress, keyed by field. Rebuilt per capture: a decline is a
/// property of a moment, not of the recorder.
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSString *> *declines;
@property(nonatomic) BOOL detached;

@end

@implementation IDTextInputStateRecorder

/// The ten members of the `traits` census, getter selector name -> published key, in the vendored
/// order. `secureTextEntry`'s getter is `isSecureTextEntry`, as in the original.
+ (NSArray<NSArray<NSString *> *> *)id_traitGetters {
    static NSArray<NSArray<NSString *> *> *getters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        getters = @[
            @[@"autocapitalizationType", @"autocapitalizationType"],
            @[@"autocorrectionType", @"autocorrectionType"],
            @[@"spellCheckingType", @"spellCheckingType"],
            @[@"smartQuotesType", @"smartQuotesType"],
            @[@"smartDashesType", @"smartDashesType"],
            @[@"smartInsertDeleteType", @"smartInsertDeleteType"],
            @[@"inlinePredictionType", @"inlinePredictionType"],
            @[@"keyboardType", @"keyboardType"],
            @[@"returnKeyType", @"returnKeyType"],
            @[@"secureTextEntry", @"isSecureTextEntry"],
        ];
    });
    return getters;
}

static NSDictionary<NSString *, NSNumber *> *IDRecorderRange(NSRange range) {
    return @{@"location": @(range.location), @"length": @(range.length)};
}

static NSDictionary<NSString *, NSNumber *> *IDRecorderRect(CGRect rect) {
    return @{
        @"x": @(rect.origin.x),
        @"y": @(rect.origin.y),
        @"width": @(rect.size.width),
        @"height": @(rect.size.height),
    };
}

static BOOL IDRecorderRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

- (instancetype)initWithHost:(IDTextInputTestHost *)host {
    NSParameterAssert(host != nil);
    self = [super init];
    if (self == nil) return nil;
    _host = host;
    _storageMutations = [NSMutableArray array];
    _declines = [NSMutableDictionary dictionary];
    _priorDelegate = host.input.inputDelegate;
    _delegateRecorder = [IDTextInputDelegateRecorder new];
    _delegateRecorder.forwardingDelegate = _priorDelegate;
    host.input.inputDelegate = _delegateRecorder;
    // The observer is installed unconditionally, exactly as the original does. For a stock host it
    // fires on every real edit; for a Telegram host the projection cannot post the notification at
    // all, which is what makes `storageMutationTrace` a STRUCTURAL decline rather than a policy one.
    __weak typeof(self) weakSelf = self;
    _storageObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:host.observedTextStorage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
        typeof(self) strongSelf = weakSelf;
        NSTextStorage *storage = notification.object;
        if (strongSelf == nil || storage == nil) return;
        [strongSelf.storageMutations addObject:@{
            @"editedMask": @(storage.editedMask),
            @"range": IDRecorderRange(storage.editedRange),
            @"delta": @(storage.changeInLength),
        }];
    }];
    return self;
}

#pragma mark - Declines

- (void)declineField:(NSString *)field because:(NSString *)reason {
    self.declines[field] = reason;
}

#pragma mark - THE AXIS MAP

/// A `UITextRange` as an `NSRange` on the STOCK character axis — `IDTelegramCharacterAxis.h`.
///
/// The map lives there rather than here because Task 9d's transaction driver needs its INVERSE to
/// realise the corpus's character-coordinate ranges, and two independently written halves of one
/// conversion is how an oracle acquires a systematic aiming error that looks like an editor bug.
///
/// A `nil` RANGE (no selection, no marked text) yields `{NSNotFound, 0}` — the vendored value, and a
/// real answer that both arms produce identically, so it is not a decline. A range the map cannot
/// convert yields `nil`, and the caller declines the field.
- (nullable NSValue *)characterRangeForTextRange:(nullable UITextRange *)range {
    return IDTelegramCharacterRangeForTextRange(self.host.input, range);
}

#pragma mark - Fields

- (NSString *)canonicalText {
    UIView<UITextInput> *input = self.host.input;
    UITextRange *range =
        [input textRangeFromPosition:input.beginningOfDocument
                          toPosition:input.endOfDocument];
    return [input textInRange:range] ?: @"";
}

/// `blocks`: the editor's own top-level block list when it offers one, the canonical "\n" split
/// otherwise. Same division of labour as the vendored original (real block list for the custom view,
/// canonical split for stock) — reached through a provider block instead of a downcast.
- (nullable NSArray<NSString *> *)blocksForCanonical:(NSString *)canonical {
    IDTelegramBlockTextsProvider provider = self.host.id_blockTextsProvider;
    if (provider == nil) {
        return [canonical componentsSeparatedByString:@"\n"];
    }
    NSArray<NSString *> *blocks = provider();
    if (blocks == nil) {
        [self declineField:@"blocks"
                   because:@"the editor declined to enumerate its own top-level blocks"];
    }
    return blocks;
}

/// Reads one `UITextInputTraits` member, or `nil` when the input does not implement its getter.
/// Every member of that protocol is `@optional` and `UIView` implements none, so an unguarded read
/// is an `unrecognized selector` raise — which is what the vendored original would do here, both of
/// ITS inputs having been `UITextView`-shaped.
- (nullable NSNumber *)readTraitWithGetterName:(NSString *)getterName
                                        isBool:(BOOL)isBool {
    SEL getter = NSSelectorFromString(getterName);
    UIView<UITextInput> *input = self.host.input;
    if (![input respondsToSelector:getter]) return nil;
    if (isBool) {
        BOOL (*read)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        return @(read(input, getter));
    }
    NSInteger (*read)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
    return @(read(input, getter));
}

/// The census the contract compares: all ten or nothing. `missing` receives the members the input
/// does not implement, and `readable` the ones it does — both published, so the decline loses no
/// measurement.
- (nullable NSDictionary<NSString *, NSNumber *> *)
    traitsWithReadable:(NSMutableDictionary<NSString *, NSNumber *> *)readable
               missing:(NSMutableArray<NSString *> *)missing {
    for (NSArray<NSString *> *pair in [self.class id_traitGetters]) {
        NSString *key = pair[0];
        NSNumber *value =
            [self readTraitWithGetterName:pair[1]
                                   isBool:[key isEqualToString:@"secureTextEntry"]];
        if (value == nil) {
            [missing addObject:key];
        } else {
            readable[key] = value;
        }
    }
    return missing.count == 0 ? readable.copy : nil;
}

- (NSArray<NSDictionary<NSString *, id> *> *)selectionRectangles {
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    for (UITextSelectionRect *selectionRect in
         [self.host.input
             selectionRectsForRange:self.host.input.selectedTextRange]) {
        if (!IDRecorderRectIsFinite(selectionRect.rect)) continue;
        [result addObject:@{
            @"rect": IDRecorderRect(selectionRect.rect),
            @"writingDirection": @(selectionRect.writingDirection),
            @"containsStart": @(selectionRect.containsStart),
            @"containsEnd": @(selectionRect.containsEnd),
            @"vertical": @(selectionRect.isVertical),
        }];
    }
    [result sortUsingComparator:
        ^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSDictionary *leftRect = left[@"rect"];
        NSDictionary *rightRect = right[@"rect"];
        for (NSString *key in @[@"y", @"x", @"height", @"width"]) {
            NSComparisonResult order =
                [leftRect[key] compare:rightRect[key]];
            if (order != NSOrderedSame) return order;
        }
        return NSOrderedSame;
    }];
    return result.copy;
}

/// `typingInlineTraits` — the traits the next typed character would carry.
///
/// Over a RANGED selection it is the intersection across the selected characters, read from
/// `observedTextStorage` **at the MAPPED range**. The vendored original indexed that storage with
/// raw `-offsetFromPosition:` values; on a sparse axis those are the wrong characters from the second
/// paragraph onward, and the comparison would have reported the mistake as agreement.
///
/// At a COLLAPSED selection the original's three branches are: `UITextView.typingAttributes`
/// (kept — it is the stock arm's own answer), a downcast to the InputDec view (forbidden here), and
/// `-textStylingAtPosition:inDirection:` (an `@optional` member `DocumentCanvasView` does not
/// implement — measured, pinned). The editor answers for itself through the provider block instead.
- (nullable NSArray<NSString *> *)typingInlineTraits {
    UIView<UITextInput> *input = self.host.input;
    NSValue *selected = [self characterRangeForTextRange:input.selectedTextRange];
    if (selected == nil) {
        [self declineField:@"typingInlineTraits"
                   because:@"the selection could not be mapped onto the character axis"];
        return nil;
    }
    NSRange selectedRange = selected.rangeValue;
    if (selectedRange.location != NSNotFound && selectedRange.length > 0) {
        NSTextStorage *storage = self.host.observedTextStorage;
        if (!self.host.id_observedTextStorageIsAligned) {
            [self declineField:@"typingInlineTraits"
                       because:[NSString stringWithFormat:
                           @"the attributed projection is not aligned with the canonical text (%@)",
                           self.host.id_observedTextStorageMisalignmentReason ?: @"no reason given"]];
            return nil;
        }
        if (NSMaxRange(selectedRange) > storage.length) {
            [self declineField:@"typingInlineTraits"
                       because:@"the mapped selection lies outside the projected storage"];
            return nil;
        }
        NSMutableSet<NSString *> *intersection = nil;
        NSString *string = storage.string;
        for (NSUInteger index = selectedRange.location;
             index < NSMaxRange(selectedRange); index++) {
            if ([string characterAtIndex:index] == '\n') continue;
            NSSet<NSString *> *traits = [NSSet setWithArray:
                IDNormalizedInlineTraitNames(
                    [storage attributesAtIndex:index effectiveRange:NULL])];
            if (intersection == nil) {
                intersection = traits.mutableCopy;
            } else {
                [intersection intersectSet:traits];
            }
        }
        NSMutableArray<NSString *> *ordered = [NSMutableArray array];
        for (NSString *name in @[
                 @"bold", @"italic", @"underline", @"strikethrough",
             ]) {
            if ([intersection containsObject:name]) [ordered addObject:name];
        }
        return ordered.copy;
    }

    UITextPosition *position =
        input.selectedTextRange.start ?: input.beginningOfDocument;
    IDTelegramTypingAttributesProvider provider = self.host.id_typingAttributesProvider;
    if (provider != nil) {
        UITextRange *collapsed =
            input.selectedTextRange
                ?: [input textRangeFromPosition:position toPosition:position];
        NSDictionary<NSAttributedStringKey, id> *attributes =
            collapsed != nil ? provider(collapsed) : nil;
        if (attributes == nil) {
            [self declineField:@"typingInlineTraits"
                       because:@"the editor declined to report its typing attributes at the caret"];
            return nil;
        }
        return IDNormalizedInlineTraitNames(attributes);
    }
    if ([input isKindOfClass:UITextView.class]) {
        return IDNormalizedInlineTraitNames(
            ((UITextView *)input).typingAttributes ?: @{});
    }
    if ([input respondsToSelector:@selector(textStylingAtPosition:inDirection:)]) {
        return IDNormalizedInlineTraitNames(
            [input textStylingAtPosition:position
                             inDirection:UITextStorageDirectionForward] ?: @{});
    }
    [self declineField:@"typingInlineTraits"
               because:@"the input offers no typing-attribute source at a collapsed selection"];
    return nil;
}

static NSString *IDNormalizedAnnotationName(id key) {
    NSString *name = [key isKindOfClass:NSString.class]
        ? key : [key description];
    if ([name localizedCaseInsensitiveContainsString:@"spelling"])
        return @"spelling";
    if ([name localizedCaseInsensitiveContainsString:@"alternative"])
        return @"alternatives";
    if ([name localizedCaseInsensitiveContainsString:@"marked"])
        return @"marked-text";
    return name ?: @"unknown";
}

/// `annotationRanges` — the non-semantic attribute names carried by the document's text.
///
/// The original read the stock arm's real storage and the custom arm's private annotated substring;
/// both arms are served here from `observedTextStorage`, which for a Telegram host is the attributed
/// projection of the editor's own live region strings. **No corpus scenario asks for this field**
/// (measured over all 68), so `comparesAnnotations` is NO throughout and this returns `@[]` — the
/// path is written for the contract, not exercised by it.
- (nullable NSArray<NSDictionary<NSString *, id> *> *)annotationRanges {
    if (!self.host.comparesAnnotations) return @[];
    if (!self.host.id_observedTextStorageIsAligned) {
        [self declineField:@"annotationRanges"
                   because:[NSString stringWithFormat:
                       @"the attributed projection is not aligned with the canonical text (%@)",
                       self.host.id_observedTextStorageMisalignmentReason ?: @"no reason given"]];
        return nil;
    }
    NSUInteger length = self.host.observedTextStorage.length;
    if (length == 0) return @[];
    NSAttributedString *annotated = [self.host.observedTextStorage
        attributedSubstringFromRange:NSMakeRange(0, length)];
    if (annotated.length == 0) return @[];

    NSSet<NSAttributedStringKey> *semanticKeys =
        [NSSet setWithArray:@[
            NSFontAttributeName, NSForegroundColorAttributeName,
            NSBackgroundColorAttributeName, NSUnderlineStyleAttributeName,
            NSStrikethroughStyleAttributeName, NSParagraphStyleAttributeName,
            NSKernAttributeName, NSLigatureAttributeName,
            NSBaselineOffsetAttributeName, NSLinkAttributeName,
            NSAttachmentAttributeName,
        ]];
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    [annotated enumerateAttributesInRange:NSMakeRange(0, annotated.length)
                                  options:0
                               usingBlock:
        ^(NSDictionary<NSAttributedStringKey, id> *attributes,
          NSRange range, BOOL *stop) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (id key in attributes) {
            if (![semanticKeys containsObject:key]) {
                [names addObject:IDNormalizedAnnotationName(key)];
            }
        }
        [names sortUsingSelector:@selector(compare:)];
        if (names.count == 0) return;
        [result addObject:@{
            @"range": IDRecorderRange(range),
            @"names": names.copy,
        }];
    }];
    return result.copy;
}

/// A DIAGNOSTIC field — the vendored comparator skips `behaviorCapabilities` and `behaviorDetached`
/// outright (its `diagnosticFields` set), so nothing here can affect a comparison.
///
/// The original distinguished its two non-stock kinds because they were two different
/// implementations. **Telegram has ONE**, so both non-stock arms report the SAME identifier: reading
/// a reference-vs-minimal agreement as "two backends agree" would be exactly the false comfort this
/// phase exists to prevent (Task 9b's finding). The pair is a determinism / execution-order check
/// until a second Telegram input backend takes the `Minimal` slot.
- (NSArray<NSDictionary<NSString *, id> *> *)behaviorCapabilities {
    if (self.host.kind == IDTextInputHostKindStock) {
        return @[@{@"identifier": @"stock-uikit", @"state": @"system"}];
    }
    return @[@{@"identifier": @"telegram-richtexteditor", @"state": @"system"}];
}

#pragma mark - Capture

- (IDTextInputSnapshot *)capturePhase:(NSString *)phase {
    NSParameterAssert(phase.length > 0);
    UIView<UITextInput> *input = self.host.input;
    // The projection is a PULL: re-pull before sampling anything derived from it.
    [self.host id_refreshObservedTextStorage];
    self.declines = [NSMutableDictionary dictionary];

    NSMutableDictionary<NSString *, id> *state = [NSMutableDictionary dictionary];

    NSString *canonical = [self canonicalText];
    state[@"canonical"] = canonical;

    NSArray<NSString *> *blocks = [self blocksForCanonical:canonical];
    if (blocks != nil) state[@"blocks"] = blocks;

    NSValue *selection = [self characterRangeForTextRange:input.selectedTextRange];
    if (selection != nil) {
        state[@"selection"] = IDRecorderRange(selection.rangeValue);
    } else {
        [self declineField:@"selection"
                   because:@"the selection could not be mapped onto the character axis"];
    }

    UITextRange *markedTextRange = input.markedTextRange;
    NSValue *marked = [self characterRangeForTextRange:markedTextRange];
    if (marked != nil) {
        state[@"markedRange"] = IDRecorderRange(marked.rangeValue);
    } else {
        [self declineField:@"markedRange"
                   because:@"the marked range could not be mapped onto the character axis"];
    }
    state[@"markedText"] = markedTextRange != nil
        ? ([input textInRange:markedTextRange] ?: @"") : @"";

    // `selectionAffinity` is `@optional`; both arms implement it (measured), but a guard here is the
    // difference between a decline and an `unrecognized selector` raise on every single capture.
    SEL affinitySelector = @selector(selectionAffinity);
    if ([input respondsToSelector:affinitySelector]) {
        UITextStorageDirection (*read)(id, SEL) =
            (UITextStorageDirection (*)(id, SEL))objc_msgSend;
        UITextStorageDirection affinity = read(input, affinitySelector);
        state[@"affinity"] =
            affinity == UITextStorageDirectionBackward ? @"backward" : @"forward";
    } else {
        [self declineField:@"affinity"
                   because:@"the input does not implement selectionAffinity (it is @optional)"];
    }

    state[@"firstResponder"] = @(input.isFirstResponder);

    NSUndoManager *undoManager = input.undoManager;
    state[@"canUndo"] = @(undoManager.canUndo);
    state[@"canRedo"] = @(undoManager.canRedo);

    NSMutableDictionary<NSString *, NSNumber *> *readableTraits =
        [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *missingTraits = [NSMutableArray array];
    NSDictionary<NSString *, NSNumber *> *traits =
        [self traitsWithReadable:readableTraits missing:missingTraits];
    if (traits != nil) {
        state[@"traits"] = traits;
    } else {
        [self declineField:@"traits"
                   because:[NSString stringWithFormat:
                       @"%@ — this input does not implement: %@",
                       IDTelegramDeclinedComparisonFieldReasons()[@"traits"],
                       [missingTraits componentsJoinedByString:@", "]]];
    }
    state[@"telegramReadableTraits"] = readableTraits.copy;
    state[@"telegramUnappliedTraits"] = self.host.id_unappliedTraits ?: @{};

    UITextPosition *caretPosition =
        input.selectedTextRange.end ?: input.beginningOfDocument;
    state[@"caretRect"] =
        IDRecorderRect([input caretRectForPosition:caretPosition]);
    state[@"selectionRects"] = [self selectionRectangles];

    state[@"inputDelegateTrace"] = self.delegateRecorder.events.copy;

    // `storageMutationTrace` is served only by a host whose observed storage is a LIVE one. A
    // projection cannot post the notification the trace is built from, so an empty array here would
    // be a plausible-looking value that was never measured — the exact failure the "absent, never
    // defaulted" rule exists to prevent. Capability, not host kind: the check is what the storage IS.
    if ([self.host.observedTextStorage isKindOfClass:IDTelegramProjectedTextStorage.class]) {
        [self declineField:@"storageMutationTrace"
                   because:IDTelegramDeclinedComparisonFieldReasons()[@"storageMutationTrace"]];
    } else {
        state[@"storageMutationTrace"] = self.storageMutations.copy;
    }

    NSArray<NSString *> *typingInlineTraits = [self typingInlineTraits];
    if (typingInlineTraits != nil) state[@"typingInlineTraits"] = typingInlineTraits;

    if (self.host.id_observedTextStorageIsAligned) {
        state[@"inlineRuns"] = IDNormalizedInlineRuns(self.host.observedTextStorage);
    } else {
        [self declineField:@"inlineRuns"
                   because:[NSString stringWithFormat:
                       @"the attributed projection is not aligned with the canonical text (%@)",
                       self.host.id_observedTextStorageMisalignmentReason ?: @"no reason given"]];
    }

    NSArray<NSDictionary<NSString *, id> *> *annotations = [self annotationRanges];
    if (annotations != nil) state[@"annotationRanges"] = annotations;

    state[@"behaviorCapabilities"] = [self behaviorCapabilities];
    // No Telegram input backend has a detached-behaviour concept; the original's YES branch read the
    // InputDec view's behaviour report. Diagnostic, and skipped by the comparator either way.
    state[@"behaviorDetached"] = @NO;

    state[IDTelegramSnapshotDeclinesKey] = self.declines.copy;

    IDTextInputSnapshot *snapshot = [IDTextInputSnapshot new];
    snapshot.phase = phase;
    snapshot.state = state.copy;
    return snapshot;
}

- (void)resetTransactionTraces {
    [self.delegateRecorder.events removeAllObjects];
    [self.storageMutations removeAllObjects];
}

- (void)detach {
    if (self.detached) return;
    self.detached = YES;
    if (self.storageObserver != nil) {
        [NSNotificationCenter.defaultCenter
            removeObserver:self.storageObserver];
        self.storageObserver = nil;
    }
    if (self.host.input.inputDelegate == self.delegateRecorder) {
        self.host.input.inputDelegate = self.priorDelegate;
    }
    self.delegateRecorder.forwardingDelegate = nil;
}

- (void)dealloc {
    [self detach];
}

@end
