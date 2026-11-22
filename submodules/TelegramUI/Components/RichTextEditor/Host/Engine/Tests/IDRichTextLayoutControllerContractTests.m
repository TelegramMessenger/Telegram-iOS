@import XCTest;
#import <objc/message.h>
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextLayoutControllerContractProbe.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import <objc/runtime.h>

@interface IDRichTextLayoutControllerContractTests : XCTestCase
@end

@interface IDRichLayoutABISignatureProbe : NSProxy
@property(nonatomic, strong) id target;
@property(nonatomic, copy) NSString *overriddenSelectorName;
@property(nonatomic, strong) NSMethodSignature *overriddenSignature;
@end

@implementation IDRichLayoutABISignatureProbe

- (BOOL)respondsToSelector:(SEL)selector {
    return [self.target respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if ([NSStringFromSelector(selector) isEqualToString:self.overriddenSelectorName]) {
        return self.overriddenSignature;
    }
    return [self.target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}

@end

@implementation IDRichTextLayoutControllerContractTests

- (IDRichTextLayoutController *)id_cleanRoomLayoutController {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"alpha"],
            [[NSAttributedString alloc] initWithString:@"beta"],
        ]
               defaultAttributes:@{}];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    IDCanonicalTextStorageAdapter *adapter = [[IDCanonicalTextStorageAdapter alloc]
        initWithDocument:document];
    return [[IDRichTextLayoutController alloc] initWithDocument:document
                                             textStorageAdapter:adapter
                                                      blockStack:stack];
}

- (void)testPublicConvenienceInitializerConstructsItsOwnCanonicalAdapter {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"alpha"],
            [[NSAttributedString alloc] initWithString:@"beta"],
        ]
               defaultAttributes:@{}];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];

    IDRichTextLayoutController *controller = [[IDRichTextLayoutController alloc]
        initWithDocument:document
              blockStack:stack];

    XCTAssertNotNil(controller);
    XCTAssertEqual(controller.document, document);
    XCTAssertEqual(controller.textStorageAdapter.document, document);
    XCTAssertEqualObjects(controller.textStorageAdapter.string, @"alpha\nbeta");
}

- (void)testRichLayoutRecoveredCallbackABIsAcceptExactCleanRoomSignatures {
    IDRichTextLayoutController *controller = [self id_cleanRoomLayoutController];

    XCTAssertNoThrow(IDPrivateRequireRichLayoutController(
        controller,
        @"Exact recovered callback ABI preflight"));
}

