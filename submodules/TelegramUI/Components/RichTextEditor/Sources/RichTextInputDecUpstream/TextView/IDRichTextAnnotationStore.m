#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextAnnotationStore.h"

@import UIKit;

#import "IDBlockDocument.h"
#import "IDBlockDocumentInternal.h"
#import "IDCanonicalTextProjection.h"
#import "IDRichTextAnchor.h"

@interface IDRichTextAnnotationEntry : NSObject
@property(nonatomic, copy) id<NSCopying> attribute;
@property(nonatomic, strong) id value;
@property(nonatomic, strong) IDRichTextAnchor *startAnchor;
@property(nonatomic, strong) IDRichTextAnchor *endAnchor;
@end

@implementation IDRichTextAnnotationEntry
@end

@interface IDRichTextAnnotationStore () <IDBlockDocumentMutationObserver>
@property(nonatomic, strong, readwrite) IDBlockDocument *document;
@property(nonatomic, strong) NSMutableArray<IDRichTextAnnotationEntry *> *entries;
@end

@implementation IDRichTextAnnotationStore

static void IDAnnotationValidateRange(IDBlockDocument *document,
                                      NSRange range,
                                      NSString *operation) {
    NSUInteger length = document.canonicalLength;
    if (range.location == NSNotFound || range.location > length ||
        range.length > length - range.location) {
        [NSException raise:NSRangeException
                    format:@"IDRichTextAnnotationStore %@ range %@ exceeds canonical length %lu",
                           operation,
                           NSStringFromRange(range),
                           (unsigned long)length];
    }
}

- (instancetype)initWithDocument:(IDBlockDocument *)document {
    if (document == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDRichTextAnnotationStore requires a document."];
    }
    self = [super init];
    if (self != nil) {
        _document = document;
        _entries = [NSMutableArray array];
        [document id_addMutationObserver:self];
    }
    return self;
}

- (void)dealloc {
    [self.document id_removeMutationObserver:self];
}

- (BOOL)id_liveRangeForEntry:(IDRichTextAnnotationEntry *)entry
                  projection:(IDCanonicalTextProjection *)projection
                       range:(NSRange *)range {
    if (entry.startAnchor.document != self.document ||
        entry.endAnchor.document != self.document) {
        return NO;
    }
    NSUInteger start = [entry.startAnchor canonicalOffsetInProjection:projection];
    NSUInteger end = [entry.endAnchor canonicalOffsetInProjection:projection];
    if (start >= end || end > self.document.canonicalLength) {
        return NO;
    }
    if (range != NULL) {
        *range = NSMakeRange(start, end - start);
    }
    return YES;
}

- (IDRichTextAnnotationEntry *)id_entryWithAttribute:(id<NSCopying>)attribute
                                                value:(id)value
                                       canonicalRange:(NSRange)range
                                           projection:(IDCanonicalTextProjection *)projection {
    IDCanonicalLocation *start = [projection locationForCanonicalOffset:range.location];
    IDCanonicalLocation *end = [projection locationForCanonicalOffset:NSMaxRange(range)];
    if (start == nil || end == nil || range.length == 0) {
        return nil;
    }
    IDRichTextAnnotationEntry *entry = [IDRichTextAnnotationEntry new];
    entry.attribute = attribute;
    entry.value = value;
    // Start-after/end-before makes replacement of the complete range invert or
    // collapse the anchors while insertion immediately outside remains outside.
    entry.startAnchor = [[IDRichTextAnchor alloc]
        initWithDocument:self.document
         blockIdentifier:start.blockIdentifier
              localOffset:start.localOffset
                     bias:IDRichTextAnchorBiasAfter];
    entry.endAnchor = [[IDRichTextAnchor alloc]
        initWithDocument:self.document
         blockIdentifier:end.blockIdentifier
              localOffset:end.localOffset
                     bias:IDRichTextAnchorBiasBefore];
    return entry;
}

- (void)id_removeInvalidEntriesWithProjection:(IDCanonicalTextProjection *)projection {
    NSIndexSet *invalid = [self.entries indexesOfObjectsPassingTest:^BOOL(
        IDRichTextAnnotationEntry *entry,
        NSUInteger index,
        BOOL *stop) {
        return ![self id_liveRangeForEntry:entry projection:projection range:NULL];
    }];
    if (invalid.count > 0) {
        [self.entries removeObjectsAtIndexes:invalid];
    }
}

- (void)id_blockDocumentDidCompleteMutation:(IDBlockDocument *)document {
    if (document != self.document) return;
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    [self id_removeInvalidEntriesWithProjection:projection];
}

- (NSUInteger)id_entryCount {
    return self.entries.count;
}

- (NSArray<NSValue *> *)id_textSegmentsInRange:(NSRange)range
                                     projection:(IDCanonicalTextProjection *)projection {
    NSMutableArray<NSValue *> *segments = [NSMutableArray array];
    NSUInteger cursor = range.location;
    NSUInteger end = NSMaxRange(range);
    NSString *string = projection.string;
    while (cursor < end) {
        NSRange remaining = NSMakeRange(cursor, end - cursor);
        NSRange newline = [string rangeOfString:@"\n" options:NSLiteralSearch range:remaining];
        NSUInteger segmentEnd = newline.location == NSNotFound ? end : newline.location;
        if (segmentEnd > cursor) {
            [segments addObject:[NSValue valueWithRange:
                NSMakeRange(cursor, segmentEnd - cursor)]];
        }
        if (newline.location == NSNotFound) break;
        cursor = NSMaxRange(newline);
    }
    return segments.copy;
}

