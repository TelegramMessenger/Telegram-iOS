#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockDocument.h"

#import "IDCanonicalTextProjection.h"
#import "IDBlockDocumentInternal.h"
#import "IDInlineTextFormatting.h"
#import "IDRichTextAnchor.h"

static NSDictionary<NSAttributedStringKey, id> *
IDStructuralSeparatorAttributes(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    NSMutableDictionary<NSAttributedStringKey, id> *result =
        attributes.mutableCopy ?: [NSMutableDictionary dictionary];
    [result removeObjectForKey:IDInlineTextBoldAttributeName];
    [result removeObjectForKey:IDInlineTextItalicAttributeName];
    [result removeObjectForKey:IDInlineTextUnderlineAttributeName];
    [result removeObjectForKey:IDInlineTextStrikethroughAttributeName];
    return result.copy;
}

@interface IDRichTextAnchor (IDBlockDocumentTracking)
- (void)id_rebaseToCanonicalLocation:(IDCanonicalLocation *)location;
@end

@interface IDBlock ()
@property(nonatomic, copy, readwrite) NSUUID *identifier;
@property(nonatomic, copy, readwrite) NSAttributedString *attributedText;
@property(nonatomic, copy, readwrite) NSDictionary<NSAttributedStringKey, id> *separatorAttributes;

- (instancetype)initWithIdentifier:(NSUUID *)identifier
                     attributedText:(NSAttributedString *)attributedText
                separatorAttributes:(NSDictionary<NSAttributedStringKey, id> *)separatorAttributes;
@end

@interface IDBlockDocumentChange ()
@property(nonatomic, readwrite) NSRange replacedCanonicalRange;
@property(nonatomic, readwrite) NSUInteger replacementLength;
@property(nonatomic, copy, readwrite) NSArray<NSUUID *> *affectedBlockIdentifiers;
@property(nonatomic, readwrite) BOOL charactersChanged;

- (instancetype)initWithRange:(NSRange)range
             replacementLength:(NSUInteger)replacementLength
      affectedBlockIdentifiers:(NSArray<NSUUID *> *)affectedBlockIdentifiers;
@end

@interface IDBlockDocument ()
@property(nonatomic, copy, readwrite) NSArray<IDBlock *> *blocks;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, copy, readwrite) NSDictionary<NSAttributedStringKey, id> *defaultAttributes;
@property(nonatomic, strong) NSHashTable<IDRichTextAnchor *> *trackedAnchors;
@property(nonatomic, strong) NSHashTable<id<IDBlockDocumentMutationObserver>> *mutationObservers;
@end

@implementation IDBlock

- (instancetype)initWithIdentifier:(NSUUID *)identifier
                     attributedText:(NSAttributedString *)attributedText
                separatorAttributes:(NSDictionary<NSAttributedStringKey, id> *)separatorAttributes {
    self = [super init];
    if (self != nil) {
        _identifier = [identifier copy];
        _attributedText = [attributedText copy];
        _separatorAttributes =
            IDStructuralSeparatorAttributes(separatorAttributes);
    }
    return self;
}

@end

@implementation IDBlockDocumentChange

- (instancetype)initWithRange:(NSRange)range
             replacementLength:(NSUInteger)replacementLength
      affectedBlockIdentifiers:(NSArray<NSUUID *> *)affectedBlockIdentifiers {
    self = [super init];
    if (self != nil) {
        _replacedCanonicalRange = range;
        _replacementLength = replacementLength;
        _affectedBlockIdentifiers = [affectedBlockIdentifiers copy];
        _charactersChanged = YES;
    }
    return self;
}

@end

static NSDictionary<NSAttributedStringKey, id> *IDAttributesForBlockText(
    NSAttributedString *text,
    NSDictionary<NSAttributedStringKey, id> *fallback) {
    if (text.length == 0) {
        return fallback;
    }
    return [text attributesAtIndex:text.length - 1 effectiveRange:NULL];
}

static NSMutableAttributedString *IDCanonicalAttributedString(NSArray<IDBlock *> *blocks) {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@""];
    [blocks enumerateObjectsUsingBlock:^(IDBlock *block, NSUInteger index, BOOL *stop) {
        [result appendAttributedString:block.attributedText];
        if (index + 1 < blocks.count) {
            [result appendAttributedString:[[NSAttributedString alloc]
                initWithString:@"\n"
                    attributes:block.separatorAttributes]];
        }
    }];
    return result;
}