- (void)testRichLayoutRecoveredCallbackABIsRejectEachWrongButPresentSignature {
    IDRichTextLayoutController *controller = [self id_cleanRoomLayoutController];
    NSArray<NSDictionary<NSString *, NSString *> *> *cases = @[
        @{
            @"selector": @"textInputController",
            @"types": @"v@:",
        },
        @{
            @"selector": @"boundingRectForCharacterRange:",
            @"types": [NSString stringWithFormat:@"v@:%s", @encode(NSRange)],
        },
        @{
            @"selector": @"boundingRectForCharacterRange:",
            @"types": [NSString stringWithFormat:@"%s@:@", @encode(CGRect)],
        },
        @{
            @"selector": @"boundingRectForCharacterRange:",
            @"types": [NSString stringWithFormat:@"@@:%s", @encode(NSRange)],
        },
        @{
            @"selector": @"attributedTextInRange:",
            @"types": @"v@:@",
        },
        @{
            @"selector": @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:",
            @"types": @"@@:@qqqf",
        },
        @{
            @"selector": @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:",
            @"types": @"@@:@@@@",
        },
        @{
            @"selector": @"cursorPositionAtPoint:inContainer:",
            @"types": @"@@:@@",
        },
        @{
            @"selector": @"rangeOfCharacterClusterAtIndex:type:",
            @"types": [NSString stringWithFormat:@"@@:%s%s",
                                                   @encode(NSUInteger),
                                                   @encode(NSInteger)],
        },
        @{
            @"selector": @"selectionRectsForRange:fromView:forContainerPassingTest:",
            @"types": @"@@:@@@",
        },
        @{
            @"selector": @"requestTextGeometryAtPosition:typingAttributes:resultBlock:",
            @"types": @"@@:@@@?",
        },
        @{
            @"selector": @"annotationAttribute:atPosition:",
            @"types": [NSString stringWithFormat:@"@@:@%s", @encode(NSUInteger)],
        },
        @{
            @"selector": @"annotatedSubstringForRange:",
            @"types": @"v@:@",
        },
        @{
            @"selector": @"addAnnotationAttribute:value:forRange:",
            @"types": @"@@:@@@",
        },
        @{
            @"selector": @"removeAnnotationAttribute:forRange:",
            @"types": @"@@:@@",
        },
        @{
            @"selector": @"addRenderingAttributes:forRange:",
            @"types": [NSString stringWithFormat:@"v@:%s@", @encode(NSUInteger)],
        },
        @{
            @"selector": @"removeRenderingAttributes:forRange:",
            @"types": [NSString stringWithFormat:@"v@:@%s", @encode(NSUInteger)],
        },
        @{
            @"selector": @"_invalidateTemporaryAttributesInRange:",
            @"types": @"@@:@",
        },
    ];

    for (NSDictionary<NSString *, NSString *> *testCase in cases) {
        NSString *selectorName = testCase[@"selector"];
        IDRichLayoutABISignatureProbe *probe = (id)[IDRichLayoutABISignatureProbe alloc];
        probe.target = controller;
        probe.overriddenSelectorName = selectorName;
        probe.overriddenSignature =
            [NSMethodSignature signatureWithObjCTypes:testCase[@"types"].UTF8String];
        NSString *stage = [@"Synthetic recovered ABI preflight: "
            stringByAppendingString:selectorName];
        NSException *caught = nil;

        @try {
            IDPrivateRequireRichLayoutController(probe, stage);
        } @catch (NSException *exception) {
            caught = exception;
        }

        XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException,
                              @"%@", selectorName);
        XCTAssertTrue([caught.reason containsString:stage], @"%@", caught.reason);
        XCTAssertTrue([caught.reason containsString:selectorName], @"%@", caught.reason);
        XCTAssertTrue([caught.reason containsString:@"ABI"], @"%@", caught.reason);
        XCTAssertTrue([caught.reason containsString:@"expected"], @"%@", caught.reason);
        XCTAssertTrue([caught.reason containsString:@"actual"], @"%@", caught.reason);
    }
}

