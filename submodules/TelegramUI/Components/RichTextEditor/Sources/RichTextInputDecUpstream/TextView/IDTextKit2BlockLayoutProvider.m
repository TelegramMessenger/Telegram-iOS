#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextKit2BlockLayoutProvider.h"

#import "IDBlockLayout.h"

#include <math.h>

static const IDBlockLayoutCapability IDTextKit2SliceOneCapabilities =
    IDBlockLayoutCapabilityCaretGeometry |
    IDBlockLayoutCapabilityPointHitTesting |
    IDBlockLayoutCapabilityLineRanges |
    IDBlockLayoutCapabilityVisualNavigation |
    IDBlockLayoutCapabilityBaseWritingDirection |
    IDBlockLayoutCapabilitySelectionSegments;

static IDBlockCaretNavigationResult IDBlockNavigationResultNotFound(
    IDBlockTextPosition position,
    CGFloat anchorPositionOffset) {
    return (IDBlockCaretNavigationResult){
        .found = NO,
        .position = position,
        .anchorPositionOffset = anchorPositionOffset,
    };
}

static BOOL IDBlockPointIsFinite(CGPoint point) {
    return isfinite(point.x) && isfinite(point.y);
}

static BOOL IDBlockRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static UITextStorageDirection IDTextKit2Affinity(
    IDBlockTextAffinity affinity) {
    switch (affinity) {
        case IDBlockTextAffinityUpstream:
            return UITextStorageDirectionBackward;
        case IDBlockTextAffinityDownstream:
            return UITextStorageDirectionForward;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"Invalid neutral block affinity: %ld", (long)affinity];
    return UITextStorageDirectionForward;
}

static IDBlockTextAffinity IDNeutralAffinity(
    UITextStorageDirection affinity) {
    switch (affinity) {
        case UITextStorageDirectionBackward:
            return IDBlockTextAffinityUpstream;
        case UITextStorageDirectionForward:
            return IDBlockTextAffinityDownstream;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"Invalid UIKit storage direction: %ld", (long)affinity];
    return IDBlockTextAffinityDownstream;
}

static UITextLayoutDirection IDTextKit2Direction(
    IDBlockLayoutDirection direction) {
    switch (direction) {
        case IDBlockLayoutDirectionLeft:
            return UITextLayoutDirectionLeft;
        case IDBlockLayoutDirectionRight:
            return UITextLayoutDirectionRight;
        case IDBlockLayoutDirectionUp:
            return UITextLayoutDirectionUp;
        case IDBlockLayoutDirectionDown:
            return UITextLayoutDirectionDown;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"Invalid neutral block layout direction: %ld",
                       (long)direction];
    return UITextLayoutDirectionRight;
}

@interface IDTextKit2BlockLayoutSnapshot : NSObject <IDBlockLayoutSnapshot>

@property(nonatomic, strong) IDBlockLayout *blockLayout;
@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, readwrite) NSUInteger utf16Length;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, readwrite) NSUInteger contentRevision;
@property(nonatomic, readwrite) NSUInteger layoutGeneration;
@property(nonatomic, readwrite) IDBlockLayoutConstraints layoutConstraints;
@property(nonatomic, readwrite) IDBlockLayoutCapability capabilities;
@property(nonatomic, readwrite) CGSize usedSize;

- (instancetype)initWithBlockLayout:(IDBlockLayout *)blockLayout
                   documentRevision:(NSUInteger)documentRevision;

@end

@implementation IDTextKit2BlockLayoutSnapshot

- (instancetype)initWithBlockLayout:(IDBlockLayout *)blockLayout
                   documentRevision:(NSUInteger)documentRevision {
    self = [super init];
    if (self != nil) {
        _blockLayout = blockLayout;
        _blockIdentifier = [blockLayout.blockIdentifier copy];
        _utf16Length = blockLayout.contentStorage.textStorage.length;
        _documentRevision = documentRevision;
        _contentRevision = blockLayout.contentRevision;
        _layoutGeneration = blockLayout.layoutGeneration;
        _layoutConstraints = IDBlockLayoutConstraintsMake(
            blockLayout.textContainer.size.width, 1.0);
        _capabilities = IDTextKit2SliceOneCapabilities;
        _usedSize = blockLayout.usedSize;
    }
    return self;
}

- (BOOL)isValid {
    return [self.blockLayout.blockIdentifier isEqual:self.blockIdentifier] &&
        self.blockLayout.layoutGeneration == self.layoutGeneration &&
        self.blockLayout.contentRevision == self.contentRevision &&
        self.blockLayout.contentStorage.textStorage.length == self.utf16Length;
}

- (IDBlockCaretGeometry *)caretGeometryForPosition:
    (IDBlockTextPosition)position {
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityCaretGeometry) ||
        position.utf16Offset > self.utf16Length) {
        return nil;
    }
    UITextStorageDirection affinity = IDTextKit2Affinity(position.affinity);
    CGRect rect = [self.blockLayout
        caretRectForLocalOffset:position.utf16Offset
                       affinity:affinity];
    if (!IDBlockRectIsFinite(rect)) {
        return nil;
    }
    NSRange lineRange = [self.blockLayout
        localLineRangeEnclosingOffset:position.utf16Offset
                    effectiveAffinity:&affinity];
    if (lineRange.location == NSNotFound) {
        return nil;
    }
    IDBlockWritingDirection writingDirection =
        [self.blockLayout baseWritingDirectionAtLocalOffset:
            position.utf16Offset] == NSWritingDirectionRightToLeft
            ? IDBlockWritingDirectionRightToLeft
            : IDBlockWritingDirectionLeftToRight;
    IDBlockLineIdentifier *line = [[IDBlockLineIdentifier alloc]
        initWithLocalRange:lineRange
          layoutGeneration:self.layoutGeneration];
    return [[IDBlockCaretGeometry alloc]
        initWithPosition:IDBlockTextPositionMake(position.utf16Offset,
                                                  IDNeutralAffinity(affinity))
                    rect:rect
        writingDirection:writingDirection
          lineIdentifier:line];
}

