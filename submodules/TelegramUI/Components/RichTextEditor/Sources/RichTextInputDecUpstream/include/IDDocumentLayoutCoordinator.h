#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "IDBlockLayoutSnapshot.h"

@class IDBlockDocument;

NS_ASSUME_NONNULL_BEGIN

@interface IDDocumentGeometryEligibilitySnapshot : NSObject

@property(nonatomic, readonly) NSUInteger geometryGeneration;
@property(nonatomic, copy, readonly) NSArray<NSUUID *> *orderedBlockIdentifiers;

- (instancetype)initWithGeometryGeneration:(NSUInteger)geometryGeneration
                    orderedBlockIdentifiers:(NSArray<NSUUID *> *)identifiers
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@protocol IDDocumentLayoutSnapshotSource <NSObject>

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision;
- (NSArray<NSUUID *> *)orderedBlockIdentifiers;
- (nullable id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:
    (NSUUID *)identifier
                                                   documentRevision:
    (NSUInteger)documentRevision;
- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier;
- (nullable NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point;
@optional
/// See `IDBlockStackCanvasView.selectionSlotForBlockIdentifier:` — the box a covered block's
/// selection fills, its reserved space included.
///
/// OPTIONAL, like the neighbour query below and for the same reason: a source that does not answer
/// is not broken, it just has nothing to say. The coordinator then grows no segment beyond its own
/// glyphs, which is what every source did before slots existed. Making it required instead sent
/// `selectionSlotForBlockIdentifier:` to conformers that had never heard of it and crashed them —
/// invisibly in production, where the block stack is the only conformer, and loudly in seven of the
/// engine's own tests (2026-09-15).
- (CGRect)selectionSlotForBlockIdentifier:(NSUUID *)identifier;

/// See `IDBlockStackCanvasView.selectionBoxForBlockIdentifier:` — the part of that slot which is the
/// block rather than the space around it. Optional on the same terms; not answering, like answering
/// `CGRectNull`, means the block has no box of its own and all of its reserved space is rhythm.
- (CGRect)selectionBoxForBlockIdentifier:(NSUUID *)identifier;

/// The block the caret enters when it leaves `identifier` vertically at document x
/// `anchorPositionOffset`. A source that places blocks side by side answers by geometry; the
/// coordinator falls back to the adjacent block in document order when this is not implemented.
- (nullable NSUUID *)verticallyAdjacentBlockIdentifierFromBlockIdentifier:(NSUUID *)identifier
                                                                  downward:(BOOL)downward
                                                      anchorPositionOffset:(CGFloat)anchorPositionOffset;

@end

@interface IDDocumentTextPosition : NSObject

@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, readonly) IDBlockTextPosition localPosition;
@property(nonatomic, readonly) NSUInteger canonicalOffset;
@property(nonatomic, readonly) NSUInteger documentRevision;

@end


@interface IDDocumentCaretGeometry : NSObject

@property(nonatomic, strong, readonly) IDDocumentTextPosition *position;
@property(nonatomic, readonly) CGRect documentRect;
@property(nonatomic, copy, nullable, readonly)
    IDBlockLineIdentifier *lineIdentifier;
@property(nonatomic, readonly, getter=isExact) BOOL exact;

@end

@interface IDDocumentLineGeometry : NSObject

@property(nonatomic, strong, readonly) IDDocumentTextPosition *position;
@property(nonatomic, readonly) NSRange canonicalRange;
@property(nonatomic, readonly) IDBlockTextAffinity resolvedAffinity;
@property(nonatomic, readonly, getter=isExact) BOOL exact;

@end

@interface IDDocumentCaretNavigationResult : NSObject

@property(nonatomic, strong, readonly) IDDocumentTextPosition *position;
@property(nonatomic, readonly) CGFloat anchorPositionOffset;
@property(nonatomic, readonly, getter=isExact) BOOL exact;

@end

@interface IDDocumentSelectionSegment : NSObject

@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, readonly) NSRange canonicalRange;
@property(nonatomic, readonly) IDBlockSelectionBoundaryRole boundaryRole;
@property(nonatomic, readonly) CGRect documentRect;
/// The line's baseline, measured down from `documentRect`'s top edge; 0 when unknown.
@property(nonatomic, readonly) CGFloat baselineOffset;
@property(nonatomic, readonly) IDBlockWritingDirection writingDirection;
@property(nonatomic, readonly, getter=isVertical) BOOL vertical;
@property(nonatomic, readonly) BOOL containsLogicalStart;
@property(nonatomic, readonly) BOOL containsLogicalEnd;

@end

@interface IDDocumentSelectionGeometry : NSObject

@property(nonatomic, readonly) NSRange canonicalSelection;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, readonly) NSUInteger sourceGeometryGeneration;
@property(nonatomic, copy, readonly) NSArray<IDDocumentSelectionSegment *> *segments;
@property(nonatomic, readonly, getter=isExact) BOOL exact;

@end

@interface IDDocumentLayoutCoordinator : NSObject

@property(nonatomic, strong, readonly) IDBlockDocument *document;
@property(nonatomic, weak, nullable, readonly)
    id<IDDocumentLayoutSnapshotSource> source;

- (instancetype)initWithDocument:(IDBlockDocument *)document
                            source:(id<IDDocumentLayoutSnapshotSource>)source
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable IDDocumentCaretGeometry *)caretGeometryForCanonicalOffset:
    (NSUInteger)offset
                                                               affinity:
    (IDBlockTextAffinity)affinity;
- (nullable IDDocumentTextPosition *)nearestPositionToDocumentPoint:
    (CGPoint)point;
- (nullable IDDocumentLineGeometry *)lineGeometryForCanonicalOffset:
    (NSUInteger)offset
                                                             affinity:
    (IDBlockTextAffinity)affinity;
- (nullable IDDocumentCaretNavigationResult *)
    visuallyAdjacentPositionFromCanonicalOffset:(NSUInteger)offset
                                        affinity:(IDBlockTextAffinity)affinity
                                       direction:(IDBlockLayoutDirection)direction
                            anchorPositionOffset:(CGFloat)anchorPositionOffset;
- (nullable IDDocumentSelectionGeometry *)selectionGeometryForCanonicalRange:
    (NSRange)range;

@end

NS_ASSUME_NONNULL_END

#endif
