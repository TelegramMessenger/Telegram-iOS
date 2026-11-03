@import XCTest;

#include <math.h>
#include <stdlib.h>

#import "IDStockSelectionRectExpectation.h"
#import <objc/message.h>
#import <objc/runtime.h>

#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDCanonicalTextProjection.h"
#import "IDDocumentLayoutCoordinator.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextAnchorInternal.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextPosition.h"
#import "IDRichTextRange.h"
#import "IDRichTextSelectionRect.h"
#import "IDTextLayoutCanvasViewInternal.h"

@interface IDUIKitOwnedRangeWrapper : UITextRange
@property(nonatomic, strong) UITextPosition *wrappedStart;
@property(nonatomic, strong) UITextPosition *wrappedEnd;
- (instancetype)initWithStart:(UITextPosition *)start end:(UITextPosition *)end;
@end

@implementation IDUIKitOwnedRangeWrapper

- (instancetype)initWithStart:(UITextPosition *)start end:(UITextPosition *)end {
    self = [super init];
    if (self != nil) {
        _wrappedStart = start;
        _wrappedEnd = end;
    }
    return self;
}

- (UITextPosition *)start {
    return self.wrappedStart;
}

- (UITextPosition *)end {
    return self.wrappedEnd;
}

- (BOOL)isEmpty {
    return [self.wrappedStart isEqual:self.wrappedEnd];
}

@end

@interface IDTask16ScriptedBlockLayout : IDBlockLayout
@property(nonatomic) IDBlockCaretStop firstStop;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *receivedOffsets;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *receivedAffinities;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *receivedAnchorOffsets;
@end

@implementation IDTask16ScriptedBlockLayout

- (IDBlockCaretStop)caretStopFromLocalOffset:(NSUInteger)offset
                                     affinity:(UITextStorageDirection)affinity
                                    direction:(UITextLayoutDirection)direction
                         anchorPositionOffset:(CGFloat)anchorPositionOffset {
    (void)direction;
    [self.receivedOffsets addObject:@(offset)];
    [self.receivedAffinities addObject:@(affinity)];
    [self.receivedAnchorOffsets addObject:@(anchorPositionOffset)];
    return self.receivedOffsets.count == 1
        ? self.firstStop
        : (IDBlockCaretStop){ .found = NO };
}

@end

typedef NS_ENUM(NSInteger, IDCrossBlockMutation) {
    IDCrossBlockMutationNone,
    IDCrossBlockMutationAffinity,
    IDCrossBlockMutationCoherentDestination,
    IDCrossBlockMutationNilResult,
    IDCrossBlockMutationNonexact,
    IDCrossBlockMutationStaleRevision,
    IDCrossBlockMutationInvalidAffinity,
    IDCrossBlockMutationNonfiniteAnchor,
    IDCrossBlockMutationOutOfRange,
    IDCrossBlockMutationIncoherentPosition,
};

@interface IDCrossBlockExitSnapshot : NSObject <IDBlockLayoutSnapshot>
@property(nonatomic, copy) NSUUID *blockIdentifier;
@property(nonatomic) NSUInteger utf16Length;
@property(nonatomic) NSUInteger documentRevision;
@property(nonatomic) NSUInteger contentRevision;
@property(nonatomic) NSUInteger layoutGeneration;
@property(nonatomic) IDBlockLayoutConstraints layoutConstraints;
@property(nonatomic) IDBlockLayoutCapability capabilities;
@property(nonatomic, getter=isValid) BOOL valid;
@property(nonatomic) CGSize usedSize;
@property(nonatomic) IDBlockWritingDirection baseWritingDirection;
@end

@implementation IDCrossBlockExitSnapshot

- (IDBlockCaretGeometry *)caretGeometryForPosition:(IDBlockTextPosition)position {
    if (position.utf16Offset > self.utf16Length) return nil;
    return [[IDBlockCaretGeometry alloc]
        initWithPosition:position
                    rect:CGRectMake(position.utf16Offset * 10.0, 2.0, 2.0, 18.0)
        writingDirection:IDBlockWritingDirectionLeftToRight
          lineIdentifier:[[IDBlockLineIdentifier alloc]
              initWithLocalRange:NSMakeRange(0, self.utf16Length)
                layoutGeneration:self.layoutGeneration]];
}

- (IDBlockCaretNavigationResult)caretNavigationResultForPoint:(CGPoint)point {
    return (IDBlockCaretNavigationResult){
        .found = YES,
        .position = IDBlockTextPositionMake(
            MIN((NSUInteger)floor(MAX(point.x, 0.0) / 10.0), self.utf16Length),
            IDBlockTextAffinityDownstream),
        .anchorPositionOffset = point.x,
    };
}

- (NSRange)lineRangeEnclosingPosition:(IDBlockTextPosition)position
                     resolvedAffinity:(IDBlockTextAffinity *)affinity {
    if (affinity != NULL) *affinity = position.affinity;
    return NSMakeRange(0, self.utf16Length);
}

- (IDBlockWritingDirection)id_snapshotBaseWritingDirectionAtPosition:
    (IDBlockTextPosition)position {
    (void)position;
    return self.baseWritingDirection;
}

- (IDBlockCaretNavigationResult)caretNavigationResultFromPosition:
    (IDBlockTextPosition)position
                                                    direction:
    (IDBlockLayoutDirection)direction
                                         anchorPositionOffset:
    (CGFloat)anchorPositionOffset {
    (void)direction;
    return (IDBlockCaretNavigationResult){
        .found = NO,
        .position = position,
        .anchorPositionOffset = anchorPositionOffset,
    };
}

@end

@interface IDCrossBlockHybridSource : NSObject <IDDocumentLayoutSnapshotSource>
@property(nonatomic, weak) IDBlockDocument *document;
@property(nonatomic, strong) IDBlockStackCanvasView *stack;
@property(nonatomic, copy) NSUUID *exitIdentifier;
@property(nonatomic, strong) IDCrossBlockExitSnapshot *exitSnapshot;
@end

@implementation IDCrossBlockHybridSource

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    return [self.stack
        selectionGeometryEligibilityForDocumentRevision:documentRevision];
}

- (NSArray<NSUUID *> *)orderedBlockIdentifiers {
    return [self.document.blocks valueForKey:@"identifier"];
}

- (id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:(NSUUID *)identifier
                                        documentRevision:(NSUInteger)documentRevision {
    if (![identifier isEqual:self.exitIdentifier]) {
        return [self.stack snapshotForBlockIdentifier:identifier
                                     documentRevision:documentRevision];
    }
    IDBlock *block = self.document.blocks.firstObject;
    self.exitSnapshot.blockIdentifier = identifier;
    self.exitSnapshot.utf16Length = block.attributedText.length;
    self.exitSnapshot.documentRevision = documentRevision;
    self.exitSnapshot.contentRevision = 1;
    self.exitSnapshot.layoutGeneration = 1;
    self.exitSnapshot.layoutConstraints = IDBlockLayoutConstraintsMake(200.0, 1.0);
    self.exitSnapshot.capabilities = IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilityPointHitTesting |
        IDBlockLayoutCapabilityLineRanges |
        IDBlockLayoutCapabilityVisualNavigation |
        IDBlockLayoutCapabilityBaseWritingDirection;
    self.exitSnapshot.valid = YES;
    self.exitSnapshot.usedSize = CGSizeMake(200.0, 20.0);
    return self.exitSnapshot;
}

- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier {
    return [self.stack documentOriginForBlockIdentifier:identifier];
}

- (NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point {
    return [self.stack nearestBlockIdentifierForDocumentPoint:point];
}

@end

@interface IDCrossBlockMutatingCoordinator : IDDocumentLayoutCoordinator
@property(nonatomic) IDCrossBlockMutation mutation;
@property(nonatomic) NSUInteger navigationCallCount;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *receivedAnchors;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *returnedCanonicalOffsets;
@property(nonatomic, strong) id retainedSource;
@property(nonatomic) NSUInteger nonexactOnCall;
@property(nonatomic) NSUInteger nilOnCall;
@property(nonatomic) NSUInteger mutateDocumentAfterCall;
@end

@implementation IDCrossBlockMutatingCoordinator

- (IDDocumentCaretNavigationResult *)
    visuallyAdjacentPositionFromCanonicalOffset:(NSUInteger)offset
                                        affinity:(IDBlockTextAffinity)affinity
                                       direction:(IDBlockLayoutDirection)direction
                            anchorPositionOffset:(CGFloat)anchorPositionOffset {
    self.navigationCallCount += 1;
    [self.receivedAnchors addObject:@(anchorPositionOffset)];
    IDDocumentCaretNavigationResult *result = [super
        visuallyAdjacentPositionFromCanonicalOffset:offset
                                          affinity:affinity
                                         direction:direction
                              anchorPositionOffset:anchorPositionOffset];
    if (result != nil) {
        [self.returnedCanonicalOffsets addObject:@(result.position.canonicalOffset)];
    }
    if (self.mutateDocumentAfterCall == self.navigationCallCount) {
        [self.document replaceCanonicalRange:
            NSMakeRange(self.document.canonicalLength, 0)
                         withAttributedString:[[NSAttributedString alloc]
                             initWithString:@"x"]];
    }
    if (self.nilOnCall == self.navigationCallCount) {
        return nil;
    }
    if (result != nil && self.nonexactOnCall == self.navigationCallCount) {
        [result setValue:@NO forKey:@"exact"];
    }
    if (self.mutation == IDCrossBlockMutationNilResult) {
        return nil;
    }
    if (result == nil || !result.exact || self.mutation == IDCrossBlockMutationNone) {
        return result;
    }
    if (self.mutation == IDCrossBlockMutationAffinity) {
        IDBlockTextPosition position = result.position.localPosition;
        position.affinity = position.affinity == IDBlockTextAffinityUpstream
            ? IDBlockTextAffinityDownstream
            : IDBlockTextAffinityUpstream;
        [result.position setValue:[NSValue valueWithBytes:&position
                                                 objCType:@encode(IDBlockTextPosition)]
                          forKey:@"localPosition"];
    } else if (self.mutation == IDCrossBlockMutationCoherentDestination) {
        NSUInteger destinationOffset = result.position.canonicalOffset + 1;
        IDBlockTextPosition local = result.position.localPosition;
        local.utf16Offset += 1;
        [result.position setValue:@(destinationOffset) forKey:@"canonicalOffset"];
        [result.position setValue:[NSValue valueWithBytes:&local
                                                 objCType:@encode(IDBlockTextPosition)]
                          forKey:@"localPosition"];
    } else if (self.mutation == IDCrossBlockMutationNonexact) {
        [result setValue:@NO forKey:@"exact"];
    } else if (self.mutation == IDCrossBlockMutationStaleRevision) {
        [result.position setValue:@(result.position.documentRevision + 1)
                          forKey:@"documentRevision"];
    } else if (self.mutation == IDCrossBlockMutationInvalidAffinity) {
        IDBlockTextPosition local = result.position.localPosition;
        local.affinity = (IDBlockTextAffinity)99;
        [result.position setValue:[NSValue valueWithBytes:&local
                                                 objCType:@encode(IDBlockTextPosition)]
                          forKey:@"localPosition"];
    } else if (self.mutation == IDCrossBlockMutationNonfiniteAnchor) {
        [result setValue:@(NAN) forKey:@"anchorPositionOffset"];
    } else if (self.mutation == IDCrossBlockMutationOutOfRange) {
        [result.position setValue:@(self.document.canonicalLength + 1)
                          forKey:@"canonicalOffset"];
    } else if (self.mutation == IDCrossBlockMutationIncoherentPosition) {
        IDBlockTextPosition local = result.position.localPosition;
        local.utf16Offset += 1;
        [result.position setValue:[NSValue valueWithBytes:&local
                                                 objCType:@encode(IDBlockTextPosition)]
                          forKey:@"localPosition"];
    }
    return result;
}

@end

typedef NS_ENUM(NSInteger, IDGeometryMutation) {
    IDGeometryMutationNone,
    IDGeometryMutationNilResult,
    IDGeometryMutationNonexact,
    IDGeometryMutationStaleRevision,
    IDGeometryMutationNonfiniteRectangle,
    IDGeometryMutationWrongBlockIdentity,
    IDGeometryMutationIncoherentLocalOffset,
    IDGeometryMutationIncoherentCanonicalOffset,
    IDGeometryMutationInvalidAffinity,
    IDGeometryMutationInvalidLineRange,
};

@interface IDGeometryMutatingCoordinator : IDDocumentLayoutCoordinator
@property(nonatomic, strong) IDDocumentCaretGeometry *caretResult;
@property(nonatomic, strong) IDDocumentTextPosition *pointResult;
@property(nonatomic, strong) IDDocumentLineGeometry *lineResult;
@property(nonatomic, strong, nullable) IDDocumentSelectionGeometry *selectionResult;
@property(nonatomic) IDGeometryMutation mutation;
@property(nonatomic) BOOL mutateDocumentAfterResult;
@property(nonatomic) NSUInteger caretCallCount;
@property(nonatomic) NSUInteger pointCallCount;
@property(nonatomic) NSUInteger lineCallCount;
@property(nonatomic) NSUInteger selectionCallCount;
@end

@implementation IDGeometryMutatingCoordinator

- (void)applyPositionMutation:(IDDocumentTextPosition *)position {
    if (self.mutation == IDGeometryMutationStaleRevision) {
        [position setValue:@(position.documentRevision + 1)
                    forKey:@"documentRevision"];
    } else if (self.mutation == IDGeometryMutationWrongBlockIdentity) {
        [position setValue:NSUUID.UUID forKey:@"blockIdentifier"];
    } else if (self.mutation == IDGeometryMutationIncoherentLocalOffset) {
        IDBlockTextPosition local = position.localPosition;
        local.utf16Offset += 1;
        [position setValue:[NSValue valueWithBytes:&local
                                           objCType:@encode(IDBlockTextPosition)]
                    forKey:@"localPosition"];
    } else if (self.mutation == IDGeometryMutationIncoherentCanonicalOffset) {
        [position setValue:@(position.canonicalOffset + 1)
                    forKey:@"canonicalOffset"];
    } else if (self.mutation == IDGeometryMutationInvalidAffinity) {
        IDBlockTextPosition local = position.localPosition;
        local.affinity = (IDBlockTextAffinity)99;
        [position setValue:[NSValue valueWithBytes:&local
                                           objCType:@encode(IDBlockTextPosition)]
                    forKey:@"localPosition"];
    }
}

- (void)mutateDocumentIfRequested {
    if (!self.mutateDocumentAfterResult) return;
    [self.document replaceCanonicalRange:NSMakeRange(self.document.canonicalLength, 0)
                    withAttributedString:[[NSAttributedString alloc]
                        initWithString:@"!"]];
}

- (IDDocumentCaretGeometry *)caretGeometryForCanonicalOffset:(NSUInteger)offset
                                                     affinity:(IDBlockTextAffinity)affinity {
    (void)offset;
    (void)affinity;
    self.caretCallCount += 1;
    if (self.mutation == IDGeometryMutationNilResult) return nil;
    if (self.mutation == IDGeometryMutationNonexact) {
        [self.caretResult setValue:@NO forKey:@"exact"];
    } else if (self.mutation == IDGeometryMutationNonfiniteRectangle) {
        [self.caretResult setValue:[NSValue valueWithCGRect:
            CGRectMake(NAN, 0, 2, 18)] forKey:@"documentRect"];
    }
    [self applyPositionMutation:self.caretResult.position];
    [self mutateDocumentIfRequested];
    return self.caretResult;
}

- (IDDocumentTextPosition *)nearestPositionToDocumentPoint:(CGPoint)point {
    (void)point;
    self.pointCallCount += 1;
    if (self.mutation == IDGeometryMutationNilResult) return nil;
    [self applyPositionMutation:self.pointResult];
    [self mutateDocumentIfRequested];
    return self.pointResult;
}

- (IDDocumentLineGeometry *)lineGeometryForCanonicalOffset:(NSUInteger)offset
                                                   affinity:(IDBlockTextAffinity)affinity {
    (void)offset;
    (void)affinity;
    self.lineCallCount += 1;
    if (self.mutation == IDGeometryMutationNilResult) return nil;
    if (self.mutation == IDGeometryMutationNonexact) {
        [self.lineResult setValue:@NO forKey:@"exact"];
    } else if (self.mutation == IDGeometryMutationInvalidAffinity) {
        [self.lineResult setValue:@((IDBlockTextAffinity)99)
                           forKey:@"resolvedAffinity"];
    } else if (self.mutation == IDGeometryMutationInvalidLineRange) {
        [self.lineResult setValue:[NSValue valueWithRange:
            NSMakeRange(self.document.canonicalLength, 2)]
                           forKey:@"canonicalRange"];
    }
    [self applyPositionMutation:self.lineResult.position];
    [self mutateDocumentIfRequested];
    return self.lineResult;
}

- (IDDocumentSelectionGeometry *)selectionGeometryForCanonicalRange:
    (NSRange)range {
    (void)range;
    self.selectionCallCount += 1;
    if (self.mutation == IDGeometryMutationNilResult) return nil;
    [self mutateDocumentIfRequested];
    return self.selectionResult;
}

@end

static IDDocumentTextPosition *IDGeometryPosition(IDBlockDocument *document,
                                                   NSUInteger offset,
                                                   IDBlockTextAffinity affinity) {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:offset];
    IDBlockTextPosition local =
        IDBlockTextPositionMake(location.localOffset, affinity);
    IDDocumentTextPosition *position = [IDDocumentTextPosition new];
    [position setValue:location.blockIdentifier forKey:@"blockIdentifier"];
    [position setValue:[NSValue valueWithBytes:&local
                                       objCType:@encode(IDBlockTextPosition)]
                forKey:@"localPosition"];
    [position setValue:@(offset) forKey:@"canonicalOffset"];
    [position setValue:@(document.documentRevision) forKey:@"documentRevision"];
    return position;
}

static IDDocumentCaretGeometry *IDGeometryCaret(
    IDDocumentTextPosition *position, CGRect rect) {
    IDDocumentCaretGeometry *geometry = [IDDocumentCaretGeometry new];
    [geometry setValue:position forKey:@"position"];
    [geometry setValue:[NSValue valueWithCGRect:rect] forKey:@"documentRect"];
    [geometry setValue:@YES forKey:@"exact"];
    return geometry;
}

static IDDocumentLineGeometry *IDGeometryLine(
    IDDocumentTextPosition *position, NSRange range,
    IDBlockTextAffinity affinity) {
    IDDocumentLineGeometry *geometry = [IDDocumentLineGeometry new];
    [geometry setValue:position forKey:@"position"];
    [geometry setValue:[NSValue valueWithRange:range] forKey:@"canonicalRange"];
    [geometry setValue:@(affinity) forKey:@"resolvedAffinity"];
    [geometry setValue:@YES forKey:@"exact"];
    return geometry;
}

@interface IDRichTextLayoutControllerTests : XCTestCase
@end

@implementation IDRichTextLayoutControllerTests

static void IDAssertRectsEqual(XCTestCase *testCase,
                               CGRect actual,
                               CGRect expected,
                               CGFloat accuracy) {
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, accuracy);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, accuracy);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, accuracy);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, accuracy);
    (void)testCase;
}

