#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "TGPrivateMethodAliases.h"
#import "IDRichTextLayoutController.h"

#import "IDRichTextLayoutControllerInternal.h"
#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockStackCanvasViewInternal.h"
#import "IDCanonicalTextProjection.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDDocumentLayoutCoordinator.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDRichTextAnnotationStore.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextAnchorInternal.h"
#import "IDRichTextPosition.h"
#import "IDRichTextRange.h"
#import "IDRichTextRangeInternal.h"
#import "IDRichTextSelectionRect.h"
#import "IDTextLayoutCanvasView.h"

#include <math.h>

@interface IDRichTextAnnotationStore (IDTemporaryAttributeReplay)
- (void)enumerateAttributesInCanonicalRange:(NSRange)range
                                  usingBlock:(void (NS_NOESCAPE ^)(
                                      id<NSCopying> attribute,
                                      id value,
                                      NSRange canonicalRange))block;
@end

@interface IDBlockLayout (IDSelectionCanvasHost)
- (nullable id)id_canvasHost;
@end

@interface IDRichTextInputControllerConnection : NSObject
@property(nonatomic, strong, nullable) id id_textInputController;
@end

@implementation IDRichTextInputControllerConnection

// UIKit reads the controller through this object by name (`-[_UITextLayoutControllerBase
// textInputController]`, reached from `_UIKeyboardStateManager`): the property is compiled under a
// neutral name and its accessors are added under the private ones (`TGPrivateMethodAliases.h`).
+ (void)initialize {
    if (self != IDRichTextInputControllerConnection.class) {
        return;
    }
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textInputController, @selector(id_textInputController) },
        { TGPN_setTextInputController_, @selector(setId_textInputController:) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

@end

@interface IDRichTextLayoutController ()

@property(nonatomic, strong, readwrite) IDBlockDocument *document;
@property(nonatomic, strong, readwrite) IDCanonicalTextStorageAdapter *textStorageAdapter;
@property(nonatomic, strong, readwrite) IDBlockStackCanvasView *id_blockStack;
@property(nonatomic, strong) IDRichTextAnnotationStore *annotationStore;
@property(nonatomic) NSUInteger id_boundingRectForCharacterRangeCallCountState;
- (NSRange)id_projectedCanonicalRangeForTextRange:(UITextRange *)range
                                           clipped:(BOOL)clipped
                                             stage:(NSString *)stage;

@end

@implementation IDRichTextLayoutController

+ (void)initialize {
    if (self == IDRichTextLayoutController.class) {
        IDRichTextLayoutControllerInstallPrivateCallbacks(self);
    }
}

static void IDRichRaise(NSString *stage, NSString *detail) {
    NSString *reason = [NSString stringWithFormat:@"IDRichTextLayoutController %@ failed: %@",
                                               stage,
                                               detail];
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:reason
                                 userInfo:nil];
}

static BOOL IDRichRangeIsValid(NSRange range, NSUInteger length) {
    return range.location != NSNotFound &&
        range.location <= length &&
        range.length <= length - range.location;
}

static BOOL IDRichRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static BOOL IDRichNeutralAffinity(UITextStorageDirection affinity,
                                  IDBlockTextAffinity *result) {
    if (affinity == UITextStorageDirectionBackward) {
        if (result != NULL) *result = IDBlockTextAffinityUpstream;
        return YES;
    }
    if (affinity == UITextStorageDirectionForward) {
        if (result != NULL) *result = IDBlockTextAffinityDownstream;
        return YES;
    }
    return NO;
}

static BOOL IDRichNeutralDirection(UITextLayoutDirection direction,
                                   IDBlockLayoutDirection *result) {
    switch (direction) {
        case UITextLayoutDirectionLeft:
            if (result != NULL) *result = IDBlockLayoutDirectionLeft;
            return YES;
        case UITextLayoutDirectionRight:
            if (result != NULL) *result = IDBlockLayoutDirectionRight;
            return YES;
        case UITextLayoutDirectionUp:
            if (result != NULL) *result = IDBlockLayoutDirectionUp;
            return YES;
        case UITextLayoutDirectionDown:
            if (result != NULL) *result = IDBlockLayoutDirectionDown;
            return YES;
    }
    return NO;
}

static BOOL IDRichUIKitAffinity(IDBlockTextAffinity affinity,
                                UITextStorageDirection *result) {
    if (affinity == IDBlockTextAffinityUpstream) {
        if (result != NULL) *result = UITextStorageDirectionBackward;
        return YES;
    }
    if (affinity == IDBlockTextAffinityDownstream) {
        if (result != NULL) *result = UITextStorageDirectionForward;
        return YES;
    }
    return NO;
}

static BOOL IDRichEffectiveDirection(UITextLayoutDirection direction,
                                     NSInteger signedOffset,
                                     UITextLayoutDirection *result) {
    IDBlockLayoutDirection ignored;
    if (!IDRichNeutralDirection(direction, &ignored)) return NO;
    UITextLayoutDirection effective = direction;
    if (signedOffset < 0) {
        if (direction == UITextLayoutDirectionLeft) {
            effective = UITextLayoutDirectionRight;
        } else if (direction == UITextLayoutDirectionRight) {
            effective = UITextLayoutDirectionLeft;
        } else if (direction == UITextLayoutDirectionUp) {
            effective = UITextLayoutDirectionDown;
        } else {
            effective = UITextLayoutDirectionUp;
        }
    }
    if (result != NULL) *result = effective;
    return YES;
}

