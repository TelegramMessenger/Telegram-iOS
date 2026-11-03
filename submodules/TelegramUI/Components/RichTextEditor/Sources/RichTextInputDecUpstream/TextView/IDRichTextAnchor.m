#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextAnchor.h"
#import "IDRichTextAnchorInternal.h"

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

@interface IDBlockDocument (IDRichTextAnchorTracking)
- (void)id_registerRichTextAnchor:(IDRichTextAnchor *)anchor;
@end

@interface IDRichTextAnchor ()
@property(nonatomic, weak, readwrite) IDBlockDocument *document;
@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, readwrite) NSUInteger localOffset;
@property(nonatomic, readwrite) IDRichTextAnchorBias bias;
@end

@implementation IDRichTextAnchor

- (instancetype)initWithDocument:(IDBlockDocument *)document
                  blockIdentifier:(NSUUID *)blockIdentifier
                       localOffset:(NSUInteger)localOffset
                              bias:(IDRichTextAnchorBias)bias {
    return [self initWithDocument:document
                  blockIdentifier:blockIdentifier
                       localOffset:localOffset
                              bias:bias
                     tracksChanges:YES];
}

- (instancetype)initWithDocument:(IDBlockDocument *)document
                  blockIdentifier:(NSUUID *)blockIdentifier
                       localOffset:(NSUInteger)localOffset
                              bias:(IDRichTextAnchorBias)bias
                     tracksChanges:(BOOL)tracksChanges {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    NSUInteger canonicalOffset =
        [projection canonicalOffsetForBlockIdentifier:blockIdentifier localOffset:localOffset];

    self = [super init];
    if (self != nil) {
        _document = document;
        _blockIdentifier = [blockIdentifier copy];
        _localOffset = localOffset;
        _bias = bias;
        _id_tracksChanges = tracksChanges;
        _id_snapshotCanonicalOffset = canonicalOffset;
        if (tracksChanges) {
            [document id_registerRichTextAnchor:self];
        }
    }
    return self;
}

- (NSUInteger)canonicalOffsetInProjection:(IDCanonicalTextProjection *)projection {
    if (projection.document != self.document) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Anchor and projection must belong to the same document."];
    }
    if (!self.id_tracksChanges) {
        return [self id_snapshotCanonicalOffsetClampedToLength:projection.document.canonicalLength];
    }
    return [projection canonicalOffsetForBlockIdentifier:self.blockIdentifier
                                              localOffset:self.localOffset];
}

- (NSUInteger)id_snapshotCanonicalOffsetClampedToLength:(NSUInteger)canonicalLength {
    if (_id_snapshotCanonicalOffset > canonicalLength) {
        _id_snapshotCanonicalOffset = canonicalLength;
    }
    return _id_snapshotCanonicalOffset;
}

- (void)id_rebaseToCanonicalLocation:(IDCanonicalLocation *)location {
    self.blockIdentifier = location.blockIdentifier;
    self.localOffset = location.localOffset;
}

@end

#endif