static NSArray<IDBlock *> *IDBlocksFromCanonicalAttributedString(
    NSAttributedString *canonical,
    NSArray<NSUUID *> *identifiers,
    NSDictionary<NSAttributedStringKey, id> *defaultAttributes) {
    NSMutableArray<IDBlock *> *blocks = [NSMutableArray array];
    NSUInteger blockStart = 0;
    NSUInteger identifierIndex = 0;
    NSString *string = canonical.string;

    while (blockStart <= canonical.length) {
        // LITERAL: a non-literal search matches whole composed character sequences, and a
        // separator followed by a mark or an emoji modifier (a block starting with an orphaned
        // skin tone) is one such sequence, so the separator was not found and the blocks came
        // out one short of the separators counted by code unit: an out-of-bounds raise in
        // `replaceCanonicalRange:withAttributedString:` (composer harness p20,
        // `HarnessAuthorLineMidClusterCrashTests`). Every structural "\n" search is literal.
        NSRange searchRange = NSMakeRange(blockStart, canonical.length - blockStart);
        NSRange newlineRange = [string rangeOfString:@"\n" options:NSLiteralSearch range:searchRange];
        NSUInteger blockEnd = newlineRange.location == NSNotFound
            ? canonical.length
            : newlineRange.location;
        NSAttributedString *text =
            [canonical attributedSubstringFromRange:NSMakeRange(blockStart, blockEnd - blockStart)];
        NSDictionary<NSAttributedStringKey, id> *separatorAttributes = nil;
        if (newlineRange.location != NSNotFound) {
            separatorAttributes = [canonical attributesAtIndex:newlineRange.location
                                                effectiveRange:NULL];
        } else {
            separatorAttributes = IDAttributesForBlockText(text, defaultAttributes);
        }
        NSUUID *identifier = identifierIndex < identifiers.count
            ? identifiers[identifierIndex]
            : [NSUUID UUID];
        [blocks addObject:[[IDBlock alloc] initWithIdentifier:identifier
                                              attributedText:text
                                         separatorAttributes:separatorAttributes]];
        identifierIndex += 1;
        if (newlineRange.location == NSNotFound) {
            break;
        }
        blockStart = NSMaxRange(newlineRange);
    }
    return blocks;
}

@implementation IDBlockDocument

- (IDBlockDocumentChange *)id_setDefaultAttributes:
    (NSDictionary<NSAttributedStringKey, id> *)attributes {
    NSDictionary<NSAttributedStringKey, id> *updatedDefaults = attributes.copy;
    NSDictionary<NSAttributedStringKey, id> *previousDefaults =
        self.defaultAttributes;
    NSMutableArray<IDBlock *> *updatedBlocks = self.blocks.mutableCopy;
    NSMutableArray<NSUUID *> *affectedIdentifiers = [NSMutableArray array];
    [self.blocks enumerateObjectsUsingBlock:
        ^(IDBlock *block, NSUInteger index, BOOL *stop) {
        if (block.attributedText.length != 0) {
            return;
        }
        NSMutableDictionary<NSAttributedStringKey, id> *separatorAttributes =
            block.separatorAttributes.mutableCopy;
        [previousDefaults enumerateKeysAndObjectsUsingBlock:
            ^(NSAttributedStringKey key, id value, BOOL *stop) {
            if ([separatorAttributes[key] isEqual:value]) {
                [separatorAttributes removeObjectForKey:key];
            }
        }];
        [separatorAttributes addEntriesFromDictionary:updatedDefaults];
        IDBlock *updatedBlock = [[IDBlock alloc]
            initWithIdentifier:block.identifier
                 attributedText:block.attributedText
            separatorAttributes:separatorAttributes];
        if (![updatedBlock.separatorAttributes
                isEqualToDictionary:block.separatorAttributes]) {
            updatedBlocks[index] = updatedBlock;
            [affectedIdentifiers addObject:block.identifier];
        }
    }];
    if ([self.defaultAttributes isEqualToDictionary:updatedDefaults] &&
        affectedIdentifiers.count == 0) {
        return nil;
    }
    self.defaultAttributes = updatedDefaults;
    self.blocks = updatedBlocks.copy;
    self.documentRevision += 1;
    [self id_notifyMutationObservers];
    IDBlockDocumentChange *change = [[IDBlockDocumentChange alloc]
        initWithRange:NSMakeRange(0, self.canonicalLength)
        replacementLength:self.canonicalLength
        affectedBlockIdentifiers:affectedIdentifiers];
    change.charactersChanged = NO;
    return change;
}

