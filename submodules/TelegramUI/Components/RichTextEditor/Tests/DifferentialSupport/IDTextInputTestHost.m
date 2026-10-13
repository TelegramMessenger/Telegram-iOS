// NOT VENDORED. Written for Telegram, Task 9b — the replacement for InputDec's own
// `IDTextInputTestHost.m`, whose four references to `IDBlockTextView` / `IDCanonicalTextStorage-
// Adapter` are exactly why it could not be carried over (see `PROVENANCE.md`).
//
// It presents the SAME vendored `@interface` — `+hostWithKind:scenario:error:` and the five
// read-only properties — because `IDTextInputDifferentialRunner.m` (vendored, uncompiled until
// Task 9d) imports `IDTextInputTestHost.h` directly and constructs hosts through it.
//
// **The stock branch is a faithful reproduction of the original's.** It has to be: the whole point
// of this corpus is that stock behaviour is RE-DERIVED live rather than compared against goldens,
// so an arm that sets its `UITextView` up differently from the arm the corpus was captured against
// is not measuring the same thing. The frame, the 17pt system font, the `(11, 9, 13, 9)` container
// inset, the never-adjust content inset behaviour, the suppressed input view, the window/controller
// scaffolding and the inline-formatting family's hidden window are all the original's values.
//
// Two deviations from the original, both forced and both narrow:
//
//   1. **Traits are applied through `-respondsToSelector:`.** `UITextInputTraits` declares all ten
//      as `@optional` and `UIView` implements none of them; the original could send all ten
//      unconditionally because both of ITS inputs were `UITextView`-shaped. MEASURED 2026-08-24:
//      `DocumentCanvasView` implements six of the ten and `-setTextColor:` not at all, so the
//      original's unguarded `applyTraits:` + `setTextColor:` would raise `unrecognized selector`
//      four times over on a Telegram host. The guard applies what the input can take and records
//      the rest in `id_unappliedTraits` rather than pretending it was applied. (That property name
//      was mis-stated here when this file was written; corrected in Task 9c, which reads it.)
//   2. **The window hosts `ownerView`, not `input`.** Telegram's `UITextInput` witness is a
//      SUBVIEW of the public editor façade, so the façade is what goes in the window and what gets
//      laid out. For a stock host the two are the same object and nothing changes.
#import "IDTextInputTestHost.h"

#import <objc/message.h>

#import "IDTelegramCharacterAxis.h"
#import "IDTelegramHostProvider.h"

NSString *const IDTextInputTestHostErrorDomain =
    @"com.inputdec.tests.text-input-host";

#pragma mark - Stock input (reproduced from the vendored original)

@interface IDDifferentialStockTextView : UITextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@end

@implementation IDDifferentialStockTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

@end