static NSArray *IDObjectIvarValues(id object) {
    NSMutableArray *values = [NSMutableArray array];
    for (Class cls = [object class]; cls != Nil; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index += 1) {
            const char *type = ivar_getTypeEncoding(ivars[index]);
            if (type != NULL && type[0] == '@') {
                id value = object_getIvar(object, ivars[index]);
                if (value != nil) [values addObject:value];
            }
        }
        free(ivars);
    }
    return values.copy;
}

- (IDBlockDocument *)documentWithBlocks:(NSArray<NSString *> *)strings {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string]];
    }
    return [[IDBlockDocument alloc] initWithAttributedBlocks:blocks
                                           defaultAttributes:@{}];
}

- (IDBlockLayout *)layoutForSingleBlock:(NSString *)text width:(CGFloat)width {
    IDBlockDocument *document = [self documentWithBlocks:@[text]];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:width];
    return stack.blockLayouts.firstObject;
}

- (IDRichTextLayoutController *)controllerForDocument:(IDBlockDocument *)document
                                                stack:(IDBlockStackCanvasView * __autoreleasing *)stack {
    IDBlockStackCanvasView *createdStack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [createdStack updateForDocumentChange:nil width:200.0];
    if (stack != NULL) {
        *stack = createdStack;
    }
    IDCanonicalTextStorageAdapter *adapter = [[IDCanonicalTextStorageAdapter alloc]
        initWithDocument:document];
    return [[IDRichTextLayoutController alloc] initWithDocument:document
                                             textStorageAdapter:adapter
                                                      blockStack:createdStack];
}

- (IDGeometryMutatingCoordinator *)geometryCoordinatorForDocument:
    (IDBlockDocument *)document
                                                           stack:
    (IDBlockStackCanvasView *)stack {
    IDGeometryMutatingCoordinator *coordinator =
        [[IDGeometryMutatingCoordinator alloc] initWithDocument:document source:stack];
    coordinator.caretResult = IDGeometryCaret(
        IDGeometryPosition(document, 3, IDBlockTextAffinityDownstream),
        CGRectMake(31, 7, 2, 18));
    coordinator.pointResult =
        IDGeometryPosition(document, 3, IDBlockTextAffinityDownstream);
    coordinator.lineResult = IDGeometryLine(
        IDGeometryPosition(document, 3, IDBlockTextAffinityDownstream),
        NSMakeRange(0, document.canonicalLength),
        IDBlockTextAffinityDownstream);
    return coordinator;
}

- (void)assertCaretGeometryFailsClosedForMutation:(IDGeometryMutation)mutation
                            mutateDocumentAfterResult:(BOOL)mutateDocument {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [self geometryCoordinatorForDocument:document stack:stack];
    coordinator.mutation = mutation;
    coordinator.mutateDocumentAfterResult = mutateDocument;
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];
    IDRichTextPosition *position = [controller positionForCanonicalOffset:3
                                                                 affinity:UITextStorageDirectionForward];

    CGRect result = [controller id_insertionRectForPosition:position
                                           typingAttributes:@{}
                                      placeholderAttachment:nil
                                              textContainer:NULL];

    XCTAssertTrue(CGRectIsNull(result), @"mutation=%ld", (long)mutation);
    XCTAssertEqual(coordinator.caretCallCount, 1U);
}

- (void)assertPointGeometryFailsClosedForMutation:(IDGeometryMutation)mutation
                            mutateDocumentAfterResult:(BOOL)mutateDocument {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [self geometryCoordinatorForDocument:document stack:stack];
    coordinator.mutation = mutation;
    coordinator.mutateDocumentAfterResult = mutateDocument;
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];

    UITextPosition *result = [controller id_nearestPositionAtPoint:CGPointMake(12, 10)
                                                       inContainer:controller.id_interactionTextContainer];

    XCTAssertNil(result, @"mutation=%ld", (long)mutation);
    XCTAssertEqual(coordinator.pointCallCount, 1U);
}

- (void)assertLineGeometryFailsClosedForMutation:(IDGeometryMutation)mutation
                           mutateDocumentAfterResult:(BOOL)mutateDocument {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [self geometryCoordinatorForDocument:document stack:stack];
    coordinator.mutation = mutation;
    coordinator.mutateDocumentAfterResult = mutateDocument;
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];
    IDRichTextPosition *position = [controller positionForCanonicalOffset:3
                                                                 affinity:UITextStorageDirectionForward];

    UITextRange *result = [controller
        id_textRangeForLineEnclosingPosition:position
                           effectiveAffinity:UITextStorageDirectionForward];

    XCTAssertNil(result, @"mutation=%ld", (long)mutation);
    XCTAssertEqual(coordinator.lineCallCount, 1U);
}

- (IDRichTextLayoutController *)crossBlockControllerForBlocks:
    (NSArray<NSString *> *)blocks
                                             coordinator:
    (IDCrossBlockMutatingCoordinator * __autoreleasing *)coordinatorOut
                                                   stack:
    (IDBlockStackCanvasView * __autoreleasing *)stackOut {
    IDBlockDocument *document = [self documentWithBlocks:blocks];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDBlockLayout *original = stack.blockLayouts.firstObject;
    IDTask16ScriptedBlockLayout *scripted = [[IDTask16ScriptedBlockLayout alloc]
        initWithBlock:document.blocks.firstObject width:200.0];
    scripted.receivedOffsets = [NSMutableArray array];
    scripted.receivedAffinities = [NSMutableArray array];
    scripted.receivedAnchorOffsets = [NSMutableArray array];
    scripted.firstStop = (IDBlockCaretStop){ .found = NO };
    scripted.canvasView.frame = original.canvasView.frame;
    scripted.canvasView.bounds = original.canvasView.bounds;
    [original.canvasView removeFromSuperview];
    [stack insertSubview:scripted.canvasView atIndex:0];

    NSMutableArray<IDBlockLayout *> *layouts = stack.blockLayouts.mutableCopy;
    layouts[0] = scripted;
    NSMutableDictionary<NSUUID *, IDBlockLayout *> *layoutsByIdentifier =
        [NSMutableDictionary dictionary];
    for (IDBlockLayout *layout in layouts) {
        layoutsByIdentifier[layout.blockIdentifier] = layout;
    }
    [stack setValue:layouts.copy forKey:@"blockLayouts"];
    [stack setValue:layoutsByIdentifier.copy forKey:@"layoutsByIdentifier"];

    IDCrossBlockHybridSource *source = [IDCrossBlockHybridSource new];
    source.document = document;
    source.stack = stack;
    source.exitIdentifier = document.blocks.firstObject.identifier;
    source.exitSnapshot = [IDCrossBlockExitSnapshot new];
    NSString *firstText = blocks.firstObject;
    source.exitSnapshot.baseWritingDirection = firstText.length > 0 &&
        [[NSCharacterSet characterSetWithRange:NSMakeRange(0x0590, 0x70)]
            characterIsMember:[firstText characterAtIndex:0]]
        ? IDBlockWritingDirectionRightToLeft
        : IDBlockWritingDirectionLeftToRight;
    IDCrossBlockMutatingCoordinator *coordinator =
        [[IDCrossBlockMutatingCoordinator alloc] initWithDocument:document
                                                            source:source];
    coordinator.receivedAnchors = [NSMutableArray array];
    coordinator.returnedCanonicalOffsets = [NSMutableArray array];
    coordinator.retainedSource = source;
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];
    if (coordinatorOut != NULL) *coordinatorOut = coordinator;
    if (stackOut != NULL) *stackOut = stack;
    return controller;
}

- (void)makeEstablishedOracleIneligibleInStack:(IDBlockStackCanvasView *)stack {
    for (IDBlockLayout *layout in stack.blockLayouts) {
        CGRect frame = layout.canvasView.frame;
        frame.origin.x += 73.0;
        layout.canvasView.frame = frame;
    }
}

- (nullable IDRichTextPosition *)neutralAuthorityResultForMutation:
    (IDCrossBlockMutation)mutation
                                                        direction:
    (UITextLayoutDirection)direction
                                                      sourceOffset:
    (NSUInteger)sourceOffset
                                                            anchor:
    (CGFloat)anchor
                                                       coordinator:
    (IDCrossBlockMutatingCoordinator * __autoreleasing *)coordinatorOut {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self
        crossBlockControllerForBlocks:@[@"abc", @"def"]
                           coordinator:&coordinator
                                 stack:&stack];
    coordinator.mutation = mutation;
    [self makeEstablishedOracleIneligibleInStack:stack];
    IDRichTextPosition *source = [controller
        positionForCanonicalOffset:sourceOffset
                          affinity:UITextStorageDirectionForward];
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:source
                    inDirection:direction
                         offset:1
                       affinity:UITextStorageDirectionForward
           anchorPositionOffset:anchor];
    if (coordinatorOut != NULL) *coordinatorOut = coordinator;
    return result;
}

- (void)testNeutralCoordinatorOwnsHorizontalDestinationWhenOracleIsIneligible {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDRichTextPosition *result = [self
        neutralAuthorityResultForMutation:IDCrossBlockMutationCoherentDestination
                                direction:UITextLayoutDirectionRight
                              sourceOffset:3
                                    anchor:17.0
                               coordinator:&coordinator];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.anchor.localOffset, 1U);
    IDCanonicalTextProjection *projection = [[IDCanonicalTextProjection alloc]
        initWithDocument:coordinator.document];
    XCTAssertEqual([result.anchor canonicalOffsetInProjection:projection], 5U);
    XCTAssertEqual(coordinator.navigationCallCount, 1U);
}

- (void)testNeutralCoordinatorOwnsVerticalDestinationAndAffinityWhenOracleIsIneligible {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDRichTextPosition *result = [self
        neutralAuthorityResultForMutation:IDCrossBlockMutationAffinity
                                direction:UITextLayoutDirectionDown
                              sourceOffset:1
                                    anchor:17.0
                               coordinator:&coordinator];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.affinity, UITextStorageDirectionBackward);
    XCTAssertEqual(coordinator.navigationCallCount, 1U);
}

- (void)testNeutralCoordinatorOwnsPositiveNegativeAndMultiStepCallbacks {
    NSArray<NSDictionary<NSString *, id> *> *fixtures = @[
        @{@"blocks": @[@"ab", @"cd"], @"source": @2,
          @"direction": @(UITextLayoutDirectionRight)},
        @{@"blocks": @[@"אב", @"גד"], @"source": @2,
          @"direction": @(UITextLayoutDirectionLeft)},
        @{@"blocks": @[@"abc אבג", @"דהו xyz"], @"source": @5,
          @"direction": @(UITextLayoutDirectionRight)},
        @{@"blocks": @[@"A👨‍👩‍👧‍👦", @"B"], @"source": @12,
          @"direction": @(UITextLayoutDirectionRight)},
        @{@"blocks": @[@"", @"", @"x"], @"source": @2,
          @"direction": @(UITextLayoutDirectionRight)},
    ];
    for (NSDictionary<NSString *, id> *fixture in fixtures) {
        for (NSNumber *signedOffset in @[@1, @2, @(-1), @(-2)]) {
            IDCrossBlockMutatingCoordinator *coordinator = nil;
            IDBlockStackCanvasView *stack = nil;
            IDRichTextLayoutController *controller = [self
                crossBlockControllerForBlocks:fixture[@"blocks"]
                                   coordinator:&coordinator
                                         stack:&stack];
            [self makeEstablishedOracleIneligibleInStack:stack];
            IDRichTextPosition *source = [controller
                positionForCanonicalOffset:[fixture[@"source"] unsignedIntegerValue]
                                  affinity:UITextStorageDirectionForward];
            (void)[controller
                id_positionFromPosition:source
                            inDirection:[fixture[@"direction"] integerValue]
                                 offset:signedOffset.integerValue
                               affinity:UITextStorageDirectionForward
                   anchorPositionOffset:17.0];
            XCTAssertEqual(coordinator.navigationCallCount,
                           (NSUInteger)labs(signedOffset.integerValue),
                           @"fixture=%@ offset=%@", fixture, signedOffset);
        }
    }
}

- (void)testNeutralCoordinatorPreservesTracksChangesOnReturnedPosition {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDRichTextPosition *result = [self
        neutralAuthorityResultForMutation:IDCrossBlockMutationNone
                                direction:UITextLayoutDirectionRight
                              sourceOffset:3
                                    anchor:17.0
                               coordinator:&coordinator];

    XCTAssertNotNil(result);
    XCTAssertTrue(result.anchor.id_tracksChanges);
    XCTAssertEqual(coordinator.navigationCallCount, 1U);
}

- (void)assertNeutralAuthorityFailsClosedForMutation:
    (IDCrossBlockMutation)mutation {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDRichTextPosition *result = [self
        neutralAuthorityResultForMutation:mutation
                                direction:UITextLayoutDirectionRight
                              sourceOffset:3
                                    anchor:17.0
                               coordinator:&coordinator];
    XCTAssertNil(result, @"mutation=%ld", (long)mutation);
    XCTAssertEqual(coordinator.navigationCallCount, 1U,
                   @"mutation=%ld", (long)mutation);
}

- (void)testNeutralAuthorityReturnsNilForAbsentOrNonexactResult {
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationNilResult];
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationNonexact];
}

- (void)testNeutralAuthorityReturnsNilForStaleRevisionAndInvalidAffinity {
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationStaleRevision];
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationInvalidAffinity];
}

