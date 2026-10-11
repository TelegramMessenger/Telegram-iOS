#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDPrivateUIKit+RichTextLayout.h"

#import "IDUIKitRuntimeContract.h"
// telegram-ios DEVIATION 5 (see PROVENANCE.md) — for the pristine contract manifest.
#import "RichTextInputDecUpstreamPristineManifest.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextSelectionRect.h"
#import "IDRichTextLayoutControllerInternal.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

typedef id (*IDPrivateRichInputControllerInitializerSend)(
    id __attribute__((ns_consumed)),
    SEL,
    id) __attribute__((ns_returns_retained));

IDUIKitRuntimeCapabilityContract *
IDPrivateRichInputControllerContract(void) {
    static IDUIKitRuntimeCapabilityContract *contract;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *resourceName = @"UIKitBehaviorContracts-iOS26.5";
        NSBundle *bundle = [NSBundle bundleForClass:IDPrivateUIKit.class];
        NSURL *URL = [bundle URLForResource:resourceName
                             withExtension:@"json"];
        if (URL == nil) {
            URL = [NSBundle.mainBundle URLForResource:resourceName
                                        withExtension:@"json"];
        }
        NSData *data = URL == nil
            ? nil
            : [NSData dataWithContentsOfURL:URL];
        // telegram-ios DEVIATION 5 (see PROVENANCE.md), site 1 of 2. ONE LINE, PURELY ADDITIVE, and
        // placed at the DATA level on purpose: upstream's resource lookup above runs first and wins
        // wherever the JSON is present, and everything below — the parse, the error handling, the
        // @throw — is upstream's, unchanged, operating on upstream's own bytes.
        if (data == nil) { data = TGRichTextInputDecUpstreamPristineContractJSON(); }
        NSError *error = nil;
        IDUIKitRuntimeManifest *manifest = data == nil
            ? nil
            : [IDUIKitRuntimeManifest manifestWithData:data
                                                 error:&error];
        contract = manifest.capabilities[@"inputController"];
        if (contract == nil) {
            NSString *reason = error.localizedDescription ?:
                @"The input-controller runtime contract resource is unavailable.";
            @throw [NSException
                exceptionWithName:NSInternalInconsistencyException
                           reason:reason
                         userInfo:nil];
        }
    });
    return contract;
}

static NSArray<NSString *> *IDPrivateRichLayoutRequiredSelectorNames(void) {
    static NSArray<NSString *> *selectorNames;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        selectorNames = @[
            @"textStorage",
            @"textContainers",
            @"firstTextContainer",
            @"textContainerForPosition:",
            @"beginningOfDocument",
            @"endOfDocument",
            @"emptyTextRangeAtPosition:",
            @"textRangeFromPosition:toPosition:",
            @"positionFromPosition:offset:",
            @"positionFromPosition:offset:affinity:",
            @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:",
            @"textRangeForLineEnclosingPosition:",
            @"textRangeForLineEnclosingPosition:effectiveAffinity:",
            @"attributesAtPosition:inDirection:",
            @"baseWritingDirectionAtPosition:",
            @"comparePosition:toPosition:",
            @"offsetFromPosition:toPosition:",
            @"affinityForPosition:",
            @"characterRangeForTextRange:",
            @"boundingRectForCharacterRange:",
            @"characterRangeForTextRange:clippedToDocument:",
            @"characterRangesForTextRange:clippedToDocument:",
            @"textRangeForCharacterRange:",
            @"textRangeForCharacterRanges:",
            @"positionWithOffset:affinity:",
            @"textInputController",
            @"adoptTextInputController:",
            @"detachFromTextInputController",
            @"canAccessLayoutManager",
            @"invalidateDisplayForCharacterRange:",
            @"rangeOfCharacterClusterAtIndex:type:",
            @"selectionRectsForRange:fromView:forContainerPassingTest:",
            @"requestTextGeometryAtPosition:typingAttributes:resultBlock:",
            @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:",
            @"cursorPositionAtPoint:inContainer:",
            @"nearestPositionAtPoint:inContainer:",
            @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:",
            @"ensureLayoutForRange:",
            @"invalidateLayoutForRange:",
            @"attributedTextInRange:",
            @"annotatedSubstringForRange:",
            @"addAnnotationAttribute:value:forRange:",
            @"annotationAttribute:atPosition:",
            @"removeAnnotationAttribute:forRange:",
            @"addRenderingAttributes:forRange:",
            @"removeRenderingAttributes:forRange:",
            @"_invalidateTemporaryAttributesInRange:",
        ];
    });
    return selectorNames;
}