static BOOL IDRichNavigationResultIsValid(
    IDDocumentCaretNavigationResult *neutral,
    IDBlockDocument *document,
    BOOL vertical,
    CGFloat requiredVerticalAnchor) {
    if (neutral == nil || !neutral.exact || neutral.position == nil ||
        neutral.position.documentRevision != document.documentRevision ||
        neutral.position.canonicalOffset > document.canonicalLength ||
        !isfinite(neutral.anchorPositionOffset) ||
        (vertical &&
         fabs(neutral.anchorPositionOffset - requiredVerticalAnchor) > 0.001)) {
        return NO;
    }
    UITextStorageDirection ignored;
    if (!IDRichUIKitAffinity(neutral.position.localPosition.affinity, &ignored)) {
        return NO;
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *location = [projection
        locationForCanonicalOffset:neutral.position.canonicalOffset];
    return location != nil &&
        [location.blockIdentifier isEqual:neutral.position.blockIdentifier] &&
        location.localOffset == neutral.position.localPosition.utf16Offset;
}

static BOOL IDRichDocumentPositionIsValid(
    IDDocumentTextPosition *position,
    IDBlockDocument *document,
    NSUInteger requestedOffset,
    BOOL requiresRequestedOffset) {
    if (position == nil ||
        position.documentRevision != document.documentRevision ||
        position.canonicalOffset > document.canonicalLength ||
        (requiresRequestedOffset &&
         position.canonicalOffset != requestedOffset)) {
        return NO;
    }
    UITextStorageDirection ignored;
    if (!IDRichUIKitAffinity(position.localPosition.affinity, &ignored)) {
        return NO;
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *location = [projection
        locationForCanonicalOffset:position.canonicalOffset];
    if (location == nil ||
        ![location.blockIdentifier isEqual:position.blockIdentifier] ||
        location.localOffset != position.localPosition.utf16Offset) {
        return NO;
    }
    return [projection canonicalOffsetForBlockIdentifier:position.blockIdentifier
                                               localOffset:position.localPosition.utf16Offset] ==
        position.canonicalOffset;
}

static BOOL IDRichCaretGeometryResultIsValid(
    IDDocumentCaretGeometry *result,
    IDBlockDocument *document,
    NSUInteger requestedOffset) {
    return result != nil && result.exact &&
        IDRichRectIsFinite(result.documentRect) &&
        IDRichDocumentPositionIsValid(result.position, document,
                                      requestedOffset, YES);
}

static BOOL IDRichPointResultIsValid(
    IDDocumentTextPosition *result,
    IDBlockDocument *document) {
    return IDRichDocumentPositionIsValid(result, document, 0, NO);
}

static BOOL IDRichLineGeometryResultIsValid(
    IDDocumentLineGeometry *result,
    IDBlockDocument *document,
    NSUInteger requestedOffset) {
    if (result == nil || !result.exact ||
        !IDRichDocumentPositionIsValid(result.position, document,
                                       requestedOffset, YES) ||
        result.resolvedAffinity != result.position.localPosition.affinity ||
        !IDRichRangeIsValid(result.canonicalRange, document.canonicalLength) ||
        requestedOffset < result.canonicalRange.location ||
        requestedOffset > NSMaxRange(result.canonicalRange)) {
        return NO;
    }
    UITextStorageDirection ignored;
    if (!IDRichUIKitAffinity(result.resolvedAffinity, &ignored)) return NO;

    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *start = [projection
        locationForCanonicalOffset:result.canonicalRange.location];
    IDCanonicalLocation *end = [projection
        locationForCanonicalOffset:NSMaxRange(result.canonicalRange)];
    if (start == nil || end == nil ||
        ![start.blockIdentifier isEqual:result.position.blockIdentifier] ||
        ![end.blockIdentifier isEqual:result.position.blockIdentifier]) {
        return NO;
    }
    return [projection canonicalOffsetForBlockIdentifier:start.blockIdentifier
                                               localOffset:start.localOffset] ==
            result.canonicalRange.location &&
        [projection canonicalOffsetForBlockIdentifier:end.blockIdentifier
                                             localOffset:end.localOffset] ==
            NSMaxRange(result.canonicalRange);
}

static BOOL IDRichSelectionGeometryResultIsValid(
    IDDocumentSelectionGeometry *result,
    IDBlockDocument *document,
    NSRange requestedRange) {
    if (result == nil || !result.exact ||
        result.documentRevision != document.documentRevision ||
        result.sourceGeometryGeneration == 0 ||
        !NSEqualRanges(result.canonicalSelection, requestedRange)) {
        return NO;
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    BOOL claimedStart = NO;
    BOOL claimedEnd = NO;
    for (IDDocumentSelectionSegment *segment in result.segments) {
        IDBlock *block = nil;
        for (IDBlock *candidate in document.blocks) {
            if ([candidate.identifier isEqual:segment.blockIdentifier]) {
                block = candidate;
                break;
            }
        }
        if (block == nil ||
            !IDRichRangeIsValid(segment.canonicalRange,
                                document.canonicalLength) ||
            !IDRichRectIsFinite(segment.documentRect) ||
            CGRectIsEmpty(segment.documentRect) ||
            (segment.writingDirection != IDBlockWritingDirectionLeftToRight &&
             segment.writingDirection != IDBlockWritingDirectionRightToLeft)) {
            return NO;
        }
        NSUInteger blockStart = [projection
            canonicalOffsetForBlockIdentifier:block.identifier localOffset:0];
        NSRange blockRange = NSMakeRange(blockStart, block.attributedText.length);
        BOOL belongsToText = segment.canonicalRange.location >= blockStart &&
            NSMaxRange(segment.canonicalRange) <= NSMaxRange(blockRange);
        BOOL belongsToHead = blockStart > 0 &&
            (segment.boundaryRole & IDBlockSelectionBoundaryRoleHead) != 0 &&
            NSEqualRanges(segment.canonicalRange,
                          NSMakeRange(blockStart - 1, 1));
        BOOL belongsToTail = NSMaxRange(blockRange) < document.canonicalLength &&
            (segment.boundaryRole & IDBlockSelectionBoundaryRoleTail) != 0 &&
            NSEqualRanges(segment.canonicalRange,
                          NSMakeRange(NSMaxRange(blockRange), 1));
        if (!belongsToText && !belongsToHead && !belongsToTail) return NO;
        if ((segment.containsLogicalStart && claimedStart) ||
            (segment.containsLogicalEnd && claimedEnd)) return NO;
        claimedStart |= segment.containsLogicalStart;
        claimedEnd |= segment.containsLogicalEnd;
    }
    return YES;
}

- (NSUInteger)id_boundingRectForCharacterRangeCallCount {
    return self.id_boundingRectForCharacterRangeCallCountState;
}

- (void)id_directSelectionReplacementDidOccur {
}

- (instancetype)initWithDocument:(IDBlockDocument *)document
                       blockStack:(IDBlockStackCanvasView *)blockStack {
    IDCanonicalTextStorageAdapter *textStorageAdapter = document == nil
        ? nil
        : IDCanonicalTextStorageAdapterCreate(document);
    return [self initWithDocument:document
              textStorageAdapter:textStorageAdapter
                       blockStack:blockStack];
}

- (instancetype)initWithDocument:(IDBlockDocument *)document
               textStorageAdapter:(IDCanonicalTextStorageAdapter *)textStorageAdapter
                        blockStack:(IDBlockStackCanvasView *)blockStack {
    if (document == nil) {
        IDRichRaise(@"initWithDocument:blockStack:", @"document is nil");
    }
    if (textStorageAdapter == nil || textStorageAdapter.document != document) {
        IDRichRaise(@"initWithDocument:blockStack:",
                    @"canonical text storage belongs to another document");
    }
    if (blockStack == nil) {
        IDRichRaise(@"initWithDocument:blockStack:", @"block stack is nil");
    }
    if ([blockStack id_document] != document) {
        IDRichRaise(@"initWithDocument:blockStack:",
                    @"block stack belongs to another document");
    }
    NSArray<IDBlock *> *blocks = document.blocks;
    NSArray<IDBlockLayout *> *layouts = blockStack.blockLayouts;
    if (layouts.count != blocks.count) {
        IDRichRaise(@"initWithDocument:blockStack:",
                    @"block stack is incomplete or stale");
    }
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        if (![layouts[index].blockIdentifier isEqual:blocks[index].identifier]) {
            IDRichRaise(@"initWithDocument:blockStack:",
                        @"block stack order or identity is stale");
        }
    }

    self = [super init];
    if (self != nil) {
        _id_textInputControllerConnection = [IDRichTextInputControllerConnection new];
        _document = document;
        _id_blockStack = blockStack;
        _textStorageAdapter = textStorageAdapter;
        _id_documentLayoutCoordinator = [[IDDocumentLayoutCoordinator alloc]
            initWithDocument:document
                       source:blockStack];
        _id_interactionTextContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
        _annotationStore = [[IDRichTextAnnotationStore alloc] initWithDocument:document];
        [layouts enumerateObjectsUsingBlock:^(IDBlockLayout *layout,
                                              NSUInteger index,
                                              BOOL *stop) {
            IDPrivateRequireRichTemporaryLayoutManager(
                layout.layoutManager,
                [NSString stringWithFormat:
                    @"Rich temporary layout-manager preflight for block %lu",
                    (unsigned long)index]);
            IDPrivateRequireRichTemporaryCanvas(
                layout.canvasView,
                [NSString stringWithFormat:
                    @"Rich temporary canvas preflight for block %lu",
                    (unsigned long)index]);
        }];
        [self id_updateInteractionContainerGeometry];
    }
    return self;
}

- (IDRichTextPosition *)positionForCanonicalOffset:(NSUInteger)offset
                                          affinity:(UITextStorageDirection)affinity {
    return [self id_positionForCanonicalOffset:offset
                                      affinity:affinity
                                 tracksChanges:YES];
}

- (IDRichTextPosition *)id_positionForCanonicalOffset:(NSUInteger)offset
                                              affinity:(UITextStorageDirection)affinity
                                         tracksChanges:(BOOL)tracksChanges {
    if (offset > self.document.canonicalLength) {
        IDRichRaise(@"positionForCanonicalOffset:affinity:",
                    @"offset is outside the document");
    }
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:offset];
    if (location == nil) {
        IDRichRaise(@"positionForCanonicalOffset:affinity:",
                    @"offset has no canonical location");
    }
    IDRichTextAnchorBias bias = affinity == UITextStorageDirectionBackward
        ? IDRichTextAnchorBiasBefore
        : IDRichTextAnchorBiasAfter;
    IDRichTextAnchor *anchor = [[IDRichTextAnchor alloc]
        initWithDocument:self.document
         blockIdentifier:location.blockIdentifier
              localOffset:location.localOffset
                     bias:bias
            tracksChanges:tracksChanges];
    return [[IDRichTextPosition alloc] initWithAnchor:anchor affinity:affinity];
}

- (IDRichTextRange *)rangeForCanonicalRange:(NSRange)range {
    if (!IDRichRangeIsValid(range, self.document.canonicalLength)) {
        IDRichRaise(@"rangeForCanonicalRange:", @"range is outside the document");
    }
    IDRichTextPosition *start = [self
        positionForCanonicalOffset:range.location
                         affinity:UITextStorageDirectionBackward];
    IDRichTextPosition *end = [self
        positionForCanonicalOffset:NSMaxRange(range)
                         affinity:UITextStorageDirectionForward];
    return [[IDRichTextRange alloc] initWithStart:start end:end];
}

- (IDRichTextRange *)id_nativeRangeForCanonicalRange:(NSRange)range {
    NSUInteger documentLength = self.document.canonicalLength;
    if (!IDRichRangeIsValid(range, documentLength)) {
        IDRichRaise(@"nativeRangeForCanonicalRange:", @"range is outside the document");
    }
    UITextStorageDirection startAffinity = range.length == 0
        ? UITextStorageDirectionForward
        : UITextStorageDirectionBackward;
    IDRichTextPosition *start = [self
        id_positionForCanonicalOffset:range.location
                             affinity:startAffinity
                        tracksChanges:NO];
    IDRichTextPosition *end = range.length == 0
        ? start
        : [self id_positionForCanonicalOffset:NSMaxRange(range)
                                      affinity:UITextStorageDirectionForward
                                 tracksChanges:NO];
    return [[IDRichTextRange alloc] initWithStart:start end:end];
}

- (NSRange)canonicalRangeForTextRange:(IDRichTextRange *)range clipped:(BOOL)clipped {
    NSString *stage = clipped
        ? TGPN_characterRangeForTextRange_clippedToDocument_()
        : TGPN_characterRangeForTextRange_();
    return [self id_projectedCanonicalRangeForTextRange:range
                                                clipped:clipped
                                                  stage:stage];
}

- (NSTextStorage *)id_textStorage {
    return self.textStorageAdapter;
}

- (void)id_attachInteractionTextView:(UIView *)view {
    if (view == nil) IDRichRaise(@"attachInteractionTextView:", @"view is nil");
    IDPrivateRequireTextContainerHost(view, @"Document interaction-container host preflight");
    self.id_interactionTextView = view;
    IDPrivateTextContainerSetTextView(self.id_interactionTextContainer, view);
}

- (void)id_detachInteractionTextView {
    IDPrivateTextContainerSetTextView(self.id_interactionTextContainer, nil);
    self.id_interactionTextView = nil;
}

- (void)id_updateInteractionContainerGeometry {
    CGSize size = self.id_blockStack.documentContentSize;
    CGFloat width = isfinite(size.width) ? MAX(size.width, 1.0) : 1.0;
    CGFloat height = isfinite(size.height) ? MAX(size.height, 1.0) : 1.0;
    self.id_interactionTextContainer.size = CGSizeMake(width, height);
}

- (NSArray<NSTextContainer *> *)id_textContainers {
    return @[self.id_interactionTextContainer];
}

- (NSTextContainer *)id_firstTextContainer {
    return self.id_interactionTextContainer;
}

- (NSTextContainer *)id_textContainerForPosition:(UITextPosition *)position {
    (void)[self id_validPosition:position stage:TGPN_textContainerForPosition_()];
    return self.id_interactionTextContainer;
}

- (BOOL)id_canAccessLayoutManager {
    return NO;
}

- (id)id_layoutManager {
    return nil;
}

- (id)inputController {
    return ((IDRichTextInputControllerConnection *)
        _id_textInputControllerConnection).id_textInputController;
}

- (void)id_adoptTextInputController:(id)controller {
    if (controller == nil) {
        IDRichRaise(TGPN_adoptTextInputController_(), @"controller is nil");
    }
    id adopted = self.inputController;
    if (adopted != nil && adopted != controller) {
        IDRichRaise(TGPN_adoptTextInputController_(),
                    @"a different controller is already adopted");
    }
    ((IDRichTextInputControllerConnection *)
        _id_textInputControllerConnection).id_textInputController = controller;
}

- (void)id_detachFromTextInputController {
    ((IDRichTextInputControllerConnection *)
        _id_textInputControllerConnection).id_textInputController = nil;
}

- (UITextPosition *)id_beginningOfDocument {
    return [self id_positionForCanonicalOffset:0
                                      affinity:UITextStorageDirectionForward
                                 tracksChanges:NO];
}

- (UITextPosition *)id_endOfDocument {
    return [self id_positionForCanonicalOffset:self.document.canonicalLength
                                       affinity:UITextStorageDirectionForward
                                  tracksChanges:NO];
}

- (IDRichTextPosition *)id_positionWithValidIdentity:(UITextPosition *)position
                                                stage:(NSString *)stage {
    if (![position isMemberOfClass:IDRichTextPosition.class]) {
        IDRichRaise(stage, @"position has a foreign concrete class");
    }
    IDRichTextPosition *richPosition = (IDRichTextPosition *)position;
    IDBlockDocument *positionDocument = richPosition.anchor.document;
    if (positionDocument == nil) {
        IDRichRaise(stage, @"position anchor has expired");
    }
    if (positionDocument != self.document) {
        IDRichRaise(stage, @"position belongs to another document");
    }
    return richPosition;
}

- (NSUInteger)id_rawCanonicalOffsetForPosition:(IDRichTextPosition *)position
                                          stage:(NSString *)stage
                                        clipped:(BOOL)clipped {
    IDRichTextPosition *valid = [self id_positionWithValidIdentity:position stage:stage];
    if (!valid.anchor.id_tracksChanges) {
        return [valid.anchor id_snapshotCanonicalOffsetClampedToLength:self.document.canonicalLength];
    }
    NSUInteger cursor = 0;
    NSArray<IDBlock *> *blocks = self.document.blocks;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        IDBlock *block = blocks[index];
        NSUInteger blockLength = block.attributedText.length;
        if ([block.identifier isEqual:valid.anchor.blockIdentifier]) {
            NSUInteger localOffset = valid.anchor.localOffset;
            if (!clipped && localOffset > blockLength) {
                IDRichRaise(stage, @"position is outside its block");
            }
            NSUInteger rawOffset = localOffset > NSUIntegerMax - cursor
                ? NSUIntegerMax
                : cursor + localOffset;
            if (clipped) {
                return MIN(rawOffset, self.document.canonicalLength);
            }
            if (rawOffset > self.document.canonicalLength) {
                IDRichRaise(stage, @"position is outside the document");
            }
            return rawOffset;
        }
        cursor += blockLength;
        if (index + 1 < blocks.count) {
            cursor += 1;
        }
    }
    IDRichRaise(stage, @"position block no longer exists");
    return 0;
}