- (void)testNeutralAuthorityReturnsNilForNonfiniteAnchorAndOutOfRangeDestination {
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationNonfiniteAnchor];
    [self assertNeutralAuthorityFailsClosedForMutation:IDCrossBlockMutationOutOfRange];
}

- (void)testNeutralAuthorityReturnsNilForIncoherentBlockLocalPosition {
    [self assertNeutralAuthorityFailsClosedForMutation:
        IDCrossBlockMutationIncoherentPosition];
}

- (void)testNeutralAuthorityRejectsNonfiniteInputAnchorWithoutCallingCoordinator {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDRichTextPosition *result = [self
        neutralAuthorityResultForMutation:IDCrossBlockMutationNone
                                direction:UITextLayoutDirectionRight
                              sourceOffset:3
                                    anchor:NAN
                               coordinator:&coordinator];
    XCTAssertNil(result);
    XCTAssertEqual(coordinator.navigationCallCount, 0U);
}

- (void)testNeutralAuthorityRejectsRevisionChangeAfterExactCoordinatorReturn {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self
        crossBlockControllerForBlocks:@[@"abc", @"def"]
                           coordinator:&coordinator
                                 stack:&stack];
    [self makeEstablishedOracleIneligibleInStack:stack];
    coordinator.mutateDocumentAfterCall = 1;
    IDRichTextPosition *source = [controller
        positionForCanonicalOffset:1 affinity:UITextStorageDirectionForward];

    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:source
                    inDirection:UITextLayoutDirectionRight
                         offset:2
                       affinity:UITextStorageDirectionForward
           anchorPositionOffset:17.0];

    XCTAssertNil(result);
    XCTAssertEqual(coordinator.navigationCallCount, 1U);
    XCTAssertEqual(coordinator.returnedCanonicalOffsets.count, 1U);
}

- (void)testNeutralAuthorityRejectsWholeCallbackWhenLaterStepIsNonexact {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self
        crossBlockControllerForBlocks:@[@"abc", @"def"]
                           coordinator:&coordinator
                                 stack:&stack];
    [self makeEstablishedOracleIneligibleInStack:stack];
    coordinator.nonexactOnCall = 2;
    IDRichTextPosition *source = [controller
        positionForCanonicalOffset:1 affinity:UITextStorageDirectionForward];

    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:source
                    inDirection:UITextLayoutDirectionRight
                         offset:2
                       affinity:UITextStorageDirectionForward
           anchorPositionOffset:17.0];

    XCTAssertNil(result);
    XCTAssertEqual(coordinator.navigationCallCount, 2U);
    XCTAssertEqual(coordinator.returnedCanonicalOffsets.count, 2U);
}

- (void)testNeutralAuthorityDoesNotPublishIntermediateMultiStepDestination {
    IDCrossBlockMutatingCoordinator *coordinator = nil;
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self
        crossBlockControllerForBlocks:@[@"abc", @"def"]
                           coordinator:&coordinator
                                 stack:&stack];
    [self makeEstablishedOracleIneligibleInStack:stack];
    coordinator.nilOnCall = 2;
    IDRichTextPosition *source = [controller
        positionForCanonicalOffset:1 affinity:UITextStorageDirectionForward];

    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:source
                    inDirection:UITextLayoutDirectionRight
                         offset:2
                       affinity:UITextStorageDirectionForward
           anchorPositionOffset:17.0];

    XCTAssertNil(result);
    XCTAssertEqual(coordinator.navigationCallCount, 2U);
    XCTAssertEqual(coordinator.returnedCanonicalOffsets.count, 2U);
    XCTAssertNotEqual(coordinator.returnedCanonicalOffsets.firstObject
                          .unsignedIntegerValue,
                      1U);
}

- (void)testSpellingBoundingRectUsesStandardTextKitSegments {
    IDBlockLayout *layout = [self layoutForSingleBlock:@"one two" width:200.0];
    NSRange localRange = NSMakeRange(0, 3);
    id<NSTextLocation> start = [layout locationForLocalOffset:localRange.location];
    id<NSTextLocation> end = [layout locationForLocalOffset:NSMaxRange(localRange)];
    NSTextRange *textRange = [[NSTextRange alloc] initWithLocation:start endLocation:end];
    [layout.layoutManager ensureLayoutForRange:textRange];
    __block CGRect expected = CGRectNull;
    [layout.layoutManager enumerateTextSegmentsInRange:textRange
                                                  type:NSTextLayoutManagerSegmentTypeStandard
                                               options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                            usingBlock:^BOOL(NSTextRange *segmentRange,
                                                              CGRect frame,
                                                              CGFloat baseline,
                                                              NSTextContainer *container) {
        (void)segmentRange;
        (void)baseline;
        (void)container;
        expected = CGRectIsNull(expected) ? frame : CGRectUnion(expected, frame);
        return YES;
    }];

    CGRect actual = [layout boundingRectForLocalRange:localRange];
    XCTAssertFalse(CGRectIsNull(expected));
    IDAssertRectsEqual(self, actual, expected, 0.001);
}

- (void)testSpellingBoundingRectComposesIndependentBlocksInHostCoordinates {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 300)];
    stack.frame = CGRectMake(9, 13, 200, 200);
    [host addSubview:stack];
    [stack setNeedsLayout];
    [stack layoutIfNeeded];

    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    CGRect firstLocal = [first boundingRectForLocalRange:NSMakeRange(2, 3)];
    CGRect secondLocal = [second boundingRectForLocalRange:NSMakeRange(0, 2)];
    CGRect expected = CGRectUnion([first.canvasView convertRect:firstLocal toView:host],
                                  [second.canvasView convertRect:secondLocal toView:host]);
    NSUInteger requestsBefore = controller.id_boundingRectForCharacterRangeCallCount;
    CGRect actual = [controller id_boundingRectForCharacterRange:NSMakeRange(2, 6)];

    IDAssertRectsEqual(self, actual, expected, 0.001);
    XCTAssertEqual(controller.id_boundingRectForCharacterRangeCallCount,
                   requestsBefore + 1);

    CGRect secondOnlyLocal = [second boundingRectForLocalRange:NSMakeRange(1, 2)];
    CGRect expectedSecondOnly = [second.canvasView convertRect:secondOnlyLocal toView:host];
    CGRect actualSecondOnly =
        [controller id_boundingRectForCharacterRange:NSMakeRange(7, 2)];

    IDAssertRectsEqual(self, actualSecondOnly, expectedSecondOnly, 0.001);
    XCTAssertEqual(controller.id_boundingRectForCharacterRangeCallCount,
                   requestsBefore + 2);
}

- (IDBlockDocument *)task16DocumentWithBlocks:(NSArray<NSString *> *)strings {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
    };
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
                                                         attributes:attributes]];
    }
    return [[IDBlockDocument alloc] initWithAttributedBlocks:blocks
                                           defaultAttributes:attributes];
}

- (CGRect)task16DocumentCaretForPosition:(IDRichTextPosition *)position
                              controller:(IDRichTextLayoutController *)controller
                                   stack:(IDBlockStackCanvasView *)stack {
    IDCanonicalTextProjection *projection = [[IDCanonicalTextProjection alloc]
        initWithDocument:controller.document];
    NSUInteger canonical = [controller id_canonicalOffsetForPosition:position];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:canonical];
    IDBlockLayout *layout = [stack layoutForBlockIdentifier:location.blockIdentifier];
    CGRect local = [layout caretRectForLocalOffset:location.localOffset
                                          affinity:position.affinity];
    return [layout.canvasView convertRect:local toView:stack];
}

- (NSArray<UITextSelectionRect *> *)stockSelectionRectsForText:(NSString *)text
                                                          range:(NSRange)range
                                                          width:(CGFloat)width {
    UITextView *stock = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 0, width, 160.0)];
    stock.textContainerInset = UIEdgeInsetsZero;
    stock.text = text;
    [stock layoutIfNeeded];
    UITextPosition *start = [stock positionFromPosition:stock.beginningOfDocument
                                                offset:(NSInteger)range.location];
    UITextPosition *end = [stock positionFromPosition:stock.beginningOfDocument
                                              offset:(NSInteger)NSMaxRange(range)];
    return [stock selectionRectsForRange:
        [stock textRangeFromPosition:start toPosition:end]];
}

- (IDRichTextPosition *)positionInDocument:(IDBlockDocument *)document
                                    offset:(NSUInteger)offset {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:offset];
    IDRichTextAnchor *anchor = [[IDRichTextAnchor alloc]
        initWithDocument:document
         blockIdentifier:location.blockIdentifier
              localOffset:location.localOffset
                     bias:IDRichTextAnchorBiasAfter];
    return [[IDRichTextPosition alloc] initWithAnchor:anchor
                                             affinity:UITextStorageDirectionForward];
}

- (void)assertThrowsStage:(NSString *)stage block:(void (^)(void))block {
    @try {
        block();
        XCTFail(@"Expected %@ rejection", stage);
    } @catch (NSException *exception) {
        XCTAssertEqualObjects(exception.name, NSInvalidArgumentException);
        XCTAssertTrue([exception.reason containsString:stage], @"%@", exception.reason);
    }
}

- (void)testCanonicalConstructionAndEveryUTF16OffsetRoundTrips {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];

    XCTAssertEqual(controller.document, document);
    XCTAssertEqual(controller.textStorageAdapter.document, document);
    XCTAssertEqualObjects(controller.textStorageAdapter.string, @"alpha\nbeta");
    XCTAssertEqual([controller id_textStorage], controller.textStorageAdapter);
    XCTAssertFalse([controller id_canAccessLayoutManager]);
    XCTAssertNil([controller id_layoutManager]);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:
        (IDRichTextPosition *)[controller id_beginningOfDocument]], 0U);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:
        (IDRichTextPosition *)[controller id_endOfDocument]], document.canonicalLength);

    for (NSUInteger offset = 0; offset <= document.canonicalLength; offset += 1) {
        for (NSNumber *affinityValue in @[@(UITextStorageDirectionBackward),
                                           @(UITextStorageDirectionForward)]) {
            UITextStorageDirection affinity = affinityValue.integerValue;
            IDRichTextPosition *position =
                [controller positionForCanonicalOffset:offset affinity:affinity];
            XCTAssertEqual([controller id_canonicalOffsetForPosition:position], offset);
            XCTAssertEqual(position.affinity, affinity);
            XCTAssertEqual(position.anchor.bias,
                           affinity == UITextStorageDirectionBackward
                               ? IDRichTextAnchorBiasBefore
                               : IDRichTextAnchorBiasAfter);
            IDRichTextRange *empty =
                (IDRichTextRange *)[controller id_emptyTextRangeAtPosition:position];
            XCTAssertTrue(empty.empty);
            XCTAssertEqual([controller canonicalRangeForTextRange:empty clipped:NO].location,
                           offset);
            XCTAssertEqual([controller canonicalRangeForTextRange:empty clipped:NO].length, 0U);
        }
    }

    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(2, 4)];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:range clipped:NO],
                               NSMakeRange(2, 4)));
    XCTAssertEqualObjects(range.start.anchor.blockIdentifier,
                          document.blocks[0].identifier);
    XCTAssertEqualObjects(range.end.anchor.blockIdentifier,
                          document.blocks[1].identifier);
}

- (void)testNeutralDocumentLayoutCoordinatorHasAcyclicControllerLifetime {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];
    __weak IDRichTextLayoutController *weakController = nil;
    __weak IDDocumentLayoutCoordinator *weakCoordinator = nil;

    @autoreleasepool {
        IDCanonicalTextStorageAdapter *adapter =
            [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
        IDRichTextLayoutController *controller = [[IDRichTextLayoutController alloc]
            initWithDocument:document
           textStorageAdapter:adapter
                    blockStack:stack];
        weakController = controller;
        weakCoordinator = controller.id_documentLayoutCoordinator;

        XCTAssertNotNil(controller.id_documentLayoutCoordinator);
        XCTAssertEqual(controller.id_documentLayoutCoordinator.document, document);
        XCTAssertEqual(controller.id_documentLayoutCoordinator.source, stack);
    }

    XCTAssertNil(weakController);
    XCTAssertNil(weakCoordinator);
}

- (void)testNeutralCaretGeometryOwnsProductionRectangle {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [[IDGeometryMutatingCoordinator alloc] initWithDocument:document source:stack];
    IDRichTextPosition *position = [controller positionForCanonicalOffset:3
                                                                 affinity:UITextStorageDirectionForward];
    CGRect expected = CGRectMake(123, 45, 2, 19);
    coordinator.caretResult = IDGeometryCaret(
        IDGeometryPosition(document, 3, IDBlockTextAffinityDownstream), expected);
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];

    CGRect actual = [controller id_insertionRectForPosition:position
                                            typingAttributes:@{}
                                       placeholderAttachment:nil
                                               textContainer:NULL];

    IDAssertRectsEqual(self, actual, expected, 0.001);
    XCTAssertEqual(coordinator.caretCallCount, 1U);
}

- (void)testNeutralPointHitOwnsProductionPositionAndAffinity {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [[IDGeometryMutatingCoordinator alloc] initWithDocument:document source:stack];
    coordinator.pointResult =
        IDGeometryPosition(document, 7, IDBlockTextAffinityUpstream);
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];

    IDRichTextPosition *actual = (IDRichTextPosition *)[controller
        id_nearestPositionAtPoint:CGPointMake(12, 10)
                      inContainer:controller.id_interactionTextContainer];

    XCTAssertEqual([controller id_canonicalOffsetForPosition:actual], 7U);
    XCTAssertEqual(actual.affinity, UITextStorageDirectionBackward);
    XCTAssertEqual(coordinator.pointCallCount, 1U);
}

- (void)testNeutralLineGeometryOwnsProductionCanonicalRange {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"alpha beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *coordinator =
        [[IDGeometryMutatingCoordinator alloc] initWithDocument:document source:stack];
    coordinator.lineResult = IDGeometryLine(
        IDGeometryPosition(document, 3, IDBlockTextAffinityDownstream),
        NSMakeRange(2, 4), IDBlockTextAffinityDownstream);
    [controller setValue:coordinator forKey:@"id_documentLayoutCoordinator"];
    IDRichTextPosition *position = [controller positionForCanonicalOffset:3
                                                                 affinity:UITextStorageDirectionForward];

    IDRichTextRange *actual = (IDRichTextRange *)[controller
        id_textRangeForLineEnclosingPosition:position
                           effectiveAffinity:UITextStorageDirectionForward];

    XCTAssertTrue(NSEqualRanges(
        [controller canonicalRangeForTextRange:actual clipped:NO], NSMakeRange(2, 4)));
    XCTAssertEqual(coordinator.lineCallCount, 1U);
}

- (void)testGeometryAuthorityRejectsNilNonexactStaleAndNonfiniteResults {
    [self assertCaretGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                          mutateDocumentAfterResult:NO];
    [self assertPointGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                          mutateDocumentAfterResult:NO];
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                         mutateDocumentAfterResult:NO];
    [self assertCaretGeometryFailsClosedForMutation:IDGeometryMutationNonexact
                          mutateDocumentAfterResult:NO];
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationNonexact
                         mutateDocumentAfterResult:NO];
    [self assertCaretGeometryFailsClosedForMutation:IDGeometryMutationStaleRevision
                          mutateDocumentAfterResult:NO];
    [self assertPointGeometryFailsClosedForMutation:IDGeometryMutationStaleRevision
                          mutateDocumentAfterResult:NO];
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationStaleRevision
                         mutateDocumentAfterResult:NO];
    [self assertCaretGeometryFailsClosedForMutation:
        IDGeometryMutationNonfiniteRectangle mutateDocumentAfterResult:NO];
}

- (void)testGeometryAuthorityRejectsIncoherentIdentityOffsetsAffinityAndRange {
    for (NSNumber *mutationValue in @[
        @(IDGeometryMutationWrongBlockIdentity),
        @(IDGeometryMutationIncoherentLocalOffset),
        @(IDGeometryMutationIncoherentCanonicalOffset),
        @(IDGeometryMutationInvalidAffinity),
    ]) {
        IDGeometryMutation mutation = mutationValue.integerValue;
        [self assertCaretGeometryFailsClosedForMutation:mutation
                              mutateDocumentAfterResult:NO];
        [self assertPointGeometryFailsClosedForMutation:mutation
                              mutateDocumentAfterResult:NO];
        [self assertLineGeometryFailsClosedForMutation:mutation
                             mutateDocumentAfterResult:NO];
    }
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationInvalidLineRange
                         mutateDocumentAfterResult:NO];
}