- (IDBlockCaretNavigationResult)caretNavigationResultForPoint:(CGPoint)point {
    IDBlockTextPosition fallback =
        IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream);
    if (!IDBlockPointIsFinite(point) || !self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityPointHitTesting)) {
        return IDBlockNavigationResultNotFound(fallback, 0);
    }
    IDBlockCaretStop stop = [self.blockLayout caretStopForPoint:point];
    if (!stop.found || stop.localOffset > self.utf16Length ||
        !isfinite(stop.anchorPositionOffset)) {
        return IDBlockNavigationResultNotFound(fallback, 0);
    }
    return (IDBlockCaretNavigationResult){
        .found = YES,
        .position = IDBlockTextPositionMake(
            stop.localOffset, IDNeutralAffinity(stop.affinity)),
        .anchorPositionOffset = stop.anchorPositionOffset,
    };
}

- (NSRange)lineRangeEnclosingPosition:(IDBlockTextPosition)position
                     resolvedAffinity:(IDBlockTextAffinity *)affinity {
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityLineRanges) ||
        position.utf16Offset > self.utf16Length) {
        return NSMakeRange(NSNotFound, 0);
    }
    UITextStorageDirection resolved = IDTextKit2Affinity(position.affinity);
    NSRange range = [self.blockLayout
        localLineRangeEnclosingOffset:position.utf16Offset
                    effectiveAffinity:&resolved];
    if (range.location != NSNotFound && affinity != NULL) {
        *affinity = IDNeutralAffinity(resolved);
    }
    return range;
}

- (IDBlockWritingDirection)id_snapshotBaseWritingDirectionAtPosition:
    (IDBlockTextPosition)position {
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityBaseWritingDirection) ||
        position.utf16Offset > self.utf16Length) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Invalid base-writing-direction snapshot query"];
    }
    return [self.blockLayout
        baseWritingDirectionAtLocalOffset:position.utf16Offset] ==
            NSWritingDirectionRightToLeft
        ? IDBlockWritingDirectionRightToLeft
        : IDBlockWritingDirectionLeftToRight;
}

- (IDBlockCaretNavigationResult)caretNavigationResultFromPosition:
    (IDBlockTextPosition)position
                                                    direction:
    (IDBlockLayoutDirection)direction
                                         anchorPositionOffset:
    (CGFloat)anchorPositionOffset {
    UITextLayoutDirection textKitDirection = IDTextKit2Direction(direction);
    if (!isfinite(anchorPositionOffset) || !self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityVisualNavigation) ||
        position.utf16Offset > self.utf16Length) {
        return IDBlockNavigationResultNotFound(position, anchorPositionOffset);
    }
    UITextStorageDirection affinity = IDTextKit2Affinity(position.affinity);
    IDBlockCaretStop stop = [self.blockLayout
        caretStopFromLocalOffset:position.utf16Offset
                         affinity:affinity
                        direction:textKitDirection
             anchorPositionOffset:anchorPositionOffset];
    if (!stop.found || stop.localOffset > self.utf16Length ||
        !isfinite(stop.anchorPositionOffset)) {
        return IDBlockNavigationResultNotFound(position, anchorPositionOffset);
    }
    return (IDBlockCaretNavigationResult){
        .found = YES,
        .position = IDBlockTextPositionMake(
            stop.localOffset, IDNeutralAffinity(stop.affinity)),
        .anchorPositionOffset = stop.anchorPositionOffset,
    };
}

- (NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                            extendHead:
    (BOOL)extendHead
                                                            extendTail:
    (BOOL)extendTail {
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilitySelectionSegments) ||
        range.location == NSNotFound || range.location > self.utf16Length ||
        range.length > self.utf16Length - range.location) {
        return nil;
    }
    NSArray<IDBlockSelectionSegment *> *segments = [self.blockLayout
        selectionSegmentsForLocalRange:range
                            extendHead:extendHead
                            extendTail:extendTail];
    if (segments == nil || !self.valid) return nil;
    for (IDBlockSelectionSegment *segment in segments) {
        if (segment.layoutGeneration != self.layoutGeneration ||
            segment.localRange.location > self.utf16Length ||
            segment.localRange.length >
                self.utf16Length - segment.localRange.location) {
            return nil;
        }
    }
    return segments;
}

@end

@interface IDTextKit2BlockLayoutProvider ()

@property(nonatomic, strong) IDBlockLayout *blockLayout;

@end

@implementation IDTextKit2BlockLayoutProvider

- (instancetype)initWithBlockLayout:(IDBlockLayout *)blockLayout {
    if (blockLayout == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"TextKit 2 block layout provider requires a layout."];
    }
    self = [super init];
    if (self != nil) {
        _blockLayout = blockLayout;
    }
    return self;
}

- (NSUUID *)blockIdentifier {
    return self.blockLayout.blockIdentifier;
}

- (id<IDBlockLayoutSnapshot>)snapshotForDocumentRevision:
    (NSUInteger)documentRevision {
    return [[IDTextKit2BlockLayoutSnapshot alloc]
        initWithBlockLayout:self.blockLayout
           documentRevision:documentRevision];
}

@end

#endif