static IMP IDPrivateRichOriginalCursorPositionIMP;
static NSUInteger IDPrivateRichCursorSequence;
static CGPoint IDPrivateRichCursorPoint;
static __strong UITextPosition *IDPrivateRichCursorOutput;
static BOOL IDPrivateRichCursorUsedInteractionContainer;

static UITextPosition *IDPrivateRichTracedCursorPosition(id controller, SEL selector,
                                                         CGPoint point, id container) {
    UITextPosition *(*original)(id, SEL, CGPoint, id) =
        (UITextPosition *(*)(id, SEL, CGPoint, id))IDPrivateRichOriginalCursorPositionIMP;
    UITextPosition *result = original(controller, selector, point, container);
    IDRichTextLayoutController *richController = controller;
    @synchronized (controller) {
        IDPrivateRichCursorSequence += 1;
        IDPrivateRichCursorPoint = point;
        IDPrivateRichCursorOutput = result;
        IDPrivateRichCursorUsedInteractionContainer =
            container == richController.id_interactionTextContainer;
    }
    return result;
}

void IDPrivateInstallRichCursorTraceForUITesting(id layoutController) {
    IDPrivateRequireRichLayoutController(layoutController,
        @"UI-test cursor trace installation preflight");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = NSSelectorFromString(@"cursorPositionAtPoint:inContainer:");
        Method method = class_getInstanceMethod([layoutController class], selector);
        IDPrivateRichOriginalCursorPositionIMP = method_getImplementation(method);
        method_setImplementation(method, (IMP)IDPrivateRichTracedCursorPosition);
    });
}

NSDictionary<NSString *, id> *IDPrivateCopyRichCursorTraceForUITesting(
    id layoutController) {
    IDRichTextLayoutController *controller = layoutController;
    @synchronized (controller) {
        if (IDPrivateRichCursorSequence == 0 || IDPrivateRichCursorOutput == nil) return nil;
        return @{
            @"sequence": @(IDPrivateRichCursorSequence),
            @"kind": @"cursor",
            @"interactionContainer": @(IDPrivateRichCursorUsedInteractionContainer),
            @"point": @{@"x": @(IDPrivateRichCursorPoint.x),
                         @"y": @(IDPrivateRichCursorPoint.y)},
            @"output": @{
                @"offset": @([controller id_canonicalOffsetForPosition:
                    (id)IDPrivateRichCursorOutput]),
                @"affinity": @([controller id_affinityForPosition:
                    IDPrivateRichCursorOutput]),
            },
        };
    }
}

static NSArray<NSString *> *IDPrivateMissingRichLayoutSelectorNames(id layoutController) {
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    for (NSString *selectorName in IDPrivateRichLayoutRequiredSelectorNames()) {
        if (![layoutController respondsToSelector:NSSelectorFromString(selectorName)]) {
            [missing addObject:selectorName];
        }
    }
    return missing.copy;
}

static NSString *IDPrivateTypeEncoding(const char *encoding) {
    return encoding ? [NSString stringWithUTF8String:encoding] : @"<missing>";
}

static const char *IDPrivateSkipTypeQualifiers(const char *encoding) {
    while (encoding != NULL && strchr("rnNoORV", encoding[0]) != NULL) {
        encoding += 1;
    }
    return encoding;
}