- (void)testGeometryAuthorityRejectsDocumentMutationAfterCoordinatorReturn {
    [self assertCaretGeometryFailsClosedForMutation:IDGeometryMutationNone
                          mutateDocumentAfterResult:YES];
    [self assertPointGeometryFailsClosedForMutation:IDGeometryMutationNone
                          mutateDocumentAfterResult:YES];
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationNone
                         mutateDocumentAfterResult:YES];
}

- (void)testGeometryAuthorityNeverFallsBackToDirectLayout {
    [self assertCaretGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                          mutateDocumentAfterResult:NO];
    [self assertPointGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                          mutateDocumentAfterResult:NO];
    [self assertLineGeometryFailsClosedForMutation:IDGeometryMutationNilResult
                         mutateDocumentAfterResult:NO];
}

- (void)testTask16InsertionRectCentersTwoPointCaretOnTextKitSegment {
    IDBlockLayout *layout = [self layoutForSingleBlock:@"one two" width:200.0];
    id<NSTextLocation> location = [layout locationForLocalOffset:3];
    __block CGRect raw = CGRectNull;
    NSTextRange *range = [[NSTextRange alloc] initWithLocation:location
                                                 endLocation:location];
    [layout.layoutManager enumerateTextSegmentsInRange:range
                                                  type:NSTextLayoutManagerSegmentTypeStandard
                                               options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                            usingBlock:^BOOL(NSTextRange *segmentRange,
                                                              CGRect segmentFrame,
                                                              CGFloat baselinePosition,
                                                              NSTextContainer *textContainer) {
        raw = segmentFrame;
        return YES;
    }];

    CGRect actual = [layout caretRectForLocalOffset:3
                                           affinity:UITextStorageDirectionForward];

    XCTAssertFalse(CGRectIsNull(raw));
    XCTAssertEqualWithAccuracy(actual.origin.x, CGRectGetMinX(raw) - 1.0, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.width, 2.0, 0.001);
}

- (void)testTask16IndependentBlocksStackAtFractionalTextKitAdvance {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
    };
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"one" attributes:attributes],
            [[NSAttributedString alloc] initWithString:@"two" attributes:attributes],
        ]
               defaultAttributes:attributes];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    CGPoint secondOrigin = [stack documentOriginForBlockIdentifier:second.blockIdentifier];
    [first.layoutManager ensureLayoutForRange:first.contentStorage.documentRange];
    CGRect usageBounds = CGRectStandardize(first.layoutManager.usageBoundsForTextContainer);
    CGFloat exactAdvance = MAX(CGRectGetMaxY(usageBounds), 0.0) -
        MIN(CGRectGetMinY(usageBounds), 0.0);

    XCTAssertEqualWithAccuracy(first.usedSize.height, exactAdvance, 0.001);
    XCTAssertEqualWithAccuracy(secondOrigin.y, exactAdvance, 0.001);
    XCTAssertNotEqual(exactAdvance, ceil(exactAdvance));
}

- (void)testTask16RTLAmbiguousInsertionsUseNativeParagraphForwardCaretSide {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
    };
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"אבגדה six"
                                            attributes:attributes],
        ]
               defaultAttributes:attributes];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:262.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    [layout.layoutManager ensureLayoutForRange:layout.contentStorage.documentRange];
    id<NSTextSelectionDataSource> dataSource =
        (id<NSTextSelectionDataSource>)layout.layoutManager;
    for (NSNumber *offsetValue in @[@6, @9]) {
        NSUInteger queryOffset = offsetValue.unsignedIntegerValue;
        id<NSTextLocation> queryLocation = [layout locationForLocalOffset:queryOffset];
        id<NSTextLocation> previousLocation = [layout locationForLocalOffset:queryOffset - 1];
        id<NSTextLocation> lineLocation = queryOffset == layout.contentStorage.textStorage.length
            ? previousLocation
            : queryLocation;
        __block CGFloat currentLeading = NAN;
        __block CGFloat previousTrailing = NAN;
        [dataSource enumerateCaretOffsetsInLineFragmentAtLocation:lineLocation
                                                       usingBlock:^(CGFloat caretOffset,
                                                                    id<NSTextLocation> candidateLocation,
                                                                    BOOL leadingEdge,
                                                                    BOOL *stop) {
            (void)stop;
            if (leadingEdge && [candidateLocation compare:queryLocation] == NSOrderedSame) {
                currentLeading = caretOffset;
            }
            if (!leadingEdge &&
                [candidateLocation compare:previousLocation] == NSOrderedSame) {
                previousTrailing = caretOffset;
            }
        }];

        XCTAssertTrue(isfinite(previousTrailing));
        CGFloat expectedOffset = previousTrailing;
        if (queryOffset < layout.contentStorage.textStorage.length) {
            XCTAssertTrue(isfinite(currentLeading));
            XCTAssertNotEqualWithAccuracy(currentLeading, previousTrailing, 0.001);
            NSTextSelectionNavigationWritingDirection direction =
                [dataSource baseWritingDirectionAtLocation:queryLocation];
            XCTAssertEqual(direction,
                           NSTextSelectionNavigationWritingDirectionRightToLeft);
            expectedOffset = MAX(currentLeading, previousTrailing);
        }

        CGRect actual = [layout caretRectForLocalOffset:queryOffset
                                                affinity:UITextStorageDirectionForward];
        XCTAssertEqualWithAccuracy(actual.origin.x, expectedOffset - 1.0, 0.001);
    }
}

- (void)testTask16BiDiBoundaryMovementUsesTextKitSelectionNavigation {
    for (NSDictionary<NSString *, id> *fixture in @[
        @{@"text": @"אבגדה six", @"boundary": @6},
        @{@"text": @"abc אבג def", @"boundary": @5},
    ]) {
        NSString *text = fixture[@"text"];
        NSUInteger boundary = [fixture[@"boundary"] unsignedIntegerValue];
        IDBlockLayout *layout = [self layoutForSingleBlock:text width:262.0];
        UITextView *stock = [[UITextView alloc]
            initWithFrame:CGRectMake(0, 0, 262.0, 120.0)];
        stock.text = text;
        [stock layoutIfNeeded];
        NSTextLayoutManager *stockManager = stock.textLayoutManager;
        NSTextContentManager *stockContentManager = stockManager.textContentManager;
        XCTAssertNotNil(stockManager);
        XCTAssertNotNil(stockContentManager);
        [stockManager ensureLayoutForRange:stockManager.documentRange];

        for (NSNumber *affinityValue in @[@(UITextStorageDirectionBackward),
                                           @(UITextStorageDirectionForward)]) {
            UITextStorageDirection sourceAffinity = affinityValue.integerValue;
            for (NSNumber *directionValue in @[@(UITextLayoutDirectionLeft),
                                                @(UITextLayoutDirectionRight)]) {
                UITextLayoutDirection direction = directionValue.integerValue;
                id<NSTextLocation> stockLocation = [stockContentManager
                    locationFromLocation:stockManager.documentRange.location
                              withOffset:(NSInteger)boundary];
                NSTextSelection *source = [[NSTextSelection alloc]
                    initWithLocation:stockLocation
                             affinity:sourceAffinity == UITextStorageDirectionForward
                                 ? NSTextSelectionAffinityDownstream
                                 : NSTextSelectionAffinityUpstream];
                NSTextSelectionNavigationDirection navigationDirection =
                    direction == UITextLayoutDirectionLeft
                        ? NSTextSelectionNavigationDirectionLeft
                        : NSTextSelectionNavigationDirectionRight;
                NSTextSelection *destination = [stockManager.textSelectionNavigation
                    destinationSelectionForTextSelection:source
                                                direction:navigationDirection
                                              destination:NSTextSelectionNavigationDestinationCharacter
                                                extending:NO
                                                 confined:NO];
                XCTAssertEqual(destination.textRanges.count, 1U);
                NSTextRange *destinationRange = destination.textRanges.firstObject;
                XCTAssertTrue(destinationRange.empty);
                id<NSTextLocation> destinationLocation =
                    destination.affinity == NSTextSelectionAffinityUpstream
                        ? destination.textRanges.firstObject.location
                        : destination.textRanges.lastObject.endLocation;
                NSInteger expectedOffset = [stockContentManager
                    offsetFromLocation:stockManager.documentRange.location
                            toLocation:destinationLocation];
                UITextStorageDirection expectedAffinity =
                    destination.affinity == NSTextSelectionAffinityUpstream
                        ? UITextStorageDirectionBackward
                        : UITextStorageDirectionForward;

                UITextStorageDirection actualAffinity = sourceAffinity;
                NSUInteger actualOffset = [layout
                    visuallyAdjacentLocalOffsetFromOffset:boundary
                                                  affinity:sourceAffinity
                                                 direction:direction
                                          resultingAffinity:&actualAffinity];
                XCTAssertEqual(actualOffset, (NSUInteger)expectedOffset,
                               @"sourceAffinity=%ld direction=%ld",
                               (long)sourceAffinity, (long)direction);
                XCTAssertEqual(actualAffinity, expectedAffinity,
                               @"sourceAffinity=%ld direction=%ld",
                               (long)sourceAffinity, (long)direction);
            }
        }
    }
}

- (void)testTask16PointInteractionNeverReturnsInsideComposedCluster {
    NSString *text = @"A👨‍👩‍👧‍👦B";
    IDBlockLayout *layout = [self layoutForSingleBlock:text width:262.0];
    UITextView *stock = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 262.0, 120.0)];
    stock.text = text;
    [stock layoutIfNeeded];
    NSTextLayoutManager *stockManager = stock.textLayoutManager;
    NSTextContentManager *stockContentManager = stockManager.textContentManager;
    [stockManager ensureLayoutForRange:stockManager.documentRange];
    NSRange emojiRange = [text rangeOfComposedCharacterSequenceAtIndex:1];
    CGRect start = [layout caretRectForLocalOffset:emojiRange.location
                                          affinity:UITextStorageDirectionForward];
    CGRect end = [layout caretRectForLocalOffset:NSMaxRange(emojiRange)
                                        affinity:UITextStorageDirectionForward];
    XCTAssertFalse(CGRectIsNull(start));
    XCTAssertFalse(CGRectIsNull(end));
    CGFloat minimumX = MIN(CGRectGetMidX(start), CGRectGetMidX(end));
    CGFloat maximumX = MAX(CGRectGetMidX(start), CGRectGetMidX(end));
    NSMutableArray<NSValue *> *stockFrames = [NSMutableArray array];
    for (NSNumber *offsetValue in @[@(emojiRange.location), @(NSMaxRange(emojiRange))]) {
        id<NSTextLocation> location = [stockContentManager
            locationFromLocation:stockManager.documentRange.location
                      withOffset:offsetValue.integerValue];
        NSTextRange *range = [[NSTextRange alloc] initWithLocation:location
                                                     endLocation:location];
        __block CGRect frame = CGRectNull;
        [stockManager enumerateTextSegmentsInRange:range
                                              type:NSTextLayoutManagerSegmentTypeStandard
                                           options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                        usingBlock:^BOOL(NSTextRange *segmentRange,
                                                          CGRect segmentFrame,
                                                          CGFloat baselinePosition,
                                                          NSTextContainer *textContainer) {
            (void)segmentRange;
            (void)baselinePosition;
            (void)textContainer;
            frame = segmentFrame;
            return NO;
        }];
        XCTAssertFalse(CGRectIsNull(frame));
        [stockFrames addObject:[NSValue valueWithCGRect:frame]];
    }
    CGFloat stockMinimumX = MIN(CGRectGetMinX(stockFrames[0].CGRectValue),
                                CGRectGetMinX(stockFrames[1].CGRectValue));
    CGFloat stockMaximumX = MAX(CGRectGetMinX(stockFrames[0].CGRectValue),
                                CGRectGetMinX(stockFrames[1].CGRectValue));
    for (NSNumber *fractionValue in @[@0.25, @0.50, @0.75]) {
        CGFloat fraction = fractionValue.doubleValue;
        CGPoint point = CGPointMake(minimumX + (maximumX - minimumX) * fraction,
                                    CGRectGetMidY(start));
        IDBlockCaretStop actual = [layout caretStopForPoint:point];
        XCTAssertTrue(actual.localOffset == emojiRange.location ||
                      actual.localOffset == NSMaxRange(emojiRange),
                      @"fraction=%g offset=%lu", fraction,
                      (unsigned long)actual.localOffset);
        CGPoint stockPoint = CGPointMake(
            stockMinimumX + (stockMaximumX - stockMinimumX) * fraction,
            CGRectGetMidY(stockFrames[0].CGRectValue));
        NSArray<NSTextSelection *> *stockSelections =
            [stockManager.textSelectionNavigation
                textSelectionsInteractingAtPoint:stockPoint
                           inContainerAtLocation:stockManager.documentRange.location
                                          anchors:@[]
                                        modifiers:0
                                         selecting:YES
                                            bounds:(CGRect){CGPointZero,
                                                            stock.textContainer.size}];
        NSTextSelection *stockSelection = stockSelections.firstObject;
        NSTextRange *stockRange = stockSelection.textRanges.firstObject;
        NSInteger expectedOffset = [stockContentManager
            offsetFromLocation:stockManager.documentRange.location
                    toLocation:stockRange.location];
        UITextStorageDirection expectedAffinity =
            stockSelection.affinity == NSTextSelectionAffinityUpstream
                ? UITextStorageDirectionBackward
                : UITextStorageDirectionForward;
        XCTAssertEqual(actual.localOffset, (NSUInteger)expectedOffset,
                       @"fraction=%g", fraction);
        XCTAssertEqual(actual.affinity, expectedAffinity, @"fraction=%g", fraction);
    }
}

- (void)testTask16MultiHopMovementCarriesNativeAffinityAndAnchorState {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc", @"def"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDBlockLayout *secondLayout = stack.blockLayouts[1];
    IDTask16ScriptedBlockLayout *scripted = [[IDTask16ScriptedBlockLayout alloc]
        initWithBlock:document.blocks.firstObject width:200.0];
    scripted.receivedOffsets = [NSMutableArray array];
    scripted.receivedAffinities = [NSMutableArray array];
    scripted.receivedAnchorOffsets = [NSMutableArray array];
    scripted.firstStop = (IDBlockCaretStop){
        .localOffset = 3,
        .affinity = UITextStorageDirectionBackward,
        .anchorPositionOffset = 42.0,
        .found = YES,
    };
    [stack setValue:@[scripted, secondLayout] forKey:@"blockLayouts"];
    [stack setValue:@{
        scripted.blockIdentifier: scripted,
        secondLayout.blockIdentifier: secondLayout,
    } forKey:@"layoutsByIdentifier"];

    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:1 affinity:UITextStorageDirectionBackward];
    IDDocumentCaretNavigationResult *first = [controller.id_documentLayoutCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:1
                                            affinity:IDBlockTextAffinityDownstream
                                           direction:IDBlockLayoutDirectionRight
                                anchorPositionOffset:13.0];
    XCTAssertTrue(first.exact);
    IDDocumentCaretNavigationResult *second = [controller.id_documentLayoutCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:first.position.canonicalOffset
                                            affinity:first.position.localPosition.affinity
                                           direction:IDBlockLayoutDirectionRight
                                anchorPositionOffset:first.anchorPositionOffset];
    XCTAssertTrue(second.exact);
    IDRichTextPosition *actual = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionRight
                         offset:2
                       affinity:UITextStorageDirectionForward
           anchorPositionOffset:13.0];

    XCTAssertNotNil(actual);
    XCTAssertEqual(scripted.receivedOffsets.count, 0U);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:actual],
                   second.position.canonicalOffset);
    XCTAssertEqual(actual.affinity,
                   second.position.localPosition.affinity == IDBlockTextAffinityUpstream
                       ? UITextStorageDirectionBackward
                       : UITextStorageDirectionForward);
    XCTAssertTrue(isfinite(first.anchorPositionOffset));
    XCTAssertTrue(isfinite(second.anchorPositionOffset));
    XCTAssertGreaterThan(fabs(first.anchorPositionOffset - 13.0), 0.001);
    XCTAssertGreaterThan(fabs(second.anchorPositionOffset -
                              first.anchorPositionOffset), 0.001);
}

