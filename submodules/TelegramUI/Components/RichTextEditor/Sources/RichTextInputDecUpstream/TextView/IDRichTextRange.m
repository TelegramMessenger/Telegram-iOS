#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextRange.h"
#import "IDRichTextRangeInternal.h"

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

@interface IDRichTextRange ()
@property(nonatomic, strong) IDRichTextPosition *storedStart;
@property(nonatomic, strong) IDRichTextPosition *storedEnd;
@end

@implementation IDRichTextRange

- (IDRichTextPosition *)id_storedStart {
    return self.storedStart;
}

- (IDRichTextPosition *)id_storedEnd {
    return self.storedEnd;
}

- (instancetype)initWithStart:(IDRichTextPosition *)start
                           end:(IDRichTextPosition *)end {
    IDBlockDocument *startDocument = start.anchor.document;
    IDBlockDocument *endDocument = end.anchor.document;
    if (startDocument == nil || startDocument != endDocument) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Rich text range endpoints must belong to the same live document."];
    }

    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:startDocument];
    NSUInteger startOffset = [start.anchor canonicalOffsetInProjection:projection];
    NSUInteger endOffset = [end.anchor canonicalOffsetInProjection:projection];
    BOOL shouldSwap = startOffset > endOffset ||
        (startOffset == endOffset &&
         start.anchor.bias == IDRichTextAnchorBiasAfter &&
         end.anchor.bias == IDRichTextAnchorBiasBefore);

    self = [super init];
    if (self != nil) {
        _storedStart = shouldSwap ? end : start;
        _storedEnd = shouldSwap ? start : end;
    }
    return self;
}

- (IDRichTextPosition *)start {
    return [self storedEndpointsShouldSwap] ? self.storedEnd : self.storedStart;
}

- (IDRichTextPosition *)end {
    return [self storedEndpointsShouldSwap] ? self.storedStart : self.storedEnd;
}

- (BOOL)storedEndpointsShouldSwap {
    IDBlockDocument *document = self.storedStart.anchor.document;
    if (document == nil || document != self.storedEnd.anchor.document) {
        return NO;
    }

    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    NSUInteger startOffset =
        [self.storedStart.anchor canonicalOffsetInProjection:projection];
    NSUInteger endOffset =
        [self.storedEnd.anchor canonicalOffsetInProjection:projection];
    return startOffset > endOffset ||
        (startOffset == endOffset &&
         self.storedStart.anchor.bias == IDRichTextAnchorBiasAfter &&
         self.storedEnd.anchor.bias == IDRichTextAnchorBiasBefore);
}

- (BOOL)isEmpty {
    IDBlockDocument *document = self.start.anchor.document;
    if (document == nil || document != self.end.anchor.document) {
        return NO;
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    return [self.start.anchor canonicalOffsetInProjection:projection] ==
        [self.end.anchor canonicalOffsetInProjection:projection];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (![object isKindOfClass:IDRichTextRange.class]) return NO;
    IDRichTextRange *other = object;
    return [self.start isEqual:other.start] && [self.end isEqual:other.end];
}

- (NSUInteger)hash {
    return self.start.hash ^ (self.end.hash * 31U);
}

@end

#endif