- (void)testIOS265NativeOracleBoundsAffinityRangeOrderingAndClipping {
    IDTextView *oracle = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
    oracle.text = @"abcdefghij";
    id native = oracle.id_layoutController;

    SEL beginningSelector = NSSelectorFromString(@"beginningOfDocument");
    SEL endSelector = NSSelectorFromString(@"endOfDocument");
    SEL affinitySelector = NSSelectorFromString(@"affinityForPosition:");
    SEL movementSelector = NSSelectorFromString(@"positionFromPosition:offset:affinity:");
    SEL rangeSelector = NSSelectorFromString(@"textRangeFromPosition:toPosition:");
    SEL characterRangeSelector = NSSelectorFromString(@"characterRangeForTextRange:");
    SEL offsetSelector = NSSelectorFromString(@"offsetFromPosition:toPosition:");
    SEL rangeForCharactersSelector = NSSelectorFromString(@"textRangeForCharacterRange:");
    SEL rangeForCharacterRangesSelector =
        NSSelectorFromString(@"textRangeForCharacterRanges:");
    SEL positionWithOffsetSelector =
        NSSelectorFromString(@"positionWithOffset:affinity:");
    SEL clippedSelector =
        NSSelectorFromString(@"characterRangeForTextRange:clippedToDocument:");
    SEL clippedRangesSelector =
        NSSelectorFromString(@"characterRangesForTextRange:clippedToDocument:");

    UITextPosition *beginning =
        ((id (*)(id, SEL))objc_msgSend)(native, beginningSelector);
    UITextPosition *end = ((id (*)(id, SEL))objc_msgSend)(native, endSelector);
    NSInteger beginningAffinity =
        ((NSInteger (*)(id, SEL, id))objc_msgSend)(native, affinitySelector, beginning);
    NSInteger endAffinity =
        ((NSInteger (*)(id, SEL, id))objc_msgSend)(native, affinitySelector, end);
    XCTAssertEqual(beginningAffinity, UITextStorageDirectionForward);
    XCTAssertEqual(endAffinity, UITextStorageDirectionForward);
    XCTAssertFalse([native respondsToSelector:NSSelectorFromString(
        @"positionFromPosition:offset:")]);
    XCTAssertNil(((id (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(
        native, movementSelector, beginning, -1, UITextStorageDirectionForward));
    XCTAssertNil(((id (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(
        native, movementSelector, end, 1, UITextStorageDirectionForward));

    UITextRange *reversed = ((id (*)(id, SEL, id, id))objc_msgSend)(
        native, rangeSelector, end, beginning);
    NSRange ordered = ((NSRange (*)(id, SEL, id))objc_msgSend)(
        native, characterRangeSelector, reversed);
    XCTAssertTrue(NSEqualRanges(ordered, NSMakeRange(0, 10)));

    UITextRange *valid = ((id (*)(id, SEL, NSRange))objc_msgSend)(
        native, rangeForCharactersSelector, NSMakeRange(2, 4));
    NSRange validClipped = ((NSRange (*)(id, SEL, id, BOOL))objc_msgSend)(
        native, clippedSelector, valid, YES);
    XCTAssertTrue(NSEqualRanges(validClipped, NSMakeRange(2, 4)));

    NSArray<NSValue *> *creationCases = @[
        [NSValue valueWithRange:NSMakeRange(0, 0)],
        [NSValue valueWithRange:NSMakeRange(2, 4)],
        [NSValue valueWithRange:NSMakeRange(99, 2)],
        [NSValue valueWithRange:NSMakeRange(NSNotFound, 0)],
        [NSValue valueWithRange:NSMakeRange(4, NSUIntegerMax)],
    ];
    NSArray<NSValue *> *expectedCreatedRanges = @[
        [NSValue valueWithRange:NSMakeRange(0, 0)],
        [NSValue valueWithRange:NSMakeRange(2, 4)],
        [NSValue valueWithRange:NSMakeRange(10, 0)],
        [NSValue valueWithRange:NSMakeRange(10, 0)],
    ];
    for (NSUInteger index = 0; index < creationCases.count; index += 1) {
        NSRange input = creationCases[index].rangeValue;
        UITextRange *created = nil;
        NSException *creationException = nil;
        @try {
            created = ((id (*)(id, SEL, NSRange))objc_msgSend)(
                native, rangeForCharactersSelector, input);
        } @catch (NSException *exception) {
            creationException = exception;
        }
        if (index == creationCases.count - 1) {
            XCTAssertEqualObjects(creationException.name, NSInvalidArgumentException);
        } else {
            XCTAssertNil(creationException);
            XCTAssertNotNil(created);
            NSRange converted = ((NSRange (*)(id, SEL, id))objc_msgSend)(
                native, characterRangeSelector, created);
            XCTAssertTrue(NSEqualRanges(converted, expectedCreatedRanges[index].rangeValue));
        }

        UITextRange *createdFromArray = nil;
        NSException *arrayCreationException = nil;
        @try {
            createdFromArray = ((id (*)(id, SEL, id))objc_msgSend)(
                native, rangeForCharacterRangesSelector, @[creationCases[index]]);
        } @catch (NSException *exception) {
            arrayCreationException = exception;
        }
        if (index == creationCases.count - 1) {
            XCTAssertEqualObjects(arrayCreationException.name, NSInvalidArgumentException);
            XCTAssertNil(createdFromArray);
        } else {
            XCTAssertNil(arrayCreationException);
            XCTAssertNotNil(createdFromArray);
            NSRange convertedFromArray = ((NSRange (*)(id, SEL, id))objc_msgSend)(
                native, characterRangeSelector, createdFromArray);
            XCTAssertTrue(NSEqualRanges(convertedFromArray,
                                       expectedCreatedRanges[index].rangeValue));
        }
    }

    for (NSNumber *offsetValue in @[@(-1), @0, @10, @11]) {
        NSInteger offset = offsetValue.integerValue;
        UITextPosition *position = nil;
        NSException *positionException = nil;
        @try {
            position = ((id (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(
                native, positionWithOffsetSelector, offset, UITextStorageDirectionForward);
        } @catch (NSException *exception) {
            positionException = exception;
        }
        NSInteger recovered = NSIntegerMin;
        NSException *offsetException = nil;
        if (position != nil) {
            @try {
                recovered = ((NSInteger (*)(id, SEL, id, id))objc_msgSend)(
                    native, offsetSelector, beginning, position);
            } @catch (NSException *exception) {
                offsetException = exception;
            }
        }
        if (offset < 0 || offset > 10) {
            XCTAssertEqualObjects(positionException.name, NSInvalidArgumentException);
            XCTAssertNil(position);
        } else {
            XCTAssertNil(positionException);
            XCTAssertNil(offsetException);
            XCTAssertNotNil(position);
            XCTAssertEqual(recovered, offset);
        }
    }

    for (NSNumber *locationValue in @[@0, @1, @4, @9, @10]) {
        NSUInteger location = locationValue.unsignedIntegerValue;
        UITextRange *nativeEmpty = ((id (*)(id, SEL, NSRange))objc_msgSend)(
            native, rangeForCharactersSelector, NSMakeRange(location, 0));
        XCTAssertNotNil(nativeEmpty);
        NSInteger startOffset = ((NSInteger (*)(id, SEL, id, id))objc_msgSend)(
            native, offsetSelector, beginning, nativeEmpty.start);
        NSInteger endOffset = ((NSInteger (*)(id, SEL, id, id))objc_msgSend)(
            native, offsetSelector, beginning, nativeEmpty.end);
        NSRange nativeUnclipped = ((NSRange (*)(id, SEL, id))objc_msgSend)(
            native, characterRangeSelector, nativeEmpty);
        NSRange nativeClipped = ((NSRange (*)(id, SEL, id, BOOL))objc_msgSend)(
            native, clippedSelector, nativeEmpty, YES);
        XCTAssertEqual(startOffset, (NSInteger)location);
        XCTAssertEqual(endOffset, (NSInteger)location);
        XCTAssertTrue(NSEqualRanges(nativeUnclipped, NSMakeRange(location, 0)));
        // iOS 26.5 collapses every clipped empty range to document beginning,
        // even though its live endpoints and unclipped conversion retain location.
        XCTAssertTrue(NSEqualRanges(nativeClipped, NSMakeRange(0, 0)));
        if (location == 0 || location == 4 || location == 10) {
            NSArray<NSValue *> *nativeClippedRanges =
                ((id (*)(id, SEL, id, BOOL))objc_msgSend)(
                    native, clippedRangesSelector, nativeEmpty, YES);
            XCTAssertEqual(nativeClippedRanges.count, 1U);
            XCTAssertTrue(NSEqualRanges(nativeClippedRanges.firstObject.rangeValue,
                                       NSMakeRange(location, 0)));
        }
    }
}

- (void)testNativeInputControllerAcceptsDuckTypedLayoutControllerAtConstruction {
    IDTextView *oracle = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
    id unattachedNativeController =
        [IDPrivateUIKit newLayoutControllerWithTextView:oracle
                                           textContainer:oracle.id_textContainer];
    IDRichTextLayoutControllerContractProbe *probe =
        (id)[[IDRichTextLayoutControllerContractProbe alloc]
            initWithTarget:unattachedNativeController];
    id input = IDPrivateNewInputControllerWithRichLayoutController(probe, oracle);
    XCTAssertNotNil(input);
    XCTAssertEqualObjects(probe.recordedSelectors, (@[
        @"adoptTextInputController:",
        @"canAccessLayoutManager",
        @"textContainers",
        @"textStorage",
        @"textStorage",
        @"beginningOfDocument",
        @"emptyTextRangeAtPosition:",
        @"textContainers",
        @"textStorage",
    ]));
}

- (void)testNativeInputControllerAcceptsCleanRoomControllerAndAdoptsIt {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"alpha"],
            [[NSAttributedString alloc] initWithString:@"beta"],
        ]
               defaultAttributes:@{}];
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    IDCanonicalTextStorageAdapter *adapter = [[IDCanonicalTextStorageAdapter alloc]
        initWithDocument:document];
    IDRichTextLayoutController *layoutController =
        [[IDRichTextLayoutController alloc] initWithDocument:document
                                         textStorageAdapter:adapter
                                                  blockStack:stack];

    IDPrivateRequireRichLayoutController(layoutController,
                                         @"Task 6 clean-room contract preflight");
    id input = IDPrivateNewInputControllerWithRichLayoutController(layoutController,
                                                                    [NSObject new]);

    XCTAssertNotNil(input);
    XCTAssertEqual(layoutController.inputController, input);
    XCTAssertEqual(layoutController.textStorageAdapter.document, document);
    XCTAssertEqualObjects(layoutController.textStorageAdapter.string, @"alpha\nbeta");
    NSArray<NSTextContainer *> *interactionContainers =
        [layoutController id_textContainers];
    XCTAssertEqual(interactionContainers.count, 1U);
    XCTAssertEqual([layoutController id_firstTextContainer],
                   interactionContainers.firstObject);
    for (IDBlockLayout *layout in stack.blockLayouts) {
        XCTAssertNotEqual(interactionContainers.firstObject, layout.textContainer);
    }
    XCTAssertFalse([NSStringFromClass(layoutController.class)
        containsString:@"_UITextKit2LayoutController"]);
}

- (void)testUIKitBaseConnectionIMPsUseTheCleanRoomConnectionSlot {
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    NSOperatingSystemVersion version = processInfo.operatingSystemVersion;
    NSString *versionString = processInfo.operatingSystemVersionString;
    BOOL isPinnedRuntime = version.majorVersion == 26 &&
        version.minorVersion == 5 &&
        version.patchVersion == 0 &&
        [versionString hasSuffix:@"(Build 23F73)"];
    if (!isPinnedRuntime) {
        XCTSkip(@"Recovered UIKitCore IMP mapping requires iOS 26.5 build 23F73; current runtime is %@",
                versionString);
        return;
    }

    IDRichTextLayoutController *layoutController = [self id_cleanRoomLayoutController];
    Class baseClass = NSClassFromString(@"_UITextLayoutControllerBase");
    SEL getterSelector = NSSelectorFromString(@"textInputController");
    SEL adoptSelector = NSSelectorFromString(@"adoptTextInputController:");
    SEL detachSelector = NSSelectorFromString(@"detachFromTextInputController");
    Method adoptMethod = class_getInstanceMethod(baseClass, adoptSelector);
    Method detachMethod = class_getInstanceMethod(baseClass, detachSelector);
    XCTAssertNotNil(baseClass);
    XCTAssertNotEqual(adoptMethod, NULL);
    XCTAssertNotEqual(detachMethod, NULL);
    if (adoptMethod == NULL || detachMethod == NULL) return;

    // UIKit calls this direct-only IMP by branch, so the getter is absent from
    // the Objective-C method list. Recover its iOS 26.5 address from the
    // discoverable base adoption IMP using the Hopper-proven address delta.
    intptr_t getterFromAdoptDelta = (intptr_t)0x1443ec0 - (intptr_t)0x1444280;
    id (*baseGetter)(id, SEL) =
        (id (*)(id, SEL))((uintptr_t)method_getImplementation(adoptMethod) +
                         getterFromAdoptDelta);
    void (*baseAdopt)(id, SEL, id) =
        (void (*)(id, SEL, id))method_getImplementation(adoptMethod);
    void (*baseDetach)(id, SEL) =
        (void (*)(id, SEL))method_getImplementation(detachMethod);

    XCTAssertNil(baseGetter(layoutController, getterSelector));

    id nativeInput = IDPrivateNewInputControllerWithRichLayoutController(
        layoutController,
        [NSObject new]);
    XCTAssertNotNil(nativeInput);
    XCTAssertEqual(layoutController.inputController, nativeInput);
    XCTAssertEqual(baseGetter(layoutController, getterSelector), nativeInput);

    Ivar connectionIvar = class_getInstanceVariable(
        layoutController.class,
        "_id_textInputControllerConnection");
    XCTAssertNotEqual(connectionIvar, NULL);
    if (connectionIvar == NULL) return;
    XCTAssertEqual(ivar_getOffset(connectionIvar), (ptrdiff_t)sizeof(void *));
    id connection = object_getIvar(layoutController, connectionIvar);
    XCTAssertNotNil(connection);

    baseDetach(layoutController, detachSelector);
    XCTAssertNil(layoutController.inputController);
    XCTAssertNil(baseGetter(layoutController, getterSelector));
    XCTAssertEqual(object_getIvar(layoutController, connectionIvar), connection);

    id replacementInput = [NSObject new];
    baseAdopt(layoutController, adoptSelector, replacementInput);
    XCTAssertEqual(layoutController.inputController, replacementInput);
    XCTAssertEqual(baseGetter(layoutController, getterSelector), replacementInput);
    XCTAssertEqual(object_getIvar(layoutController, connectionIvar), connection);
}

@end