- (instancetype)initWithAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
                        defaultAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes {
    self = [super init];
    if (self != nil) {
        _defaultAttributes = [attributes copy];
        NSMutableArray<IDBlock *> *documentBlocks = [NSMutableArray array];
        NSArray<NSAttributedString *> *sourceBlocks = blocks.count > 0
            ? blocks
            : @[[[NSAttributedString alloc] initWithString:@""]];
        for (NSAttributedString *text in sourceBlocks) {
            if ([text.string rangeOfString:@"\n" options:NSLiteralSearch].location != NSNotFound) {
                [NSException raise:NSInvalidArgumentException
                            format:@"IDBlockDocument attributed blocks must not contain U+000A structural newlines."];
            }
            [documentBlocks addObject:[[IDBlock alloc]
                initWithIdentifier:[NSUUID UUID]
                    attributedText:text
               separatorAttributes:IDAttributesForBlockText(text, _defaultAttributes)]];
        }
        _blocks = [documentBlocks copy];
        _documentRevision = 0;
        _trackedAnchors = [NSHashTable weakObjectsHashTable];
        _mutationObservers = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (NSUInteger)canonicalLength {
    NSUInteger length = self.blocks.count - 1;
    for (IDBlock *block in self.blocks) {
        length += block.attributedText.length;
    }
    return length;
}

- (void)validateCanonicalRange:(NSRange)range {
    NSUInteger length = self.canonicalLength;
    if (range.location > length || range.length > length - range.location) {
        [NSException raise:NSRangeException
                    format:@"Canonical range %@ exceeds document length %lu",
                           NSStringFromRange(range),
                           (unsigned long)length];
    }
}

- (NSUInteger)blockIndexForCanonicalOffset:(NSUInteger)offset {
    NSUInteger cursor = 0;
    for (NSUInteger index = 0; index < self.blocks.count; index += 1) {
        NSUInteger blockEnd = cursor + self.blocks[index].attributedText.length;
        if (offset <= blockEnd || index + 1 == self.blocks.count) {
            return index;
        }
        cursor = blockEnd + 1;
    }
    return self.blocks.count - 1;
}

- (NSUInteger)lastAffectedBlockIndexForRange:(NSRange)range
                              firstBlockIndex:(NSUInteger)firstBlockIndex {
    if (range.length == 0) {
        return firstBlockIndex;
    }

    NSUInteger lastUnitOffset = NSMaxRange(range) - 1;
    NSUInteger cursor = 0;
    for (NSUInteger index = 0; index < self.blocks.count; index += 1) {
        NSUInteger blockEnd = cursor + self.blocks[index].attributedText.length;
        if (lastUnitOffset < blockEnd) {
            return index;
        }
        if (lastUnitOffset == blockEnd) {
            return MIN(index + 1, self.blocks.count - 1);
        }
        cursor = blockEnd + 1;
    }
    return self.blocks.count - 1;
}

- (IDBlockDocumentChange *)replaceCanonicalRange:(NSRange)range
                            withAttributedString:(NSAttributedString *)replacement {
    [self validateCanonicalRange:range];

    NSArray<IDRichTextAnchor *> *trackedAnchors = self.trackedAnchors.allObjects;
    IDCanonicalTextProjection *oldProjection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self];
    NSMutableArray<NSNumber *> *oldOffsets =
        [NSMutableArray arrayWithCapacity:trackedAnchors.count];
    for (IDRichTextAnchor *anchor in trackedAnchors) {
        [oldOffsets addObject:@([anchor canonicalOffsetInProjection:oldProjection])];
    }

    NSArray<IDBlock *> *oldBlocks = self.blocks;
    NSUInteger firstAffectedIndex = [self blockIndexForCanonicalOffset:range.location];
    NSUInteger lastAffectedIndex = [self lastAffectedBlockIndexForRange:range
                                                        firstBlockIndex:firstAffectedIndex];
    NSMutableAttributedString *canonical = IDCanonicalAttributedString(oldBlocks);
    [canonical replaceCharactersInRange:range withAttributedString:replacement];

    NSUInteger beforeCount = firstAffectedIndex;
    NSUInteger afterCount = oldBlocks.count - lastAffectedIndex - 1;
    NSUInteger resultBlockCount = 1;
    for (NSUInteger index = 0; index < canonical.length; index += 1) {
        if ([canonical.string characterAtIndex:index] == '\n') {
            resultBlockCount += 1;
        }
    }
    NSUInteger affectedResultCount = resultBlockCount - beforeCount - afterCount;

    NSMutableArray<NSUUID *> *resultIdentifiers = [NSMutableArray array];
    for (NSUInteger index = 0; index < beforeCount; index += 1) {
        [resultIdentifiers addObject:oldBlocks[index].identifier];
    }
    [resultIdentifiers addObject:oldBlocks[firstAffectedIndex].identifier];
    for (NSUInteger index = 1; index < affectedResultCount; index += 1) {
        [resultIdentifiers addObject:[NSUUID UUID]];
    }
    for (NSUInteger index = oldBlocks.count - afterCount; index < oldBlocks.count; index += 1) {
        [resultIdentifiers addObject:oldBlocks[index].identifier];
    }

    NSArray<IDBlock *> *newBlocks = IDBlocksFromCanonicalAttributedString(
        canonical,
        resultIdentifiers,
        self.defaultAttributes);
    NSMutableOrderedSet<NSUUID *> *affectedIdentifiers = [NSMutableOrderedSet orderedSet];
    for (NSUInteger index = firstAffectedIndex; index <= lastAffectedIndex; index += 1) {
        [affectedIdentifiers addObject:oldBlocks[index].identifier];
    }
    for (NSUInteger index = beforeCount; index < beforeCount + affectedResultCount; index += 1) {
        [affectedIdentifiers addObject:newBlocks[index].identifier];
    }

    self.blocks = newBlocks;
    self.documentRevision += 1;
    IDBlockDocumentChange *change = [[IDBlockDocumentChange alloc]
        initWithRange:range
        replacementLength:replacement.length
        affectedBlockIdentifiers:affectedIdentifiers.array];

    NSUInteger replacedStart = change.replacedCanonicalRange.location;
    NSUInteger replacedEnd = NSMaxRange(change.replacedCanonicalRange);
    NSUInteger replacementEnd = replacedStart + change.replacementLength;
    IDCanonicalTextProjection *newProjection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self];
    NSMutableArray<IDCanonicalLocation *> *newLocations =
        [NSMutableArray arrayWithCapacity:trackedAnchors.count];
    [trackedAnchors enumerateObjectsUsingBlock:^(IDRichTextAnchor *anchor,
                                                 NSUInteger index,
                                                 BOOL *stop) {
        NSUInteger oldOffset = oldOffsets[index].unsignedIntegerValue;
        NSUInteger newOffset = oldOffset;
        if (oldOffset < replacedStart) {
            newOffset = oldOffset;
        } else if (change.replacedCanonicalRange.length == 0 && oldOffset > replacedStart) {
            newOffset = oldOffset + change.replacementLength;
        } else if (change.replacedCanonicalRange.length > 0 && oldOffset >= replacedEnd) {
            newOffset = oldOffset - change.replacedCanonicalRange.length +
                change.replacementLength;
        } else {
            newOffset = anchor.bias == IDRichTextAnchorBiasBefore
                ? replacedStart
                : replacementEnd;
        }
        [newLocations addObject:[newProjection locationForCanonicalOffset:newOffset]];
    }];
    [trackedAnchors enumerateObjectsUsingBlock:^(IDRichTextAnchor *anchor,
                                                 NSUInteger index,
                                                 BOOL *stop) {
        [anchor id_rebaseToCanonicalLocation:newLocations[index]];
    }];
    [self id_notifyMutationObservers];
    return change;
}