- (void)addAttribute:(id<NSCopying>)attribute
                value:(id)value
       canonicalRange:(NSRange)range {
    if (attribute == nil || value == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDRichTextAnnotationStore addAttribute requires a key and value."];
    }
    IDAnnotationValidateRange(self.document, range, @"add");
    if (range.length == 0) return;
    [self removeAttribute:attribute canonicalRange:range];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    for (NSValue *segmentValue in [self id_textSegmentsInRange:range
                                                    projection:projection]) {
        IDRichTextAnnotationEntry *entry = [self
            id_entryWithAttribute:attribute
                            value:value
                   canonicalRange:segmentValue.rangeValue
                       projection:projection];
        if (entry != nil) [self.entries addObject:entry];
    }
}

- (id)annotationAttribute:(id<NSCopying>)attribute
         atCanonicalOffset:(NSUInteger)offset {
    if (attribute == nil) return nil;
    if (offset > self.document.canonicalLength) {
        [NSException raise:NSRangeException
                    format:@"IDRichTextAnnotationStore lookup offset %lu exceeds canonical length %lu",
                           (unsigned long)offset,
                           (unsigned long)self.document.canonicalLength];
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    [self id_removeInvalidEntriesWithProjection:projection];
    for (IDRichTextAnnotationEntry *entry in self.entries.reverseObjectEnumerator) {
        if (![(id)entry.attribute isEqual:attribute]) continue;
        NSRange liveRange;
        if ([self id_liveRangeForEntry:entry projection:projection range:&liveRange] &&
            NSLocationInRange(offset, liveRange)) {
            return entry.value;
        }
    }
    return nil;
}

- (void)removeAttribute:(id<NSCopying>)attribute
          canonicalRange:(NSRange)range {
    if (attribute == nil) return;
    IDAnnotationValidateRange(self.document, range, @"remove");
    if (range.length == 0) return;
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    [self id_removeInvalidEntriesWithProjection:projection];
    NSMutableArray<IDRichTextAnnotationEntry *> *result = [NSMutableArray array];
    for (IDRichTextAnnotationEntry *entry in self.entries) {
        NSRange liveRange;
        if (![self id_liveRangeForEntry:entry projection:projection range:&liveRange] ||
            ![(id)entry.attribute isEqual:attribute]) {
            [result addObject:entry];
            continue;
        }
        NSRange intersection = NSIntersectionRange(liveRange, range);
        if (intersection.length == 0) {
            [result addObject:entry];
            continue;
        }
        if (intersection.location > liveRange.location) {
            NSRange left = NSMakeRange(liveRange.location,
                                       intersection.location - liveRange.location);
            IDRichTextAnnotationEntry *leftEntry = [self
                id_entryWithAttribute:entry.attribute
                                value:entry.value
                       canonicalRange:left
                           projection:projection];
            if (leftEntry != nil) [result addObject:leftEntry];
        }
        NSUInteger intersectionEnd = NSMaxRange(intersection);
        NSUInteger liveEnd = NSMaxRange(liveRange);
        if (intersectionEnd < liveEnd) {
            NSRange right = NSMakeRange(intersectionEnd, liveEnd - intersectionEnd);
            IDRichTextAnnotationEntry *rightEntry = [self
                id_entryWithAttribute:entry.attribute
                                value:entry.value
                       canonicalRange:right
                           projection:projection];
            if (rightEntry != nil) [result addObject:rightEntry];
        }
    }
    self.entries = result;
}

- (NSAttributedString *)annotatedSubstringForCanonicalRange:(NSRange)range {
    IDAnnotationValidateRange(self.document, range, @"substring");
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    [self id_removeInvalidEntriesWithProjection:projection];
    NSMutableAttributedString *result = [[projection.attributedString
        attributedSubstringFromRange:range] mutableCopy];
    if (result.length > 0) {
        [result removeAttribute:NSShadowAttributeName
                         range:NSMakeRange(0, result.length)];
    }
    if (range.length == 0) return result.copy;
    for (IDRichTextAnnotationEntry *entry in self.entries) {
        NSRange liveRange;
        if (![self id_liveRangeForEntry:entry projection:projection range:&liveRange]) {
            continue;
        }
        NSRange intersection = NSIntersectionRange(liveRange, range);
        if (intersection.length == 0) continue;
        NSRange local = NSMakeRange(intersection.location - range.location,
                                    intersection.length);
        [result addAttribute:(NSAttributedStringKey)entry.attribute
                       value:entry.value
                       range:local];
    }
    return result.copy;
}

- (void)enumerateAttributesInCanonicalRange:(NSRange)range
                                  usingBlock:(void (NS_NOESCAPE ^)(
                                      id<NSCopying> attribute,
                                      id value,
                                      NSRange canonicalRange))block {
    IDAnnotationValidateRange(self.document, range, @"enumerate");
    if (range.length == 0 || block == nil) return;
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    [self id_removeInvalidEntriesWithProjection:projection];
    for (IDRichTextAnnotationEntry *entry in self.entries.copy) {
        NSRange liveRange;
        if (![self id_liveRangeForEntry:entry projection:projection range:&liveRange]) {
            continue;
        }
        NSRange intersection = NSIntersectionRange(liveRange, range);
        if (intersection.length > 0) {
            block(entry.attribute, entry.value, intersection);
        }
    }
}

@end

#endif