NSException *IDTelegramCatchException(NS_NOESCAPE void (^block)(void)) {
    @try {
        block();
    } @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

#pragma mark - The handle the Swift factory returns

@interface IDTelegramInputHandle ()
@property(nonatomic, strong, readwrite) UIView<UITextInput> *input;
@property(nonatomic, strong, readwrite) UIView *ownerView;
@property(nonatomic, copy, readwrite, nullable)
    IDTelegramAttributedTextProjection attributedTextProjection;
@property(nonatomic, copy, readwrite, nullable)
    IDTelegramBlockTextsProvider blockTextsProvider;
@property(nonatomic, copy, readwrite, nullable)
    IDTelegramTypingAttributesProvider typingAttributesProvider;
@property(nonatomic, copy, readwrite, nullable)
    IDTelegramInlineTraitToggle inlineTraitToggle;
@end

@implementation IDTelegramInputHandle

+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(UIView *)ownerView
       attributedTextProjection:(IDTelegramAttributedTextProjection)projection {
    return [self handleWithInput:input
                       ownerView:ownerView
        attributedTextProjection:projection
                      blockTexts:nil
                typingAttributes:nil];
}

+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(UIView *)ownerView
       attributedTextProjection:(IDTelegramAttributedTextProjection)projection
                     blockTexts:(IDTelegramBlockTextsProvider)blockTexts
               typingAttributes:(IDTelegramTypingAttributesProvider)typingAttributes {
    return [self handleWithInput:input
                       ownerView:ownerView
        attributedTextProjection:projection
                      blockTexts:blockTexts
                typingAttributes:typingAttributes
               inlineTraitToggle:nil];
}

+ (instancetype)handleWithInput:(UIView<UITextInput> *)input
                      ownerView:(UIView *)ownerView
       attributedTextProjection:(IDTelegramAttributedTextProjection)projection
                     blockTexts:(IDTelegramBlockTextsProvider)blockTexts
               typingAttributes:(IDTelegramTypingAttributesProvider)typingAttributes
              inlineTraitToggle:(IDTelegramInlineTraitToggle)inlineTraitToggle {
    NSParameterAssert(input != nil);
    IDTelegramInputHandle *handle = [IDTelegramInputHandle new];
    handle.input = input;
    handle.ownerView = ownerView ?: input;
    handle.attributedTextProjection = projection;
    handle.blockTextsProvider = blockTexts;
    handle.typingAttributesProvider = typingAttributes;
    handle.inlineTraitToggle = inlineTraitToggle;
    return handle;
}

@end

#pragma mark - The projected text storage

@interface IDTelegramProjectedTextStorage ()
@property(nonatomic, readwrite) BOOL isAligned;
@property(nonatomic, copy, readwrite, nullable) NSString *misalignmentReason;
- (instancetype)initWithInput:(UIView<UITextInput> *)input
                      projection:(nullable IDTelegramAttributedTextProjection)projection;
- (nullable UITextRange *)id_documentRange;
@end

@implementation IDTelegramProjectedTextStorage {
    NSAttributedString *_backing;
    __weak UIView<UITextInput> *_input;
    IDTelegramAttributedTextProjection _projection;
}

- (instancetype)initWithInput:(UIView<UITextInput> *)input
                      projection:(nullable IDTelegramAttributedTextProjection)projection {
    self = [super init];
    if (self == nil) return nil;
    _backing = [[NSAttributedString alloc] initWithString:@""];
    _input = input;
    _projection = [projection copy];
    [self refresh];
    return self;
}

/// The whole-document range, exactly as the vendored recorder spells it.
- (nullable UITextRange *)id_documentRange {
    UIView<UITextInput> *input = _input;
    if (input == nil) return nil;
    return [input textRangeFromPosition:input.beginningOfDocument
                             toPosition:input.endOfDocument];
}

- (void)refresh {
    self.isAligned = NO;
    self.misalignmentReason = nil;
    NSAttributedString *empty = [[NSAttributedString alloc] initWithString:@""];

    UIView<UITextInput> *input = _input;
    if (input == nil || _projection == nil) {
        _backing = empty;
        self.misalignmentReason = @"the host's input or its attributed projection is gone";
        return;
    }
    UITextRange *range = [self id_documentRange];
    if (range == nil) {
        _backing = empty;
        self.misalignmentReason =
            @"the input could not form a range over its own document";
        return;
    }
    NSAttributedString *projected = _projection(range);
    if (projected == nil) {
        _backing = empty;
        self.misalignmentReason =
            @"the editor declined to project the whole document";
        return;
    }
    NSString *canonical = [input textInRange:range];
    if (canonical == nil) {
        _backing = empty;
        self.misalignmentReason = @"the input returned no text for its own document range";
        return;
    }
    if (![projected.string isEqualToString:canonical]) {
        _backing = empty;
        self.misalignmentReason = [NSString stringWithFormat:
            @"the projection (%lu chars) does not equal the canonical text (%lu chars)",
            (unsigned long)projected.length, (unsigned long)canonical.length];
        return;
    }
    _backing = [projected copy];
    self.isAligned = YES;
}

// MARK: NSTextStorage primitives. The two readers answer from the pulled backing; the two writers
// raise, because a projection has no upstream to write to and a silent no-op write would leave the
// caller believing it had changed the editor.

- (NSString *)string {
    return _backing.string;
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location
                                                effectiveRange:(NSRangePointer)range {
    return [_backing attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
    [NSException raise:NSInternalInconsistencyException
                format:@"IDTelegramProjectedTextStorage is a read-only projection of the editor; "
                       @"it cannot be mutated (attempted replaceCharactersInRange:)"];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes range:(NSRange)range {
    [NSException raise:NSInternalInconsistencyException
                format:@"IDTelegramProjectedTextStorage is a read-only projection of the editor; "
                       @"it cannot be mutated (attempted setAttributes:range:)"];
}

@end

#pragma mark - The host

@interface IDTextInputTestHost ()

@property(nonatomic, readwrite) IDTextInputHostKind kind;
@property(nonatomic, strong, readwrite) UIWindow *window;
@property(nonatomic, strong, readwrite) UIView<UITextInput> *input;
@property(nonatomic, strong, readwrite) NSTextStorage *observedTextStorage;
@property(nonatomic, readwrite) BOOL comparesAnnotations;
@property(nonatomic, weak) UIWindow *previousKeyWindow;

@property(nonatomic, strong) UIView *id_ownerView;
@property(nonatomic, copy, nullable)
    IDTelegramAttributedTextProjection id_attributedTextProjection;
@property(nonatomic, copy, nullable) IDTelegramBlockTextsProvider id_blockTextsProvider;
@property(nonatomic, copy, nullable)
    IDTelegramTypingAttributesProvider id_typingAttributesProvider;
@property(nonatomic, copy, nullable) IDTelegramInlineTraitToggle id_inlineTraitToggle;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *id_unappliedTraits;

@end

@implementation IDTextInputTestHost

static IDTelegramInputFactory IDTelegramFactory = nil;

+ (void)id_setTelegramInputFactory:(IDTelegramInputFactory)factory {
    IDTelegramFactory = [factory copy];
}

+ (IDTelegramInputFactory)id_telegramInputFactory {
    return IDTelegramFactory;
}

static NSError *IDTextInputHostError(NSString *description) {
    return [NSError errorWithDomain:IDTextInputTestHostErrorDomain
                               code:1
                           userInfo:@{
        NSLocalizedDescriptionKey: description,
    }];
}

/// The ten `UITextInputTraits` members the vendored host applies and the vendored recorder reads,
/// in the original's order, each as its getter/setter pair.
+ (NSArray<NSArray<NSString *> *> *)id_traitSelectorPairs {
    static NSArray<NSArray<NSString *> *> *pairs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pairs = @[
            @[@"autocapitalizationType", @"setAutocapitalizationType:", @"autocapitalizationType"],
            @[@"autocorrectionType", @"setAutocorrectionType:", @"autocorrectionType"],
            @[@"spellCheckingType", @"setSpellCheckingType:", @"spellCheckingType"],
            @[@"smartQuotesType", @"setSmartQuotesType:", @"smartQuotesType"],
            @[@"smartDashesType", @"setSmartDashesType:", @"smartDashesType"],
            @[@"smartInsertDeleteType", @"setSmartInsertDeleteType:", @"smartInsertDeleteType"],
            @[@"inlinePredictionType", @"setInlinePredictionType:", @"inlinePredictionType"],
            @[@"keyboardType", @"setKeyboardType:", @"keyboardType"],
            @[@"returnKeyType", @"setReturnKeyType:", @"returnKeyType"],
            @[@"secureTextEntry", @"setSecureTextEntry:", @"isSecureTextEntry"],
        ];
    });
    return pairs;
}

/// Applies each trait and READS IT BACK, returning the ones that did not stick (name -> why).
/// The original sent all ten unconditionally and checked nothing; see the file header for why
/// neither half of that is available here.
+ (NSDictionary<NSString *, NSString *> *)id_applyTraits:(NSDictionary<NSString *, id> *)traits
                                                   input:(UIView<UITextInput> *)input {
    NSMutableDictionary<NSString *, NSString *> *unapplied = [NSMutableDictionary dictionary];
    for (NSArray<NSString *> *pair in [self id_traitSelectorPairs]) {
        NSString *key = pair[0];
        SEL setter = NSSelectorFromString(pair[1]);
        SEL getter = NSSelectorFromString(pair[2]);
        if (![input respondsToSelector:setter] || ![input respondsToSelector:getter]) {
            unapplied[key] = @"the input implements neither the setter nor the getter "
                             @"(every UITextInputTraits member is @optional)";
            continue;
        }
        // `secureTextEntry` is the one BOOL; the other nine are NSInteger-shaped enums. Both go
        // through an explicitly-typed function pointer rather than `performSelector:`, which
        // cannot carry a non-object argument.
        if ([key isEqualToString:@"secureTextEntry"]) {
            void (*send)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
            BOOL (*read)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            BOOL requested = [traits[key] boolValue];
            send(input, setter, requested);
            BOOL actual = read(input, getter);
            if (actual != requested) {
                unapplied[key] = [NSString stringWithFormat:
                    @"the setter did not take: requested %@, reads %@",
                    requested ? @"YES" : @"NO", actual ? @"YES" : @"NO"];
            }
        } else {
            void (*send)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))objc_msgSend;
            NSInteger (*read)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
            NSInteger requested = (NSInteger)[traits[key] integerValue];
            send(input, setter, requested);
            NSInteger actual = read(input, getter);
            if (actual != requested) {
                unapplied[key] = [NSString stringWithFormat:
                    @"the setter did not take: requested %ld, reads %ld",
                    (long)requested, (long)actual];
            }
        }
    }
    return unapplied.copy;
}