static BOOL IDPrivateTypeEncodingMatches(const char *actual,
                                         const char *expected) {
    actual = IDPrivateSkipTypeQualifiers(actual);
    expected = IDPrivateSkipTypeQualifiers(expected);
    if (actual == NULL || expected == NULL) return actual == expected;

    // Runtime encodings may retain an Objective-C class name (for example
    // @"NSString"). That is still the same object ABI as @, but @? remains a
    // distinct block ABI and must never be accepted as an ordinary object.
    if (expected[0] == '@' && expected[1] == '\0') {
        return actual[0] == '@' && actual[1] != '?';
    }
    if (expected[0] == '@' && expected[1] == '?') {
        return actual[0] == '@' && actual[1] == '?' && actual[2] == '\0';
    }
    return strcmp(actual, expected) == 0;
}

static NSArray<NSDictionary<NSString *, id> *> *IDPrivateRichLayoutABISpecs(void) {
    static NSArray<NSDictionary<NSString *, id> *> *specs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        specs = @[
            @{
                @"selector": @"textInputController",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[],
            },
            @{
                @"selector": @"firstTextContainer",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[],
            },
            @{
                @"selector": @"textContainerForPosition:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(UITextLayoutDirection)),
                    IDPrivateTypeEncoding(@encode(NSInteger)),
                    IDPrivateTypeEncoding(@encode(UITextStorageDirection)),
                    IDPrivateTypeEncoding(@encode(CGFloat)),
                ],
            },
            @{
                @"selector": @"textRangeForLineEnclosingPosition:effectiveAffinity:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(UITextStorageDirection)),
                ],
            },
            @{
                @"selector": @"textRangeForLineEnclosingPosition:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"attributesAtPosition:inDirection:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(UITextStorageDirection)),
                ],
            },
            @{
                @"selector": @"baseWritingDirectionAtPosition:",
                @"return": IDPrivateTypeEncoding(@encode(NSWritingDirection)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"boundingRectForCharacterRange:",
                @"return": IDPrivateTypeEncoding(@encode(CGRect)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(NSRange))],
            },
            @{
                @"selector": @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:",
                @"return": IDPrivateTypeEncoding(@encode(CGRect)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                    @"^@",
                ],
            },
            @{
                @"selector": @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(CGPoint)),
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(UITextStorageDirection)),
                ],
            },
            @{
                @"selector": @"cursorPositionAtPoint:inContainer:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(CGPoint)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"nearestPositionAtPoint:inContainer:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(CGPoint)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"ensureLayoutForRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"invalidateLayoutForRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"rangeOfCharacterClusterAtIndex:type:",
                @"return": IDPrivateTypeEncoding(@encode(NSRange)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(NSUInteger)),
                    IDPrivateTypeEncoding(@encode(NSInteger)),
                ],
            },
            @{
                @"selector": @"selectionRectsForRange:fromView:forContainerPassingTest:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                    @"@?",
                ],
            },
            @{
                @"selector": @"requestTextGeometryAtPosition:typingAttributes:resultBlock:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                    @"@?",
                ],
            },
            @{
                @"selector": @"attributedTextInRange:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"annotationAttribute:atPosition:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"annotatedSubstringForRange:",
                @"return": IDPrivateTypeEncoding(@encode(id)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
            @{
                @"selector": @"addAnnotationAttribute:value:forRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"removeAnnotationAttribute:forRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"addRenderingAttributes:forRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"removeRenderingAttributes:forRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[
                    IDPrivateTypeEncoding(@encode(id)),
                    IDPrivateTypeEncoding(@encode(id)),
                ],
            },
            @{
                @"selector": @"_invalidateTemporaryAttributesInRange:",
                @"return": IDPrivateTypeEncoding(@encode(void)),
                @"arguments": @[IDPrivateTypeEncoding(@encode(id))],
            },
        ];
    });
    return specs;
}

