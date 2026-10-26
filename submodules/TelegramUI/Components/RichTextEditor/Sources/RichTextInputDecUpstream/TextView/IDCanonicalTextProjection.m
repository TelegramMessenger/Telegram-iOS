#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDCanonicalTextProjection.h"

@interface IDCanonicalLocation ()
@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, readwrite) NSUInteger localOffset;
@property(nonatomic, readwrite) IDCanonicalBoundarySide boundarySide;

- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                             localOffset:(NSUInteger)localOffset
                            boundarySide:(IDCanonicalBoundarySide)boundarySide;
@end

@interface IDCanonicalTextProjection ()
@property(nonatomic, weak, readwrite) IDBlockDocument *document;
/// `attributedString`'s cache and the `blocks` array it was built from (retained, so its pointer
/// cannot be reused by a later array while the cache is held).
@property(nonatomic, strong) NSArray<IDBlock *> *cachedBlocks;
@property(nonatomic, copy) NSAttributedString *cachedAttributedString;
@end

@implementation IDCanonicalLocation

- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                             localOffset:(NSUInteger)localOffset
                            boundarySide:(IDCanonicalBoundarySide)boundarySide {
    self = [super init];
    if (self != nil) {
        _blockIdentifier = [blockIdentifier copy];
        _localOffset = localOffset;
        _boundarySide = boundarySide;
    }
    return self;
}

@end

@implementation IDCanonicalTextProjection

- (instancetype)initWithDocument:(IDBlockDocument *)document {
    if (document == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDCanonicalTextProjection requires a document."];
    }
    self = [super init];
    if (self != nil) {
        _document = document;
    }
    return self;
}

/// Built once per `blocks` array, not once per call. The document replaces that (immutable)
/// array on every mutation, so its identity is the revision. `NSTextStorage`'s attribute fixing
/// reads the adapter's `attributesAtIndex:` once per attribute run, and every read rebuilt the whole
/// document here: O(n²) in the document length on a long paste (composer harness, 2026-09-23,
/// `HarnessLargeRichPasteScalingTests`).
- (NSAttributedString *)attributedString {
    NSArray<IDBlock *> *blocks = self.document.blocks;
    if (self.cachedAttributedString != nil && blocks == self.cachedBlocks) {
        return self.cachedAttributedString;
    }
    NSAttributedString *built = [self id_buildAttributedStringFromBlocks:blocks];
    self.cachedBlocks = blocks;
    self.cachedAttributedString = built;
    return built;
}

- (NSAttributedString *)id_buildAttributedStringFromBlocks:(NSArray<IDBlock *> *)blocks {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@""];
    [blocks enumerateObjectsUsingBlock:^(IDBlock *block, NSUInteger index, BOOL *stop) {
        [result appendAttributedString:block.attributedText];
        if (index + 1 < blocks.count) {
            [result appendAttributedString:[[NSAttributedString alloc]
                initWithString:@"\n"
                    attributes:block.separatorAttributes]];
        }
    }];
    return [result copy];
}

- (NSString *)string {
    return self.attributedString.string;
}

- (nullable IDCanonicalLocation *)locationForCanonicalOffset:(NSUInteger)offset {
    IDBlockDocument *document = self.document;
    if (document == nil || offset > document.canonicalLength) {
        return nil;
    }

    NSUInteger cursor = 0;
    for (NSUInteger index = 0; index < document.blocks.count; index += 1) {
        IDBlock *block = document.blocks[index];
        if (index > 0 && offset == cursor) {
            return [[IDCanonicalLocation alloc]
                initWithBlockIdentifier:block.identifier
                             localOffset:0
                            boundarySide:IDCanonicalBoundarySideAfterSeparator];
        }

        NSUInteger blockEnd = cursor + block.attributedText.length;
        if (offset < blockEnd) {
            return [[IDCanonicalLocation alloc]
                initWithBlockIdentifier:block.identifier
                             localOffset:offset - cursor
                            boundarySide:IDCanonicalBoundarySideText];
        }
        if (offset == blockEnd) {
            IDCanonicalBoundarySide side = index + 1 < document.blocks.count
                ? IDCanonicalBoundarySideBeforeSeparator
                : IDCanonicalBoundarySideText;
            return [[IDCanonicalLocation alloc]
                initWithBlockIdentifier:block.identifier
                             localOffset:block.attributedText.length
                            boundarySide:side];
        }
        cursor = blockEnd + 1;
    }
    return nil;
}

- (NSUInteger)canonicalOffsetForBlockIdentifier:(NSUUID *)identifier
                                     localOffset:(NSUInteger)localOffset {
    NSUInteger cursor = 0;
    for (IDBlock *block in self.document.blocks) {
        if ([block.identifier isEqual:identifier]) {
            if (localOffset > block.attributedText.length) {
                [NSException raise:NSRangeException
                            format:@"Local offset %lu exceeds block length %lu",
                                   (unsigned long)localOffset,
                                   (unsigned long)block.attributedText.length];
            }
            return cursor + localOffset;
        }
        cursor += block.attributedText.length + 1;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"Unknown block identifier %@", identifier];
    return NSNotFound;
}

@end

#endif