- (void)testTask16OneVerticalCallbackPreservesCallerAnchorAcrossIndependentBlocks {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[
        @"abcdefghijklmno", @"xy", @"abcdefghijklmno",
    ]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:12 affinity:UITextStorageDirectionForward];
    CGRect initialCaret = [self task16DocumentCaretForPosition:start
                                                   controller:controller
                                                        stack:stack];
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionDown
                         offset:2
                       affinity:start.affinity
           anchorPositionOffset:CGRectGetMinX(initialCaret)];
    XCTAssertNotNil(result);
    CGRect finalCaret = [self task16DocumentCaretForPosition:result
                                                 controller:controller
                                                      stack:stack];
    XCTAssertEqual([controller id_canonicalOffsetForPosition:result], 31U);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(finalCaret),
                               CGRectGetMinX(initialCaret), 0.5);
}

- (void)testVerticalAnchorFromInsertionBoundaryConvertsStackToSameCanvas {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[
        @"abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz",
    ]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    stack.frame = CGRectMake(37, 19, 200, 240);
    [host addSubview:stack];
    IDBlockLayout *original = stack.blockLayouts.firstObject;
    IDTask16ScriptedBlockLayout *layout = [[IDTask16ScriptedBlockLayout alloc]
        initWithBlock:document.blocks.firstObject width:200.0];
    layout.receivedOffsets = [NSMutableArray array];
    layout.receivedAffinities = [NSMutableArray array];
    layout.receivedAnchorOffsets = [NSMutableArray array];
    layout.firstStop = (IDBlockCaretStop){
        .localOffset = 35,
        .affinity = UITextStorageDirectionForward,
        .anchorPositionOffset = 0.0,
        .found = YES,
    };
    [original.canvasView removeFromSuperview];
    [stack addSubview:layout.canvasView];
    [stack setValue:@[layout] forKey:@"blockLayouts"];
    [stack setValue:@{layout.blockIdentifier: layout} forKey:@"layoutsByIdentifier"];
    CGRect canvasFrame = original.canvasView.frame;
    canvasFrame.origin.x = 131.0;
    layout.canvasView.frame = canvasFrame;
    CGRect canvasBounds = layout.canvasView.bounds;
    canvasBounds.origin = CGPointMake(-19.0, 3.0);
    layout.canvasView.bounds = canvasBounds;
    [stack layoutIfNeeded];

    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:10 affinity:UITextStorageDirectionForward];
    CGRect insertion = [controller id_insertionRectForPosition:start
                                               typingAttributes:@{}
                                          placeholderAttachment:nil
                                                  textContainer:NULL];
    CGFloat anchorX = CGRectGetMinX(insertion);
    CGPoint expectedLocalAnchor = [layout.canvasView
        convertPoint:CGPointMake(anchorX, 0.0) fromView:stack];
    XCTAssertGreaterThan(fabs(expectedLocalAnchor.x - anchorX), 20.0);
    CGPoint projectOrigin = [stack
        documentOriginForBlockIdentifier:layout.blockIdentifier];
    CGPoint mountedOrigin = [layout.canvasView convertPoint:CGPointZero toView:stack];
    XCTAssertGreaterThan(fabs(projectOrigin.x - mountedOrigin.x), 20.0);
    IDDocumentCaretNavigationResult *expected =
        [controller.id_documentLayoutCoordinator
            visuallyAdjacentPositionFromCanonicalOffset:10
                                                affinity:IDBlockTextAffinityDownstream
                                               direction:IDBlockLayoutDirectionDown
                                    anchorPositionOffset:anchorX];
    XCTAssertTrue(expected.exact);
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionDown
                         offset:1
                       affinity:start.affinity
           anchorPositionOffset:anchorX];

    XCTAssertNotNil(result);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:result],
                   expected.position.canonicalOffset);
    XCTAssertEqual(result.affinity,
                   expected.position.localPosition.affinity == IDBlockTextAffinityUpstream
                       ? UITextStorageDirectionBackward
                       : UITextStorageDirectionForward);
    XCTAssertEqualWithAccuracy(expected.anchorPositionOffset, anchorX, 0.001);
    XCTAssertEqual(layout.receivedAnchorOffsets.count, 0U);
}

- (void)testVerticalAnchorFromInsertionBoundaryConvertsStackToAdjacentAsymmetricCanvas {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[
        @"abcdefghijklmno", @"abcdefghijklmnopqrstuv",
    ]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 320)];
    stack.frame = CGRectMake(29, 17, 240, 260);
    [host addSubview:stack];
    IDBlockLayout *sourceLayout = stack.blockLayouts[0];
    IDBlockLayout *targetLayout = stack.blockLayouts[1];
    CGRect sourceFrame = sourceLayout.canvasView.frame;
    sourceFrame.origin.x = 31.0;
    sourceLayout.canvasView.frame = sourceFrame;
    CGRect sourceBounds = sourceLayout.canvasView.bounds;
    sourceBounds.origin = CGPointMake(-7.0, 2.0);
    sourceLayout.canvasView.bounds = sourceBounds;
    CGRect targetFrame = targetLayout.canvasView.frame;
    targetFrame.origin.x = 83.0;
    targetLayout.canvasView.frame = targetFrame;
    CGRect targetBounds = targetLayout.canvasView.bounds;
    targetBounds.origin = CGPointMake(12.0, -4.0);
    targetLayout.canvasView.bounds = targetBounds;
    [stack layoutIfNeeded];

    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:12 affinity:UITextStorageDirectionForward];
    CGRect insertion = [controller id_insertionRectForPosition:start
                                               typingAttributes:@{}
                                          placeholderAttachment:nil
                                                  textContainer:NULL];
    CGFloat anchorX = CGRectGetMinX(insertion);
    CGRect targetEdgeCaret = [targetLayout caretRectForLocalOffset:0
                                                          affinity:UITextStorageDirectionForward];
    CGPoint targetPoint = [targetLayout.canvasView
        convertPoint:CGPointMake(anchorX, 0.0) fromView:stack];
    targetPoint.y = CGRectGetMidY(targetEdgeCaret);
    XCTAssertGreaterThan(fabs(targetPoint.x - anchorX), 20.0);
    IDBlockCaretStop expected = [targetLayout caretStopForPoint:targetPoint];
    XCTAssertTrue(expected.found);
    CGPoint projectOrigin = [stack
        documentOriginForBlockIdentifier:sourceLayout.blockIdentifier];
    CGPoint mountedOrigin = [sourceLayout.canvasView
        convertPoint:CGPointZero toView:stack];
    XCTAssertGreaterThan(fabs(projectOrigin.x - mountedOrigin.x), 20.0);
    IDDocumentCaretNavigationResult *neutral =
        [controller.id_documentLayoutCoordinator
            visuallyAdjacentPositionFromCanonicalOffset:12
                                                affinity:IDBlockTextAffinityDownstream
                                               direction:IDBlockLayoutDirectionDown
                                    anchorPositionOffset:anchorX];
    XCTAssertTrue(neutral.exact);
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionDown
                         offset:1
                       affinity:start.affinity
           anchorPositionOffset:anchorX];

    XCTAssertNotNil(result);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:result],
                   neutral.position.canonicalOffset);
    XCTAssertNotEqual(neutral.position.canonicalOffset,
                      document.blocks.firstObject.attributedText.length + 1 +
                          expected.localOffset);
}

- (void)testVerticalAnchorFromInsertionBoundaryConvertsStackUpToAdjacentAsymmetricCanvas {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[
        @"abcdefghijklmnopqrstuv", @"abcdefghijklmno",
    ]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 320)];
    stack.frame = CGRectMake(41, 23, 240, 260);
    [host addSubview:stack];
    IDBlockLayout *targetLayout = stack.blockLayouts[0];
    IDBlockLayout *sourceLayout = stack.blockLayouts[1];
    CGRect targetFrame = targetLayout.canvasView.frame;
    targetFrame.origin.x = 97.0;
    targetLayout.canvasView.frame = targetFrame;
    CGRect targetBounds = targetLayout.canvasView.bounds;
    targetBounds.origin = CGPointMake(14.0, -6.0);
    targetLayout.canvasView.bounds = targetBounds;
    CGRect sourceFrame = sourceLayout.canvasView.frame;
    sourceFrame.origin.x = 27.0;
    sourceLayout.canvasView.frame = sourceFrame;
    CGRect sourceBounds = sourceLayout.canvasView.bounds;
    sourceBounds.origin = CGPointMake(-9.0, 5.0);
    sourceLayout.canvasView.bounds = sourceBounds;
    [stack layoutIfNeeded];

    NSUInteger sourceStart = document.blocks.firstObject.attributedText.length + 1;
    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:sourceStart + 12
                          affinity:UITextStorageDirectionForward];
    CGRect insertion = [controller id_insertionRectForPosition:start
                                               typingAttributes:@{}
                                          placeholderAttachment:nil
                                                  textContainer:NULL];
    CGFloat anchorX = CGRectGetMinX(insertion);
    CGRect targetEdgeCaret = [targetLayout
        caretRectForLocalOffset:document.blocks.firstObject.attributedText.length
                      affinity:UITextStorageDirectionBackward];
    CGPoint targetPoint = [targetLayout.canvasView
        convertPoint:CGPointMake(anchorX, 0.0) fromView:stack];
    targetPoint.y = CGRectGetMidY(targetEdgeCaret);
    XCTAssertGreaterThan(fabs(targetPoint.x - anchorX), 20.0);
    IDBlockCaretStop expected = [targetLayout caretStopForPoint:targetPoint];
    XCTAssertTrue(expected.found);
    CGPoint projectOrigin = [stack
        documentOriginForBlockIdentifier:sourceLayout.blockIdentifier];
    CGPoint mountedOrigin = [sourceLayout.canvasView
        convertPoint:CGPointZero toView:stack];
    XCTAssertGreaterThan(fabs(projectOrigin.x - mountedOrigin.x), 20.0);
    IDDocumentCaretNavigationResult *neutral =
        [controller.id_documentLayoutCoordinator
            visuallyAdjacentPositionFromCanonicalOffset:sourceStart + 12
                                                affinity:IDBlockTextAffinityDownstream
                                               direction:IDBlockLayoutDirectionUp
                                    anchorPositionOffset:anchorX];
    XCTAssertTrue(neutral.exact);
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionUp
                         offset:1
                       affinity:start.affinity
           anchorPositionOffset:anchorX];

    XCTAssertNotNil(result);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:result],
                   neutral.position.canonicalOffset);
    XCTAssertNotEqual(neutral.position.canonicalOffset, expected.localOffset);
}

- (void)testTask16SeparateVerticalCallbacksUseEachCallerAnchor {
    NSArray<NSString *> *blocks = @[@"abcdefghijklmno", @"xy", @"abcdefghijklmno"];
    IDBlockDocument *document = [self task16DocumentWithBlocks:blocks];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:12 affinity:UITextStorageDirectionForward];
    CGRect startCaret = [self task16DocumentCaretForPosition:start
                                                  controller:controller
                                                       stack:stack];
    IDRichTextPosition *shortPosition = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionDown
                         offset:1
                       affinity:start.affinity
           anchorPositionOffset:CGRectGetMinX(startCaret)];
    XCTAssertNotNil(shortPosition);
    CGRect shortCaret = [self task16DocumentCaretForPosition:shortPosition
                                                  controller:controller
                                                       stack:stack];
    NSUInteger shortCanonical = [controller id_canonicalOffsetForPosition:shortPosition];
    shortPosition = [controller positionForCanonicalOffset:shortCanonical
                                                  affinity:shortPosition.affinity];
    IDRichTextPosition *thirdPosition = (IDRichTextPosition *)[controller
        id_positionFromPosition:shortPosition
                    inDirection:UITextLayoutDirectionDown
                         offset:1
                       affinity:shortPosition.affinity
           anchorPositionOffset:CGRectGetMinX(shortCaret)];
    XCTAssertNotNil(thirdPosition);

    UITextView *stock = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 200, 160)];
    stock.textContainerInset = UIEdgeInsetsZero;
    stock.attributedText = [[NSAttributedString alloc]
        initWithString:[blocks componentsJoinedByString:@"\n"]
            attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17.0]}];
    [stock layoutIfNeeded];
    UITextPosition *stockStart = [stock positionFromPosition:stock.beginningOfDocument
                                                     offset:12];
    UITextPosition *stockShort = [stock positionFromPosition:stockStart
                                                 inDirection:UITextLayoutDirectionDown
                                                      offset:1];
    UITextPosition *stockThird = [stock positionFromPosition:stockShort
                                                 inDirection:UITextLayoutDirectionDown
                                                      offset:1];
    NSInteger stockShortOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                                toPosition:stockShort];
    NSInteger stockThirdOffset = [stock offsetFromPosition:stock.beginningOfDocument
                                                toPosition:stockThird];
    XCTAssertEqual([controller id_canonicalOffsetForPosition:shortPosition],
                   (NSUInteger)stockShortOffset);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:thirdPosition],
                   (NSUInteger)stockThirdOffset);
}

- (void)testTask16SameLineVerticalBoundaryCrossesOnlyOneAdjacentBlock {
    IDBlockDocument *document = [self task16DocumentWithBlocks:@[@"abc", @"def", @"ghi"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDRichTextPosition *start = [controller
        positionForCanonicalOffset:1 affinity:UITextStorageDirectionForward];
    CGRect startCaret = [self task16DocumentCaretForPosition:start
                                                  controller:controller
                                                       stack:stack];
    IDRichTextPosition *result = (IDRichTextPosition *)[controller
        id_positionFromPosition:start
                    inDirection:UITextLayoutDirectionDown
                         offset:1
                       affinity:start.affinity
           anchorPositionOffset:CGRectGetMinX(startCaret)];
    XCTAssertNotNil(result);
    IDCanonicalTextProjection *projection = [[IDCanonicalTextProjection alloc]
        initWithDocument:document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:
        [controller id_canonicalOffsetForPosition:result]];
    XCTAssertEqualObjects(location.blockIdentifier, document.blocks[1].identifier);
}

- (void)testTask16StructuralNewlineSelectionComposesSegmentsBeforeAssigningFlags {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc", @"אבג"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(2, 3)];
    NSArray<IDRichTextSelectionRect *> *rects = [controller
        id_selectionRectsForRange:range
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];

    XCTAssertEqual(rects.count, 2U);
    NSUInteger startCount = 0;
    NSUInteger endCount = 0;
    for (IDRichTextSelectionRect *rect in rects) {
        XCTAssertTrue(isfinite(rect.rect.origin.x));
        XCTAssertTrue(isfinite(rect.rect.origin.y));
        XCTAssertTrue(isfinite(rect.rect.size.width));
        XCTAssertTrue(isfinite(rect.rect.size.height));
        XCTAssertGreaterThan(rect.rect.size.width, 0.0);
        XCTAssertGreaterThan(rect.rect.size.height, 0.0);
        startCount += rect.containsStart ? 1 : 0;
        endCount += rect.containsEnd ? 1 : 0;
    }
    XCTAssertEqual(startCount, 1U);
    XCTAssertTrue(rects.firstObject.containsStart);
    XCTAssertEqual(endCount, 1U);
    XCTAssertTrue(rects.lastObject.containsEnd);

    IDBlockLayout *firstLayout = stack.blockLayouts[0];
    IDBlockLayout *secondLayout = stack.blockLayouts[1];
    NSArray<IDRichTextSelectionRect *> *firstLocalRects =
        [firstLayout selectionRectsForLocalRange:NSMakeRange(2, 1)];
    NSArray<IDRichTextSelectionRect *> *secondLocalRects =
        [secondLayout selectionRectsForLocalRange:NSMakeRange(0, 1)];
    XCTAssertEqual(firstLocalRects.count, 1U);
    XCTAssertEqual(secondLocalRects.count, 1U);
    CGRect firstLocal = firstLocalRects.firstObject.rect;
    CGRect secondLocal = secondLocalRects.firstObject.rect;
    CGRect firstSegment = [firstLayout.canvasView convertRect:firstLocal toView:stack];
    CGRect secondSegment = [secondLayout.canvasView convertRect:secondLocal toView:stack];
    CGRect firstContainer = [firstLayout.canvasView
        convertRect:(CGRect){CGPointZero, firstLayout.textContainer.size}
            toView:stack];
    CGRect secondContainer = [secondLayout.canvasView
        convertRect:(CGRect){CGPointZero, secondLayout.textContainer.size}
            toView:stack];
    // The selection is "c" + the separator + the first Hebrew letter, so the LTR line is covered
    // to its end and the RTL line from its beginning — which is its RIGHT edge. Both therefore fill
    // toward the container's trailing side, for opposite reasons. The per-block segments composed
    // above are the glyph-hugging rects a stock text view vends, so the transform applies to them.
    CGRect firstExpected = IDSelectionRectExpectedFromStock(
        firstSegment, firstContainer, NSWritingDirectionLeftToRight, NO, YES);
    CGRect secondExpected = IDSelectionRectExpectedFromStock(
        secondSegment, secondContainer, NSWritingDirectionRightToLeft, YES, NO);

    XCTAssertEqualWithAccuracy(CGRectGetMinX(rects[0].rect),
                               CGRectGetMinX(firstExpected), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(rects[0].rect),
                               CGRectGetMaxX(firstExpected), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(rects[1].rect),
                               CGRectGetMinX(secondExpected), 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(rects[1].rect),
                               CGRectGetMaxX(secondExpected), 0.001);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(rects[0].rect),
                             CGRectGetMinY(rects[1].rect) + 0.001);
    XCTAssertLessThan(CGRectGetWidth(rects[0].rect), 200.0);
    XCTAssertLessThan(CGRectGetWidth(rects[1].rect), 200.0);
    XCTAssertEqual(rects[0].writingDirection, NSWritingDirectionLeftToRight);
    XCTAssertEqual(rects[1].writingDirection, NSWritingDirectionLeftToRight);
}

- (void)testTask16MixedBiDiSelectionFlagsLogicalSegmentsLikeUIKit {
    NSString *text = @"אבג abc דהו xyz";
    NSRange selection = NSMakeRange(1, 13);
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:text
                                                                       range:selection
                                                                       width:200.0];
    IDBlockDocument *document = [self documentWithBlocks:@[text]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];

    XCTAssertEqual(stock.count, 2U);
    XCTAssertTrue(stock[0].containsEnd);
    XCTAssertFalse(stock[0].containsStart);
    XCTAssertTrue(stock[1].containsStart);
    XCTAssertFalse(stock[1].containsEnd);
    XCTAssertEqual(actual.count, stock.count);
    for (NSUInteger index = 0; index < MIN(actual.count, stock.count); index += 1) {
        XCTAssertEqual(actual[index].containsStart, stock[index].containsStart,
                       @"visual index %lu", (unsigned long)index);
        XCTAssertEqual(actual[index].containsEnd, stock[index].containsEnd,
                       @"visual index %lu", (unsigned long)index);
    }
}