static NSString *IDPrivateRichLayoutABIMismatch(
    id layoutController,
    NSDictionary<NSString *, id> *spec) {
    NSString *selectorName = spec[@"selector"];
    NSString *expectedReturn = spec[@"return"];
    NSArray<NSString *> *expectedArguments = spec[@"arguments"];
    NSMethodSignature *signature =
        [layoutController methodSignatureForSelector:NSSelectorFromString(selectorName)];
    if (signature == nil) {
        return [NSString stringWithFormat:
            @"%@ ABI mismatch: expected return %@ and arguments (%@); actual method signature is missing.",
            selectorName,
            expectedReturn,
            [expectedArguments componentsJoinedByString:@", "]];
    }

    NSMutableArray<NSString *> *actualArguments = [NSMutableArray array];
    NSUInteger actualExplicitArgumentCount =
        signature.numberOfArguments >= 2 ? signature.numberOfArguments - 2 : 0;
    for (NSUInteger index = 0; index < actualExplicitArgumentCount; index++) {
        [actualArguments addObject:IDPrivateTypeEncoding(
            [signature getArgumentTypeAtIndex:index + 2])];
    }

    BOOL returnMatches = IDPrivateTypeEncodingMatches(
        signature.methodReturnType,
        expectedReturn.UTF8String);
    BOOL argumentsMatch =
        actualExplicitArgumentCount == expectedArguments.count;
    if (argumentsMatch) {
        for (NSUInteger index = 0; index < expectedArguments.count; index++) {
            if (!IDPrivateTypeEncodingMatches(
                    [signature getArgumentTypeAtIndex:index + 2],
                    expectedArguments[index].UTF8String)) {
                argumentsMatch = NO;
                break;
            }
        }
    }
    if (returnMatches && argumentsMatch) return nil;

    return [NSString stringWithFormat:
        @"%@ ABI mismatch: expected return %@ and arguments (%@); actual return %@ and arguments (%@).",
        selectorName,
        expectedReturn,
        [expectedArguments componentsJoinedByString:@", "],
        IDPrivateTypeEncoding(signature.methodReturnType),
        [actualArguments componentsJoinedByString:@", "]];
}

static NSArray<NSString *> *IDPrivateRichLayoutABIMismatches(id layoutController) {
    NSMutableArray<NSString *> *mismatches = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *spec in IDPrivateRichLayoutABISpecs()) {
        NSString *mismatch = IDPrivateRichLayoutABIMismatch(layoutController, spec);
        if (mismatch != nil) [mismatches addObject:mismatch];
    }
    return mismatches.copy;
}

static NSArray<NSDictionary<NSString *, id> *> *IDPrivateMutableSelectionRectABISpecs(void) {
    return @[
        @{
            @"selector": @"setRect:fromView:",
            @"return": IDPrivateTypeEncoding(@encode(void)),
            @"arguments": @[
                IDPrivateTypeEncoding(@encode(CGRect)),
                IDPrivateTypeEncoding(@encode(id)),
            ],
        },
        @{
            @"selector": @"setContainsStart:",
            @"return": IDPrivateTypeEncoding(@encode(void)),
            @"arguments": @[IDPrivateTypeEncoding(@encode(BOOL))],
        },
        @{
            @"selector": @"setContainsEnd:",
            @"return": IDPrivateTypeEncoding(@encode(void)),
            @"arguments": @[IDPrivateTypeEncoding(@encode(BOOL))],
        },
    ];
}