- (IDRichTextPosition *)id_validPosition:(UITextPosition *)position
                                   stage:(NSString *)stage {
    IDRichTextPosition *richPosition =
        [self id_positionWithValidIdentity:position stage:stage];
    (void)[self id_rawCanonicalOffsetForPosition:richPosition stage:stage clipped:NO];
    return richPosition;
}

- (UITextRange *)id_validRange:(UITextRange *)range stage:(NSString *)stage {
    UITextPosition *start = nil;
    UITextPosition *end = nil;
    if ([range isMemberOfClass:IDRichTextRange.class]) {
        IDRichTextRange *richRange = (IDRichTextRange *)range;
        start = [richRange id_storedStart];
        end = [richRange id_storedEnd];
    } else {
        start = range.start;
        end = range.end;
    }
    if (start == nil && end == nil) {
        return range;
    }
    if (start == nil || end == nil) {
        IDRichRaise(stage, @"range has only one endpoint");
    }
    [self id_positionWithValidIdentity:start stage:stage];
    [self id_positionWithValidIdentity:end stage:stage];
    return range;
}

- (NSUInteger)id_canonicalOffsetForPosition:(IDRichTextPosition *)position {
    return [self id_rawCanonicalOffsetForPosition:position
                                            stage:@"canonicalOffsetForPosition:"
                                          clipped:NO];
}

- (UITextRange *)id_emptyTextRangeAtPosition:(nullable UITextPosition *)position {
    // nil is the beginning of the document, the native layout controller's answer (UIKit's input
    // controller passes an unchecked stepped position here after a keyboard replacement; p19).
    if (position == nil) {
        position = [self id_beginningOfDocument];
    }
    IDRichTextPosition *valid = [self id_validPosition:position
                                                stage:TGPN_emptyTextRangeAtPosition_()];
    return [[IDRichTextRange alloc] initWithStart:valid end:valid];
}

- (UITextRange *)id_textRangeFromPosition:(nullable UITextPosition *)from
                               toPosition:(nullable UITextPosition *)to {
    // A MISSING endpoint is the native layout controller's answer, not a failure: nil `from` is the
    // beginning of the document and nil `to` is `from`. UIKit's own input controller relies on it —
    // `characterRangeByExtendingPosition:inDirection:` steps one character with
    // `positionFromPosition:offset:affinity:` and passes the result straight through, so at a
    // document edge it asks for a range to nil and a stock text view answers an empty range there
    // (composer harness p19, `HarnessExtendPastDocumentEdgeTests`). A position of a foreign class,
    // an expired anchor or another document still fails.
    if (from == nil) {
        from = [self id_beginningOfDocument];
    }
    if (to == nil) {
        to = from;
    }
    IDRichTextPosition *validFrom = [self id_validPosition:from
                                                    stage:@"textRangeFromPosition:toPosition:"];
    IDRichTextPosition *validTo = [self id_validPosition:to
                                                  stage:@"textRangeFromPosition:toPosition:"];
    return [[IDRichTextRange alloc] initWithStart:validFrom end:validTo];
}

- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                     offset:(NSInteger)offset {
    IDRichTextPosition *valid = [self id_validPosition:position
                                                stage:@"positionFromPosition:offset:"];
    NSUInteger base = [self id_canonicalOffsetForPosition:valid];
    NSUInteger length = self.document.canonicalLength;
    if ((offset < 0 && (NSUInteger)(-(offset + 1)) + 1 > base) ||
        (offset >= 0 && (NSUInteger)offset > length - base)) {
        return nil;
    }
    NSUInteger result = offset < 0
        ? base - ((NSUInteger)(-(offset + 1)) + 1)
        : base + (NSUInteger)offset;
    return [self id_positionForCanonicalOffset:result
                                      affinity:valid.affinity
                                 tracksChanges:valid.anchor.id_tracksChanges];
}

- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                     offset:(NSInteger)offset
                                   affinity:(UITextStorageDirection)affinity {
    IDRichTextPosition *valid = [self id_validPosition:position
                                                stage:@"positionFromPosition:offset:affinity:"];
    NSUInteger base = [self id_canonicalOffsetForPosition:valid];
    NSUInteger length = self.document.canonicalLength;
    if ((offset < 0 && (NSUInteger)(-(offset + 1)) + 1 > base) ||
        (offset >= 0 && (NSUInteger)offset > length - base)) {
        return nil;
    }
    NSUInteger result = offset < 0
        ? base - ((NSUInteger)(-(offset + 1)) + 1)
        : base + (NSUInteger)offset;
    return [self id_positionForCanonicalOffset:result
                                      affinity:affinity
                                 tracksChanges:valid.anchor.id_tracksChanges];
}