- (void)testTask5MixedBiDiSelectionRectsMatchStockByLogicalEndpointRole {
    NSString *text = @"אבג abc דהו xyz";
    NSRange selection = NSMakeRange(1, 13);
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:text
                                                                       range:selection
                                                                       width:200.0];
    IDBlockDocument *document = [self documentWithBlocks:@[text]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];

    for (NSNumber *role in @[@YES, @NO]) {
        BOOL start = role.boolValue;
        NSPredicate *stockPredicate = [NSPredicate predicateWithBlock:
            ^BOOL(UITextSelectionRect *rect, NSDictionary *bindings) {
                return start ? rect.containsStart : rect.containsEnd;
            }];
        NSPredicate *actualPredicate = [NSPredicate predicateWithBlock:
            ^BOOL(IDRichTextSelectionRect *rect, NSDictionary *bindings) {
                return start ? rect.containsStart : rect.containsEnd;
            }];
        UITextSelectionRect *stockRect = [[stock filteredArrayUsingPredicate:stockPredicate] firstObject];
        IDRichTextSelectionRect *actualRect = [[actual filteredArrayUsingPredicate:actualPredicate] firstObject];
        XCTAssertNotNil(stockRect);
        XCTAssertNotNil(actualRect);
        if (stockRect == nil || actualRect == nil) continue;
        XCTAssertEqual(actualRect.containsStart, stockRect.containsStart);
        XCTAssertEqual(actualRect.containsEnd, stockRect.containsEnd);
        XCTAssertEqual(actualRect.writingDirection, stockRect.writingDirection);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actualRect.rect),
                                   CGRectGetMinX(stockRect.rect), 1.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(actualRect.rect),
                                   CGRectGetMinY(stockRect.rect), 1.5);
    }
}

- (void)testTask5StructuralBoundarySelectionRectsMatchStockByLogicalEndpointRole {
    NSString *first = @"Boundary alpha omega";
    NSString *second = @"Boundary beta gamma";
    NSString *text = [@[first, second] componentsJoinedByString:@"\n"];
    NSRange selection = NSMakeRange(first.length - 3, 1 + 1 + 9);
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:text
                                                                       range:selection
                                                                       width:200.0];
    IDBlockDocument *document = [self documentWithBlocks:@[first, second]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];

    for (NSNumber *role in @[@YES, @NO]) {
        BOOL start = role.boolValue;
        UITextSelectionRect *stockRect = nil;
        for (UITextSelectionRect *candidate in stock) {
            if (start ? candidate.containsStart : candidate.containsEnd) {
                stockRect = candidate;
                break;
            }
        }
        IDRichTextSelectionRect *actualRect = nil;
        for (IDRichTextSelectionRect *candidate in actual) {
            if (start ? candidate.containsStart : candidate.containsEnd) {
                actualRect = candidate;
                break;
            }
        }
        XCTAssertNotNil(stockRect);
        XCTAssertNotNil(actualRect);
        if (stockRect == nil || actualRect == nil) continue;
        XCTAssertEqual(actualRect.containsStart, stockRect.containsStart);
        XCTAssertEqual(actualRect.containsEnd, stockRect.containsEnd);
        XCTAssertEqual(actualRect.writingDirection, stockRect.writingDirection);
        // The selection runs from inside the first block to inside the second, so the line
        // holding the START is covered to its end and the line holding the END from its beginning.
        CGRect expected = IDSelectionRectExpectedFromStock(
            stockRect.rect,
            [self containerBoundsForBlockAtIndex:(start ? 0 : 1) inStack:stack],
            NSWritingDirectionLeftToRight, !start, start);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actualRect.rect),
                                   CGRectGetMinX(expected), 1.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(actualRect.rect),
                                   CGRectGetMinY(expected), 1.5);
    }
}

- (void)testTask5SecondBlockBiDiEndpointRectsMatchStockByLogicalRole {
    NSString *first = @"English prefix";
    NSString *second = @"אבגדה mixed suffix";
    NSString *text = [@[first, second] componentsJoinedByString:@"\n"];
    NSRange selection = [text rangeOfString:@"אבגדה"];
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:text
                                                                       range:selection
                                                                       width:200.0];
    IDBlockDocument *document = [self documentWithBlocks:@[first, second]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];
    XCTAssertEqual(actual.count, stock.count);
    for (NSNumber *role in @[@YES, @NO]) {
        BOOL start = role.boolValue;
        UITextSelectionRect *stockRect = nil;
        IDRichTextSelectionRect *actualRect = nil;
        for (UITextSelectionRect *candidate in stock) {
            if (start ? candidate.containsStart : candidate.containsEnd) stockRect = candidate;
        }
        for (IDRichTextSelectionRect *candidate in actual) {
            if (start ? candidate.containsStart : candidate.containsEnd) actualRect = candidate;
        }
        XCTAssertNotNil(stockRect);
        XCTAssertNotNil(actualRect);
        if (stockRect == nil || actualRect == nil) continue;
        XCTAssertEqual(actualRect.containsStart, stockRect.containsStart);
        XCTAssertEqual(actualRect.containsEnd, stockRect.containsEnd);
        XCTAssertEqual(actualRect.writingDirection, stockRect.writingDirection);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actualRect.rect), CGRectGetMinX(stockRect.rect), 1.5);
        XCTAssertEqualWithAccuracy(CGRectGetMinY(actualRect.rect), CGRectGetMinY(stockRect.rect), 1.5);
    }
}

/// The line container of the block at `index`, in the stack's coordinate space — the edges this
/// editor fills a covered line out to. Derived from the block's own layout rather than written down,
/// so a test says "the container's edge" and cannot drift into asserting a number.
- (CGRect)containerBoundsForBlockAtIndex:(NSUInteger)index
                                 inStack:(IDBlockStackCanvasView *)stack {
    IDBlockLayout *layout = stack.blockLayouts[index];
    return [layout.canvasView
        convertRect:(CGRect){CGPointZero, layout.textContainer.size}
             toView:stack];
}

- (void)testTask16SeparatorOnlyLTRSelectionMatchesUIKitUpstreamTail {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc", @"def"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(3, 1);
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:@"abc\ndef"
                                                                       range:selection
                                                                       width:200.0];

    XCTAssertEqual(stock.count, 1U);
    XCTAssertEqual(actual.count, stock.count);
    if (actual.count == 1 && stock.count == 1) {
        XCTAssertTrue(isfinite(actual[0].rect.origin.x));
        XCTAssertTrue(isfinite(actual[0].rect.origin.y));
        XCTAssertGreaterThan(CGRectGetWidth(actual[0].rect), 0.0);
        XCTAssertGreaterThan(CGRectGetHeight(actual[0].rect), 0.0);
        XCTAssertTrue(actual[0].containsStart);
        XCTAssertTrue(actual[0].containsEnd);
        XCTAssertEqual(actual[0].containsStart, stock[0].containsStart);
        XCTAssertEqual(actual[0].containsEnd, stock[0].containsEnd);
        XCTAssertEqual(actual[0].writingDirection, stock[0].writingDirection);
        // The selection is the separator alone, so the line it sits on is covered to its END and
        // not from its beginning: the trailing side fills, the leading side stays on stock's glyph.
        CGRect expected = IDSelectionRectExpectedFromStock(
            stock[0].rect, [self containerBoundsForBlockAtIndex:0 inStack:stack],
            NSWritingDirectionLeftToRight, NO, YES);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actual[0].rect),
                                   CGRectGetMinX(expected), 1.0);
        XCTAssertEqualWithAccuracy(CGRectGetMaxX(actual[0].rect),
                                   CGRectGetMaxX(expected), 1.0);
    }
}

- (void)testTask16SeparatorOnlyRTLSelectionMatchesUIKitUpstreamTail {
    IDBlockDocument *document = [self documentWithBlocks:@[@"אבג", @"abc"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(3, 1);
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:@"אבג\nabc"
                                                                       range:selection
                                                                       width:200.0];

    XCTAssertEqual(stock.count, 1U);
    XCTAssertEqual(actual.count, stock.count);
    if (actual.count == 1 && stock.count == 1) {
        XCTAssertGreaterThan(CGRectGetWidth(actual[0].rect), 0.0);
        XCTAssertGreaterThan(CGRectGetHeight(actual[0].rect), 0.0);
        XCTAssertTrue(actual[0].containsStart);
        XCTAssertTrue(actual[0].containsEnd);
        XCTAssertEqual(actual[0].containsStart, stock[0].containsStart);
        XCTAssertEqual(actual[0].containsEnd, stock[0].containsEnd);
        XCTAssertEqual(actual[0].writingDirection, NSWritingDirectionRightToLeft);
        XCTAssertEqual(actual[0].writingDirection, stock[0].writingDirection);
        // The separator is the line's tail here too, so the same side is covered — and on an RTL
        // line the end of the line is its LEFT edge, which is where the fill lands.
        CGRect expected = IDSelectionRectExpectedFromStock(
            stock[0].rect, [self containerBoundsForBlockAtIndex:0 inStack:stack],
            NSWritingDirectionRightToLeft, NO, YES);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actual[0].rect),
                                   CGRectGetMinX(expected), 1.0);
        XCTAssertEqualWithAccuracy(CGRectGetMaxX(actual[0].rect),
                                   CGRectGetMaxX(expected), 1.0);
    }
}

- (void)testTask16SeparatorAfterEmptyMiddleBlockFillsUpstreamLineFragment {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc", @"", @"def"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(4, 1);
    NSArray<IDRichTextSelectionRect *> *actual = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            (void)container;
            return YES;
        }];
    NSArray<UITextSelectionRect *> *stock = [self stockSelectionRectsForText:@"abc\n\ndef"
                                                                       range:selection
                                                                       width:200.0];

    XCTAssertEqual(document.blocks[1].attributedText.length, 0U);
    XCTAssertEqual(stock.count, 1U);
    XCTAssertEqual(actual.count, stock.count);
    if (actual.count == 1 && stock.count == 1) {
        XCTAssertTrue(actual[0].containsStart);
        XCTAssertTrue(actual[0].containsEnd);
        XCTAssertEqual(actual[0].containsStart, stock[0].containsStart);
        XCTAssertEqual(actual[0].containsEnd, stock[0].containsEnd);
        XCTAssertEqual(actual[0].writingDirection, stock[0].writingDirection);
        // The empty middle block has no glyphs, so the selection that covers its separator covers
        // its line from beginning to end: both sides fill.
        CGRect expected = IDSelectionRectExpectedFromStock(
            stock[0].rect, [self containerBoundsForBlockAtIndex:1 inStack:stack],
            NSWritingDirectionLeftToRight, YES, YES);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(actual[0].rect),
                                   CGRectGetMinX(expected), 1.0);
        XCTAssertEqualWithAccuracy(CGRectGetMaxX(actual[0].rect),
                                   CGRectGetMaxX(expected), 1.0);
        XCTAssertEqualWithAccuracy(CGRectGetWidth(actual[0].rect),
                                   CGRectGetWidth(expected), 1.0);
    }
}

- (void)testTask14PrivateAttributedTextCallbackReturnsCanonicalAttributesInsideOneBlock {
    NSAttributedStringKey attribute = @"IDTask14Attribute";
    NSMutableAttributedString *first = [[NSMutableAttributedString alloc]
        initWithString:@"alpha"
            attributes:@{attribute: @"base"}];
    [first addAttribute:attribute value:@"accent" range:NSMakeRange(1, 3)];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            first,
            [[NSAttributedString alloc] initWithString:@"beta"
                                            attributes:@{attribute: @"second"}],
        ]
               defaultAttributes:@{}];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(1, 3)];
    SEL selector = NSSelectorFromString(@"attributedTextInRange:");
    __block NSAttributedString *actual = nil;

    XCTAssertTrue([controller respondsToSelector:selector]);
    XCTAssertNoThrow(actual = ((id (*)(id, SEL, id))objc_msgSend)(controller,
                                                                  selector,
                                                                  range));
    NSAttributedString *expected = [controller.textStorageAdapter
        attributedSubstringFromRange:NSMakeRange(1, 3)];
    XCTAssertEqualObjects(actual, expected);
    XCTAssertEqualObjects([actual attribute:attribute atIndex:0 effectiveRange:NULL],
                          @"accent");
}

- (void)testTask14AttributedTextPreservesStructuralNewlineAndFollowingBlockAttributes {
    NSAttributedStringKey attribute = @"IDTask14Attribute";
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"alpha"
                                            attributes:@{attribute: @"first"}],
            [[NSAttributedString alloc] initWithString:@"beta"
                                            attributes:@{attribute: @"second"}],
        ]
               defaultAttributes:@{}];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(4, 4)];
    NSAttributedString *actual = [controller id_attributedTextInRange:range];

    XCTAssertEqualObjects(actual.string, @"a\nbe");
    XCTAssertEqualObjects(actual, [controller.textStorageAdapter
        attributedSubstringFromRange:NSMakeRange(4, 4)]);
    XCTAssertEqualObjects([actual attribute:attribute atIndex:0 effectiveRange:NULL], @"first");
    XCTAssertEqualObjects([actual attribute:attribute atIndex:1 effectiveRange:NULL], @"first");
    XCTAssertEqualObjects([actual attribute:attribute atIndex:2 effectiveRange:NULL], @"second");
}

- (void)testTask14AttributedTextReturnsEmptyAttributedSubstringForEmptyRange {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(5, 0)];

    NSAttributedString *actual = [controller id_attributedTextInRange:range];

    XCTAssertEqual(actual.length, 0U);
    XCTAssertEqualObjects(actual, [controller.textStorageAdapter
        attributedSubstringFromRange:NSMakeRange(5, 0)]);
}