static NSArray<NSString *> *IDPrivateMutableSelectionRectABIMismatches(void) {
    NSMutableArray<NSString *> *mismatches = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *spec in IDPrivateMutableSelectionRectABISpecs()) {
        NSString *selectorName = spec[@"selector"];
        Method method = class_getInstanceMethod(IDRichTextSelectionRect.class,
                                                NSSelectorFromString(selectorName));
        NSMethodSignature *signature = method == NULL
            ? nil
            : [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        NSString *expectedReturn = spec[@"return"];
        NSArray<NSString *> *expectedArguments = spec[@"arguments"];
        BOOL matches = signature != nil &&
            IDPrivateTypeEncodingMatches(signature.methodReturnType,
                                         expectedReturn.UTF8String) &&
            signature.numberOfArguments == expectedArguments.count + 2;
        if (matches) {
            for (NSUInteger index = 0; index < expectedArguments.count; index += 1) {
                if (!IDPrivateTypeEncodingMatches(
                        [signature getArgumentTypeAtIndex:index + 2],
                        expectedArguments[index].UTF8String)) {
                    matches = NO;
                    break;
                }
            }
        }
        if (!matches) {
            [mismatches addObject:[NSString stringWithFormat:
                @"IDRichTextSelectionRect %@ ABI mismatch: expected return %@ and arguments (%@); actual %@.",
                selectorName,
                expectedReturn,
                [expectedArguments componentsJoinedByString:@", "],
                signature == nil ? @"method signature is missing" :
                    IDPrivateTypeEncoding(signature.methodReturnType)]];
        }
    }
    return mismatches.copy;
}

NSString *IDPrivateRichLayoutCompatibilityReport(id layoutController) {
    NSArray<NSString *> *missing =
        IDPrivateMissingRichLayoutSelectorNames(layoutController);
    if (missing.count != 0) {
        return [NSString stringWithFormat:
            @"Rich layout controller is missing %lu P0 selector contracts:\n%@",
            (unsigned long)missing.count,
            [missing componentsJoinedByString:@"\n"]];
    }

    NSArray<NSString *> *ABIProblems =
        IDPrivateRichLayoutABIMismatches(layoutController);
    NSArray<NSString *> *selectionRectABIProblems =
        IDPrivateMutableSelectionRectABIMismatches();
    if (ABIProblems.count == 0 && selectionRectABIProblems.count == 0) {
        return [NSString stringWithFormat:
            @"Rich layout controller satisfies all %lu P0 selector contracts, all %lu recovered callback ABI contracts, and all 3 mutable selection-rect ABI contracts.",
            (unsigned long)IDPrivateRichLayoutRequiredSelectorNames().count,
            (unsigned long)IDPrivateRichLayoutABISpecs().count];
    }

    NSMutableArray<NSString *> *allABIProblems = [ABIProblems mutableCopy];
    [allABIProblems addObjectsFromArray:selectionRectABIProblems];

    return [NSString stringWithFormat:
        @"Rich layout controller has %lu recovered callback ABI mismatches:\n%@",
        (unsigned long)allABIProblems.count,
        [allABIProblems componentsJoinedByString:@"\n"]];
}