- (IDBlockLayout *)id_layoutForPosition:(IDRichTextPosition *)position
                                  stage:(NSString *)stage
                               location:(IDCanonicalLocation * __autoreleasing *)location {
    NSUInteger offset = [self id_rawCanonicalOffsetForPosition:position stage:stage clipped:NO];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    IDCanonicalLocation *projected = [projection locationForCanonicalOffset:offset];
    IDBlockLayout *layout = [self.id_blockStack
        layoutForBlockIdentifier:projected.blockIdentifier];
    if (layout == nil) IDRichRaise(stage, @"position has no current block layout");
    if (location != NULL) *location = projected;
    return layout;
}

- (IDRichTextPosition *)id_positionForBlockLayout:(IDBlockLayout *)layout
                                      localOffset:(NSUInteger)localOffset
                                         affinity:(UITextStorageDirection)affinity
                                    tracksChanges:(BOOL)tracksChanges {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    NSUInteger canonical = [projection canonicalOffsetForBlockIdentifier:layout.blockIdentifier
                                                               localOffset:localOffset];
    return [self id_positionForCanonicalOffset:canonical
                                      affinity:affinity
                                 tracksChanges:tracksChanges];
}

- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position
                                          inDirection:(UITextLayoutDirection)direction
                                               offset:(NSInteger)offset
                                             affinity:(UITextStorageDirection)affinity
                                 anchorPositionOffset:(CGFloat)anchorPositionOffset {
    NSString *stage = @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:";
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    if (offset == 0) return valid;
    if (!isfinite(anchorPositionOffset)) return nil;
    NSUInteger stepCount = offset < 0
        ? (NSUInteger)(-(offset + 1)) + 1
        : (NSUInteger)offset;
    if (stepCount > self.document.canonicalLength) return nil;
    UITextLayoutDirection effectiveDirection;
    IDBlockTextAffinity currentAffinity;
    IDBlockLayoutDirection neutralDirection;
    if (!IDRichEffectiveDirection(direction, offset, &effectiveDirection) ||
        !IDRichNeutralAffinity(affinity, &currentAffinity) ||
        !IDRichNeutralDirection(effectiveDirection, &neutralDirection)) {
        return nil;
    }
    BOOL vertical = effectiveDirection == UITextLayoutDirectionUp ||
        effectiveDirection == UITextLayoutDirectionDown;
    NSUInteger currentOffset = [self id_canonicalOffsetForPosition:valid];
    CGFloat currentAnchor = anchorPositionOffset;
    // Each line is one step from where the previous step landed, always toward the SAME goal x
    // (the caller's anchor), which is how a held ↑/↓ resolves: UIKit asks for `offset` lines from
    // the history's start. A step with no line beyond it is the document's edge, and the walk ends
    // there at the document's END (↓) or START (↑) — a stock text view's answer. Answering nil
    // instead left UIKit to fall back on a position of its own, which past a container was a line
    // far back up the document (composer harness p17, `HarnessVerticalMoveAtDocumentEdgeTests`).
    IDDocumentCaretNavigationResult *neutral = nil;
    BOOL reachedEdge = NO;
    for (NSUInteger index = 0; index < stepCount; index += 1) {
        neutral = [self.id_documentLayoutCoordinator
            visuallyAdjacentPositionFromCanonicalOffset:currentOffset
                                                affinity:currentAffinity
                                               direction:neutralDirection
                                    anchorPositionOffset:vertical
                                        ? anchorPositionOffset
                                        : currentAnchor];
        if (!IDRichNavigationResultIsValid(neutral, self.document,
                                           vertical, anchorPositionOffset)) {
            neutral = nil;
            if (vertical) {
                BOOL downward = effectiveDirection == UITextLayoutDirectionDown;
                NSUInteger edgeOffset = downward ? self.document.canonicalLength : 0;
                IDBlockTextAffinity edgeAffinity = downward
                    ? IDBlockTextAffinityUpstream
                    : IDBlockTextAffinityDownstream;
                if ([self id_canonicalOffset:currentOffset
                                    affinity:currentAffinity
                         isOnTheLineOfOffset:edgeOffset
                                    affinity:edgeAffinity
                                    downward:downward]) {
                    currentOffset = edgeOffset;
                    currentAffinity = edgeAffinity;
                    reachedEdge = YES;
                }
            }
            break;
        }
        currentOffset = neutral.position.canonicalOffset;
        currentAffinity = neutral.position.localPosition.affinity;
        currentAnchor = neutral.anchorPositionOffset;
    }
    BOOL landed = neutral != nil || reachedEdge;
    UITextStorageDirection uiAffinity = UITextStorageDirectionForward;
    if (landed && !IDRichUIKitAffinity(currentAffinity, &uiAffinity)) {
        landed = NO;
    }
    IDRichTextPosition *result = !landed
        ? nil
        : [self id_positionForCanonicalOffset:currentOffset
                                      affinity:uiAffinity
                                 tracksChanges:valid.anchor.id_tracksChanges];
    return result;
}