- (void)id_registerRichTextAnchor:(IDRichTextAnchor *)anchor {
    [self.trackedAnchors addObject:anchor];
}

- (void)id_addMutationObserver:(id<IDBlockDocumentMutationObserver>)observer {
    if (observer != nil) [self.mutationObservers addObject:observer];
}

- (void)id_removeMutationObserver:(id<IDBlockDocumentMutationObserver>)observer {
    if (observer != nil) [self.mutationObservers removeObject:observer];
}

- (void)id_notifyMutationObservers {
    for (id<IDBlockDocumentMutationObserver> observer in self.mutationObservers.allObjects) {
        [observer id_blockDocumentDidCompleteMutation:self];
    }
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
        canonicalRange:(NSRange)range {
    (void)[self id_setAttributes:attributes canonicalRange:range];
}

- (IDBlockDocumentChange *)id_setAttributes:(
    NSDictionary<NSAttributedStringKey, id> *)attributes
                              canonicalRange:(NSRange)range {
    [self validateCanonicalRange:range];
    NSMutableAttributedString *canonical = IDCanonicalAttributedString(self.blocks);
    [canonical setAttributes:attributes range:range];
    return [self id_adoptCanonicalAttributes:canonical changedRange:range];
}

- (IDBlockDocumentChange *)id_adoptCanonicalAttributes:(NSAttributedString *)canonical
                                          changedRange:(NSRange)range {
    if (canonical.length != self.canonicalLength) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Adopted canonical attributes must keep the document's text."];
    }
    [self validateCanonicalRange:range];
    NSArray<IDBlock *> *oldBlocks = self.blocks;
    NSArray<NSUUID *> *identifiers = [self.blocks valueForKey:@"identifier"];
    NSArray<IDBlock *> *newBlocks = IDBlocksFromCanonicalAttributedString(
        canonical,
        identifiers,
        self.defaultAttributes);
    NSMutableArray<NSUUID *> *affectedIdentifiers = [NSMutableArray array];
    [newBlocks enumerateObjectsUsingBlock:^(IDBlock *newBlock,
                                            NSUInteger index,
                                            BOOL *stop) {
        IDBlock *oldBlock = oldBlocks[index];
        if (![newBlock.attributedText isEqualToAttributedString:oldBlock.attributedText] ||
            ![newBlock.separatorAttributes isEqualToDictionary:oldBlock.separatorAttributes]) {
            [affectedIdentifiers addObject:newBlock.identifier];
        }
    }];
    self.blocks = newBlocks;
    self.documentRevision += 1;
    [self id_notifyMutationObservers];
    IDBlockDocumentChange *change = [[IDBlockDocumentChange alloc]
        initWithRange:range
        replacementLength:range.length
        affectedBlockIdentifiers:affectedIdentifiers];
    change.charactersChanged = NO;
    return change;
}