- (void)testTask14AttributedTextRejectsForeignRangeWithControllerFailurePolicy {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDBlockDocument *foreignDocument = [self documentWithBlocks:@[@"other"]];
    IDRichTextPosition *foreignPosition = [self positionInDocument:foreignDocument offset:1];
    IDRichTextRange *foreignRange = [[IDRichTextRange alloc]
        initWithStart:foreignPosition end:foreignPosition];
    NSException *caught = nil;

    @try {
        (void)[controller id_attributedTextInRange:foreignRange];
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInvalidArgumentException);
    XCTAssertTrue([caught.reason containsString:
        @"IDRichTextLayoutController attributedTextInRange: failed"], @"%@", caught.reason);
}

- (void)testUTF16OffsetsPreserveSurrogatesStructuralNewlineAndEmptyBlocks {
    IDBlockDocument *document = [self documentWithBlocks:@[@"A😀", @"", @"Z"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    XCTAssertEqualObjects(controller.textStorageAdapter.string, @"A😀\n\nZ");
    XCTAssertEqual(document.canonicalLength, 6U);

    for (NSUInteger offset = 0; offset <= 6; offset += 1) {
        IDRichTextPosition *position = [controller
            positionForCanonicalOffset:offset
                              affinity:UITextStorageDirectionForward];
        XCTAssertEqual([controller id_canonicalOffsetForPosition:position], offset);
    }
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        [controller rangeForCanonicalRange:NSMakeRange(3, 2)] clipped:NO],
                               NSMakeRange(3, 2)));
}

- (void)testPositionAndRangeOperationsMatchNativeAffinityBoundsAndRangeOrdering {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextPosition *two = [controller positionForCanonicalOffset:2
                                                            affinity:UITextStorageDirectionBackward];
    IDRichTextPosition *six = (IDRichTextPosition *)[controller
        id_positionFromPosition:two offset:4];
    IDRichTextPosition *sevenForward = (IDRichTextPosition *)[controller
        id_positionFromPosition:two offset:5 affinity:UITextStorageDirectionForward];

    XCTAssertEqual([controller id_canonicalOffsetForPosition:six], 6U);
    XCTAssertEqual(six.affinity, UITextStorageDirectionBackward);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:sevenForward], 7U);
    XCTAssertEqual(sevenForward.affinity, UITextStorageDirectionForward);
    XCTAssertEqual([controller id_comparePosition:two toPosition:six], NSOrderedAscending);
    XCTAssertEqual([controller id_comparePosition:six toPosition:two], NSOrderedDescending);
    XCTAssertEqual([controller id_offsetFromPosition:two toPosition:six], 4);
    XCTAssertEqual([controller id_affinityForPosition:two], UITextStorageDirectionBackward);
    XCTAssertNil([controller id_positionFromPosition:
        [controller id_beginningOfDocument] offset:-1]);
    XCTAssertNil([controller id_positionFromPosition:
        [controller id_endOfDocument] offset:1]);
    XCTAssertNil([controller id_positionFromPosition:
        [controller id_beginningOfDocument]
                                     offset:-1
                                   affinity:UITextStorageDirectionForward]);
    XCTAssertNil([controller id_positionFromPosition:
        [controller id_endOfDocument]
                                     offset:1
                                   affinity:UITextStorageDirectionForward]);
    [self assertThrowsStage:@"positionWithOffset:affinity:" block:^{
        (void)[controller id_positionWithOffset:-1 affinity:UITextStorageDirectionForward];
    }];
    [self assertThrowsStage:@"positionWithOffset:affinity:" block:^{
        (void)[controller id_positionWithOffset:11 affinity:UITextStorageDirectionForward];
    }];
    XCTAssertEqual([controller id_canonicalOffsetForPosition:(IDRichTextPosition *)
        [controller id_positionWithOffset:0 affinity:UITextStorageDirectionForward]], 0U);
    XCTAssertEqual([controller id_canonicalOffsetForPosition:(IDRichTextPosition *)
        [controller id_positionWithOffset:10 affinity:UITextStorageDirectionForward]], 10U);
    XCTAssertEqual([controller id_affinityForPosition:[controller id_beginningOfDocument]],
                   UITextStorageDirectionForward);
    XCTAssertEqual([controller id_affinityForPosition:[controller id_endOfDocument]],
                   UITextStorageDirectionForward);

    IDRichTextRange *range = (IDRichTextRange *)[controller
        id_textRangeFromPosition:two toPosition:six];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:range clipped:NO],
                               NSMakeRange(2, 4)));
    IDRichTextRange *reversed = (IDRichTextRange *)[controller
        id_textRangeFromPosition:six toPosition:two];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:reversed clipped:NO],
                               NSMakeRange(2, 4)));

    // The typed canonical helper preserves location; the private singular
    // callback mirrors iOS 26.5's clipped-empty collapse independently.
    IDRichTextRange *endEmpty =
        [controller rangeForCanonicalRange:NSMakeRange(document.canonicalLength, 0)];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:endEmpty clipped:YES],
                               NSMakeRange(document.canonicalLength, 0)));
    XCTAssertTrue(NSEqualRanges([controller id_characterRangeForTextRange:endEmpty clipped:YES],
                               NSMakeRange(0, 0)));
}

- (void)testForeignCrossDocumentExpiredAndOutOfBoundsValuesAreRejected {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDBlockDocument *foreignDocument = [self documentWithBlocks:@[@"other"]];
    IDRichTextPosition *foreignPosition = [self positionInDocument:foreignDocument offset:1];
    IDRichTextRange *foreignRange = [[IDRichTextRange alloc]
        initWithStart:foreignPosition end:foreignPosition];

    [self assertThrowsStage:@"emptyTextRangeAtPosition:" block:^{
        (void)[controller id_emptyTextRangeAtPosition:(UITextPosition *)[UITextPosition new]];
    }];
    [self assertThrowsStage:@"comparePosition:toPosition:" block:^{
        (void)[controller id_comparePosition:[controller positionForCanonicalOffset:0
                                                                    affinity:UITextStorageDirectionForward]
                                  toPosition:foreignPosition];
    }];
    [self assertThrowsStage:@"characterRangeForTextRange:" block:^{
        (void)[controller id_characterRangeForTextRange:foreignRange clipped:NO];
    }];

    __strong IDRichTextPosition *expiredPosition = nil;
    @autoreleasepool {
        IDBlockDocument *expiringDocument = [self documentWithBlocks:@[@"gone"]];
        expiredPosition = [self positionInDocument:expiringDocument offset:1];
    }
    XCTAssertNil(expiredPosition.anchor.document);
    [self assertThrowsStage:@"affinityForPosition:" block:^{
        (void)[controller id_affinityForPosition:expiredPosition];
    }];

    [self assertThrowsStage:@"positionWithOffset:affinity:" block:^{
        (void)[controller id_positionWithOffset:-1 affinity:UITextStorageDirectionForward];
    }];
    XCTAssertNil([controller id_positionFromPosition:
        [controller positionForCanonicalOffset:0 affinity:UITextStorageDirectionForward]
                                     offset:-1]);
    [self assertThrowsStage:@"rangeForCanonicalRange:" block:^{
        (void)[controller rangeForCanonicalRange:NSMakeRange(NSNotFound, 0)];
    }];
    [self assertThrowsStage:@"rangeForCanonicalRange:" block:^{
        (void)[controller rangeForCanonicalRange:NSMakeRange(9, NSUIntegerMax)];
    }];
}

- (void)testNilAndNilEndpointRangeShellConvertToZeroLikeIOS265NilUnionRange {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:NULL];

    XCTAssertTrue(NSEqualRanges(
        [controller id_characterRangeForTextRange:nil clipped:NO],
        NSMakeRange(0, 0)));
    XCTAssertTrue(NSEqualRanges(
        [controller id_characterRangeForTextRange:nil clipped:YES],
        NSMakeRange(0, 0)));

    UITextRange *foreign = [UITextRange new];
    XCTAssertTrue(NSEqualRanges(
        [controller id_characterRangeForTextRange:foreign clipped:NO],
        NSMakeRange(0, 0)));
}

- (void)testCharacterRangeArrayContractIsSingleOrderedContiguousRange {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *empty = [controller rangeForCanonicalRange:NSMakeRange(4, 0)];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(2, 4)];

    NSArray<NSValue *> *emptyRanges =
        [controller id_characterRangesForTextRange:empty clipped:YES];
    NSArray<NSValue *> *ranges =
        [controller id_characterRangesForTextRange:range clipped:NO];
    XCTAssertEqual(emptyRanges.count, 1U);
    XCTAssertTrue(NSEqualRanges(emptyRanges.firstObject.rangeValue, NSMakeRange(4, 0)));
    XCTAssertTrue(NSEqualRanges([controller id_characterRangeForTextRange:empty clipped:YES],
                               NSMakeRange(0, 0)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:empty clipped:YES],
                               NSMakeRange(4, 0)));
    XCTAssertEqual(ranges.count, 1U);
    XCTAssertTrue(NSEqualRanges(ranges.firstObject.rangeValue, NSMakeRange(2, 4)));

    IDRichTextRange *roundTrip = (IDRichTextRange *)[controller
        id_textRangeForCharacterRanges:@[[NSValue valueWithRange:NSMakeRange(2, 4)]]];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:roundTrip clipped:NO],
                               NSMakeRange(2, 4)));
    IDRichTextRange *clampedOOB = (IDRichTextRange *)[controller
        id_textRangeForCharacterRanges:@[[NSValue valueWithRange:NSMakeRange(99, 2)]]];
    IDRichTextRange *clampedNotFound = (IDRichTextRange *)[controller
        id_textRangeForCharacterRanges:@[[NSValue valueWithRange:
            NSMakeRange(NSNotFound, 0)]]];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:clampedOOB clipped:NO],
                               NSMakeRange(10, 0)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:clampedNotFound
                                                              clipped:NO],
                               NSMakeRange(10, 0)));
    [self assertThrowsStage:@"textRangeForCharacterRanges:" block:^{
        (void)[controller id_textRangeForCharacterRanges:@[]];
    }];
    [self assertThrowsStage:@"textRangeForCharacterRanges:" block:^{
        (void)[controller id_textRangeForCharacterRanges:@[
            [NSValue valueWithRange:NSMakeRange(1, 1)],
            [NSValue valueWithRange:NSMakeRange(4, 1)],
        ]];
    }];
    [self assertThrowsStage:@"textRangeForCharacterRanges:" block:^{
        (void)[controller id_textRangeForCharacterRanges:(NSArray<NSValue *> *)@[@"foreign"]];
    }];
    [self assertThrowsStage:@"textRangeForCharacterRanges:" block:^{
        (void)[controller id_textRangeForCharacterRanges:@[
            [NSValue valueWithRange:NSMakeRange(4, NSUIntegerMax)],
        ]];
    }];
}

- (void)testCharacterRangeCallbacksAcceptUIKitOwnedRangeWrapperWithDocumentPositions {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDUIKitOwnedRangeWrapper *range = [[IDUIKitOwnedRangeWrapper alloc]
        initWithStart:[controller positionForCanonicalOffset:2
                                                   affinity:UITextStorageDirectionForward]
                  end:[controller positionForCanonicalOffset:6
                                                   affinity:UITextStorageDirectionForward]];

    XCTAssertTrue(NSEqualRanges(
        [controller id_characterRangeForTextRange:range clipped:YES],
        NSMakeRange(2, 4)));
    XCTAssertEqualObjects(
        [controller id_characterRangesForTextRange:range clipped:YES],
        (@[[NSValue valueWithRange:NSMakeRange(2, 4)]]));
}

- (void)testCharacterRangeCallbacksNormalizeUIKitClearSelectionRangeShell {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDUIKitOwnedRangeWrapper *clearSelection = [IDUIKitOwnedRangeWrapper new];

    XCTAssertTrue(NSEqualRanges(
        [controller id_characterRangeForTextRange:clearSelection clipped:YES],
        NSMakeRange(0, 0)));
    XCTAssertEqualObjects(
        [controller id_characterRangesForTextRange:clearSelection clipped:YES],
        (@[[NSValue valueWithRange:NSMakeRange(0, 0)]]));

    IDUIKitOwnedRangeWrapper *malformed = [[IDUIKitOwnedRangeWrapper alloc]
        initWithStart:[controller positionForCanonicalOffset:2
                                                   affinity:UITextStorageDirectionForward]
                  end:nil];
    [self assertThrowsStage:@"characterRangesForTextRange:clippedToDocument:"
                      block:^{
        (void)[controller id_characterRangesForTextRange:malformed clipped:YES];
    }];
}

- (void)testClippedConversionAndPrivateCreationMatchVerifiedNativeSemantics {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(5, 1)];

    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:range clipped:YES],
                               NSMakeRange(5, 1)));
    XCTAssertTrue(NSEqualRanges([controller id_characterRangeForTextRange:range clipped:YES],
                               NSMakeRange(5, 1)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        (IDRichTextRange *)[controller id_textRangeForCharacterRange:NSMakeRange(0, 0)]
                                                              clipped:NO],
                               NSMakeRange(0, 0)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        (IDRichTextRange *)[controller id_textRangeForCharacterRange:NSMakeRange(2, 4)]
                                                              clipped:NO],
                               NSMakeRange(2, 4)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        (IDRichTextRange *)[controller id_textRangeForCharacterRange:NSMakeRange(99, 2)]
                                                              clipped:NO],
                               NSMakeRange(10, 0)));
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        (IDRichTextRange *)[controller id_textRangeForCharacterRange:
            NSMakeRange(NSNotFound, 0)] clipped:NO],
                               NSMakeRange(10, 0)));
    [self assertThrowsStage:@"textRangeForCharacterRange:" block:^{
        (void)[controller id_textRangeForCharacterRange:NSMakeRange(4, NSUIntegerMax)];
    }];
}

- (void)testPrivateCharacterRangeCreationUsesForwardAffinityForEmptyRange {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller =
        [self controllerForDocument:document stack:NULL];

    IDRichTextRange *empty = (IDRichTextRange *)
        [controller id_textRangeForCharacterRange:NSMakeRange(2, 0)];

    XCTAssertTrue(empty.empty);
    XCTAssertEqual(empty.start.affinity, UITextStorageDirectionForward);
    XCTAssertEqual(empty.end.affinity, UITextStorageDirectionForward);
}

- (void)testClippedConversionSaturatesForgedTrackedEndpointsWithoutProjectionOverflow {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];

    IDRichTextRange *reversedAfterClamp =
        [controller rangeForCanonicalRange:NSMakeRange(2, 4)];
    IDRichTextPosition *forgedStart = reversedAfterClamp.start;
    [forgedStart.anchor setValue:@(NSUIntegerMax) forKey:@"localOffset"];
    XCTAssertTrue(NSEqualRanges(
        [controller canonicalRangeForTextRange:reversedAfterClamp clipped:YES],
        NSMakeRange(6, 4)));
    [self assertThrowsStage:@"characterRangeForTextRange:" block:^{
        (void)[controller canonicalRangeForTextRange:reversedAfterClamp clipped:NO];
    }];

    IDRichTextRange *notFoundEnd =
        [controller rangeForCanonicalRange:NSMakeRange(2, 4)];
    IDRichTextPosition *forgedNotFoundEnd = notFoundEnd.end;
    [forgedNotFoundEnd.anchor setValue:@(NSNotFound) forKey:@"localOffset"];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:notFoundEnd clipped:YES],
                               NSMakeRange(2, 8)));
    [self assertThrowsStage:@"characterRangeForTextRange:" block:^{
        (void)[controller canonicalRangeForTextRange:notFoundEnd clipped:NO];
    }];

    IDRichTextRange *bothSaturated =
        [controller rangeForCanonicalRange:NSMakeRange(2, 4)];
    IDRichTextPosition *bothStart = bothSaturated.start;
    IDRichTextPosition *bothEnd = bothSaturated.end;
    [bothStart.anchor setValue:@(NSUIntegerMax) forKey:@"localOffset"];
    [bothEnd.anchor setValue:@(NSUIntegerMax) forKey:@"localOffset"];
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:bothSaturated clipped:YES],
                               NSMakeRange(10, 0)));
}

