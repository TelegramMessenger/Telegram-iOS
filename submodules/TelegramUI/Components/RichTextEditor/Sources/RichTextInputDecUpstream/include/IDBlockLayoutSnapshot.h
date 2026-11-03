#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDBlockTextAffinity) {
    IDBlockTextAffinityUpstream,
    IDBlockTextAffinityDownstream,
};

typedef NS_ENUM(NSInteger, IDBlockLayoutDirection) {
    IDBlockLayoutDirectionLeft,
    IDBlockLayoutDirectionRight,
    IDBlockLayoutDirectionUp,
    IDBlockLayoutDirectionDown,
};

typedef NS_ENUM(NSInteger, IDBlockWritingDirection) {
    IDBlockWritingDirectionLeftToRight,
    IDBlockWritingDirectionRightToLeft,
};

typedef NS_OPTIONS(NSUInteger, IDBlockSelectionBoundaryRole) {
    IDBlockSelectionBoundaryRoleNone = 0,
    IDBlockSelectionBoundaryRoleHead = 1 << 0,
    IDBlockSelectionBoundaryRoleTail = 1 << 1,
};

typedef NS_OPTIONS(NSUInteger, IDBlockLayoutCapability) {
    IDBlockLayoutCapabilityCaretGeometry = 1 << 0,
    IDBlockLayoutCapabilityPointHitTesting = 1 << 1,
    IDBlockLayoutCapabilityLineRanges = 1 << 2,
    IDBlockLayoutCapabilityVisualNavigation = 1 << 3,
    IDBlockLayoutCapabilityBaseWritingDirection = 1 << 4,
    IDBlockLayoutCapabilitySelectionSegments = 1 << 5,
};

typedef struct {
    CGFloat containerWidth;
    CGFloat layoutScale;
} IDBlockLayoutConstraints;

typedef struct {
    NSUInteger utf16Offset;
    IDBlockTextAffinity affinity;
} IDBlockTextPosition;

typedef struct {
    IDBlockTextPosition start;
    IDBlockTextPosition end;
} IDBlockTextRange;

FOUNDATION_EXPORT IDBlockTextPosition IDBlockTextPositionMake(
    NSUInteger utf16Offset,
    IDBlockTextAffinity affinity);
FOUNDATION_EXPORT BOOL IDBlockTextPositionEqual(
    IDBlockTextPosition first,
    IDBlockTextPosition second);
FOUNDATION_EXPORT IDBlockTextRange IDBlockTextRangeMake(
    IDBlockTextPosition start,
    IDBlockTextPosition end);
FOUNDATION_EXPORT IDBlockLayoutConstraints IDBlockLayoutConstraintsMake(
    CGFloat containerWidth,
    CGFloat layoutScale);
FOUNDATION_EXPORT BOOL IDBlockLayoutConstraintsEqual(
    IDBlockLayoutConstraints first,
    IDBlockLayoutConstraints second);

@interface IDBlockLineIdentifier : NSObject <NSCopying>

@property(nonatomic, readonly) NSRange localRange;
@property(nonatomic, readonly) NSUInteger layoutGeneration;

- (instancetype)initWithLocalRange:(NSRange)localRange
                  layoutGeneration:(NSUInteger)layoutGeneration
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface IDBlockSelectionSegment : NSObject

@property(nonatomic, readonly) NSRange localRange;
@property(nonatomic, readonly) CGRect rect;
/// The line's baseline, measured down from the rect's top edge; 0 when unknown.
@property(nonatomic, readonly) CGFloat baselineOffset;
@property(nonatomic, readonly) IDBlockSelectionBoundaryRole boundaryRole;
@property(nonatomic, readonly) BOOL containsLocalStart;
@property(nonatomic, readonly) BOOL containsLocalEnd;
@property(nonatomic, readonly) IDBlockWritingDirection writingDirection;
@property(nonatomic, readonly, getter=isVertical) BOOL vertical;
@property(nonatomic, readonly) NSUInteger layoutGeneration;

- (instancetype)initWithLocalRange:(NSRange)localRange
                               rect:(CGRect)rect
                     baselineOffset:(CGFloat)baselineOffset
                       boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                 containsLocalStart:(BOOL)containsLocalStart
                   containsLocalEnd:(BOOL)containsLocalEnd
                   writingDirection:(IDBlockWritingDirection)writingDirection
                           vertical:(BOOL)vertical
                   layoutGeneration:(NSUInteger)layoutGeneration
    NS_DESIGNATED_INITIALIZER;
/// A segment whose baseline is unknown (`baselineOffset` 0).
- (instancetype)initWithLocalRange:(NSRange)localRange
                               rect:(CGRect)rect
                       boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                 containsLocalStart:(BOOL)containsLocalStart
                   containsLocalEnd:(BOOL)containsLocalEnd
                   writingDirection:(IDBlockWritingDirection)writingDirection
                           vertical:(BOOL)vertical
                   layoutGeneration:(NSUInteger)layoutGeneration;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface IDBlockCaretGeometry : NSObject

@property(nonatomic, readonly) IDBlockTextPosition position;
@property(nonatomic, readonly) CGRect rect;
@property(nonatomic, readonly) IDBlockWritingDirection writingDirection;
@property(nonatomic, copy, readonly) IDBlockLineIdentifier *lineIdentifier;

- (instancetype)initWithPosition:(IDBlockTextPosition)position
                             rect:(CGRect)rect
                 writingDirection:(IDBlockWritingDirection)writingDirection
                   lineIdentifier:(IDBlockLineIdentifier *)lineIdentifier
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


typedef struct {
    BOOL found;
    IDBlockTextPosition position;
    CGFloat anchorPositionOffset;
} IDBlockCaretNavigationResult;

@protocol IDBlockLayoutSnapshot <NSObject>

@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;
@property(nonatomic, readonly) NSUInteger utf16Length;
@property(nonatomic, readonly) NSUInteger documentRevision;
@property(nonatomic, readonly) NSUInteger contentRevision;
@property(nonatomic, readonly) NSUInteger layoutGeneration;
@property(nonatomic, readonly) IDBlockLayoutConstraints layoutConstraints;
@property(nonatomic, readonly) IDBlockLayoutCapability capabilities;
@property(nonatomic, readonly, getter=isValid) BOOL valid;
@property(nonatomic, readonly) CGSize usedSize;

- (nullable IDBlockCaretGeometry *)caretGeometryForPosition:
    (IDBlockTextPosition)position;
- (IDBlockCaretNavigationResult)caretNavigationResultForPoint:(CGPoint)point;
- (NSRange)lineRangeEnclosingPosition:(IDBlockTextPosition)position
                     resolvedAffinity:(nullable IDBlockTextAffinity *)affinity;
- (IDBlockWritingDirection)id_snapshotBaseWritingDirectionAtPosition:
    (IDBlockTextPosition)position;
- (IDBlockCaretNavigationResult)caretNavigationResultFromPosition:
    (IDBlockTextPosition)position
                                                    direction:
    (IDBlockLayoutDirection)direction
                                         anchorPositionOffset:
    (CGFloat)anchorPositionOffset;
- (nullable NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                                      extendHead:
    (BOOL)extendHead
                                                                      extendTail:
    (BOOL)extendTail;

@end

@protocol IDBlockLayoutProvider <NSObject>

@property(nonatomic, copy, readonly) NSUUID *blockIdentifier;

- (id<IDBlockLayoutSnapshot>)snapshotForDocumentRevision:
    (NSUInteger)documentRevision;

@end

NS_ASSUME_NONNULL_END

#endif