- (IDBlockDocumentChange *)
    id_transformTextAttributesInCanonicalRange:(NSRange)range
                                    usingBlock:
                                        (IDBlockDocumentAttributeTransform)
                                            transform {
    if (transform == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDBlockDocument attribute transform must not be nil."];
    }
    [self validateCanonicalRange:range];
    if (range.length == 0) {
        return nil;
    }

    NSArray<IDBlock *> *oldBlocks = self.blocks;
    NSMutableArray<IDBlock *> *newBlocks = [oldBlocks mutableCopy];
    NSMutableArray<NSUUID *> *affectedIdentifiers = [NSMutableArray array];
    __block NSUInteger canonicalBlockStart = 0;
    NSRange requestedRange = range;

    [oldBlocks enumerateObjectsUsingBlock:
        ^(IDBlock *block, NSUInteger index, BOOL *stop) {
        NSRange canonicalTextRange =
            NSMakeRange(canonicalBlockStart, block.attributedText.length);
        NSRange intersection =
            NSIntersectionRange(requestedRange, canonicalTextRange);
        if (intersection.length > 0) {
            NSRange localRange =
                NSMakeRange(intersection.location - canonicalBlockStart,
                            intersection.length);
            NSMutableAttributedString *text =
                [block.attributedText mutableCopy];
            __block BOOL changed = NO;
            [block.attributedText enumerateAttributesInRange:localRange
                                                    options:0
                                                 usingBlock:
                ^(NSDictionary<NSAttributedStringKey, id> *attributes,
                  NSRange runRange,
                  BOOL *runStop) {
                NSDictionary<NSAttributedStringKey, id> *next =
                    transform(attributes);
                if (next == nil) {
                    [NSException raise:NSInvalidArgumentException
                                format:@"IDBlockDocument attribute transform returned nil."];
                }
                if (![next isEqualToDictionary:attributes]) {
                    [text setAttributes:next range:runRange];
                    changed = YES;
                }
            }];
            if (changed) {
                // The separator follows the block's LAST character, the rule
                // `id_restoreAttributedBlocks:changedRange:` applies (and the canonical rebuild and a
                // fresh document give it). Kept as it was, a transform (a link applied over the end of a
                // line) left the separator plain while an undo's restore of the same text linked it, so
                // text typed over a selection starting on that separator was plain before an undo and
                // linked after it (telegram-ios composer harness p23,
                // `HarnessCompositionAfterLinkFromLineEndTests`). An empty block keeps its separator.
                newBlocks[index] = [[IDBlock alloc]
                    initWithIdentifier:block.identifier
                         attributedText:text
                    separatorAttributes:IDAttributesForBlockText(text, block.separatorAttributes)];
                [affectedIdentifiers addObject:block.identifier];
            }
        }
        canonicalBlockStart += block.attributedText.length;
        if (index + 1 < oldBlocks.count) {
            canonicalBlockStart += 1;
        }
    }];

    if (affectedIdentifiers.count == 0) {
        return nil;
    }
    self.blocks = newBlocks.copy;
    self.documentRevision += 1;
    IDBlockDocumentChange *change = [[IDBlockDocumentChange alloc]
        initWithRange:range
        replacementLength:range.length
        affectedBlockIdentifiers:affectedIdentifiers];
    change.charactersChanged = NO;
    [self id_notifyMutationObservers];
    return change;
}

