#import "TGIDTextAlternatives.h"

#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import <objc/message.h>
#import "IDBlockDocument.h"
#import "IDBlockTextViewInternal.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"

static NSString *const TGIDTextAlternativesKey = @"NSTextAlternatives";
#define TGIDTextAlternativesDisplayStyleKey TGPN_NSTextAlternativesDisplayStyle()

@implementation TGIDObservingBlockTextView (TGIDTextAlternatives)

+ (NSAttributedStringKey)tgid_textAlternativesKey { return TGIDTextAlternativesKey; }
+ (NSAttributedStringKey)tgid_textAlternativesDisplayStyleKey { return TGIDTextAlternativesDisplayStyleKey; }

// MARK: - Geometry

/// The engine's positions are canonical offsets, so the public difference IS the canonical offset.
- (NSUInteger)tgid_canonicalOffsetOfPosition:(UITextPosition *)position {
    NSInteger offset = [self offsetFromPosition:self.beginningOfDocument toPosition:position];
    return offset < 0 ? 0 : (NSUInteger)offset;
}

- (nullable UITextRange *)tgid_textRangeForCanonicalRange:(NSRange)range {
    UITextPosition *start = [self positionFromPosition:self.beginningOfDocument
                                                offset:(NSInteger)range.location];
    if (start == nil) return nil;
    UITextPosition *end = [self positionFromPosition:start offset:(NSInteger)range.length];
    if (end == nil) return nil;
    return [self textRangeFromPosition:start toPosition:end];
}

/// The canonical range of the block holding `offset` — the window an annotation lookup enumerates,
/// since an alternatives entry never crosses a block.
- (NSRange)tgid_blockRangeContainingCanonicalOffset:(NSUInteger)offset {
    NSUInteger cursor = 0;
    for (IDBlock *block in self.id_document.blocks) {
        NSUInteger length = block.attributedText.length;
        if (offset <= cursor + length) return NSMakeRange(cursor, length);
        cursor += length + 1;
    }
    return NSMakeRange(NSNotFound, 0);
}

// MARK: - The store, through the layout controller

- (void)tgid_annotateCanonicalRange:(NSRange)range
                       alternatives:(nullable id)alternatives
                              style:(NSInteger)style {
    if (range.length == 0) return;
    UITextRange *textRange = [self tgid_textRangeForCanonicalRange:range];
    if (textRange == nil) return;
    IDRichTextLayoutController *controller = self.id_richLayoutController;
    if (alternatives != nil) {
        [controller id_addAnnotationAttribute:TGIDTextAlternativesKey value:alternatives forRange:textRange];
    }
    [controller id_addAnnotationAttribute:TGIDTextAlternativesDisplayStyleKey value:@(style) forRange:textRange];
}

- (void)tgid_removeAlternativesInCanonicalRange:(NSRange)range {
    if (range.length == 0) return;
    UITextRange *textRange = [self tgid_textRangeForCanonicalRange:range];
    if (textRange == nil) return;
    IDRichTextLayoutController *controller = self.id_richLayoutController;
    [controller id_removeAnnotationAttribute:TGIDTextAlternativesKey forRange:textRange];
    [controller id_removeAnnotationAttribute:TGIDTextAlternativesDisplayStyleKey forRange:textRange];
}

/// Every alternatives run in `range`, as canonical ranges with their objects.
- (void)tgid_enumerateAlternativesInCanonicalRange:(NSRange)range
                                        usingBlock:(void (^)(NSRange canonicalRange, id alternatives))block {
    UITextRange *textRange = [self tgid_textRangeForCanonicalRange:range];
    if (textRange == nil || range.length == 0) return;
    NSAttributedString *annotated = [self.id_richLayoutController id_annotatedSubstringForRange:textRange];
    NSUInteger length = MIN(annotated.length, range.length);
    if (length == 0) return;
    [annotated enumerateAttribute:TGIDTextAlternativesKey
                          inRange:NSMakeRange(0, length)
                          options:0
                       usingBlock:^(id value, NSRange run, BOOL *stop) {
        if (value == nil) return;
        block(NSMakeRange(range.location + run.location, run.length), value);
    }];
}

/// `NSTextAlternatives` is public on macOS and private on iOS: resolved by name, and absent means
/// the underline is still drawn but the tap has nothing to offer.
- (nullable id)tgid_alternativesWithPrimary:(NSString *)primary
                               alternatives:(NSArray<NSString *> *)alternatives
                              lowConfidence:(BOOL)lowConfidence {
    Class cls = NSClassFromString(@"NSTextAlternatives");
    if (cls == Nil) return nil;
    SEL initializer = NSSelectorFromString(TGPN_initWithPrimaryString_alternativeStrings_isLowConfidence_());
    if (![cls instancesRespondToSelector:initializer]) return nil;
    id allocated = [cls alloc];
    return ((id (*)(id, SEL, id, id, BOOL))objc_msgSend)(allocated, initializer, primary,
                                                         alternatives ?: @[], lowConfidence);
}