+ (nullable instancetype)hostWithKind:(IDTextInputHostKind)kind
                             scenario:(IDTextInputScenario *)scenario
                                error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (scenario == nil ||
        (kind != IDTextInputHostKindStock &&
         kind != IDTextInputHostKindReference &&
         kind != IDTextInputHostKindMinimal)) {
        if (error != NULL) {
            *error = IDTextInputHostError(
                @"Host kind or scenario is invalid.");
        }
        return nil;
    }

    IDTextInputTestHost *host = [IDTextInputTestHost new];
    host.kind = kind;
    // The vendored rule, unchanged: the scenario asks for annotations or it does not. MEASURED over
    // the vendored corpus 2026-08-24: no scenario names `annotationRanges`, so this is NO for all
    // 68 and the Telegram host is never asked for annotations by this corpus. It is computed rather
    // than hard-coded NO because the honest answer is "whatever the scenario asked for": the
    // projection carries whatever attributes the editor's live region strings carry, so a future
    // corpus that did request annotations would be served from the same place — a claim this corpus
    // gives no opportunity to verify, which is why it is stated as a capability and not a result.
    host.comparesAnnotations =
        [scenario.comparisonFields containsObject:@"annotationRanges"];
    UIFont *font = [UIFont systemFontOfSize:17.0];
    CGRect editorFrame = CGRectMake(35, 120, 320, 480);
    UIEdgeInsets textInsets = UIEdgeInsetsMake(11, 9, 13, 9);

    if (kind == IDTextInputHostKindStock) {
        IDDifferentialStockTextView *stock =
            [[IDDifferentialStockTextView alloc]
                initWithFrame:editorFrame];
        stock.font = font;
        stock.text = scenario.initialText;
        stock.textContainerInset = textInsets;
        stock.contentInsetAdjustmentBehavior =
            UIScrollViewContentInsetAdjustmentNever;
        host.input = stock;
        host.id_ownerView = stock;
        host.observedTextStorage = stock.textStorage;
    } else {
        IDTelegramInputFactory factory = IDTelegramFactory;
        if (factory == nil) {
            if (error != NULL) {
                *error = IDTextInputHostError(
                    @"No Telegram input factory is registered. The Swift test target must call "
                    @"TelegramDifferentialInputFactory.install() before building a non-stock host; "
                    @"falling back to a stock input here would compare stock against stock and "
                    @"report it as agreement.");
            }
            return nil;
        }
        NSError *factoryError = nil;
        IDTelegramInputHandle *handle = factory(kind, scenario, &factoryError);
        if (handle == nil) {
            if (error != NULL) {
                *error = factoryError ?: IDTextInputHostError(
                    @"The Telegram input factory produced no input and reported no error.");
            }
            return nil;
        }
        host.input = handle.input;
        host.id_ownerView = handle.ownerView;
        host.id_attributedTextProjection = handle.attributedTextProjection;
        host.id_blockTextsProvider = handle.blockTextsProvider;
        host.id_typingAttributesProvider = handle.typingAttributesProvider;
        host.id_inlineTraitToggle = handle.inlineTraitToggle;
        if (handle.attributedTextProjection != nil) {
            host.observedTextStorage =
                [[IDTelegramProjectedTextStorage alloc]
                    initWithInput:handle.input
                          projection:handle.attributedTextProjection];
        } else {
            // No projection offered: an EMPTY storage that is explicitly not aligned, so every
            // storage-derived field is declined rather than read as "the document is empty".
            host.observedTextStorage =
                [[IDTelegramProjectedTextStorage alloc]
                    initWithInput:handle.input
                          projection:nil];
        }
    }
    host.input.backgroundColor = UIColor.whiteColor;
    if ([host.input respondsToSelector:@selector(setTextColor:)]) {
        [(id)host.input setTextColor:UIColor.blackColor];
    }
    host.id_unappliedTraits =
        [self id_applyTraits:scenario.initialTraits input:host.input];

    UIWindowScene *scene = nil;
    for (UIScene *candidate in
         UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    UIWindow *window = scene != nil
        ? [[UIWindow alloc] initWithWindowScene:scene]
        : [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    window.frame = CGRectMake(0, 0, 390, 844);
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.whiteColor;
    window.rootViewController = controller;
    [controller.view addSubview:host.id_ownerView];
    host.previousKeyWindow = scene.keyWindow;
    host.window = window;
    if (scenario.family == IDTextInputScenarioFamilyInlineFormatting) {
        window.hidden = YES;
    } else {
        [window makeKeyAndVisible];
    }
    [controller.view layoutIfNeeded];
    [host.id_ownerView setNeedsLayout];
    [host.id_ownerView layoutIfNeeded];

    // TASK 9d FIX. This was `positionFromPosition:offset:` from `beginningOfDocument`, which is the
    // trap Task 9c measured and pinned: that call does RAW-OFFSET arithmetic and then snaps, so on
    // the editor's SPARSE axis it lands ONE CHARACTER EARLY at every character index two or more
    // past a top-level paragraph boundary. MEASURED over the corpus: **10 of the 68 scenarios have
    // an `initialSelection.location` in that region** — the seven `after-boundary-*` autocorrection
    // scenarios and the three `after-boundary-*` inline-prediction ones, i.e. exactly the group
    // written to exercise post-boundary behaviour.
    //
    // The defect was MASKED rather than harmless: all 54 non-inline-formatting scenarios re-aim the
    // caret with a `set-selection` transaction before their first checkpoint (measured: 54/54), and
    // the driver aims correctly, so no snapshot ever saw the wrong caret. Masked is not fixed — the
    // next corpus that opens with a checkpoint would have reported the harness's aim as the
    // editor's behaviour. `IDTelegramTextRangeForCharacterRange` steps the input's own positions and
    // is the identity on a `UITextView`, so the stock arm is bit-for-bit unchanged.
    UITextRange *selection = IDTelegramTextRangeForCharacterRange(
        host.input, scenario.initialSelection);
    if (selection == nil) {
        if (error != NULL) {
            *error = IDTextInputHostError(
                @"Initial selection cannot be represented by the host.");
        }
        window.hidden = YES;
        return nil;
    }
    host.input.selectedTextRange = selection;
    [host.id_ownerView layoutIfNeeded];
    [host id_refreshObservedTextStorage];
    return host;
}

#pragma mark - IDTelegramProvider

- (void)id_refreshObservedTextStorage {
    NSTextStorage *storage = self.observedTextStorage;
    if ([storage isKindOfClass:IDTelegramProjectedTextStorage.class]) {
        [(IDTelegramProjectedTextStorage *)storage refresh];
    }
}

- (BOOL)id_observedTextStorageIsAligned {
    NSTextStorage *storage = self.observedTextStorage;
    if ([storage isKindOfClass:IDTelegramProjectedTextStorage.class]) {
        return ((IDTelegramProjectedTextStorage *)storage).isAligned;
    }
    return YES;   // a stock host's storage IS the document
}

- (NSString *)id_observedTextStorageMisalignmentReason {
    NSTextStorage *storage = self.observedTextStorage;
    if ([storage isKindOfClass:IDTelegramProjectedTextStorage.class]) {
        return ((IDTelegramProjectedTextStorage *)storage).misalignmentReason;
    }
    return nil;
}

- (void)dealloc {
    [self.input resignFirstResponder];
    [self.id_ownerView removeFromSuperview];
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    [self.previousKeyWindow makeKeyWindow];
}

@end