- (IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks {
    return [self id_restoreAttributedBlocks:blocks
                               changedRange:NSMakeRange(0, self.canonicalLength)];
}

- (IDBlockDocumentChange *)id_restoreAttributedBlocks:
    (NSArray<NSAttributedString *> *)blocks
                                         changedRange:(NSRange)changedRange {
    [self validateCanonicalRange:changedRange];
    if (![blocks isKindOfClass:NSArray.class] ||
        blocks.count != self.blocks.count) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Formatting snapshot must have the current block count."];
    }

    NSArray<IDBlock *> *oldBlocks = self.blocks;
    NSMutableArray<IDBlock *> *newBlocks = [oldBlocks mutableCopy];
    NSMutableArray<NSUUID *> *affectedIdentifiers = [NSMutableArray array];
    [oldBlocks enumerateObjectsUsingBlock:
        ^(IDBlock *block, NSUInteger index, BOOL *stop) {
        id candidate = blocks[index];
        if (![candidate isKindOfClass:NSAttributedString.class]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Formatting snapshot entries must be attributed strings."];
        }
        NSAttributedString *snapshot = candidate;
        if ([snapshot.string rangeOfString:@"\n" options:NSLiteralSearch].location != NSNotFound ||
            ![snapshot.string isEqualToString:block.attributedText.string]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Formatting snapshot must preserve block text and structure."];
        }
        if (![snapshot isEqualToAttributedString:block.attributedText]) {
            // A non-empty block's separator follows its LAST character, as the canonical rebuild and
            // a fresh document give it (`IDAttributesForBlockText`). Kept as it was, a presentation
            // pass (a theme change) restyled every character but left each separator in the old
            // presentation, and text typed over a selection starting at a block's end took the
            // separator's: the light theme's black in the dark theme (telegram-ios composer harness
            // p21). An empty block keeps its separator: its attributes are its line's own.
            newBlocks[index] = [[IDBlock alloc]
                initWithIdentifier:block.identifier
                     attributedText:snapshot
                separatorAttributes:IDAttributesForBlockText(snapshot, block.separatorAttributes)];
            [affectedIdentifiers addObject:block.identifier];
        }
    }];

    if (affectedIdentifiers.count == 0) {
        return nil;
    }
    NSRange range = changedRange;
    self.blocks = newBlocks.copy;
    self.documentRevision += 1;
    IDBlockDocumentChange *change = [[IDBlockDocumentChange alloc]
        initWithRange:range
        replacementLength:range.length
        affectedBlockIdentifiers:affectedIdentifiers];
    change.charactersChanged = NO;
    [self id_notifyMutationObservers];
    return change;
}

@end

#endif