- (nullable NSString *)tgid_primaryStringOf:(id)alternatives {
    SEL selector = NSSelectorFromString(@"primaryString");
    if (![alternatives respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(alternatives, selector);
}

// MARK: - The keyboard's delivery

- (void)insertText:(NSString *)text alternatives:(NSArray<NSString *> *)alternatives style:(UITextAlternativeStyle)style {
    UITextRange *selection = self.selectedTextRange;
    NSUInteger start = selection == nil ? NSNotFound : [self tgid_canonicalOffsetOfPosition:selection.start];
    // Through this view's own gated insert — the host may transform or veto, and the annotation
    // covers whatever the gate let land, measured by where the caret went.
    [self insertText:text];
    if (start == NSNotFound) return;
    UITextRange *after = self.selectedTextRange;
    NSUInteger end = after == nil ? start : [self tgid_canonicalOffsetOfPosition:after.start];
    if (end <= start) return;
    BOOL lowConfidence = style == UITextAlternativeStyleLowConfidence;
    id object = [self tgid_alternativesWithPrimary:text alternatives:alternatives lowConfidence:lowConfidence];
    [self tgid_annotateCanonicalRange:NSMakeRange(start, end - start)
                         alternatives:object
                                style:lowConfidence ? 1 : 0];
}

- (void)insertText:(NSString *)text style:(UITextAlternativeStyle)style alternatives:(NSArray<NSString *> *)alternatives {
    [self insertText:text alternatives:alternatives style:style];
}

- (void)tgpn_replaceRange:(UITextRange *)range
    withAnnotatedString:(NSAttributedString *)annotatedString
    relativeReplacementRange:(NSRange)relativeReplacementRange {
    (void)relativeReplacementRange;
    NSUInteger start = [self tgid_canonicalOffsetOfPosition:range.start];
    [self replaceRange:range withText:annotatedString.string];
    NSUInteger length = annotatedString.length;
    if (length == 0) return;
    [annotatedString enumerateAttributesInRange:NSMakeRange(0, length)
                                        options:0
                                     usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes,
                                                  NSRange run, BOOL *stop) {
        id alternatives = attributes[TGIDTextAlternativesKey];
        NSNumber *displayStyle = attributes[TGIDTextAlternativesDisplayStyleKey];
        if (alternatives == nil && displayStyle == nil) return;
        NSRange canonical = NSMakeRange(start + run.location, run.length);
        UITextRange *textRange = [self tgid_textRangeForCanonicalRange:canonical];
        if (textRange == nil) return;
        IDRichTextLayoutController *controller = self.id_richLayoutController;
        if (alternatives != nil) {
            [controller id_addAnnotationAttribute:TGIDTextAlternativesKey value:alternatives forRange:textRange];
        }
        if (displayStyle != nil) {
            [controller id_addAnnotationAttribute:TGIDTextAlternativesDisplayStyleKey value:displayStyle forRange:textRange];
        }
    }];
}

- (void)addTextAlternatives:(id)alternatives {
    NSString *primary = [self tgid_primaryStringOf:alternatives];
    UITextRange *selection = self.selectedTextRange;
    if (primary.length == 0 || selection == nil) return;
    NSUInteger caret = [self tgid_canonicalOffsetOfPosition:selection.start];
    if (caret < primary.length) return;
    NSRange candidate = NSMakeRange(caret - primary.length, primary.length);
    UITextRange *textRange = [self tgid_textRangeForCanonicalRange:candidate];
    if (textRange == nil || ![[self textInRange:textRange] isEqualToString:primary]) return;
    SEL lowConfidenceSelector = NSSelectorFromString(TGPN_isLowConfidence());
    BOOL lowConfidence = [alternatives respondsToSelector:lowConfidenceSelector]
        && ((BOOL (*)(id, SEL))objc_msgSend)(alternatives, lowConfidenceSelector);
    [self tgid_annotateCanonicalRange:candidate alternatives:alternatives style:lowConfidence ? 1 : 0];
}

- (void)tgpn_addTextAlternativesDisplayStyle:(NSInteger)style toRange:(UITextRange *)range {
    if (range == nil) return;
    [self.id_richLayoutController id_addAnnotationAttribute:TGIDTextAlternativesDisplayStyleKey
                                                       value:@(style)
                                                    forRange:range];
}

// MARK: - The tap's question

- (nullable UITextRange *)tgpn_rangeWithTextAlternatives:(id _Nullable * _Nullable)alternatives
                                          atPosition:(UITextPosition *)position {
    if (alternatives != NULL) *alternatives = nil;
    if (position == nil) return nil;
    IDRichTextLayoutController *controller = self.id_richLayoutController;
    NSUInteger offset = [self tgid_canonicalOffsetOfPosition:position];
    id value = [controller id_annotationAttribute:TGIDTextAlternativesKey atPosition:position];
    NSUInteger probe = offset;
    if (value == nil && offset > 0) {
        UITextPosition *before = [self positionFromPosition:position offset:-1];
        if (before != nil) {
            value = [controller id_annotationAttribute:TGIDTextAlternativesKey atPosition:before];
            probe = offset - 1;
        }
    }
    if (value == nil) return nil;
    NSRange block = [self tgid_blockRangeContainingCanonicalOffset:probe];
    if (block.location == NSNotFound) return nil;
    __block NSRange found = NSMakeRange(NSNotFound, 0);
    [self tgid_enumerateAlternativesInCanonicalRange:block usingBlock:^(NSRange canonicalRange, id run) {
        if (found.location != NSNotFound) return;
        if (run == value && NSLocationInRange(probe, canonicalRange)) found = canonicalRange;
    }];
    if (found.location == NSNotFound) return nil;
    if (alternatives != NULL) *alternatives = value;
    return [self tgid_textRangeForCanonicalRange:found];
}

- (NSAttributedString *)tgpn_annotatedSubstringForRange:(UITextRange *)range {
    return [self.id_richLayoutController id_annotatedSubstringForRange:range];
}

- (void)removeAnnotation:(id)annotation forRange:(UITextRange *)range {
    if (annotation == nil || range == nil) return;
    [self.id_richLayoutController id_removeAnnotationAttribute:annotation forRange:range];
}

// MARK: - Clearing

- (NSRange)tgid_wholeDocumentCanonicalRange {
    NSInteger length = [self offsetFromPosition:self.beginningOfDocument toPosition:self.endOfDocument];
    return NSMakeRange(0, length < 0 ? 0 : (NSUInteger)length);
}

- (void)tgpn_removeAllTextAlternatives {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    [self tgid_enumerateAlternativesInCanonicalRange:[self tgid_wholeDocumentCanonicalRange]
                                          usingBlock:^(NSRange canonicalRange, id run) {
        [ranges addObject:[NSValue valueWithRange:canonicalRange]];
    }];
    for (NSValue *value in ranges) [self tgid_removeAlternativesInCanonicalRange:value.rangeValue];
}

- (void)tgpn_removeAlternativesForCurrentWord {
    UITextRange *selection = self.selectedTextRange;
    if (selection == nil) return;
    UITextRange *word = [self.tokenizer rangeEnclosingPosition:selection.start
                                               withGranularity:UITextGranularityWord
                                                   inDirection:UITextStorageDirectionBackward];
    if (word == nil) {
        word = [self.tokenizer rangeEnclosingPosition:selection.start
                                      withGranularity:UITextGranularityWord
                                          inDirection:UITextStorageDirectionForward];
    }
    if (word == nil) return;
    NSUInteger start = [self tgid_canonicalOffsetOfPosition:word.start];
    NSUInteger end = [self tgid_canonicalOffsetOfPosition:word.end];
    if (end > start) [self tgid_removeAlternativesInCanonicalRange:NSMakeRange(start, end - start)];
}

/// The keyboard's emoji suggestions annotate the word they stood for; those are the alternatives
/// whose primary string has no letter or digit in it.
- (void)tgpn_removeEmojiAlternatives {
    NSCharacterSet *alphanumerics = NSCharacterSet.alphanumericCharacterSet;
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    [self tgid_enumerateAlternativesInCanonicalRange:[self tgid_wholeDocumentCanonicalRange]
                                          usingBlock:^(NSRange canonicalRange, id run) {
        NSString *primary = [self tgid_primaryStringOf:run];
        if (primary.length == 0) return;
        if ([primary rangeOfCharacterFromSet:alphanumerics].location == NSNotFound) {
            [ranges addObject:[NSValue valueWithRange:canonicalRange]];
        }
    }];
    for (NSValue *value in ranges) [self tgid_removeAlternativesInCanonicalRange:value.rangeValue];
}

@end

#endif
