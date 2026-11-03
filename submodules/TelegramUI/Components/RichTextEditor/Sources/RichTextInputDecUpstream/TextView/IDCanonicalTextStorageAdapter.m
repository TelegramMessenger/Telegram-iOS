#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDCanonicalTextStorageAdapter.h"
#import "IDBlockDocumentInternal.h"
#import "IDCanonicalTextStorageAdapterInternal.h"

@interface IDCanonicalTextStorageAdapter ()
@property(nonatomic, strong, readwrite) IDBlockDocument *document;
@property(nonatomic, strong, readwrite) IDCanonicalTextProjection *projection;
@property(nonatomic, copy, nullable) void (^documentChangeHandler)(
    IDBlockDocumentChange *change);
@property(nonatomic, strong) NSMutableArray<IDBlockDocumentChange *> *pendingDocumentChanges;
/// Non-nil only inside `fixAttributesInRange:`: the canonical string the fix is applied to, adopted
/// by the document ONCE when the fix ends. See `fixAttributesInRange:`.
@property(nonatomic, strong) NSMutableAttributedString *fixingCanonical;
@property(nonatomic) NSRange fixingChangedRange;
@end

IDCanonicalTextStorageAdapter *IDCanonicalTextStorageAdapterCreate(
    IDBlockDocument *document) {
    return [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
}

@implementation IDCanonicalTextStorageAdapter

- (instancetype)initWithDocument:(IDBlockDocument *)document {
    if (document == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDCanonicalTextStorageAdapter requires a document."];
    }
    self = [super init];
    if (self != nil) {
        _document = document;
        _projection = [[IDCanonicalTextProjection alloc] initWithDocument:document];
        _pendingDocumentChanges = [NSMutableArray array];
    }
    return self;
}

- (NSString *)string {
    return self.projection.string;
}

/// NOT a presentation hook. An earlier attempt ran host style contributors here; it was wrong twice
/// over. The canvas does not render through this method at all — `IDBlockLayout` builds a per-block
/// `NSTextContentStorage` from `block.attributedText` — and `id_insertionAttributesForReplacedRange:`
/// DOES read it, so decorating here silently baked display styling into every newly typed run.
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location
                                                 effectiveRange:(NSRangePointer)range {
    if (self.fixingCanonical != nil) {
        return [self.fixingCanonical attributesAtIndex:location effectiveRange:range];
    }
    return [self.projection.attributedString attributesAtIndex:location
                                                effectiveRange:range];
}

/// `NSTextStorage`'s attribute fixing, applied to ONE working copy of the canonical string and
/// adopted by the document once at the end — not one document rebuild per fix.
///
/// The fix reads and re-sets attributes once per paragraph (`fixParagraphStyleAttributeInRange:`)
/// and once per font run, and each `setAttributes:range:` rebuilt every block of the document and
/// a new projection: O(n²) in the block count, ~40% of a 200-paragraph paste (composer harness,
/// 2026-09-23, `HarnessLargeRichPasteScalingTests`). The fix's own reads see its own writes through
/// the working copy, exactly as they saw them through the document, and the NSTextStorage side —
/// `beginEditing` / `edited:` / `endEditing` per write — is unchanged. The document gets one
/// attribute-only change covering every range the fix touched, and the working copy's text cannot
/// differ from the document's: fixing never changes characters.
- (void)fixAttributesInRange:(NSRange)range {
    if (self.fixingCanonical != nil) {
        [super fixAttributesInRange:range];
        return;
    }
    self.fixingCanonical = [self.projection.attributedString mutableCopy];
    self.fixingChangedRange = NSMakeRange(NSNotFound, 0);
    @try {
        [super fixAttributesInRange:range];
    } @finally {
        NSAttributedString *fixed = self.fixingCanonical;
        NSRange changedRange = self.fixingChangedRange;
        self.fixingCanonical = nil;
        if (changedRange.location != NSNotFound) {
            IDBlockDocumentChange *change =
                [self.document id_adoptCanonicalAttributes:fixed changedRange:changedRange];
            self.projection = [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
            if (change != nil) [self.pendingDocumentChanges addObject:change];
        }
    }
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
    NSAttributedString *replacement = [[NSAttributedString alloc]
        initWithString:string
            attributes:[self id_insertionAttributesForReplacedRange:range]];
    [self id_replaceRange:range withAttributedString:replacement];
}

- (void)replaceCharactersInRange:(NSRange)range
            withAttributedString:(NSAttributedString *)attributedString {
    [self id_replaceRange:range withAttributedString:attributedString];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                 range:(NSRange)range {
    if (self.fixingCanonical != nil) {
        [self beginEditing];
        @try {
            [self.fixingCanonical setAttributes:attributes range:range];
            NSRange changed = self.fixingChangedRange;
            self.fixingChangedRange = changed.location == NSNotFound ? range : NSUnionRange(changed, range);
            [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
        } @finally {
            [self endEditing];
        }
        return;
    }
    IDBlockDocumentChange *change = nil;
    [self beginEditing];
    @try {
        change = [self.document id_setAttributes:attributes canonicalRange:range];
        self.projection = [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
        if (change != nil) [self.pendingDocumentChanges addObject:change];
    } @finally {
        [self endEditing];
    }
}

- (IDBlockDocumentChange *)
    id_transformTextAttributesInCanonicalRange:(NSRange)range
                                    usingBlock:
                                        (IDBlockDocumentAttributeTransform)
                                            transform {
    IDBlockDocumentChange *change = nil;
    [self beginEditing];
    @try {
        change =
            [self.document
                id_transformTextAttributesInCanonicalRange:range
                                                usingBlock:transform];
        if (change != nil) {
            self.projection =
                [[IDCanonicalTextProjection alloc]
                    initWithDocument:self.document];
            [self edited:NSTextStorageEditedAttributes
                   range:change.replacedCanonicalRange
          changeInLength:0];
            [self.pendingDocumentChanges addObject:change];
        }
    } @finally {
        [self endEditing];
    }
    return change;
}

- (IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks {
    return [self id_restoreAttributedBlocks:blocks
                               changedRange:NSMakeRange(0, self.document.canonicalLength)];
}

- (IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks
                                         changedRange:(NSRange)changedRange {
    IDBlockDocumentChange *change = nil;
    [self beginEditing];
    @try {
        change = [self.document id_restoreAttributedBlocks:blocks changedRange:changedRange];
        if (change != nil) {
            self.projection =
                [[IDCanonicalTextProjection alloc]
                    initWithDocument:self.document];
            [self edited:NSTextStorageEditedAttributes
                   range:change.replacedCanonicalRange
          changeInLength:0];
            [self.pendingDocumentChanges addObject:change];
        }
    } @finally {
        [self endEditing];
    }
    return change;
}

- (NSDictionary<NSAttributedStringKey, id> *)id_insertionAttributesForReplacedRange:
    (NSRange)range {
    NSUInteger length = self.document.canonicalLength;
    if (range.location > length || range.length > length - range.location) {
        return self.document.defaultAttributes;
    }
    if (range.location > 0) {
        return [self attributesAtIndex:range.location - 1 effectiveRange:NULL];
    }
    NSUInteger followingLocation = NSMaxRange(range);
    if (followingLocation < length) {
        return [self attributesAtIndex:followingLocation effectiveRange:NULL];
    }
    if (length == 0 || range.length == length) {
        return self.document.defaultAttributes;
    }
    return self.document.defaultAttributes;
}

- (void)id_replaceRange:(NSRange)range
    withAttributedString:(NSAttributedString *)replacement {
    NSInteger delta = (NSInteger)replacement.length - (NSInteger)range.length;
    IDBlockDocumentChange *change = nil;
    [self beginEditing];
    @try {
        change = [self.document replaceCanonicalRange:range
                                  withAttributedString:replacement];
        self.projection = [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        [self edited:NSTextStorageEditedCharacters | NSTextStorageEditedAttributes
               range:range
      changeInLength:delta];
        if (change != nil) [self.pendingDocumentChanges addObject:change];
    } @finally {
        [self endEditing];
    }
}

- (void)processEditing {
    [super processEditing];
    NSArray<IDBlockDocumentChange *> *changes = self.pendingDocumentChanges.copy;
    [self.pendingDocumentChanges removeAllObjects];
    void (^handler)(IDBlockDocumentChange *) = self.documentChangeHandler;
    if (handler == nil) return;
    for (IDBlockDocumentChange *change in changes) {
        handler(change);
    }
}

@end

#endif