- (void)testInitializerRejectsForeignIncompleteStaleAndMisorderedBlockStacks {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockDocument *foreignDocument = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *foreignStack =
        [[IDBlockStackCanvasView alloc] initWithDocument:foreignDocument];
    IDCanonicalTextStorageAdapter *adapter = [[IDCanonicalTextStorageAdapter alloc]
        initWithDocument:document];
    [self assertThrowsStage:@"initWithDocument:blockStack:" block:^{
        (void)[[IDRichTextLayoutController alloc] initWithDocument:document
                                                textStorageAdapter:adapter
                                                         blockStack:foreignStack];
    }];

    IDBlockStackCanvasView *incompleteStack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [incompleteStack setValue:@[incompleteStack.blockLayouts.firstObject]
                       forKey:@"blockLayouts"];
    [self assertThrowsStage:@"initWithDocument:blockStack:" block:^{
        (void)[[IDRichTextLayoutController alloc] initWithDocument:document
                                                textStorageAdapter:adapter
                                                         blockStack:incompleteStack];
    }];

    IDBlockStackCanvasView *misorderedStack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [misorderedStack setValue:[[misorderedStack.blockLayouts reverseObjectEnumerator] allObjects]
                       forKey:@"blockLayouts"];
    [self assertThrowsStage:@"initWithDocument:blockStack:" block:^{
        (void)[[IDRichTextLayoutController alloc] initWithDocument:document
                                                textStorageAdapter:adapter
                                                         blockStack:misorderedStack];
    }];

    IDBlockStackCanvasView *staleStack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [self assertThrowsStage:@"initWithDocument:blockStack:" block:^{
        (void)[[IDRichTextLayoutController alloc] initWithDocument:document
                                                textStorageAdapter:adapter
                                                         blockStack:staleStack];
    }];
}

- (void)testTrackedControllerRangesRoundTripAfterCanonicalMutationAndRebasing {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    IDRichTextRange *range = [controller rangeForCanonicalRange:NSMakeRange(2, 4)];
    IDRichTextPosition *caret = [controller positionForCanonicalOffset:7
                                                              affinity:UITextStorageDirectionForward];

    [controller.textStorageAdapter replaceCharactersInRange:NSMakeRange(0, 0)
                                                  withString:@"X"];

    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:range clipped:NO],
                               NSMakeRange(3, 4)));
    XCTAssertEqual([controller id_canonicalOffsetForPosition:caret], 8U);
    XCTAssertTrue(NSEqualRanges([controller canonicalRangeForTextRange:
        [controller rangeForCanonicalRange:NSMakeRange(3, 4)] clipped:NO],
                               NSMakeRange(3, 4)));
}

- (void)testTask8GeometryNavigationBiDiAndExactContainerRouting {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"אבג"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSArray<NSTextContainer *> *containers = [controller id_textContainers];
    XCTAssertEqual(containers.count, 1U);
    XCTAssertEqual([controller id_firstTextContainer], containers.firstObject);
    for (IDBlockLayout *layout in stack.blockLayouts) {
        XCTAssertNotEqual(containers.firstObject, layout.textContainer);
    }

    UITextPosition *secondStart = [controller positionForCanonicalOffset:6
                                                                 affinity:UITextStorageDirectionForward];
    IDBlockLayout *secondLayout = stack.blockLayouts[1];
    XCTAssertNil([secondLayout.contentStorage.textStorage
        attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL]);
    XCTAssertEqual([controller id_textContainerForPosition:secondStart],
                   containers.firstObject);
    XCTAssertEqual([controller id_baseWritingDirectionAtPosition:secondStart],
                   NSWritingDirectionRightToLeft);
    XCTAssertNotNil([controller id_textRangeForLineEnclosingPosition:secondStart]);

    NSTextContainer *routedContainer = nil;
    CGRect insertion = [controller id_insertionRectForPosition:secondStart
                                               typingAttributes:@{}
                                          placeholderAttachment:nil
                                                  textContainer:&routedContainer];
    XCTAssertEqual(routedContainer, containers.firstObject);
    XCTAssertTrue(isfinite(insertion.origin.x));
    XCTAssertTrue(isfinite(insertion.origin.y));
    XCTAssertTrue(isfinite(insertion.size.width));
    XCTAssertTrue(isfinite(insertion.size.height));
    XCTAssertGreaterThan(insertion.size.width, 0.0);
    XCTAssertGreaterThan(insertion.size.height, 0.0);

    UITextRange *crossBlock = [controller rangeForCanonicalRange:NSMakeRange(4, 3)];
    NSMutableArray<NSTextContainer *> *visited = [NSMutableArray array];
    NSArray<IDRichTextSelectionRect *> *rects = [controller
        id_selectionRectsForRange:crossBlock
        fromView:stack
        forContainerPassingTest:^BOOL(NSTextContainer *container) {
            [visited addObject:container];
            return YES;
        }];
    XCTAssertEqualObjects(visited, containers);
    XCTAssertEqual(rects.count, 2U);
    for (IDRichTextSelectionRect *rect in rects) {
        XCTAssertTrue(isfinite(rect.rect.origin.x));
        XCTAssertTrue(isfinite(rect.rect.origin.y));
        XCTAssertTrue(isfinite(rect.rect.size.width));
        XCTAssertTrue(isfinite(rect.rect.size.height));
        XCTAssertGreaterThan(rect.rect.size.width, 0.0);
        XCTAssertGreaterThan(rect.rect.size.height, 0.0);
    }

    UITextPosition *nearest = [controller id_nearestPositionAtPoint:CGPointMake(5, 5)
                                                         inContainer:containers[0]];
    XCTAssertNotNil(nearest);
    XCTAssertLessThanOrEqual([controller id_canonicalOffsetForPosition:(IDRichTextPosition *)nearest],
                             1U);
    XCTAssertNoThrow([controller id_ensureLayoutForRange:crossBlock]);
    XCTAssertNoThrow([controller id_invalidateLayoutForRange:crossBlock]);
}

- (void)testAdoptionRetainsControllerRejectsConflictsAndDetachIsLifecycleSafe {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha"]];
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:NULL];
    NSObject *first = [NSObject new];
    NSObject *second = [NSObject new];

    [controller id_adoptTextInputController:first];
    [controller id_adoptTextInputController:first];
    XCTAssertEqual(controller.inputController, first);
    [self assertThrowsStage:@"adoptTextInputController:" block:^{
        [controller id_adoptTextInputController:second];
    }];
    [controller id_detachFromTextInputController];
    XCTAssertNil(controller.inputController);
    [controller id_detachFromTextInputController];

    __weak NSObject *weakOwner = nil;
    @autoreleasepool {
        NSObject *owner = [NSObject new];
        weakOwner = owner;
        [controller id_adoptTextInputController:owner];
        XCTAssertEqual(controller.inputController, owner);
    }
    XCTAssertNotNil(weakOwner);
    XCTAssertEqual(controller.inputController, weakOwner);
    [controller id_detachFromTextInputController];
    XCTAssertNil(weakOwner);
    XCTAssertNil(controller.inputController);
}

- (void)testNativeInputOwnershipUsesRetainedConnectionAndNoNativeLayoutControllerOwnsCleanRoomState {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    id input = IDPrivateNewInputControllerWithRichLayoutController(controller,
                                                                    [NSObject new]);
    XCTAssertEqual(controller.inputController, input);
    XCTAssertEqual([controller id_textStorage], controller.textStorageAdapter);
    XCTAssertEqual([controller id_layoutManager], nil);
    XCTAssertFalse([controller id_canAccessLayoutManager]);
    objc_property_t inputProperty = class_getProperty(controller.class, "inputController");
    NSString *attributes = [NSString stringWithUTF8String:property_getAttributes(inputProperty)];
    XCTAssertTrue([attributes containsString:@",R,"], @"%@", attributes);
    XCTAssertFalse([attributes containsString:@",W,"], @"%@", attributes);
    NSArray *nativeInputObjects = IDObjectIvarValues(input);
    XCTAssertTrue([nativeInputObjects containsObject:controller], @"%@", nativeInputObjects);
    for (id value in nativeInputObjects) {
        XCTAssertFalse([NSStringFromClass([value class])
            containsString:@"_UITextKit2LayoutController"]);
    }
    [controller id_detachFromTextInputController];
    XCTAssertNil(controller.inputController);

    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(controller.class, &count);
    for (unsigned int index = 0; index < count; index += 1) {
        id value = object_getIvar(controller, ivars[index]);
        NSString *className = value == nil ? @"" : NSStringFromClass([value class]);
        XCTAssertFalse([className containsString:@"_UITextKit2LayoutController"], @"%@", className);
    }
    free(ivars);
    for (IDBlockLayout *layout in stack.blockLayouts) {
        XCTAssertNotEqual(layout.layoutManager.delegate, controller);
        XCTAssertFalse([NSStringFromClass([layout.layoutManager.delegate class])
            containsString:@"_UITextKit2LayoutController"]);
    }
}

- (void)testDisplayInvalidationRoutesTextNewlinesAndEmptyRangesToExistingCanvases {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta", @""]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    NSArray<IDBlockLayout *> *layouts = stack.blockLayouts;

    for (IDBlockLayout *layout in layouts) layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    [controller id_invalidateDisplayForCharacterRange:NSMakeRange(0, 1)];
    XCTAssertTrue(layouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(layouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(layouts[2].canvasView.layoutFragmentViewsNeedDisplay);

    for (IDBlockLayout *layout in layouts) layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    [controller id_invalidateDisplayForCharacterRange:NSMakeRange(5, 1)];
    XCTAssertTrue(layouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(layouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(layouts[2].canvasView.layoutFragmentViewsNeedDisplay);

    for (IDBlockLayout *layout in layouts) layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    [controller id_invalidateDisplayForCharacterRange:NSMakeRange(6, 5)];
    XCTAssertFalse(layouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(layouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(layouts[2].canvasView.layoutFragmentViewsNeedDisplay);

    for (IDBlockLayout *layout in layouts) layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    [controller id_invalidateDisplayForCharacterRange:NSMakeRange(6, 0)];
    XCTAssertFalse(layouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(layouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(layouts[2].canvasView.layoutFragmentViewsNeedDisplay);

    [self assertThrowsStage:@"invalidateDisplayForCharacterRange:" block:^{
        [controller id_invalidateDisplayForCharacterRange:NSMakeRange(NSNotFound, 1)];
    }];
}

- (void)testEmptyDisplayInvalidationAtDocumentEndAndAcrossAllEmptyBlocks {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta", @""]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document stack:&stack];
    for (IDBlockLayout *layout in stack.blockLayouts) {
        layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    }
    [controller id_invalidateDisplayForCharacterRange:
        NSMakeRange(document.canonicalLength, 0)];
    XCTAssertFalse(stack.blockLayouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(stack.blockLayouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(stack.blockLayouts[2].canvasView.layoutFragmentViewsNeedDisplay);

    IDBlockDocument *emptyDocument = [self documentWithBlocks:@[@"", @"", @""]];
    IDBlockStackCanvasView *emptyStack = nil;
    IDRichTextLayoutController *emptyController =
        [self controllerForDocument:emptyDocument stack:&emptyStack];
    for (IDBlockLayout *layout in emptyStack.blockLayouts) {
        layout.canvasView.layoutFragmentViewsNeedDisplay = NO;
    }
    [emptyController id_invalidateDisplayForCharacterRange:
        NSMakeRange(emptyDocument.canonicalLength, 0)];
    XCTAssertFalse(emptyStack.blockLayouts[0].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertFalse(emptyStack.blockLayouts[1].canvasView.layoutFragmentViewsNeedDisplay);
    XCTAssertTrue(emptyStack.blockLayouts[2].canvasView.layoutFragmentViewsNeedDisplay);
}

- (IDGeometryMutatingCoordinator *)selectionCoordinatorForDocument:
    (IDBlockDocument *)document
                                                              stack:
    (IDBlockStackCanvasView *)stack
                                                              range:
    (NSRange)range {
    IDDocumentLayoutCoordinator *real = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:stack];
    IDGeometryMutatingCoordinator *scripted =
        [[IDGeometryMutatingCoordinator alloc] initWithDocument:document
                                                         source:stack];
    scripted.selectionResult = [real selectionGeometryForCanonicalRange:range];
    return scripted;
}

- (void)testExactSelectionAdapterDistinguishesFailureFromExactEmpty {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(1, 6);
    IDGeometryMutatingCoordinator *scripted = [self
        selectionCoordinatorForDocument:document stack:stack range:selection];
    [controller setValue:scripted forKey:@"id_documentLayoutCoordinator"];
    [scripted.selectionResult setValue:@[] forKey:@"segments"];

    NSArray *empty = [controller
        id_exactSelectionRectsForRange:[controller rangeForCanonicalRange:selection]
                               fromView:stack
                forContainerPassingTest:nil];
    XCTAssertNotNil(empty);
    XCTAssertEqual(empty.count, 0U);

    scripted.mutation = IDGeometryMutationNilResult;
    XCTAssertNil([controller
        id_exactSelectionRectsForRange:[controller rangeForCanonicalRange:selection]
                               fromView:stack
                forContainerPassingTest:nil]);
}

- (void)testNeutralSelectionGeometryOwnsProductionRectanglesAndEndpointRoles {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(1, 6);
    IDGeometryMutatingCoordinator *scripted = [self
        selectionCoordinatorForDocument:document stack:stack range:selection];
    IDDocumentSelectionSegment *first = scripted.selectionResult.segments.firstObject;
    CGRect authoritativeRect = CGRectMake(73, 91, 37, 19);
    [first setValue:[NSValue valueWithCGRect:authoritativeRect]
             forKey:@"documentRect"];
    [first setValue:@NO forKey:@"containsLogicalStart"];
    [controller setValue:scripted forKey:@"id_documentLayoutCoordinator"];

    NSArray<IDRichTextSelectionRect *> *rects = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
                          fromView:stack
           forContainerPassingTest:nil];
    XCTAssertEqual(scripted.selectionCallCount, 1U);
    XCTAssertTrue(CGRectEqualToRect(rects.firstObject.rect, authoritativeRect));
    XCTAssertFalse(rects.firstObject.containsStart);
}

- (void)testNeutralSelectionGeometryOwnsExactEmptyOffscreenResult {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    NSRange selection = NSMakeRange(1, 6);
    IDGeometryMutatingCoordinator *scripted = [self
        selectionCoordinatorForDocument:document stack:stack range:selection];
    [scripted.selectionResult setValue:@[] forKey:@"segments"];
    [controller setValue:scripted forKey:@"id_documentLayoutCoordinator"];

    NSArray *rects = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:selection]
                          fromView:stack
           forContainerPassingTest:nil];
    XCTAssertEqual(scripted.selectionCallCount, 1U);
    XCTAssertEqual(rects.count, 0U);
}

- (void)testNeutralSelectionGeometryFailureReturnsEmptyWithoutEstablishedFallback {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *scripted = [self
        selectionCoordinatorForDocument:document stack:stack range:NSMakeRange(1, 6)];
    scripted.mutation = IDGeometryMutationNilResult;
    [controller setValue:scripted forKey:@"id_documentLayoutCoordinator"];

    NSArray *rects = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:NSMakeRange(1, 6)]
                          fromView:stack
           forContainerPassingTest:nil];
    XCTAssertEqual(scripted.selectionCallCount, 1U);
    XCTAssertEqual(rects.count, 0U);
}

- (void)testSelectionContainerPredicateRejectsBeforeCoordinatorQuery {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha"]];
    IDBlockStackCanvasView *stack = nil;
    IDRichTextLayoutController *controller = [self controllerForDocument:document
                                                                    stack:&stack];
    IDGeometryMutatingCoordinator *scripted = [self
        selectionCoordinatorForDocument:document stack:stack range:NSMakeRange(0, 5)];
    [controller setValue:scripted forKey:@"id_documentLayoutCoordinator"];

    NSArray *rects = [controller
        id_selectionRectsForRange:[controller rangeForCanonicalRange:NSMakeRange(0, 5)]
                          fromView:stack
           forContainerPassingTest:^BOOL(__unused id container) { return NO; }];
    XCTAssertEqual(rects.count, 0U);
    XCTAssertEqual(scripted.selectionCallCount, 0U);
}

@end