void IDPrivateRequireRichLayoutController(id layoutController, NSString *stage) {
    NSArray<NSString *> *missing =
        IDPrivateMissingRichLayoutSelectorNames(layoutController);
    if (missing.count == 0 &&
        IDPrivateRichLayoutABIMismatches(layoutController).count == 0 &&
        IDPrivateMutableSelectionRectABIMismatches().count == 0) return;

    NSString *reason = [NSString stringWithFormat:
        @"%@ failed.\n%@",
        stage,
        IDPrivateRichLayoutCompatibilityReport(layoutController)];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

static NSString *IDPrivateRichInputControllerABIMismatch(
    Class inputControllerClass,
    SEL selector,
    const char *expectedReturnType) {
    Method method = class_getInstanceMethod(inputControllerClass, selector);
    if (method == NULL) {
        return [NSString stringWithFormat:@"%@ method signature is missing",
                                          NSStringFromSelector(selector)];
    }
    NSMethodSignature *signature = [NSMethodSignature
        signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (!IDPrivateTypeEncodingMatches(signature.methodReturnType,
                                      expectedReturnType) ||
        signature.numberOfArguments != 3 ||
        !IDPrivateTypeEncodingMatches([signature getArgumentTypeAtIndex:2],
                                      @encode(id))) {
        return [NSString stringWithFormat:
            @"%@ ABI mismatch: expected %@ with one object argument; actual return %@ with %lu explicit arguments%@",
            NSStringFromSelector(selector),
            IDPrivateTypeEncoding(expectedReturnType),
            IDPrivateTypeEncoding(signature.methodReturnType),
            (unsigned long)(signature.numberOfArguments >= 2
                ? signature.numberOfArguments - 2
                : 0),
            signature.numberOfArguments == 3
                ? [NSString stringWithFormat:@", argument 0 %@",
                    IDPrivateTypeEncoding([signature getArgumentTypeAtIndex:2])]
                : @""];
    }
    return nil;
}

static void IDPrivateRequireRichInputControllerABI(Class inputControllerClass,
                                                    SEL selector,
                                                    const char *returnType,
                                                    NSString *stage) {
    NSString *mismatch = IDPrivateRichInputControllerABIMismatch(
        inputControllerClass,
        selector,
        returnType);
    if (mismatch == nil) return;
    NSString *reason = [NSString stringWithFormat:@"%@ failed: %@",
                                                   stage,
                                                   mismatch];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

id IDPrivateNewInputControllerWithRichLayoutControllerUsingClass(
    id layoutController,
    id delegate,
    Class inputControllerClass) {
    SEL initializer = NSSelectorFromString(@"initWithTextLayoutController:");
    SEL delegateSetter = NSSelectorFromString(@"setDelegate:");
    [IDPrivateUIKit requireObject:inputControllerClass
             respondsToSelector:@selector(alloc)
                          stage:@"Rich input-controller class lookup"];
    IDPrivateRequireRichInputControllerABI(
        inputControllerClass,
        initializer,
        @encode(id),
        @"Rich input-controller initializer ABI preflight");
    IDPrivateRequireRichInputControllerABI(
        inputControllerClass,
        delegateSetter,
        @encode(void),
        @"Rich input-controller delegate ABI preflight");
    id allocatedController = [inputControllerClass alloc];
    id controller =
        ((IDPrivateRichInputControllerInitializerSend)objc_msgSend)(
        allocatedController,
        initializer,
        layoutController);
    [IDPrivateUIKit requireObject:controller stage:@"Rich input-controller initialization"];
    IDPrivateRequireRichInputControllerABI(
        [controller class],
        delegateSetter,
        @encode(void),
        @"Rich input-controller initialized delegate ABI preflight");
    ((void (*)(id, SEL, id))objc_msgSend)(controller, delegateSetter, delegate);
    return controller;
}

id IDPrivateNewInputControllerWithRichLayoutController(id layoutController,
                                                        id delegate) {
    return IDPrivateNewInputControllerWithRichLayoutControllerUsingClass(
        layoutController,
        delegate,
        NSClassFromString(@"UITextInputController"));
}

static NSString *IDPrivateTemporaryLayoutManagerABIMismatch(
    NSTextLayoutManager *layoutManager,
    NSString *selectorName,
    NSUInteger expectedArgumentCount) {
    NSMethodSignature *signature = [layoutManager
        methodSignatureForSelector:NSSelectorFromString(selectorName)];
    if (signature == nil) {
        return [NSString stringWithFormat:@"%@ method signature is missing", selectorName];
    }
    if (!IDPrivateTypeEncodingMatches(signature.methodReturnType, @encode(void)) ||
        signature.numberOfArguments != expectedArgumentCount + 2) {
        return [NSString stringWithFormat:
            @"%@ ABI mismatch: expected void with %lu object arguments; actual return %@ with %lu explicit arguments",
            selectorName,
            (unsigned long)expectedArgumentCount,
            IDPrivateTypeEncoding(signature.methodReturnType),
            (unsigned long)(signature.numberOfArguments - 2)];
    }
    for (NSUInteger index = 0; index < expectedArgumentCount; index += 1) {
        if (!IDPrivateTypeEncodingMatches(
                [signature getArgumentTypeAtIndex:index + 2], @encode(id))) {
            return [NSString stringWithFormat:
                @"%@ ABI mismatch: argument %lu is %@ instead of object",
                selectorName,
                (unsigned long)index,
                IDPrivateTypeEncoding([signature getArgumentTypeAtIndex:index + 2])];
        }
    }
    return nil;
}

void IDPrivateRequireRichTemporaryLayoutManager(NSTextLayoutManager *layoutManager,
                                                NSString *stage) {
    [IDPrivateUIKit requireObject:layoutManager stage:stage];
    NSMutableArray<NSString *> *problems = [NSMutableArray array];
    NSString *addProblem = IDPrivateTemporaryLayoutManagerABIMismatch(
        layoutManager,
        @"addTemporaryAttribute:value:forTextRange:",
        3);
    NSString *removeProblem = IDPrivateTemporaryLayoutManagerABIMismatch(
        layoutManager,
        @"removeTemporaryAttribute:forTextRange:",
        2);
    if (addProblem != nil) [problems addObject:addProblem];
    if (removeProblem != nil) [problems addObject:removeProblem];
    if (problems.count == 0) return;
    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: NSTextLayoutManager temporary-attribute contract:\n%@",
        stage,
        [problems componentsJoinedByString:@"\n"]];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

void IDPrivateRichAddTemporaryAttribute(NSTextLayoutManager *layoutManager,
                                        id attribute,
                                        id value,
                                        NSTextRange *range,
                                        NSString *stage) {
    IDPrivateRequireRichTemporaryLayoutManager(layoutManager, stage);
    SEL selector = NSSelectorFromString(@"addTemporaryAttribute:value:forTextRange:");
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(layoutManager,
                                                  selector,
                                                  attribute,
                                                  value,
                                                  range);
}

void IDPrivateRichRemoveTemporaryAttribute(NSTextLayoutManager *layoutManager,
                                           id attribute,
                                           NSTextRange *range,
                                           NSString *stage) {
    IDPrivateRequireRichTemporaryLayoutManager(layoutManager, stage);
    SEL selector = NSSelectorFromString(@"removeTemporaryAttribute:forTextRange:");
    ((void (*)(id, SEL, id, id))objc_msgSend)(layoutManager,
                                              selector,
                                              attribute,
                                              range);
}

static NSString *IDPrivateTemporaryCanvasABIMismatch(UIView *canvas) {
    NSString *selectorName = @"invalidateTemporaryAttributesInRange:";
    NSMethodSignature *signature = [canvas
        methodSignatureForSelector:NSSelectorFromString(selectorName)];
    if (signature == nil) {
        return [NSString stringWithFormat:@"%@ method signature is missing", selectorName];
    }
    if (!IDPrivateTypeEncodingMatches(signature.methodReturnType, @encode(void)) ||
        signature.numberOfArguments != 3 ||
        !IDPrivateTypeEncodingMatches([signature getArgumentTypeAtIndex:2], @encode(id))) {
        return [NSString stringWithFormat:
            @"%@ ABI mismatch: expected void with one object argument; actual return %@ with %lu explicit arguments",
            selectorName,
            IDPrivateTypeEncoding(signature.methodReturnType),
            (unsigned long)(signature.numberOfArguments - 2)];
    }
    return nil;
}

void IDPrivateRequireRichTemporaryCanvas(UIView *canvas, NSString *stage) {
    [IDPrivateUIKit requireObject:canvas stage:stage];
    NSString *problem = IDPrivateTemporaryCanvasABIMismatch(canvas);
    if (problem == nil) return;
    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: temporary-attribute canvas contract: %@",
        stage,
        problem];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

void IDPrivateRichInvalidateTemporaryAttributes(UIView *canvas,
                                                NSTextRange *range,
                                                NSString *stage) {
    IDPrivateRequireRichTemporaryCanvas(canvas, stage);
    ((void (*)(id, SEL, id))objc_msgSend)(
        canvas,
        NSSelectorFromString(@"invalidateTemporaryAttributesInRange:"),
        range);
}

#endif
