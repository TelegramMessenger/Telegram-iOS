#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextPosition.h"

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

@interface IDRichTextPosition ()
@property(nonatomic, strong, readwrite) IDRichTextAnchor *anchor;
@property(nonatomic, readwrite) UITextStorageDirection affinity;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@end

@implementation IDRichTextPosition

- (instancetype)initWithAnchor:(IDRichTextAnchor *)anchor
                       affinity:(UITextStorageDirection)affinity {
    IDBlockDocument *document = anchor.document;
    if (document == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Rich text positions require an anchor with a live document."];
    }

    self = [super init];
    if (self != nil) {
        _anchor = anchor;
        _affinity = affinity;
        _documentRevision = document.documentRevision;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (![object isKindOfClass:IDRichTextPosition.class]) return NO;
    IDRichTextPosition *other = object;
    IDBlockDocument *document = self.anchor.document;
    if (document == nil || document != other.anchor.document) {
        return NO;
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    return [self.anchor canonicalOffsetInProjection:projection] ==
        [other.anchor canonicalOffsetInProjection:projection];
}

- (NSUInteger)hash {
    IDBlockDocument *document = self.anchor.document;
    if (document == nil) return (NSUInteger)(__bridge void *)self;
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    NSUInteger offset = [self.anchor canonicalOffsetInProjection:projection];
    return document.hash ^ (offset * 31U);
}

@end

#endif