- (UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position {
    IDRichTextPosition *valid = [self id_validPosition:position
                                                stage:TGPN_textRangeForLineEnclosingPosition_()];
    return [self id_textRangeForLineEnclosingPosition:valid
                                     effectiveAffinity:valid.affinity];
}

- (UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position
                                      effectiveAffinity:(UITextStorageDirection)affinity {
    NSString *stage = TGPN_textRangeForLineEnclosingPosition_effectiveAffinity_();
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    NSUInteger revision = self.document.documentRevision;
    NSUInteger canonicalOffset = [self id_canonicalOffsetForPosition:valid];
    IDBlockTextAffinity neutralRequestedAffinity;
    BOOL hasNeutralRequestedAffinity =
        IDRichNeutralAffinity(affinity, &neutralRequestedAffinity);
    IDDocumentLineGeometry *neutral = hasNeutralRequestedAffinity
        ? [self.id_documentLayoutCoordinator
            lineGeometryForCanonicalOffset:canonicalOffset
                                    affinity:neutralRequestedAffinity]
        : nil;
    BOOL validNeutral = revision == self.document.documentRevision &&
        IDRichLineGeometryResultIsValid(neutral, self.document, canonicalOffset);
    IDRichTextRange *result = validNeutral
        ? [self id_nativeRangeForCanonicalRange:neutral.canonicalRange]
        : nil;
    return result;
}

- (NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:(UITextPosition *)position
                                                          inDirection:(UITextStorageDirection)direction {
    NSString *stage = TGPN_attributesAtPosition_inDirection_();
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    IDCanonicalLocation *location = nil;
    IDBlockLayout *layout = [self id_layoutForPosition:valid stage:stage location:&location];
    return [layout attributesAtLocalOffset:location.localOffset direction:direction];
}

- (NSWritingDirection)id_baseWritingDirectionAtPosition:(UITextPosition *)position {
    NSString *stage = TGPN_baseWritingDirectionAtPosition_();
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    IDCanonicalLocation *location = nil;
    IDBlockLayout *layout = [self id_layoutForPosition:valid stage:stage location:&location];
    return [layout baseWritingDirectionAtLocalOffset:location.localOffset];
}

- (NSComparisonResult)id_comparePosition:(UITextPosition *)first
                              toPosition:(UITextPosition *)second {
    IDRichTextPosition *validFirst = [self id_validPosition:first
                                                     stage:@"comparePosition:toPosition:"];
    IDRichTextPosition *validSecond = [self id_validPosition:second
                                                      stage:@"comparePosition:toPosition:"];
    NSUInteger firstOffset = [self id_canonicalOffsetForPosition:validFirst];
    NSUInteger secondOffset = [self id_canonicalOffsetForPosition:validSecond];
    if (firstOffset < secondOffset) return NSOrderedAscending;
    if (firstOffset > secondOffset) return NSOrderedDescending;
    return NSOrderedSame;
}

- (NSInteger)id_offsetFromPosition:(UITextPosition *)first
                        toPosition:(UITextPosition *)second {
    IDRichTextPosition *validFirst = [self id_validPosition:first
                                                     stage:@"offsetFromPosition:toPosition:"];
    IDRichTextPosition *validSecond = [self id_validPosition:second
                                                      stage:@"offsetFromPosition:toPosition:"];
    NSUInteger firstOffset = [self id_canonicalOffsetForPosition:validFirst];
    NSUInteger secondOffset = [self id_canonicalOffsetForPosition:validSecond];
    if (secondOffset >= firstOffset) {
        NSUInteger delta = secondOffset - firstOffset;
        if (delta > NSIntegerMax) {
            IDRichRaise(@"offsetFromPosition:toPosition:", @"offset overflows NSInteger");
        }
        return (NSInteger)delta;
    }
    NSUInteger delta = firstOffset - secondOffset;
    if (delta > (NSUInteger)NSIntegerMax) {
        IDRichRaise(@"offsetFromPosition:toPosition:", @"offset overflows NSInteger");
    }
    return -(NSInteger)delta;
}

- (UITextStorageDirection)id_affinityForPosition:(UITextPosition *)position {
    return [self id_validPosition:position stage:TGPN_affinityForPosition_()].affinity;
}

- (NSRange)id_projectedCanonicalRangeForTextRange:(UITextRange *)range
                                           clipped:(BOOL)clipped
                                             stage:(NSString *)stage {
    UITextRange *valid = [self id_validRange:range stage:stage];
    UITextPosition *firstPosition = nil;
    UITextPosition *secondPosition = nil;
    if ([valid isMemberOfClass:IDRichTextRange.class]) {
        IDRichTextRange *richRange = (IDRichTextRange *)valid;
        firstPosition = [richRange id_storedStart];
        secondPosition = [richRange id_storedEnd];
    } else {
        firstPosition = valid.start;
        secondPosition = valid.end;
    }
    if (firstPosition == nil && secondPosition == nil) {
        return NSMakeRange(0, 0);
    }
    NSUInteger first = [self id_rawCanonicalOffsetForPosition:(IDRichTextPosition *)firstPosition
                                                        stage:stage
                                                      clipped:clipped];
    NSUInteger second = [self id_rawCanonicalOffsetForPosition:(IDRichTextPosition *)secondPosition
                                                         stage:stage
                                                       clipped:clipped];
    NSUInteger start = MIN(first, second);
    NSUInteger end = MAX(first, second);
    return NSMakeRange(start, end - start);
}

- (NSRange)id_characterRangeForTextRange:(nullable UITextRange *)range
                                  clipped:(BOOL)clipped {
    if (range == nil) {
        return NSMakeRange(0, 0);
    }
    NSString *stage = clipped
        ? TGPN_characterRangeForTextRange_clippedToDocument_()
        : TGPN_characterRangeForTextRange_();
    NSRange characterRange = [self id_projectedCanonicalRangeForTextRange:range
                                                                   clipped:clipped
                                                                     stage:stage];
    // iOS 26.5's singular clipped callback collapses every empty range to zero.
    return clipped && characterRange.length == 0 ? NSMakeRange(0, 0) : characterRange;
}

- (NSArray<NSValue *> *)id_characterRangesForTextRange:(UITextRange *)range
                                                clipped:(BOOL)clipped {
    NSString *stage = clipped
        ? TGPN_characterRangesForTextRange_clippedToDocument_()
        : @"characterRangesForTextRange:";
    NSRange characterRange = [self id_projectedCanonicalRangeForTextRange:range
                                                                   clipped:clipped
                                                                     stage:stage];
    return @[[NSValue valueWithRange:characterRange]];
}

- (UITextRange *)id_textRangeForCharacterRange:(NSRange)range {
    NSString *stage = TGPN_textRangeForCharacterRange_();
    if (range.length > NSUIntegerMax - range.location) {
        IDRichRaise(stage, @"range overflows NSUInteger");
    }
    NSUInteger documentLength = self.document.canonicalLength;
    if (range.location > documentLength || NSMaxRange(range) > documentLength) {
        range = NSMakeRange(documentLength, 0);
    }
    return [self id_nativeRangeForCanonicalRange:range];
}

- (UITextRange *)id_textRangeForCharacterRanges:(NSArray<NSValue *> *)ranges {
    if (![ranges isKindOfClass:NSArray.class] || ranges.count != 1) {
        IDRichRaise(TGPN_textRangeForCharacterRanges_(),
                    @"P0 requires exactly one contiguous range");
    }
    id value = ranges.firstObject;
    if (![value isKindOfClass:NSValue.class] ||
        strcmp([value objCType], @encode(NSRange)) != 0) {
        IDRichRaise(TGPN_textRangeForCharacterRanges_(),
                    @"range element has a foreign value type");
    }
    NSRange range = [value rangeValue];
    NSString *stage = TGPN_textRangeForCharacterRanges_();
    if (range.length > NSUIntegerMax - range.location) {
        IDRichRaise(stage, @"range element overflows NSUInteger");
    }
    NSUInteger documentLength = self.document.canonicalLength;
    if (range.location > documentLength || NSMaxRange(range) > documentLength) {
        range = NSMakeRange(documentLength, 0);
    }
    return [self id_nativeRangeForCanonicalRange:range];
}

- (UITextPosition *)id_positionWithOffset:(NSInteger)offset
                                  affinity:(UITextStorageDirection)affinity {
    if (offset < 0 || (NSUInteger)offset > self.document.canonicalLength) {
        IDRichRaise(TGPN_positionWithOffset_affinity_(), @"offset is outside the document");
    }
    return [self id_positionForCanonicalOffset:(NSUInteger)offset
                                       affinity:affinity
                                  tracksChanges:NO];
}

- (NSRange)id_rangeOfCharacterClusterAtIndex:(NSUInteger)index type:(NSInteger)type {
    if (type < 1 || type > 4) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Unexpected clusterType = %ld", (long)type];
    }
    NSString *string = self.textStorageAdapter.string;
    if (string.length == 0 || index == string.length) {
        return NSMakeRange(string.length, 0);
    }
    NSUInteger characterIndex = MIN(index, string.length - 1);
    return [string rangeOfComposedCharacterSequenceAtIndex:characterIndex];
}

- (NSArray *)id_selectionRectsForRange:(UITextRange *)range
                              fromView:(UIView *)view
               forContainerPassingTest:(BOOL (^)(id container))predicate {
    NSRange characterRange = [self id_projectedCanonicalRangeForTextRange:range
                                                                  clipped:YES
                                                                    stage:TGPN_selectionRectsForRange_fromView_forContainerPassingTest_()];
    if (predicate != nil && !predicate(self.id_interactionTextContainer)) {
        return @[];
    }
    if (characterRange.length == 0) {
        UITextPosition *position = range.start;
        CGRect documentRect = [self
            id_insertionRectForPosition:position
                       typingAttributes:@{}
                  placeholderAttachment:nil
                          textContainer:NULL];
        if (!IDRichRectIsFinite(documentRect)) {
            return @[];
        }
        documentRect.origin.x = CGRectGetMidX(documentRect);
        documentRect.size.width = 0.0;
        return @[[[IDRichTextSelectionRect alloc]
            initWithRect:documentRect
            containsStart:YES
            containsEnd:YES
            isVertical:NO
            writingDirection:
                [self id_baseWritingDirectionAtPosition:position]]];
    }
    NSArray<IDRichTextSelectionRect *> *exact = [self
            id_exactSelectionRectsForRange:range
                                   fromView:view
                    forContainerPassingTest:nil];
    return exact ?: @[];
}

- (NSArray<IDRichTextSelectionRect *> *)
    id_exactSelectionRectsForRange:(UITextRange *)range
                           fromView:(UIView *)view
            forContainerPassingTest:(BOOL (^)(id container))predicate {
    NSRange characterRange = [self id_projectedCanonicalRangeForTextRange:range
                                                                  clipped:YES
                                                                    stage:@"exactSelectionRectsForRange:"];
    if (predicate != nil && !predicate(self.id_interactionTextContainer)) {
        return @[];
    }
    if (characterRange.length == 0) {
        return [self id_selectionRectsForRange:range
                                      fromView:view
                       forContainerPassingTest:nil];
    }
    NSUInteger documentRevision = self.document.documentRevision;
    IDDocumentSelectionGeometry *geometry = [self.id_documentLayoutCoordinator
        selectionGeometryForCanonicalRange:characterRange];
    if (documentRevision != self.document.documentRevision ||
        !IDRichSelectionGeometryResultIsValid(geometry, self.document,
                                              characterRange)) {
        return nil;
    }
    UIView *targetView = view ?: self.id_blockStack.superview;
    NSMutableArray<IDRichTextSelectionRect *> *rects =
        [NSMutableArray arrayWithCapacity:geometry.segments.count];
    IDBlockWritingDirection sharedDirection = geometry.segments.count == 0
        ? IDBlockWritingDirectionLeftToRight
        : geometry.segments.firstObject.writingDirection;
    for (IDDocumentSelectionSegment *segment in geometry.segments) {
        CGRect rect = targetView == nil
            ? segment.documentRect
            : [self.id_blockStack convertRect:segment.documentRect toView:targetView];
        if (!IDRichRectIsFinite(rect) || CGRectIsEmpty(rect)) return nil;
        NSWritingDirection direction =
            sharedDirection == IDBlockWritingDirectionRightToLeft
                ? NSWritingDirectionRightToLeft
                : NSWritingDirectionLeftToRight;
        [rects addObject:[[IDRichTextSelectionRect alloc]
            initWithRect:rect
            baselineOffset:segment.baselineOffset
            containsStart:segment.containsLogicalStart
            containsEnd:segment.containsLogicalEnd
            isVertical:segment.isVertical
            writingDirection:direction]];
    }
    return rects.copy;
}

- (void)id_requestTextGeometryAtPosition:(UITextPosition *)position
                         typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                              resultBlock:(void (^)(NSTextContainer *container,
                                                    CGRect rect,
                                                    CGFloat baselineOffset,
                                                    UITextPosition *position))resultBlock {
    NSString *stage = TGPN_requestTextGeometryAtPosition_typingAttributes_resultBlock_();
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    if (resultBlock == nil) return;
    CGRect rect = [self id_insertionRectForPosition:valid
                                   typingAttributes:attributes
                              placeholderAttachment:nil
                                      textContainer:NULL];
    // `-[UITextInputController selectionRectsForRange:]` asks this for the range's end and stamps
    // the baseline on every rect the layout controller returned; the text-choice assistant reads
    // it back to place an accepted autocorrection's underline. Called with the rect alone, this
    // block left the baseline in an unset register — infinity on device, an underline at
    // y = infinity (2026-09-11).
    resultBlock(self.id_interactionTextContainer, rect,
                [self id_baselineOffsetForPosition:valid insertionRect:rect stage:stage], valid);
}

/// The line's baseline measured down from `insertionRect`'s top, from the same TextKit segments
/// the selection rects carry; 0 when the line has no geometry, which UIKit reads as "unknown".
- (CGFloat)id_baselineOffsetForPosition:(IDRichTextPosition *)position
                           insertionRect:(CGRect)insertionRect
                                   stage:(NSString *)stage {
    (void)stage;
    if (!IDRichRectIsFinite(insertionRect)) return 0.0;
    // Not `id_layoutForPosition:`, which raises for a block without a layout: this runs inside
    // UIKit's own geometry calls, where an unlaid-out block is an ordinary in-flight state.
    NSUInteger offset = [self id_canonicalOffsetForPosition:position];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:offset];
    IDBlockLayout *layout = location == nil ? nil
        : [self.id_blockStack layoutForBlockIdentifier:location.blockIdentifier];
    if (layout == nil) return 0.0;
    NSArray<IDRichTextSelectionRect *> *rects =
        [layout selectionRectsForLocalRange:NSMakeRange(location.localOffset, 0)
                                 extendHead:YES
                                 extendTail:YES];
    IDRichTextSelectionRect *line = rects.firstObject;
    if (line == nil || line.baselineOffset <= 0.0) return 0.0;
    CGRect lineRect = [self.id_blockStack convertRect:line.rect fromView:layout.canvasView];
    CGFloat baseline = CGRectGetMinY(lineRect) + line.baselineOffset - CGRectGetMinY(insertionRect);
    return isfinite(baseline) && baseline > 0.0 ? baseline : 0.0;
}

- (CGRect)id_insertionRectForPosition:(UITextPosition *)position
                      typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                 placeholderAttachment:(id)attachment
                         textContainer:(NSTextContainer * _Nullable * _Nullable)textContainer {
    NSString *stage = TGPN_insertionRectForPosition_typingAttributes_placeholderAttachment_textContainer_();
    IDRichTextPosition *valid = [self id_validPosition:position stage:stage];
    (void)attributes;
    (void)attachment;
    if (textContainer != NULL) *textContainer = self.id_interactionTextContainer;
    NSUInteger revision = self.document.documentRevision;
    NSUInteger canonicalOffset = [self id_canonicalOffsetForPosition:valid];
    IDBlockTextAffinity neutralCaretAffinity;
    BOOL hasNeutralCaretAffinity =
        IDRichNeutralAffinity(valid.affinity, &neutralCaretAffinity);
    IDDocumentCaretGeometry *neutral = hasNeutralCaretAffinity
        ? [self.id_documentLayoutCoordinator
            caretGeometryForCanonicalOffset:canonicalOffset
                                      affinity:neutralCaretAffinity]
        : nil;
    BOOL validNeutral = revision == self.document.documentRevision &&
        IDRichCaretGeometryResultIsValid(neutral, self.document, canonicalOffset);
    CGRect documentRect = validNeutral ? neutral.documentRect : CGRectNull;
    return documentRect;
}

- (UITextPosition *)id_nearestPositionAtPoint:(CGPoint)point
                                    inContainer:(NSTextContainer *)container {
    NSString *stage = TGPN_nearestPositionAtPoint_inContainer_();
    if (container != nil && container != self.id_interactionTextContainer) {
        IDRichRaise(stage, @"container is not the document interaction container");
    }
    NSUInteger revision = self.document.documentRevision;
    IDDocumentTextPosition *neutral = [self.id_documentLayoutCoordinator
        nearestPositionToDocumentPoint:point];
    BOOL validNeutral = revision == self.document.documentRevision &&
        IDRichPointResultIsValid(neutral, self.document);
    UITextStorageDirection affinity = UITextStorageDirectionForward;
    if (validNeutral &&
        !IDRichUIKitAffinity(neutral.localPosition.affinity, &affinity)) {
        validNeutral = NO;
    }
    IDRichTextPosition *result = validNeutral
        ? [self id_positionForCanonicalOffset:neutral.canonicalOffset
                                      affinity:affinity
                                 tracksChanges:NO]
        : nil;
    return result;
}

- (UITextPosition *)id_cursorPositionAtPoint:(CGPoint)point
                                   inContainer:(NSTextContainer *)container {
    return [self id_nearestPositionAtPoint:point inContainer:container];
}

- (UITextRange *)id_visualSelectionRangeForExtent:(UITextPosition *)extent
                                          forPoint:(CGPoint)point
                                      fromPosition:(UITextPosition *)position
                                       inDirection:(UITextStorageDirection)direction {
    NSString *stage = @"visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:";
    IDRichTextPosition *validExtent = [self id_validPosition:extent stage:stage];
    IDRichTextPosition *anchor = [self id_validPosition:position
        stage:stage];
    IDCanonicalLocation *extentLocation = nil;
    IDBlockLayout *layout = [self id_layoutForPosition:validExtent
                                                 stage:stage
                                              location:&extentLocation];
    UIView *hostView = self.id_blockStack.superview;
    CGPoint localPoint = hostView == nil
        ? [layout.canvasView convertPoint:point fromView:self.id_blockStack]
        : [layout.canvasView convertPoint:point fromView:hostView];
    localPoint.x = MAX(localPoint.x, 0.0);
    localPoint.y = MAX(localPoint.y, 0.0);

    NSUInteger anchorOffset = [self id_canonicalOffsetForPosition:anchor];
    NSUInteger extentOffset = [self id_canonicalOffsetForPosition:validExtent];
    IDCanonicalLocation *anchorLocation = nil;
    IDBlockLayout *anchorLayout = [self id_layoutForPosition:anchor
                                                       stage:stage
                                                    location:&anchorLocation];
    BOOL sameLayout = anchorLayout == layout;
    NSUInteger localAnchorOffset = sameLayout
        ? anchorLocation.localOffset
        : (anchorOffset < extentOffset ? 0 : layout.contentStorage.textStorage.length);
    id<NSTextLocation> localExtent = [layout locationForLocalOffset:extentLocation.localOffset];
    id<NSTextLocation> localAnchor = [layout locationForLocalOffset:localAnchorOffset];
    if (localExtent == nil || localAnchor == nil) return nil;

    @try {
        NSTextSelectionAffinity affinity = direction == UITextStorageDirectionForward
            ? NSTextSelectionAffinityDownstream
            : NSTextSelectionAffinityUpstream;
        NSTextSelection *fixedAnchor = [[NSTextSelection alloc]
            initWithLocation:localAnchor affinity:affinity];
        NSArray<NSTextSelection *> *selections =
            [layout.layoutManager.textSelectionNavigation
                textSelectionsInteractingAtPoint:localPoint
                           inContainerAtLocation:localExtent
                                          anchors:@[fixedAnchor]
                                        modifiers:1
                                         selecting:YES
                                            bounds:(CGRect){CGPointZero,
                                                            layout.textContainer.size}];
        NSMutableArray<NSTextRange *> *ranges = [NSMutableArray array];
        for (NSTextSelection *selection in selections) {
            [ranges addObjectsFromArray:selection.textRanges];
        }
        if (ranges.count == 0) return nil;
        NSUInteger localStart = [layout localOffsetForLocation:ranges.firstObject.location];
        NSUInteger localEnd = [layout localOffsetForLocation:ranges.lastObject.endLocation];
        if (localStart > layout.contentStorage.textStorage.length ||
            localEnd > layout.contentStorage.textStorage.length) {
            return nil;
        }
        IDRichTextPosition *start = nil;
        IDRichTextPosition *end = nil;
        if (sameLayout) {
            start = [self id_positionForBlockLayout:layout localOffset:localStart
                                          affinity:direction tracksChanges:NO];
            end = [self id_positionForBlockLayout:layout localOffset:localEnd
                                        affinity:direction tracksChanges:NO];
        } else {
            NSUInteger movingLocalOffset = anchorOffset < extentOffset
                ? localEnd
                : localStart;
            IDRichTextPosition *moving = [self id_positionForBlockLayout:layout
                                                             localOffset:movingLocalOffset
                                                                affinity:direction
                                                           tracksChanges:NO];
            NSUInteger movingOffset = [self id_canonicalOffsetForPosition:moving];
            NSUInteger visualAnchorLocalOffset = anchorLocation.localOffset;
            NSUInteger oppositeAnchorLocalOffset = anchorOffset < extentOffset
                ? anchorLayout.contentStorage.textStorage.length
                : 0;
            id<NSTextLocation> visualAnchorLocation =
                [anchorLayout locationForLocalOffset:anchorLocation.localOffset];
            id<NSTextLocation> oppositeAnchorLocation =
                [anchorLayout locationForLocalOffset:oppositeAnchorLocalOffset];
            CGRect anchorCaret = [anchorLayout
                caretRectForLocalOffset:anchorLocation.localOffset
                               affinity:direction];
            if (visualAnchorLocation != nil && oppositeAnchorLocation != nil &&
                !CGRectIsNull(anchorCaret)) {
                NSTextSelection *oppositeAnchor = [[NSTextSelection alloc]
                    initWithLocation:oppositeAnchorLocation affinity:affinity];
                NSArray<NSTextSelection *> *anchorSelections =
                    [anchorLayout.layoutManager.textSelectionNavigation
                        textSelectionsInteractingAtPoint:
                            CGPointMake(CGRectGetMidX(anchorCaret), CGRectGetMidY(anchorCaret))
                                   inContainerAtLocation:visualAnchorLocation
                                                  anchors:@[oppositeAnchor]
                                                modifiers:1
                                                 selecting:YES
                                                    bounds:(CGRect){CGPointZero,
                                                                    anchorLayout.textContainer.size}];
                NSTextRange *visualAnchorRange =
                    anchorSelections.firstObject.textRanges.firstObject;
                if (visualAnchorRange != nil) {
                    NSUInteger candidate = [anchorLayout localOffsetForLocation:
                        anchorOffset < extentOffset
                            ? visualAnchorRange.location
                            : visualAnchorRange.endLocation];
                    if (candidate <= anchorLayout.contentStorage.textStorage.length) {
                        visualAnchorLocalOffset = candidate;
                    }
                }
            }
            IDRichTextPosition *visualAnchor = [self
                id_positionForBlockLayout:anchorLayout
                              localOffset:visualAnchorLocalOffset
                                 affinity:direction
                            tracksChanges:NO];
            NSUInteger visualAnchorOffset =
                [self id_canonicalOffsetForPosition:visualAnchor];
            start = [self id_positionForCanonicalOffset:MIN(visualAnchorOffset, movingOffset)
                                                affinity:direction tracksChanges:NO];
            end = [self id_positionForCanonicalOffset:MAX(visualAnchorOffset, movingOffset)
                                              affinity:direction tracksChanges:NO];
        }
        return [[IDRichTextRange alloc] initWithStart:start end:end];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (void)id_enumerateLayoutsForTextRange:(UITextRange *)range
                                   stage:(NSString *)stage
                              usingBlock:(void (^)(IDBlockLayout *, NSRange))block {
    NSRange canonical = [self id_projectedCanonicalRangeForTextRange:range
                                                              clipped:YES
                                                                stage:stage];
    NSArray<IDBlock *> *blocks = self.document.blocks;
    NSUInteger cursor = 0;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        IDBlock *documentBlock = blocks[index];
        NSRange blockRange = NSMakeRange(cursor, documentBlock.attributedText.length);
        NSRange intersection = NSIntersectionRange(canonical, blockRange);
        BOOL emptyInBlock = canonical.length == 0 &&
            canonical.location >= blockRange.location &&
            canonical.location <= NSMaxRange(blockRange);
        BOOL followingSeparator = index + 1 < blocks.count &&
            NSLocationInRange(NSMaxRange(blockRange), canonical);
        BOOL precedingSeparator = index > 0 &&
            NSLocationInRange(blockRange.location - 1, canonical);
        if (intersection.length > 0 || emptyInBlock ||
            followingSeparator || precedingSeparator) {
            IDBlockLayout *layout = [self.id_blockStack
                layoutForBlockIdentifier:documentBlock.identifier];
            NSRange local = intersection.length > 0
                ? NSMakeRange(intersection.location - cursor, intersection.length)
                : NSMakeRange(precedingSeparator
                    ? 0
                    : MIN(canonical.location - cursor, blockRange.length), 0);
            if (layout != nil) block(layout, local);
        }
        cursor = NSMaxRange(blockRange) + (index + 1 < blocks.count ? 1 : 0);
    }
}

- (CGRect)id_boundingRectForCharacterRange:(NSRange)range {
    self.id_boundingRectForCharacterRangeCallCountState += 1;
    UITextRange *textRange = [self id_textRangeForCharacterRange:range];
    UIView *hostView = self.id_blockStack.superview;
    __block CGRect result = CGRectNull;
    [self id_enumerateLayoutsForTextRange:textRange
                                    stage:TGPN_boundingRectForCharacterRange_()
                               usingBlock:^(IDBlockLayout *layout, NSRange localRange) {
        CGRect local = [layout boundingRectForLocalRange:localRange];
        if (CGRectIsNull(local) || !IDRichRectIsFinite(local)) return;
        CGRect converted = hostView == nil
            ? local
            : [layout.canvasView convertRect:local toView:hostView];
        if (!IDRichRectIsFinite(converted)) return;
        result = CGRectIsNull(result) ? converted : CGRectUnion(result, converted);
    }];
    return result;
}

- (void)id_ensureLayoutForRange:(UITextRange *)range {
    [self id_enumerateLayoutsForTextRange:range
                                    stage:@"ensureLayoutForRange:"
                               usingBlock:^(IDBlockLayout *layout, NSRange localRange) {
        id<NSTextLocation> start = [layout locationForLocalOffset:localRange.location];
        id<NSTextLocation> end = [layout locationForLocalOffset:NSMaxRange(localRange)];
        if (start != nil && end != nil) {
            [layout.layoutManager ensureLayoutForRange:[[NSTextRange alloc]
                initWithLocation:start endLocation:end]];
        }
    }];
}

- (void)id_invalidateLayoutForRange:(UITextRange *)range {
    [self id_enumerateLayoutsForTextRange:range
                                    stage:@"invalidateLayoutForRange:"
                               usingBlock:^(IDBlockLayout *layout, NSRange localRange) {
        id<NSTextLocation> start = [layout locationForLocalOffset:localRange.location];
        id<NSTextLocation> end = [layout locationForLocalOffset:NSMaxRange(localRange)];
        if (start != nil && end != nil) {
            [layout.layoutManager invalidateLayoutForRange:[[NSTextRange alloc]
                initWithLocation:start endLocation:end]];
        }
    }];
}

- (nullable id)id_annotationAttribute:(id)attribute
                           atPosition:(UITextPosition *)position {
    IDRichTextPosition *valid = [self id_validPosition:position
                                                stage:TGPN_annotationAttribute_atPosition_()];
    return [self.annotationStore annotationAttribute:attribute
                                   atCanonicalOffset:[self
                                       id_canonicalOffsetForPosition:valid]];
}

- (NSAttributedString *)id_attributedTextInRange:(UITextRange *)range {
    NSRange canonical = [self id_projectedCanonicalRangeForTextRange:range
                                                              clipped:NO
                                                                stage:@"attributedTextInRange:"];
    return [self.textStorageAdapter attributedSubstringFromRange:canonical];
}

- (NSAttributedString *)id_annotatedSubstringForRange:(UITextRange *)range {
    NSRange canonical = [self id_projectedCanonicalRangeForTextRange:range
                                                              clipped:YES
                                                                stage:TGPN_annotatedSubstringForRange_()];
    return [self.annotationStore annotatedSubstringForCanonicalRange:canonical];
}

- (void)id_enumerateTemporaryLayoutsForCanonicalRange:(NSRange)canonical
                                                 stage:(NSString *)stage
                                            usingBlock:(void (^)(IDBlockLayout *, NSTextRange *))block {
    NSUInteger documentLength = self.document.canonicalLength;
    if (!IDRichRangeIsValid(canonical, documentLength)) {
        IDRichRaise(stage, @"range is outside the document");
    }
    if (canonical.length == 0) return;
    NSUInteger cursor = 0;
    for (IDBlock *documentBlock in self.document.blocks) {
        NSRange blockRange = NSMakeRange(cursor, documentBlock.attributedText.length);
        NSRange intersection = NSIntersectionRange(canonical, blockRange);
        if (intersection.length > 0) {
            IDBlockLayout *layout = [self.id_blockStack
                layoutForBlockIdentifier:documentBlock.identifier];
            if (layout == nil) {
                IDRichRaise(stage, @"participating block layout is missing");
            }
            NSRange local = NSMakeRange(intersection.location - cursor,
                                        intersection.length);
            id<NSTextLocation> start = [layout locationForLocalOffset:local.location];
            id<NSTextLocation> end = [layout locationForLocalOffset:NSMaxRange(local)];
            if (start == nil || end == nil) {
                IDRichRaise(stage, @"participating block range has no TextKit 2 locations");
            }
            block(layout, [[NSTextRange alloc] initWithLocation:start endLocation:end]);
        }
        cursor = NSMaxRange(blockRange) + 1;
    }
}

- (NSRange)id_temporaryCanonicalRangeForTextRange:(UITextRange *)range
                                             stage:(NSString *)stage {
    return [self id_projectedCanonicalRangeForTextRange:range
                                                 clipped:YES
                                                   stage:stage];
}

- (void)id_addTemporaryAttribute:(id)attribute
                           value:(id)value
                  canonicalRange:(NSRange)canonical
                            stage:(NSString *)stage {
    [self id_enumerateTemporaryLayoutsForCanonicalRange:canonical
                                                   stage:stage
                                              usingBlock:^(IDBlockLayout *layout,
                                                           NSTextRange *localRange) {
        IDPrivateRichAddTemporaryAttribute(layout.layoutManager,
                                           attribute,
                                           value,
                                           localRange,
                                           stage);
    }];
}

- (void)id_removeTemporaryAttribute:(id)attribute
                      canonicalRange:(NSRange)canonical
                               stage:(NSString *)stage {
    [self id_enumerateTemporaryLayoutsForCanonicalRange:canonical
                                                   stage:stage
                                              usingBlock:^(IDBlockLayout *layout,
                                                           NSTextRange *localRange) {
        IDPrivateRichRemoveTemporaryAttribute(layout.layoutManager,
                                              attribute,
                                              localRange,
                                              stage);
    }];
}

- (void)id_addAnnotationAttribute:(id)attribute
                            value:(id)value
                         forRange:(UITextRange *)range {
    NSString *stage = TGPN_addAnnotationAttribute_value_forRange_();
    NSRange canonical = [self id_temporaryCanonicalRangeForTextRange:range stage:stage];
    [self.annotationStore addAttribute:attribute value:value canonicalRange:canonical];
    [self id_addTemporaryAttribute:attribute
                             value:value
                    canonicalRange:canonical
                              stage:stage];
    [self id_invalidateTemporaryAttributesInRange:range];
}

- (void)id_removeAnnotationAttribute:(id)attribute
                             forRange:(UITextRange *)range {
    NSString *stage = TGPN_removeAnnotationAttribute_forRange_();
    NSRange canonical = [self id_temporaryCanonicalRangeForTextRange:range stage:stage];
    [self.annotationStore removeAttribute:attribute canonicalRange:canonical];
    [self id_removeTemporaryAttribute:attribute canonicalRange:canonical stage:stage];
    [self id_invalidateTemporaryAttributesInRange:range];
}

- (void)id_addRenderingAttributes:(NSDictionary *)attributes
                          forRange:(UITextRange *)range {
    if (![attributes isKindOfClass:NSDictionary.class]) {
        IDRichRaise(TGPN_addRenderingAttributes_forRange_(), @"attributes are not a dictionary");
    }
    NSString *stage = TGPN_addRenderingAttributes_forRange_();
    NSRange canonical = [self id_temporaryCanonicalRangeForTextRange:range stage:stage];
    [attributes enumerateKeysAndObjectsUsingBlock:^(id attribute, id value, BOOL *stop) {
        [self.annotationStore addAttribute:attribute value:value canonicalRange:canonical];
        [self id_addTemporaryAttribute:attribute
                                 value:value
                        canonicalRange:canonical
                                  stage:stage];
    }];
    [self id_invalidateTemporaryAttributesInRange:range];
}

- (void)id_removeRenderingAttributes:(id<NSFastEnumeration>)attributes
                             forRange:(UITextRange *)range {
    if (attributes == nil) {
        IDRichRaise(TGPN_removeRenderingAttributes_forRange_(), @"attribute collection is nil");
    }
    NSString *stage = TGPN_removeRenderingAttributes_forRange_();
    NSRange canonical = [self id_temporaryCanonicalRangeForTextRange:range stage:stage];
    for (id attribute in attributes) {
        [self.annotationStore removeAttribute:attribute canonicalRange:canonical];
        [self id_removeTemporaryAttribute:attribute canonicalRange:canonical stage:stage];
    }
    [self id_invalidateTemporaryAttributesInRange:range];
}

- (void)id_invalidateTemporaryAttributesInRange:(UITextRange *)range {
    NSString *stage = TGPN__invalidateTemporaryAttributesInRange_();
    NSRange canonical = [self id_temporaryCanonicalRangeForTextRange:range stage:stage];
    [self id_enumerateTemporaryLayoutsForCanonicalRange:canonical
                                                   stage:stage
                                              usingBlock:^(IDBlockLayout *layout,
                                                           NSTextRange *localRange) {
        IDPrivateRichInvalidateTemporaryAttributes(layout.canvasView,
                                                   localRange,
                                                   stage);
    }];
}

- (void)id_reapplyTemporaryAttributesForDocumentChange:(IDBlockDocumentChange *)change {
    if (change == nil || change.affectedBlockIdentifiers.count == 0) return;
    NSSet<NSUUID *> *affectedIdentifiers =
        [NSSet setWithArray:change.affectedBlockIdentifiers];
    NSString *stage = @"Reapply temporary attributes after document change";
    NSUInteger cursor = 0;
    NSArray<IDBlock *> *blocks = self.document.blocks;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        IDBlock *block = blocks[index];
        NSRange blockRange = NSMakeRange(cursor, block.attributedText.length);
        if ([affectedIdentifiers containsObject:block.identifier] && blockRange.length > 0) {
            IDBlockLayout *layout = [self.id_blockStack
                layoutForBlockIdentifier:block.identifier];
            if (layout == nil) {
                IDRichRaise(stage, @"affected block layout is missing");
            }
            [self.annotationStore enumerateAttributesInCanonicalRange:blockRange
                usingBlock:^(id<NSCopying> attribute,
                             id value,
                             NSRange canonicalRange) {
                    NSRange localRange = NSMakeRange(
                        canonicalRange.location - blockRange.location,
                        canonicalRange.length);
                    id<NSTextLocation> start =
                        [layout locationForLocalOffset:localRange.location];
                    id<NSTextLocation> end =
                        [layout locationForLocalOffset:NSMaxRange(localRange)];
                    if (start == nil || end == nil) {
                        IDRichRaise(stage, @"affected temporary range has no TextKit 2 locations");
                    }
                    NSTextRange *textRange = [[NSTextRange alloc]
                        initWithLocation:start endLocation:end];
                    IDPrivateRichAddTemporaryAttribute(layout.layoutManager,
                                                       attribute,
                                                       value,
                                                       textRange,
                                                       stage);
                    IDPrivateRichInvalidateTemporaryAttributes(layout.canvasView,
                                                               textRange,
                                                               stage);
                }];
        }
        cursor = NSMaxRange(blockRange) + (index + 1 < blocks.count ? 1 : 0);
    }
}

- (void)id_invalidateDisplayForCharacterRange:(NSRange)range {
    NSUInteger documentLength = self.document.canonicalLength;
    if (!IDRichRangeIsValid(range, documentLength)) {
        IDRichRaise(@"invalidateDisplayForCharacterRange:",
                    @"range is outside the document");
    }

    NSArray<IDBlock *> *blocks = self.document.blocks;
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (range.length == 0) {
        IDCanonicalTextProjection *projection =
            [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        IDCanonicalLocation *location = [projection locationForCanonicalOffset:range.location];
        for (IDBlockLayout *layout in layouts) {
            if ([layout.blockIdentifier isEqual:location.blockIdentifier]) {
                [layout.canvasView setNeedsDisplay];
                return;
            }
        }
        return;
    }

    NSMutableSet<NSUUID *> *invalidated = [NSMutableSet set];
    NSUInteger cursor = 0;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        IDBlock *block = blocks[index];
        NSRange textRange = NSMakeRange(cursor, block.attributedText.length);
        if (NSIntersectionRange(range, textRange).length > 0) {
            [invalidated addObject:block.identifier];
        }
        if (index + 1 < blocks.count) {
            NSRange separatorRange = NSMakeRange(NSMaxRange(textRange), 1);
            if (NSIntersectionRange(range, separatorRange).length > 0) {
                [invalidated addObject:block.identifier];
                [invalidated addObject:blocks[index + 1].identifier];
            }
            cursor = NSMaxRange(separatorRange);
        }
    }
    for (IDBlockLayout *layout in layouts) {
        if ([invalidated containsObject:layout.blockIdentifier]) {
            [layout.canvasView setNeedsDisplay];
        }
    }
}


/// Whether a caret that found no line beyond it in a vertical direction sits on the document's
/// edge line — the line holding `edgeOffset` (the document's end going down, its start going up) —
/// rather than having failed for another reason (a layout not ready, a revision that moved), which
/// must keep answering nil.
- (BOOL)id_canonicalOffset:(NSUInteger)offset
                  affinity:(IDBlockTextAffinity)affinity
       isOnTheLineOfOffset:(NSUInteger)edgeOffset
                  affinity:(IDBlockTextAffinity)edgeAffinity
                  downward:(BOOL)downward {
    if (offset == edgeOffset) {
        return YES;
    }
    IDDocumentCaretGeometry *caret = [self.id_documentLayoutCoordinator
        caretGeometryForCanonicalOffset:offset affinity:affinity];
    IDDocumentCaretGeometry *edge = [self.id_documentLayoutCoordinator
        caretGeometryForCanonicalOffset:edgeOffset affinity:edgeAffinity];
    if (caret == nil || edge == nil) {
        return NO;
    }
    CGRect caretRect = caret.documentRect;
    CGRect edgeRect = edge.documentRect;
    if (!isfinite(CGRectGetMidY(caretRect)) || !isfinite(CGRectGetMidY(edgeRect))) {
        return NO;
    }
    return downward
        ? CGRectGetMidY(caretRect) >= CGRectGetMinY(edgeRect)
        : CGRectGetMidY(caretRect) <= CGRectGetMaxY(edgeRect);
}
@end

#endif
