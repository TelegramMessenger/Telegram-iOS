#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockLayoutSnapshot.h"

#include <math.h>

static BOOL IDBlockTextAffinityIsValid(IDBlockTextAffinity affinity) {
    return affinity == IDBlockTextAffinityUpstream ||
        affinity == IDBlockTextAffinityDownstream;
}

static BOOL IDBlockWritingDirectionIsValid(
    IDBlockWritingDirection writingDirection) {
    return writingDirection == IDBlockWritingDirectionLeftToRight ||
        writingDirection == IDBlockWritingDirectionRightToLeft;
}

static void IDRequireValidPosition(IDBlockTextPosition position) {
    if (!IDBlockTextAffinityIsValid(position.affinity)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block text affinity: %ld",
                           (long)position.affinity];
    }
}

static BOOL IDRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

IDBlockTextPosition IDBlockTextPositionMake(
    NSUInteger utf16Offset,
    IDBlockTextAffinity affinity) {
    IDBlockTextPosition position = {
        .utf16Offset = utf16Offset,
        .affinity = affinity,
    };
    IDRequireValidPosition(position);
    return position;
}

BOOL IDBlockTextPositionEqual(
    IDBlockTextPosition first,
    IDBlockTextPosition second) {
    return first.utf16Offset == second.utf16Offset &&
        first.affinity == second.affinity;
}

IDBlockTextRange IDBlockTextRangeMake(
    IDBlockTextPosition start,
    IDBlockTextPosition end) {
    IDRequireValidPosition(start);
    IDRequireValidPosition(end);
    if (end.utf16Offset < start.utf16Offset) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Block text range end %lu precedes start %lu",
                           (unsigned long)end.utf16Offset,
                           (unsigned long)start.utf16Offset];
    }
    return (IDBlockTextRange){.start = start, .end = end};
}

IDBlockLayoutConstraints IDBlockLayoutConstraintsMake(
    CGFloat containerWidth,
    CGFloat layoutScale) {
    if (!isfinite(containerWidth) || containerWidth < 0 ||
        !isfinite(layoutScale) || layoutScale <= 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block layout constraints: width=%g scale=%g",
                           containerWidth,
                           layoutScale];
    }
    return (IDBlockLayoutConstraints){
        .containerWidth = containerWidth,
        .layoutScale = layoutScale,
    };
}

BOOL IDBlockLayoutConstraintsEqual(
    IDBlockLayoutConstraints first,
    IDBlockLayoutConstraints second) {
    return first.containerWidth == second.containerWidth &&
        first.layoutScale == second.layoutScale;
}

@implementation IDBlockLineIdentifier

- (instancetype)initWithLocalRange:(NSRange)localRange
                  layoutGeneration:(NSUInteger)layoutGeneration {
    if (localRange.location == NSNotFound) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Block line range cannot start at NSNotFound."];
    }
    self = [super init];
    if (self != nil) {
        _localRange = localRange;
        _layoutGeneration = layoutGeneration;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:IDBlockLineIdentifier.class]) {
        return NO;
    }
    IDBlockLineIdentifier *other = object;
    return NSEqualRanges(self.localRange, other.localRange) &&
        self.layoutGeneration == other.layoutGeneration;
}

- (NSUInteger)hash {
    return self.localRange.location ^ (self.localRange.length << 1) ^
        (self.layoutGeneration << 2);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p range=%@ generation=%lu>",
            NSStringFromClass(self.class),
            self,
            NSStringFromRange(self.localRange),
            (unsigned long)self.layoutGeneration];
}

@end

@implementation IDBlockSelectionSegment

- (instancetype)initWithLocalRange:(NSRange)localRange
                               rect:(CGRect)rect
                       boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                 containsLocalStart:(BOOL)containsLocalStart
                   containsLocalEnd:(BOOL)containsLocalEnd
                   writingDirection:(IDBlockWritingDirection)writingDirection
                           vertical:(BOOL)vertical
                   layoutGeneration:(NSUInteger)layoutGeneration {
    return [self initWithLocalRange:localRange
                               rect:rect
                     baselineOffset:0.0
                       boundaryRole:boundaryRole
                 containsLocalStart:containsLocalStart
                   containsLocalEnd:containsLocalEnd
                   writingDirection:writingDirection
                           vertical:vertical
                   layoutGeneration:layoutGeneration];
}

- (instancetype)initWithLocalRange:(NSRange)localRange
                               rect:(CGRect)rect
                     baselineOffset:(CGFloat)baselineOffset
                       boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                 containsLocalStart:(BOOL)containsLocalStart
                   containsLocalEnd:(BOOL)containsLocalEnd
                   writingDirection:(IDBlockWritingDirection)writingDirection
                           vertical:(BOOL)vertical
                   layoutGeneration:(NSUInteger)layoutGeneration {
    if (!isfinite(baselineOffset)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Block selection baseline must be finite: %g", baselineOffset];
    }
    if (localRange.location == NSNotFound ||
        localRange.length > NSUIntegerMax - localRange.location) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block selection range: %@",
                           NSStringFromRange(localRange)];
    }
    if (!IDRectIsFinite(rect) || CGRectIsNull(rect) ||
        CGRectIsInfinite(rect) || CGRectIsEmpty(rect)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Block selection geometry must be finite and nonempty"];
    }
    IDBlockSelectionBoundaryRole knownRoles =
        IDBlockSelectionBoundaryRoleHead | IDBlockSelectionBoundaryRoleTail;
    if ((boundaryRole & ~knownRoles) != 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block selection boundary role: %lu",
                           (unsigned long)boundaryRole];
    }
    if (!IDBlockWritingDirectionIsValid(writingDirection)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block selection writing direction: %ld",
                           (long)writingDirection];
    }
    if (layoutGeneration == 0) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Block selection layout generation must be nonzero"];
    }
    self = [super init];
    if (self != nil) {
        _localRange = localRange;
        _rect = rect;
        _baselineOffset = baselineOffset;
        _boundaryRole = boundaryRole;
        _containsLocalStart = containsLocalStart;
        _containsLocalEnd = containsLocalEnd;
        _writingDirection = writingDirection;
        _vertical = vertical;
        _layoutGeneration = layoutGeneration;
    }
    return self;
}

@end

@implementation IDBlockCaretGeometry

- (instancetype)initWithPosition:(IDBlockTextPosition)position
                             rect:(CGRect)rect
                 writingDirection:(IDBlockWritingDirection)writingDirection
                   lineIdentifier:(IDBlockLineIdentifier *)lineIdentifier {
    IDRequireValidPosition(position);
    if (!IDRectIsFinite(rect)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Caret geometry must be finite: {%g,%g,%g,%g}",
                           rect.origin.x,
                           rect.origin.y,
                           rect.size.width,
                           rect.size.height];
    }
    if (!IDBlockWritingDirectionIsValid(writingDirection)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid block writing direction: %ld",
                           (long)writingDirection];
    }
    if (lineIdentifier == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Caret geometry requires a line identifier."];
    }
    self = [super init];
    if (self != nil) {
        _position = position;
        _rect = rect;
        _writingDirection = writingDirection;
        _lineIdentifier = [lineIdentifier copy];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:
        @"<%@: %p offset=%lu affinity=%ld rect={%g,%g,%g,%g} direction=%ld line=%@>",
        NSStringFromClass(self.class),
        self,
        (unsigned long)self.position.utf16Offset,
        (long)self.position.affinity,
        self.rect.origin.x,
        self.rect.origin.y,
        self.rect.size.width,
        self.rect.size.height,
        (long)self.writingDirection,
        self.lineIdentifier];
}

@end

#endif
