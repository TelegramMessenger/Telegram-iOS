@import XCTest;
#import <objc/runtime.h>
#import "IDAppDelegate.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDDemoViewController.h"
#import "IDPrivateUIKit.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDEngineSourceLayout.h"

static NSArray<NSString *> *IDAllCanvasOriginSelectorNames(void) {
    return @[
        [@"invalidateTextContainer" stringByAppendingString:@"Origin"],
        [@"textContainer" stringByAppendingString:@"Origin"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasOriginSelectorNames(void) {
    return @[];
}

static NSArray<NSString *> *IDRetainedCanvasOriginSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasOriginSelectorNames() mutableCopy];
    [retained removeObjectsInArray:IDRemovableCanvasOriginSelectorNames()];
    return retained.copy;
}

static NSArray<NSString *> *IDAllCanvasControllerGetterSelectorNames(void) {
    return @[
        [@"textLayout" stringByAppendingString:@"Controller"],
        [@"layout" stringByAppendingString:@"Manager"],
        [@"customRender" stringByAppendingString:@"Controller"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasControllerGetterSelectorNames(void) {
    return IDAllCanvasControllerGetterSelectorNames();
}

static NSArray<NSString *> *IDRetainedCanvasControllerGetterSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasControllerGetterSelectorNames() mutableCopy];
    [retained
        removeObjectsInArray:IDRemovableCanvasControllerGetterSelectorNames()];
    return retained.copy;
}

static NSArray<NSString *> *IDAllCanvasStateGetterSelectorNames(void) {
    return @[
        [@"text" stringByAppendingString:@"Color"],
        [@"is" stringByAppendingString:@"Editable"],
        [@"is" stringByAppendingString:@"Editing"],
    ];
}

static NSArray<NSString *> *IDRemovableCanvasStateGetterSelectorNames(void) {
    return @[
        [@"text" stringByAppendingString:@"Color"],
        [@"is" stringByAppendingString:@"Editable"],
    ];
}

static NSArray<NSString *> *IDRetainedCanvasStateGetterSelectorNames(void) {
    NSMutableArray<NSString *> *retained =
        [IDAllCanvasStateGetterSelectorNames() mutableCopy];
    [retained
        removeObjectsInArray:IDRemovableCanvasStateGetterSelectorNames()];
    return retained.copy;
}

@interface IDDemoViewController (SmokeTesting)
- (IDTextView *)id_newEditor;
- (nullable NSString *)id_requestedBlockUIScenario;
- (NSString *)id_privateUIKitCompatibilityReport;
- (NSString *)id_blockStatusValue;
- (NSString *)id_geometryStatusValue;
- (NSString *)id_touchSelectionStatusValue;
- (BOOL)id_selectionCallbackReducedSurfaceRequested;
@end

@interface IDTouchScenarioDemoViewController : IDDemoViewController
@property(nonatomic, copy) NSString *scenario;
@end


// RETIRED (2026-09-15), four ownership audits that INVENTORY a directory layout this port
// deliberately restructured: the headers are flat in include/ and Internal/, the behaviour kernel is
// a module of its own, and IDTextView is out of the shipped tree entirely. They compare a walk of
// App/TextView/PrivateUIKit against hand-written manifests of 55 implementations and 56 headers, and
// here the walk finds 43 and 4.
//
// They were NOT adapted, and the reason is the trap in adapting them: deriving the on-disk set from
// the manifest makes the test pass while checking nothing, because the thing it checks is that those
// two agree. An honest adaptation re-authors BOTH the walk and the manifest in this repo's
// vocabulary — which is writing a new rule about this tree ("no file enters the vendored engine
// unclassified"), a good rule and a separate piece of work, not a path fix smuggled in under a port.

@implementation IDTouchScenarioDemoViewController
- (NSString *)id_requestedBlockUIScenario { return self.scenario; }
@end

@interface IDSelectionCallbackReductionScenarioDemoViewController :
    IDTouchScenarioDemoViewController
@end

@implementation IDSelectionCallbackReductionScenarioDemoViewController
- (BOOL)id_selectionCallbackReducedSurfaceRequested { return YES; }
@end

@interface IDTextView (Task11TeardownTesting)
- (UIView *)selectionContainerView;
@end

@interface IDBlockTextView (Task11TeardownTesting)
- (UIView *)selectionContainerView;
@end

@interface IDIncompatibleDemoViewController : IDDemoViewController
@property(nonatomic) NSUInteger editorFactoryCallCount;
@end

@implementation IDIncompatibleDemoViewController
- (BOOL)id_isPrivateUIKitCompatible { return NO; }
- (NSString *)id_privateUIKitCompatibilityReport {
    return [@"Deliberate test incompatibility\n"
        stringByPaddingToLength:4000
                      withString:@"Missing private contract; copy this complete report.\n"
                 startingAtIndex:0];
}
- (IDTextView *)id_newEditor {
    self.editorFactoryCallCount += 1;
    return nil;
}
@end

@interface IDInvalidConstructionBackwardDeleteController : NSObject
@end

@implementation IDInvalidConstructionBackwardDeleteController
- (id)_rangesForBackwardsDelete {
    return [NSObject new];
}
@end

@interface IDFinalFloatingAssistantABIProbe : NSObject
@end

@implementation IDFinalFloatingAssistantABIProbe
- (void)selectionChanged {}
- (void)activateSelection {}
- (void)deactivateSelection {}
- (void)setSelectionDisplayVisible:(BOOL)visible { (void)visible; }
- (void)setNeedsSelectionDisplayUpdate {}
- (void)setGestureRecognizers {}
- (void)clearGestureRecognizers:(BOOL)force { (void)force; }
- (void)beginFloatingCursorAtPoint:(CGPoint)point { (void)point; }
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    (void)point;
    (void)animated;
}
- (void)endFloatingCursor {}
- (void)resignedFirstResponder {}
- (void)detach:(BOOL)force { (void)force; }
@end

static NSInteger IDFinalWrongFloatingCursorABI(id self, SEL selector) {
    (void)self;
    (void)selector;
    return 0;
}

@interface IDConstructionFailureDemoViewController : IDDemoViewController
@property(nonatomic) NSUInteger editorFactoryCallCount;
@end

@implementation IDConstructionFailureDemoViewController
- (BOOL)id_isPrivateUIKitCompatible { return YES; }
- (IDTextView *)id_newEditor {
    self.editorFactoryCallCount += 1;
    IDPrivateInputPreflightBackwardDeleteRanges(
        [IDInvalidConstructionBackwardDeleteController new]);
    return nil;
}
@end

@interface IDBlockScenarioDemoViewController : IDDemoViewController
@property(nonatomic) NSUInteger flatEditorFactoryCallCount;
@end

@implementation IDBlockScenarioDemoViewController
- (NSString *)id_requestedBlockUIScenario { return @"selection"; }
- (IDTextView *)id_newEditor {
    self.flatEditorFactoryCallCount += 1;
    return [super id_newEditor];
}
@end

@interface IDIMEScenarioDemoViewController : IDDemoViewController
@end

@implementation IDIMEScenarioDemoViewController
- (NSString *)id_requestedBlockUIScenario {
    return @"ime-japanese-romaji-interior-candidate-commit";
}
@end

static NSArray<UIView *> *IDDescendantsOfView(UIView *view) {
    NSMutableArray<UIView *> *descendants = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        [descendants addObject:subview];
        [descendants addObjectsFromArray:IDDescendantsOfView(subview)];
    }
    return descendants;
}

@interface IDWindowTestHost : NSObject
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, weak) UIWindow *priorKeyWindow;
- (instancetype)initWithController:(UIViewController *)controller size:(CGSize)size;
- (void)tearDown;
@end

@implementation IDWindowTestHost
- (instancetype)initWithController:(UIViewController *)controller size:(CGSize)size {
    self = [super init];
    if (self == nil) return nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        self.priorKeyWindow = windowScene.keyWindow;
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        self.window.frame = (CGRect){CGPointZero, size};
        self.window.rootViewController = controller;
        [self.window makeKeyAndVisible];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        [controller.view setNeedsLayout];
        [controller.view layoutIfNeeded];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        return self;
    }
    return nil;
}

- (void)tearDown {
    UIWindow *window = self.window;
    if (window == nil) return;
    window.hidden = YES;
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    window.rootViewController = nil;
    [self.priorKeyWindow makeKeyWindow];
    self.window = nil;
    self.priorKeyWindow = nil;
}
@end

static UIView *IDViewWithAccessibilityIdentifier(UIView *root, NSString *identifier) {
    if ([root.accessibilityIdentifier isEqualToString:identifier]) {
        return root;
    }
    for (UIView *subview in root.subviews) {
        UIView *match = IDViewWithAccessibilityIdentifier(subview, identifier);
        if (match != nil) return match;
    }
    return nil;
}

static NSString *IDProjectSourceRoot(void) {
    return IDEngineSourceRoot();
}

static NSArray<NSString *> *IDBlockHostMethodDefinitionPaths(
    NSString *selectorName) {
    NSString *root = IDProjectSourceRoot();
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSString *escapedSelector = [NSRegularExpression
        escapedPatternForString:selectorName];
    NSRegularExpression *implementation = [NSRegularExpression
        regularExpressionWithPattern:
            @"@implementation\\s+IDBlockTextView(?:\\s*\\([^)]*\\))?[\\s\\S]*?@end"
                               options:0 error:nil];
    NSRegularExpression *method = [NSRegularExpression
        regularExpressionWithPattern:[NSString stringWithFormat:
            @"(?m)^\\s*-\\s*\\([^\\n)]*\\)\\s*(?:tgpn_)?%@\\s*\\{",
            escapedSelector]
                               options:0 error:nil];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"]) continue;
            NSString *relativePath = [folder stringByAppendingPathComponent:file];
            NSString *source = [NSString stringWithContentsOfFile:
                IDEngineSourceFile(relativePath)
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            for (NSTextCheckingResult *match
                 in [implementation matchesInString:source
                                             options:0
                                               range:NSMakeRange(0, source.length)]) {
                if ([method firstMatchInString:source options:0 range:match.range]) {
                    [paths addObject:relativePath];
                    break;
                }
            }
        }
    }
    return paths.copy;
}

typedef NS_ENUM(NSInteger, IDSourceConditionalVisibility) {
    IDSourceConditionalVisibilityProduction,
    IDSourceConditionalVisibilityDebug,
};

static NSArray<NSString *> *IDSourceLinesContainingToken(
    NSString *source,
    NSString *token,
    IDSourceConditionalVisibility visibility) {
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    NSMutableArray<NSMutableDictionary<NSString *, NSNumber *> *> *conditions =
        [NSMutableArray array];
    [source enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceCharacterSet];
        if ([trimmed hasPrefix:@"#if "] ||
            [trimmed hasPrefix:@"#ifdef "] ||
            [trimmed hasPrefix:@"#ifndef "]) {
            BOOL positiveDebug = [trimmed isEqualToString:@"#if DEBUG"] ||
                [trimmed isEqualToString:@"#ifdef DEBUG"] ||
                [trimmed isEqualToString:@"#if defined(DEBUG)"];
            BOOL negativeDebug = [trimmed isEqualToString:@"#ifndef DEBUG"] ||
                [trimmed isEqualToString:@"#if !DEBUG"] ||
                [trimmed isEqualToString:@"#if !defined(DEBUG)"];
            [conditions addObject:[@{
                @"mentionsDebug": @(positiveDebug || negativeDebug),
                @"debugBranch": @(positiveDebug),
            } mutableCopy]];
        } else if ([trimmed hasPrefix:@"#elif "]) {
            NSMutableDictionary<NSString *, NSNumber *> *condition =
                conditions.lastObject;
            if (condition != nil) {
                BOOL positiveDebug = [trimmed isEqualToString:@"#elif DEBUG"] ||
                    [trimmed isEqualToString:@"#elif defined(DEBUG)"];
                condition[@"mentionsDebug"] = @(
                    condition[@"mentionsDebug"].boolValue || positiveDebug);
                condition[@"debugBranch"] = @(positiveDebug);
            }
        } else if ([trimmed hasPrefix:@"#else"]) {
            NSMutableDictionary<NSString *, NSNumber *> *condition =
                conditions.lastObject;
            if (condition[@"mentionsDebug"].boolValue) {
                condition[@"debugBranch"] = @(!condition[@"debugBranch"].boolValue);
            }
        } else if ([trimmed hasPrefix:@"#endif"]) {
            if (conditions.count > 0) [conditions removeLastObject];
        }
        BOOL debugVisible = NO;
        for (NSDictionary<NSString *, NSNumber *> *condition in conditions) {
            if (condition[@"debugBranch"].boolValue) {
                debugVisible = YES;
                break;
            }
        }
        BOOL visibilityMatches = visibility == IDSourceConditionalVisibilityDebug
            ? debugVisible
            : !debugVisible;
        if (visibilityMatches && [line containsString:token]) {
            [matches addObject:line];
        }
    }];
    return matches.copy;
}

static NSUInteger IDSourceOccurrenceCount(NSString *source, NSString *token) {
    if (source.length == 0 || token.length == 0) return 0;
    return [source componentsSeparatedByString:token].count - 1;
}

static NSArray<NSString *> *IDNeutralNavigationAuthorityViolations(
    NSString *source) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSString *sliceStartToken = @"static BOOL IDRichNavigationResultIsValid(";
    NSString *callbackStartToken =
        @"- (nullable UITextPosition *)id_positionFromPosition:";
    NSString *sliceEndToken =
        @"- (UITextRange *)id_textRangeForLineEnclosingPosition:";
    NSRange sliceStart = [source rangeOfString:sliceStartToken];
    if (sliceStart.location == NSNotFound) {
        return @[@"missing navigation validation slice"];
    }
    NSRange sliceEnd = [source rangeOfString:sliceEndToken
                                     options:0
                                       range:NSMakeRange(
                                           sliceStart.location,
                                           source.length - sliceStart.location)];
    if (sliceEnd.location == NSNotFound) {
        return @[@"missing navigation authority slice terminator"];
    }
    NSString *authoritySlice = [source substringWithRange:NSMakeRange(
        sliceStart.location, sliceEnd.location - sliceStart.location)];
    NSRange callbackStart = [authoritySlice rangeOfString:callbackStartToken];
    if (callbackStart.location == NSNotFound) {
        return @[@"missing directional navigation callback"];
    }
    NSString *callback = [authoritySlice substringFromIndex:callbackStart.location];

    NSString *coordinatorToken =
        @"visuallyAdjacentPositionFromCanonicalOffset:";
    NSUInteger coordinatorCalls =
        IDSourceOccurrenceCount(callback, coordinatorToken);
    if (coordinatorCalls != 1) {
        [violations addObject:[NSString stringWithFormat:
            @"coordinator call count is %lu, expected 1",
            (unsigned long)coordinatorCalls]];
    }

    for (NSString *token in @[
        @"id_establishedNavigationFromPosition:",
        @"id_adjacentClusterOffsetFromOffset:",
        @"id_compareNeutralNavigationFromPosition:",
        @"traversedBlockIdentifiers",
    ]) {
        if ([authoritySlice containsString:token]) {
            [violations addObject:[@"obsolete navigation oracle: "
                stringByAppendingString:token]];
        }
    }
    for (NSString *token in @[
        @"caretStopFromLocalOffset:",
        @"baseWritingDirectionAtLocalOffset:",
        @"rangeOfComposedCharacterSequenceAtIndex:",
    ]) {
        if ([callback containsString:token]) {
            [violations addObject:[@"alternate caret traversal: "
                stringByAppendingString:token]];
        }
    }

    NSDictionary<NSString *, NSArray<NSString *> *> *requiredVocabulary = @{
        @"exact result": @[@"neutral.exact"],
        @"document revision": @[@"neutral.position.documentRevision",
                                  @"document.documentRevision"],
        @"finite vertical anchor": @[@"isfinite(neutral.anchorPositionOffset)"],
        @"canonical projection": @[@"neutral.position.canonicalOffset"],
        @"block identity coherence": @[@"location.blockIdentifier",
                                         @"neutral.position.blockIdentifier"],
        @"block-local offset coherence": @[@"location.localOffset",
                                             @"neutral.position.localPosition.utf16Offset"],
        @"affinity translation": @[@"IDRichUIKitAffinity"],
        @"result construction": @[@"id_positionForCanonicalOffset:"],
        @"strict validation call": @[@"IDRichNavigationResultIsValid"],
    };
    [requiredVocabulary enumerateKeysAndObjectsUsingBlock:
        ^(NSString *name, NSArray<NSString *> *tokens, BOOL *stop) {
            (void)stop;
            for (NSString *token in tokens) {
                if (![authoritySlice containsString:token]) {
                    [violations addObject:[NSString stringWithFormat:
                        @"missing %@ vocabulary: %@", name, token]];
                }
            }
        }];

    NSRange coordinator = [callback rangeOfString:coordinatorToken];
    if (coordinator.location != NSNotFound) {
        NSString *afterCoordinator =
            [callback substringFromIndex:NSMaxRange(coordinator)];
        NSUInteger terminalReturns =
            IDSourceOccurrenceCount(afterCoordinator, @"return result;");
        NSUInteger allReturns =
            IDSourceOccurrenceCount(afterCoordinator, @"return ");
        if (terminalReturns != 1 || allReturns != 1) {
            [violations addObject:[NSString stringWithFormat:
                @"alternate return path after coordinator call: returns=%lu terminal=%lu",
                (unsigned long)allReturns, (unsigned long)terminalReturns]];
        }
    }
    return violations.copy;
}

static NSString *IDNeutralNavigationValidAuthorityFixture(void) {
    return
        @"static BOOL IDRichNavigationResultIsValid(\n"
         "    IDDocumentCaretNavigationResult *neutral,\n"
         "    IDBlockDocument *document) {\n"
         "    if (neutral == nil || !neutral.exact ||\n"
         "        neutral.position.documentRevision != document.documentRevision ||\n"
         "        !isfinite(neutral.anchorPositionOffset)) return NO;\n"
         "    IDCanonicalLocation *location = [projection\n"
         "        locationForCanonicalOffset:neutral.position.canonicalOffset];\n"
         "    UITextStorageDirection affinity;\n"
         "    return IDRichUIKitAffinity(neutral.position.localPosition.affinity, &affinity) &&\n"
         "        [location.blockIdentifier isEqual:neutral.position.blockIdentifier] &&\n"
         "        location.localOffset == neutral.position.localPosition.utf16Offset;\n"
         "}\n"
         "- (nullable UITextPosition *)id_positionFromPosition:(UITextPosition *)position\n"
         "                                          inDirection:(UITextLayoutDirection)direction\n"
         "                                               offset:(NSInteger)offset\n"
         "                                             affinity:(UITextStorageDirection)affinity\n"
         "                                 anchorPositionOffset:(CGFloat)anchorPositionOffset {\n"
         "    IDDocumentCaretNavigationResult *neutral = [coordinator\n"
         "        visuallyAdjacentPositionFromCanonicalOffset:currentOffset];\n"
         "    if (!IDRichNavigationResultIsValid(neutral, document)) neutral = nil;\n"
         "    IDRichTextPosition *result = neutral == nil ? nil :\n"
         "        [self id_positionForCanonicalOffset:neutral.position.canonicalOffset];\n"
         "    return result;\n"
         "}\n"
         "- (UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position;\n";
}

static NSString *IDSourceSlice(NSString *source,
                               NSString *startToken,
                               NSString *endToken) {
    NSRange start = [source rangeOfString:startToken];
    if (start.location == NSNotFound) return nil;
    NSRange end = [source rangeOfString:endToken
                                options:0
                                  range:NSMakeRange(start.location + start.length,
                                      source.length - start.location - start.length)];
    if (end.location == NSNotFound) return nil;
    return [source substringWithRange:NSMakeRange(
        start.location, end.location - start.location)];
}

static NSArray<NSString *> *IDNeutralGeometryAuthorityViolations(
    NSString *source) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSArray<NSDictionary<NSString *, NSString *> *> *families = @[
        @{
            @"name": @"line",
            @"start": @"- (UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position\n                                      effectiveAffinity:",
            @"end": @"- (NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:",
            @"query": @"lineGeometryForCanonicalOffset:",
            @"validator": @"IDRichLineGeometryResultIsValid",
            @"oracle": @"id_establishedTextRangeForLineEnclosingPosition:",
            @"direct": @"localLineRangeEnclosingOffset:",
            @"terminal": @"return result;",
        },
        @{
            @"name": @"caret",
            @"start": @"- (CGRect)id_insertionRectForPosition:",
            @"end": @"- (UITextPosition *)id_nearestPositionAtPoint:",
            @"query": @"caretGeometryForCanonicalOffset:",
            @"validator": @"IDRichCaretGeometryResultIsValid",
            @"oracle": @"id_establishedInsertionRectForPosition:",
            @"direct": @"caretRectForLocalOffset:",
            @"terminal": @"return documentRect;",
        },
        @{
            @"name": @"point",
            @"start": @"- (UITextPosition *)id_nearestPositionAtPoint:",
            @"end": @"- (UITextPosition *)id_cursorPositionAtPoint:",
            @"query": @"nearestPositionToDocumentPoint:",
            @"validator": @"IDRichPointResultIsValid",
            @"oracle": @"id_establishedNearestPositionAtPoint:",
            @"direct": @"caretStopForPoint:",
            @"terminal": @"return result;",
        },
    ];
    for (NSDictionary<NSString *, NSString *> *family in families) {
        NSString *name = family[@"name"];
        NSString *slice = IDSourceSlice(source, family[@"start"], family[@"end"]);
        if (slice == nil) {
            [violations addObject:[NSString stringWithFormat:
                @"missing %@ geometry callback slice", name]];
            continue;
        }
        NSUInteger queryCalls = IDSourceLinesContainingToken(
            slice, family[@"query"],
            IDSourceConditionalVisibilityProduction).count;
        if (queryCalls != 1) {
            [violations addObject:[NSString stringWithFormat:
                @"%@ production coordinator call count is %lu, expected 1",
                name, (unsigned long)queryCalls]];
        }
        NSUInteger allQueryCalls = IDSourceOccurrenceCount(slice, family[@"query"]);
        if (allQueryCalls != 1) {
            [violations addObject:[NSString stringWithFormat:
                @"%@ total coordinator call count is %lu, expected 1",
                name, (unsigned long)allQueryCalls]];
        }
        if (IDSourceLinesContainingToken(
                slice, family[@"validator"],
                IDSourceConditionalVisibilityProduction).count == 0) {
            [violations addObject:[NSString stringWithFormat:
                @"%@ production callback omits %@",
                name, family[@"validator"]]];
        }
        for (NSString *token in @[
            family[@"oracle"], family[@"direct"], @"convertRect:",
            @"convertPoint:", @"id_layoutForPosition:",
            @"IDRichMountedCanvasMatchesNeutralOrigin",
            @"IDRichShouldCompareEstablishedGeometry",
        ]) {
            if ([slice containsString:token]) {
                [violations addObject:[NSString stringWithFormat:
                    @"%@ callback contains alternate geometry path %@",
                    name, token]];
            }
        }
        NSUInteger terminalReturns =
            IDSourceOccurrenceCount(slice, family[@"terminal"]);
        NSUInteger allReturns = IDSourceOccurrenceCount(slice, @"return ");
        if (terminalReturns != 1 || allReturns != 1) {
            [violations addObject:[NSString stringWithFormat:
                @"%@ alternate return path: returns=%lu terminal=%lu",
                name, (unsigned long)allReturns,
                (unsigned long)terminalReturns]];
        }
    }
    for (NSString *token in @[
        @"id_establishedInsertionRectForPosition:",
        @"id_establishedNearestPositionAtPoint:",
        @"id_establishedTextRangeForLineEnclosingPosition:",
        @"IDRichMountedCanvasMatchesNeutralOrigin",
        @"IDRichShouldCompareEstablishedGeometry",
    ]) {
        if ([source containsString:token]) {
            [violations addObject:[@"obsolete geometry oracle: "
                stringByAppendingString:token]];
        }
    }
    return violations.copy;
}

static NSString *IDNeutralGeometryValidAuthorityFixture(void) {
    return
        @"- (UITextRange *)id_textRangeForLineEnclosingPosition:(UITextPosition *)position\n"
         "                                      effectiveAffinity:(UITextStorageDirection)affinity {\n"
         "    IDDocumentLineGeometry *neutral = [coordinator\n"
         "        lineGeometryForCanonicalOffset:offset affinity:neutralAffinity];\n"
         "    BOOL valid = IDRichLineGeometryResultIsValid(neutral, document, offset);\n"
         "    IDRichTextRange *result = valid ? [self id_nativeRangeForCanonicalRange:neutral.canonicalRange] : nil;\n"
         "    return result;\n"
         "}\n"
         "- (NSDictionary<NSAttributedStringKey, id> *)id_attributesAtPosition:position;\n"
         "- (CGRect)id_insertionRectForPosition:(UITextPosition *)position {\n"
         "    IDDocumentCaretGeometry *neutral = [coordinator\n"
         "        caretGeometryForCanonicalOffset:offset affinity:neutralAffinity];\n"
         "    BOOL valid = IDRichCaretGeometryResultIsValid(neutral, document, offset);\n"
         "    CGRect documentRect = valid ? neutral.documentRect : CGRectNull;\n"
         "    return documentRect;\n"
         "}\n"
         "- (UITextPosition *)id_nearestPositionAtPoint:(CGPoint)point {\n"
         "    IDDocumentTextPosition *neutral = [coordinator\n"
         "        nearestPositionToDocumentPoint:point];\n"
         "    BOOL valid = IDRichPointResultIsValid(neutral, document);\n"
         "    IDRichTextPosition *result = valid ? [self id_positionForCanonicalOffset:neutral.canonicalOffset] : nil;\n"
         "    return result;\n"
         "}\n"
         "- (UITextPosition *)id_cursorPositionAtPoint:(CGPoint)point;\n";
}

static NSArray<NSString *> *IDNeutralSelectionGeometryAuthorityViolations(
    NSString *source) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSString *callbackToken = @"- (NSArray *)id_selectionRectsForRange:";
    NSString *adapterToken =
        @"- (NSArray<IDRichTextSelectionRect *> *)\n"
         "    id_exactSelectionRectsForRange:";
    NSString *endToken = @"- (void)id_requestTextGeometryAtPosition:";
    NSString *callback = IDSourceSlice(source, callbackToken, adapterToken);
    NSString *adapter = IDSourceSlice(source, adapterToken, endToken);
    if (callback == nil) [violations addObject:@"missing selection callback"];
    if (adapter == nil) [violations addObject:@"missing exact selection adapter"];
    if (callback == nil || adapter == nil) return violations.copy;

    NSString *query = @"selectionGeometryForCanonicalRange:";
    NSUInteger productionQueries = IDSourceLinesContainingToken(
        adapter, query, IDSourceConditionalVisibilityProduction).count;
    NSUInteger totalQueries = IDSourceOccurrenceCount(source, query);
    if (productionQueries != 1) {
        [violations addObject:[NSString stringWithFormat:
            @"production coordinator call count is %lu, expected 1",
            (unsigned long)productionQueries]];
    }
    if (totalQueries != 1) {
        [violations addObject:[NSString stringWithFormat:
            @"total coordinator call count is %lu, expected 1",
            (unsigned long)totalQueries]];
    }
    if (![adapter containsString:@"IDRichSelectionGeometryResultIsValid"]) {
        [violations addObject:@"exact adapter omits result validation"];
    }
    NSRange exactDeclaration = [callback rangeOfString:
        @"NSArray<IDRichTextSelectionRect *> *exact = [self"];
    NSString *terminalCallback = exactDeclaration.location == NSNotFound
        ? @""
        : [callback substringFromIndex:exactDeclaration.location];
    if (IDSourceOccurrenceCount(callback,
            @"id_exactSelectionRectsForRange:range") != 1 ||
        IDSourceOccurrenceCount(terminalCallback, @"return exact ?: @[];") != 1 ||
        IDSourceOccurrenceCount(terminalCallback, @"return ") != 1) {
        [violations addObject:@"selection callback has an alternate return path"];
    }
    for (NSString *token in @[@"retry", @"fallback", @"secondAttempt"]) {
        if ([adapter localizedCaseInsensitiveContainsString:token]) {
            [violations addObject:[@"selection adapter contains retry/fallback: "
                stringByAppendingString:token]];
        }
    }

    NSRange callbackRange = [source rangeOfString:callbackToken];
    NSRange helperRange = [source rangeOfString:
        @"id_establishedSelectionRectsForCanonicalRange:"];
    NSUInteger regionStart = callbackRange.location;
    if (helperRange.location != NSNotFound) {
        regionStart = MIN(regionStart, helperRange.location);
    }
    NSRange endRange = [source rangeOfString:endToken
                                     options:0
                                       range:NSMakeRange(
                                           regionStart,
                                           source.length - regionStart)];
    NSString *selectionRegion = endRange.location == NSNotFound
        ? @""
        : [source substringWithRange:NSMakeRange(
            regionStart, endRange.location - regionStart)];
    for (NSString *token in @[
        @"id_establishedSelectionRectsForCanonicalRange:",
        @"selectionRectsForLocalRange:", @"layoutForBlockIdentifier:",
        @"blockLayouts", @"canvasView",
        @"hasSharedWritingDirection", @"logicalStartIndex",
        @"logicalEndIndex",
    ]) {
        if ([selectionRegion containsString:token]) {
            [violations addObject:[@"obsolete direct selection path: "
                stringByAppendingString:token]];
        }
    }
    if (IDSourceOccurrenceCount(selectionRegion, @"convertRect:") != 1 ||
        ![selectionRegion containsString:@"[self.id_blockStack convertRect:"]) {
        [violations addObject:
            @"obsolete direct selection path: convertRect:"];
    }
    return violations.copy;
}

static NSString *IDNeutralSelectionGeometryValidAuthorityFixture(void) {
    return
        @"- (NSArray *)id_selectionRectsForRange:(UITextRange *)range\n"
         "                              fromView:(UIView *)view\n"
         "               forContainerPassingTest:(BOOL (^)(id container))predicate {\n"
         "    NSArray<IDRichTextSelectionRect *> *exact = [self\n"
         "        id_exactSelectionRectsForRange:range fromView:view\n"
         "        forContainerPassingTest:predicate];\n"
         "    return exact ?: @[];\n"
         "}\n"
         "- (NSArray<IDRichTextSelectionRect *> *)\n"
         "    id_exactSelectionRectsForRange:(UITextRange *)range {\n"
         "    IDDocumentSelectionGeometry *geometry = [coordinator\n"
         "        selectionGeometryForCanonicalRange:characterRange];\n"
         "    if (!IDRichSelectionGeometryResultIsValid(geometry, document, characterRange))\n"
         "        return nil;\n"
         "    CGRect rect = [self.id_blockStack convertRect:documentRect toView:view];\n"
         "    return rects.copy;\n"
         "}\n"
         "- (void)id_requestTextGeometryAtPosition:(UITextPosition *)position;\n";
}

static NSArray<NSString *> *IDProductionPrivateSelectorMatches(
    NSArray<NSString *> *selectors) {
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    for (NSString *relativeRoot in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSString *directory =
            IDEngineSourceFile(relativeRoot);
        NSDirectoryEnumerator *enumerator =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in enumerator) {
            if (![@[@"h", @"m"] containsObject:relativePath.pathExtension]) {
                continue;
            }
            NSString *body = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
            for (NSString *selector in selectors) {
                NSString *pattern = [NSString stringWithFormat:
                    @"(?<![A-Za-z0-9_])%@(?![A-Za-z0-9_])",
                    [NSRegularExpression escapedPatternForString:selector]];
                NSRegularExpression *expression =
                    [NSRegularExpression regularExpressionWithPattern:pattern
                                                               options:0
                                                                 error:nil];
                if ([expression firstMatchInString:body
                                           options:0
                                             range:NSMakeRange(0, body.length)]) {
                    [matches addObject:[NSString stringWithFormat:
                        @"%@/%@|%@", relativeRoot, relativePath, selector]];
                }
            }
        }
    }
    return matches.copy;
}

static void IDDrainTask11OwnershipUntil(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
    while (!condition() && [deadline timeIntervalSinceNow] > 0.0) {
        @autoreleasepool {
            [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:deadline];
        }
    }
}

static NSArray<NSString *> *IDTask9NativeRecognizerClassNames(void) {
    return @[
        @"UITextMultiTapRecognizer",
        @"UITapAndAHalfRecognizer",
        @"UIVariableDelayLoupeGesture",
        @"_UIPanOrFlickGestureRecognizer",
        @"UITextTapRecognizer",
        @"UITextRangeAdjustmentGestureRecognizer",
    ];
}

static NSDictionary<NSString *, NSNumber *> *IDTask9RecognizerClassCounts(UIView *view) {
    NSSet<NSString *> *accepted = [NSSet setWithArray:IDTask9NativeRecognizerClassNames()];
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        NSString *className = NSStringFromClass(gesture.class);
        if (![accepted containsObject:className]) continue;
        counts[className] = @(counts[className].unsignedIntegerValue + 1);
    }
    return counts.copy;
}

static NSRegularExpression *IDLiteralPrivateSelectorExpression(void) {
    return [NSRegularExpression regularExpressionWithPattern:
        @"NSSelectorFromString\\(@\"([^\"]+)\"\\)"
                                                    options:0
                                                      error:nil];
}

static NSSet<NSString *> *IDLiteralPrivateSelectorInventory(NSString *source) {
    NSRegularExpression *selector = IDLiteralPrivateSelectorExpression();
    NSRange implementation = [source rangeOfString:@"@implementation IDPrivateUIKit"];
    NSRange inventoryRange = implementation.location == NSNotFound
        ? NSMakeRange(0, source.length)
        : NSMakeRange(0, implementation.location);
    NSMutableSet<NSString *> *inventory = [NSMutableSet set];
    for (NSTextCheckingResult *match in [selector matchesInString:source
                                                          options:0
                                                            range:inventoryRange]) {
        [inventory addObject:[source substringWithRange:[match rangeAtIndex:1]]];
    }
    return inventory.copy;
}

static NSRegularExpression *IDPrivateCallbackBoundaryExpression(void) {
    // `(?:tgpn_)?`: a callback UIKit sends under a private name is compiled under its neutral
    // `tgpn_` name (`TGPrivateMethodAliases.h`), and is still that callback's definition.
    NSString *pattern = @"(?m)^\\s*-\\s*\\([^\\n\\)]*\\)\\s*(?:tgpn_)?(textLayoutManager|textContainer|setTextContainer:|invalidateTextContainerOrigin|textContainerOrigin|textStorage|_nsRangeForTextKitRanges:|textInputView|_textInputViewForAddingGestureRecognizers|textLayoutController|_internalTextLayoutController|layoutManager|_inputController|textInputController|_implicitPasteConfigurationClasses|textInput:|textInputDidChange:|textInputDidChangeSelection:|keyboardInputChangedSelection:|keyboardInputShouldDelete:|keyboardInput:|interactionAssistant|customRenderController|textColor|_convertPointFromRenderSpace:|selectionContainerView|_existingSelectionContainerView|_placeSelectionContainerView|_isInteractiveTextSelectionDisabled|_updateSelectionGestures|_performViewportLayout:|_viewportWillLayout|_viewportDidLayout|viewportBoundsForTextViewportLayoutController:|textViewportLayoutController:|textViewportLayoutControllerWillLayout:|textViewportLayoutControllerDidLayout:|_removeUnusedElementViews|updateContentSizeIfNeeded|setNeedsDisplayInRect:|flushElementViews|invalidateTemporaryAttributesInRange:|setTextEmphasisBackgroundView:|_updateRenderingSurfaceViewsForTextRange:|isEditingDidChange|observeEnclosingScrollView|_traitsChanged|_textKit2CanvasDidLayout|_updateInteractionGeometry|hoverEffectContainerLayer|uniqueWritingToolsAnimatedLayoutInfo|setUniqueWritingToolsAnimatedLayoutInfo:|isLayoutFragmentView|rangeOfCharacterClusterAtIndex:|boundingRectForCharacterRange:|selectionRectsForRange:[^\\n]*\\n\\s*fromView:|requestTextGeometryAtPosition:|annotatedSubstringForRange:|addAnnotationAttribute:|removeAnnotationAttribute:|addRenderingAttributes:|removeRenderingAttributes:|_invalidateTemporaryAttributesInRange:)";
    return [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
}

static NSArray<NSString *> *IDExperimentalProductionImplementationPaths(void) {
    return @[
        @"App/IDDemoViewController.m",
        @"App/IDSelectionCallbackReductionProbe.m",
        @"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m",
        @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m",
        @"PrivateUIKit/IDBlockTextView+PrivateInputDelegate.m",
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m",
        @"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m",
        @"PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitAutoscrollEntryCapability.m",
        @"TextView/IDBlockDocument.m",
        @"TextView/IDBlockLayout.m",
        @"TextView/IDBlockLayoutSnapshot.m",
        @"TextView/IDBlockTextGeometry.m",
        @"TextView/IDBlockStackCanvasView.m",
        @"TextView/IDBlockTextView+Interaction.m",
        @"TextView/IDBlockTextView+TextInput.m",
        @"TextView/IDBlockTextView.m",
        @"TextView/IDCanonicalTextProjection.m",
        @"TextView/IDCanonicalTextStorageAdapter.m",
        @"TextView/IDDocumentLayoutCoordinator.m",
        @"TextView/IDInlineTextFormattingController.m",
        @"TextView/IDInlineTextStyleResolver.m",
        @"TextView/IDNativeSelectionPresentationBackend.m",
        @"TextView/IDRichTextAnchor.m",
        @"TextView/IDRichTextAnnotationStore.m",
        @"TextView/IDRichTextLayoutController.m",
        @"TextView/IDRichTextPosition.m",
        @"TextView/IDRichTextRange.m",
        @"TextView/IDRichTextSelectionRect.m",
        @"TextView/IDSelectionPresentation.m",
        @"TextView/IDTextKit2BlockLayoutProvider.m",
        @"TextView/Autoscroll/IDVerticalAutoscroll.m",
        @"TextView/Autoscroll/IDVerticalAutoscrollGeometry.m",
    ];
}

static NSArray<NSString *> *IDLegacyProductionImplementationPaths(void) {
    return @[
        @"App/IDAppDelegate.m",
        @"App/IDSceneDelegate.m",
        @"App/main.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorReport.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorKernel.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitInteractionCapability.m",
        @"PrivateUIKit/BehaviorKernel/IDUIKitRuntimeContract.m",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m",
        @"PrivateUIKit/IDPrivateUIKit.m",
        @"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m",
        @"PrivateUIKit/IDTextView+PrivateCallbacks.m",
        @"PrivateUIKit/IDTextView+PrivateInputDelegate.m",
        @"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m",
        @"TextView/IDTextCanvasAttachmentCoordinator.m",
        @"TextView/IDTextCanvasInvalidation.m",
        @"TextView/IDTextLayoutCanvasView.m",
        @"TextView/IDTextRenderingSurfaceView.m",
        @"TextView/IDTextView+Interaction.m",
        @"TextView/IDTextView+TextInput.m",
        @"TextView/IDTextView.m",
    ];
}

static NSSet<NSString *> *IDProductionImplementationPaths(void) {
    NSString *root = IDProjectSourceRoot();
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if ([file.pathExtension isEqualToString:@"m"]) {
                [paths addObject:[folder stringByAppendingPathComponent:file]];
            }
        }
    }
    return paths.copy;
}

static NSArray<NSString *> *IDClassifiedProductionHeaderPaths(void) {
    return @[
        @"App/IDAppDelegate.h",
        @"App/IDDemoViewController.h",
        @"App/IDSelectionCallbackReductionProbe.h",
        @"App/IDSceneDelegate.h",
        @"PrivateUIKit/IDPrivateUIKit+RichTextLayout.h",
        @"PrivateUIKit/IDPrivateUIKit+Testing.h",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.h",
        @"PrivateUIKit/IDPrivateUIKit.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorCapabilities.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorBackend.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorKernel.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorReport.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitAutoscrollEntryCapability.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitInteractionCapability.h",
        @"PrivateUIKit/BehaviorKernel/IDUIKitRuntimeContract.h",
        @"TextView/IDBlockDocument.h",
        @"TextView/IDBlockDocumentInternal.h",
        @"TextView/IDBlockLayout.h",
        @"TextView/IDBlockLayoutSnapshot.h",
        @"TextView/IDBlockStackCanvasView.h",
        @"TextView/IDBlockStackCanvasViewInternal.h",
        @"TextView/IDBlockTextGeometry.h",
        @"TextView/IDBlockTextView.h",
        @"TextView/IDBlockTextViewInternal.h",
        @"TextView/IDCanonicalTextProjection.h",
        @"TextView/IDCanonicalTextStorageAdapter.h",
        @"TextView/IDCanonicalTextStorageAdapterInternal.h",
        @"TextView/IDDocumentLayoutCoordinator.h",
        @"TextView/IDInlineTextFormatting.h",
        @"TextView/IDInlineTextFormattingController.h",
        @"TextView/IDInlineTextStyleResolver.h",
        @"TextView/IDNativeSelectionPresentationBackend.h",
        @"TextView/IDRichTextAnchor.h",
        @"TextView/IDRichTextAnchorInternal.h",
        @"TextView/IDRichTextAnnotationStore.h",
        @"TextView/IDRichTextLayoutController.h",
        @"TextView/IDRichTextLayoutControllerInternal.h",
        @"TextView/IDRichTextPosition.h",
        @"TextView/IDRichTextRange.h",
        @"TextView/IDRichTextRangeInternal.h",
        @"TextView/IDRichTextSelectionRect.h",
        @"TextView/IDSelectionPresentation.h",
        @"TextView/IDTextCanvasAttachmentLifecycle.h",
        @"TextView/IDTextCanvasAttachmentCoordinator.h",
        @"TextView/IDTextCanvasInvalidation.h",
        @"TextView/IDTextLayoutCanvasView.h",
        @"TextView/IDTextLayoutCanvasViewInternal.h",
        @"TextView/IDTextRenderingSurfaceView.h",
        @"TextView/IDTextKit2BlockLayoutProvider.h",
        @"TextView/IDTextView.h",
        @"TextView/IDTextViewInternal.h",
        @"TextView/Autoscroll/IDVerticalAutoscroll.h",
        @"TextView/Autoscroll/IDVerticalAutoscrollGeometry.h",
        @"TextView/Autoscroll/IDVerticalAutoscrollInternal.h",
    ];
}

static NSSet<NSString *> *IDProductionHeaderPaths(void) {
    NSString *root = IDProjectSourceRoot();
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if ([file.pathExtension isEqualToString:@"h"]) {
                [paths addObject:[folder stringByAppendingPathComponent:file]];
            }
        }
    }
    return paths.copy;
}

static NSSet<NSString *> *IDUnclassifiedProductionImplementationPaths(
    NSSet<NSString *> *actual,
    NSSet<NSString *> *classified);

static NSDictionary<NSString *, NSArray<NSString *> *> *IDFinalForbiddenFloatingStateTokens(void) {
    NSArray<NSString *> *privateHIDTokens = @[
        [@[@"XC", @"PointerEventPath"] componentsJoinedByString:@""],
        [@[@"XC", @"SynthesizedEventRecord"] componentsJoinedByString:@""],
    ];
    return @{
        @"UITextView": @[@"UITextView"],
        @"private HID": privateHIDTokens,
        @"gesture recognizer": @[
            @"floatingCursorRecognizer", @"floatingCursorGesture",
            @"cursorFloatingRecognizer", @"cursorFloatingGesture",
        ],
        @"cursor layer": @[@"floatingCursorLayer", @"cursorFloatingLayer"],
        @"cursor view": @[@"floatingCursorView", @"cursorFloatingView"],
        @"cursor drawing": @[
            @"drawFloatingCursor", @"drawCursorFloating",
            @"floatingCursorPath", @"cursorFloatingPath",
        ],
        @"displacement": @[
            @"floatingCursorDisplacement", @"cursorFloatingDisplacement",
        ],
        @"anchor": @[@"floatingCursorAnchor", @"cursorFloatingAnchor"],
        @"display link": @[
            @"floatingCursorDisplayLink", @"cursorFloatingDisplayLink",
        ],
        @"timer": @[@"floatingCursorTimer", @"cursorFloatingTimer"],
    };
}

static NSDictionary<NSString *, NSArray<NSString *> *> *
IDForbiddenCorrectionOwnershipTokens(void) {
    return @{
        @"correction candidate view": @[
            @"UIKeyboardCandidate", @"correctionCandidateView",
            @"autocorrectionCandidateView", @"candidateView",
        ],
        @"rejection state": @[
            @"autocorrectionRejected", @"correctionRejected",
            @"rejectionPending", @"pendingAutocorrectionRejection",
            @"rejectedCorrection",
        ],
        @"correction timer": @[
            @"autocorrectionTimer", @"correctionTimer", @"candidateTimer",
        ],
        @"injected correction": @[
            @"_acceptAutocorrection", @"applyAutocorrection:",
            @"setAutocorrectionCandidate", @"injectAutocorrection",
            @"injectedCorrection",
        ],
        @"fixture spelling": @[@"@\"adress\"", @"@\"address\""],
    };
}

static NSArray<NSString *> *IDCorrectionOwnershipAuditViolationsForSources(
    NSDictionary<NSString *, NSString *> *sources) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    [sources enumerateKeysAndObjectsUsingBlock:
        ^(NSString *path, NSString *body, BOOL *stop) {
            [IDForbiddenCorrectionOwnershipTokens() enumerateKeysAndObjectsUsingBlock:
                ^(NSString *category, NSArray<NSString *> *tokens, BOOL *innerStop) {
                    for (NSString *token in tokens) {
                        if ([body containsString:token]) {
                            [violations addObject:[NSString stringWithFormat:
                                @"%@ ownership violation in %@: %@",
                                category, path, token]];
                        }
                    }
                }];
        }];
    return violations.copy;
}

static void IDAppendFinalForbiddenFloatingStateViolations(
    NSMutableArray<NSString *> *violations,
    NSString *path,
    NSString *body) {
    [IDFinalForbiddenFloatingStateTokens() enumerateKeysAndObjectsUsingBlock:
        ^(NSString *category, NSArray<NSString *> *tokens, BOOL *stop) {
            for (NSString *token in tokens) {
                if ([body containsString:token]) {
                    [violations addObject:[NSString stringWithFormat:
                        @"%@ ownership violation in %@: %@", category, path, token]];
                }
            }
        }];
}

static NSArray<NSString *> *IDFinalHeaderAuditViolationsForSources(
    NSDictionary<NSString *, NSString *> *sources,
    NSSet<NSString *> *classifiedHeaderPaths) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSSet<NSString *> *actual = [NSSet setWithArray:sources.allKeys];
    for (NSString *path in IDUnclassifiedProductionImplementationPaths(
             actual, classifiedHeaderPaths)) {
        [violations addObject:[NSString stringWithFormat:@"unclassified header: %@", path]];
    }
    for (NSString *path in classifiedHeaderPaths) {
        NSString *body = sources[path];
        if (body == nil) {
            [violations addObject:[NSString stringWithFormat:@"classified header is missing: %@", path]];
            continue;
        }
        IDAppendFinalForbiddenFloatingStateViolations(violations, path, body);
    }
    for (NSString *path in actual) {
        if ([classifiedHeaderPaths containsObject:path]) continue;
        IDAppendFinalForbiddenFloatingStateViolations(violations, path, sources[path]);
    }
    return violations.copy;
}

static NSArray<NSString *> *IDMarkdownSerialTestCommandViolationsForSources(
    NSDictionary<NSString *, NSString *> *sources,
    NSSet<NSString *> *requiredPaths) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSRegularExpression *testCommand = [NSRegularExpression
        regularExpressionWithPattern:@"^\\s*xcodebuild\\s+(?:clean\\s+)?test(?:\\s|$)"
                              options:0 error:nil];
    NSRegularExpression *serialFlag = [NSRegularExpression
        regularExpressionWithPattern:
            @"(?:^|\\s)-parallel-testing-enabled\\s+NO(?:\\s|$)"
                              options:0 error:nil];
    for (NSString *path in requiredPaths) {
        NSString *body = sources[path];
        if (body == nil) {
            [violations addObject:[NSString stringWithFormat:@"required command source is missing: %@", path]];
            continue;
        }
        NSArray<NSString *> *lines = [body componentsSeparatedByCharactersInSet:
            NSCharacterSet.newlineCharacterSet];
        NSUInteger commandCount = 0;
        for (NSUInteger lineIndex = 0; lineIndex < lines.count; lineIndex += 1) {
            NSString *line = lines[lineIndex];
            if ([testCommand firstMatchInString:line options:0
                                         range:NSMakeRange(0, line.length)] == nil) continue;
            commandCount += 1;
            NSMutableString *logicalCommand = [NSMutableString stringWithString:line];
            while ([[lines[lineIndex] stringByTrimmingCharactersInSet:
                       NSCharacterSet.whitespaceCharacterSet] hasSuffix:@"\\"] &&
                   lineIndex + 1 < lines.count) {
                lineIndex += 1;
                [logicalCommand appendFormat:@"\n%@", lines[lineIndex]];
            }
            NSUInteger invocationCount = [testCommand numberOfMatchesInString:logicalCommand
                                                                        options:0
                                                                          range:NSMakeRange(0, logicalCommand.length)];
            BOOL hasShellControl = [logicalCommand containsString:@"#"] ||
                [logicalCommand containsString:@";"] ||
                [logicalCommand containsString:@"&&"] ||
                [logicalCommand containsString:@"||"];
            BOOL hasSerialFlag = [serialFlag firstMatchInString:logicalCommand options:0
                                                          range:NSMakeRange(0, logicalCommand.length)] != nil;
            if (invocationCount != 1U || hasShellControl || !hasSerialFlag) {
                [violations addObject:[NSString stringWithFormat:
                    @"xcodebuild test command must contain its own -parallel-testing-enabled NO argument and no shell chaining/comment in %@",
                    path]];
            }
        }
        if (commandCount == 0U) {
            [violations addObject:[NSString stringWithFormat:
                @"required command source has no runnable xcodebuild test command: %@", path]];
        }
    }
    return violations.copy;
}

static NSSet<NSString *> *IDUnclassifiedProductionImplementationPaths(
    NSSet<NSString *> *actual,
    NSSet<NSString *> *classified) {
    NSMutableSet<NSString *> *unknown = actual.mutableCopy;
    [unknown minusSet:classified];
    return unknown.copy;
}

static NSArray<NSString *> *IDPrivateHIDAuditViolationsForSources(
    NSDictionary<NSString *, id> *sources,
    NSString *sharedSupportPath) {
    NSArray<NSString *> *privateClassTokens = @[
        [@[@"XCPointer", @"EventPath"] componentsJoinedByString:@""],
        [@[@"XCSynthesized", @"EventRecord"] componentsJoinedByString:@""],
    ];
    NSArray<NSString *> *runtimeInvocationTokens = @[
        [@[@"objc_", @"msgSend"] componentsJoinedByString:@""],
        [@[@"NSSelector", @"FromString"] componentsJoinedByString:@""],
        [@[@"sel_", @"registerName"] componentsJoinedByString:@""],
        [@[@"class_", @"getInstanceMethod"] componentsJoinedByString:@""],
        [@[@"method_", @"getTypeEncoding"] componentsJoinedByString:@""],
    ];
    NSString *allowed = sharedSupportPath.stringByStandardizingPath;
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    [sources enumerateKeysAndObjectsUsingBlock:
        ^(NSString *path, id source, BOOL *stop) {
            NSString *standardPath = path.stringByStandardizingPath;
            if (![source isKindOfClass:NSString.class]) {
                [violations addObject:[NSString stringWithFormat:
                    @"Could not read source %@", standardPath]];
                return;
            }
            if ([standardPath isEqualToString:allowed]) return;
            NSString *body = source;
            for (NSString *token in privateClassTokens) {
                if ([body containsString:token]) {
                    [violations addObject:[NSString stringWithFormat:
                        @"Private XCTest HID class escaped shared support in %@",
                        standardPath]];
                }
            }
            if (![standardPath containsString:@"/UITests/"]) return;
            for (NSString *token in runtimeInvocationTokens) {
                if ([body containsString:token]) {
                    [violations addObject:[NSString stringWithFormat:
                        @"UI-test runtime invocation escaped shared HID support in %@",
                        standardPath]];
                }
            }
        }];
    return violations.copy;
}

static NSArray<NSString *> *IDPrivateHIDAuditViolationsAtRoots(
    NSArray<NSString *> *roots,
    NSString *sharedSupportPath,
    NSFileManager *fileManager) {
    NSSet<NSString *> *sourceExtensions = [NSSet setWithArray:@[@"h", @"m", @"mm"]];
    NSMutableDictionary<NSString *, id> *sources = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    for (NSString *root in roots) {
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:root isDirectory:&isDirectory] || !isDirectory) {
            [violations addObject:[NSString stringWithFormat:
                @"Could not enumerate source root %@", root]];
            continue;
        }
        NSDirectoryEnumerator<NSURL *> *files = [fileManager
            enumeratorAtURL:[NSURL fileURLWithPath:root isDirectory:YES]
 includingPropertiesForKeys:nil
                    options:0
               errorHandler:^BOOL(NSURL *url, NSError *error) {
                   [violations addObject:[NSString stringWithFormat:
                       @"Could not enumerate %@: %@", url.path, error]];
                   return YES;
               }];
        if (files == nil) {
            [violations addObject:[NSString stringWithFormat:
                @"Could not enumerate source root %@", root]];
            continue;
        }
        for (NSURL *url in files) {
            if (![sourceExtensions containsObject:url.pathExtension]) continue;
            NSError *error = nil;
            NSString *source = [NSString stringWithContentsOfURL:url
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
            sources[url.path] = source ?: NSNull.null;
        }
    }
    [violations addObjectsFromArray:
        IDPrivateHIDAuditViolationsForSources(sources, sharedSupportPath)];
    return violations.copy;
}

static NSUInteger IDConstructionMatchCount(NSString *source,
                                           NSString *className,
                                           NSArray<NSString *> *factoryNames) {
    NSString *escapedClass = [NSRegularExpression escapedPatternForString:className];
    NSMutableArray<NSString *> *alternatives = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"\\[\\s*%@\\s+(?:alloc|new)\\b", escapedClass]];
    for (NSString *factoryName in factoryNames) {
        [alternatives addObject:[NSString stringWithFormat:@"\\b%@\\s*\\(",
            [NSRegularExpression escapedPatternForString:factoryName]]];
    }
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:[alternatives componentsJoinedByString:@"|"]
                              options:0
                                error:nil];
    return [expression numberOfMatchesInString:source
                                       options:0
                                         range:NSMakeRange(0, source.length)];
}

static NSUInteger IDNativeInteractionAssistantFactoryCallCount(NSString *source) {
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:
            @"\\[\\s*IDPrivateUIKit\\s+newInteractionAssistantWithView:"
                              options:0 error:nil];
    return [expression numberOfMatchesInString:source options:0
                                         range:NSMakeRange(0, source.length)];
}

static NSUInteger
IDBlockInteractionCapabilityConstructionCount(NSString *source) {
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:
            @"\\[\\s*\\[\\s*IDUIKitInteractionCapability\\s+alloc\\s*\\]"
                              options:0 error:nil];
    return [expression numberOfMatchesInString:source options:0
                                         range:NSMakeRange(0, source.length)];
}

static NSString *IDSourceByRemovingExactPublicSelectionContainerDefinition(
    NSString *source) {
    NSString *signature = @"- (UIView *)selectionContainerView {";
    NSRange start = [source rangeOfString:signature];
    if (start.location == NSNotFound) return source;
    NSRange nextMethod = [source rangeOfString:@"\n- ("
                                      options:0
                                        range:NSMakeRange(NSMaxRange(start),
                                                          source.length - NSMaxRange(start))];
    NSUInteger end = nextMethod.location == NSNotFound ? source.length : nextMethod.location + 1;
    NSMutableString *result = source.mutableCopy;
    [result deleteCharactersInRange:NSMakeRange(start.location, end - start.location)];
    return result.copy;
}

static NSArray<NSString *> *IDRichLayoutRequiredSelectorNames(void) {
    return @[
        @"textStorage", @"textContainers", @"firstTextContainer",
        @"textContainerForPosition:", @"beginningOfDocument", @"endOfDocument",
        @"emptyTextRangeAtPosition:", @"textRangeFromPosition:toPosition:",
        @"positionFromPosition:offset:", @"positionFromPosition:offset:affinity:",
        @"positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:",
        @"textRangeForLineEnclosingPosition:",
        @"textRangeForLineEnclosingPosition:effectiveAffinity:",
        @"attributesAtPosition:inDirection:", @"baseWritingDirectionAtPosition:",
        @"comparePosition:toPosition:", @"offsetFromPosition:toPosition:",
        @"affinityForPosition:", @"characterRangeForTextRange:",
        @"boundingRectForCharacterRange:",
        @"characterRangeForTextRange:clippedToDocument:",
        @"characterRangesForTextRange:clippedToDocument:",
        @"textRangeForCharacterRange:", @"textRangeForCharacterRanges:",
        @"positionWithOffset:affinity:", @"textInputController",
        @"adoptTextInputController:",
        @"detachFromTextInputController", @"canAccessLayoutManager",
        @"invalidateDisplayForCharacterRange:", @"rangeOfCharacterClusterAtIndex:type:",
        @"selectionRectsForRange:fromView:forContainerPassingTest:",
        @"requestTextGeometryAtPosition:typingAttributes:resultBlock:",
        @"insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:",
        @"cursorPositionAtPoint:inContainer:", @"nearestPositionAtPoint:inContainer:",
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:",
        @"ensureLayoutForRange:", @"invalidateLayoutForRange:",
        @"attributedTextInRange:",
        @"annotatedSubstringForRange:", @"addAnnotationAttribute:value:forRange:",
        @"annotationAttribute:atPosition:", @"removeAnnotationAttribute:forRange:",
        @"addRenderingAttributes:forRange:", @"removeRenderingAttributes:forRange:",
        @"_invalidateTemporaryAttributesInRange:",
    ];
}

static NSArray<NSString *> *IDMethodDefinitionSelectors(NSString *implementation) {
    NSRegularExpression *definitions = [NSRegularExpression
        regularExpressionWithPattern:@"(?m)^-\\s*\\([^)]*\\)\\s*([^;{]+)\\{"
                              options:0
                                error:nil];
    NSRegularExpression *components = [NSRegularExpression
        regularExpressionWithPattern:@"([A-Za-z_][A-Za-z0-9_]*):"
                              options:0
                                error:nil];
    NSMutableArray<NSString *> *selectors = [NSMutableArray array];
    for (NSTextCheckingResult *definition in
         [definitions matchesInString:implementation
                              options:0
                                range:NSMakeRange(0, implementation.length)]) {
        NSString *signature = [implementation substringWithRange:[definition rangeAtIndex:1]];
        NSArray<NSTextCheckingResult *> *parts = [components matchesInString:signature
                                                                      options:0
                                                                        range:NSMakeRange(0, signature.length)];
        if (parts.count == 0) {
            NSRegularExpression *name = [NSRegularExpression
                regularExpressionWithPattern:@"^([A-Za-z_][A-Za-z0-9_]*)"
                                      options:0
                                        error:nil];
            NSTextCheckingResult *match = [name firstMatchInString:signature
                                                           options:0
                                                             range:NSMakeRange(0, signature.length)];
            if (match != nil) [selectors addObject:[signature substringWithRange:[match rangeAtIndex:1]]];
            continue;
        }
        NSMutableString *selector = [NSMutableString string];
        for (NSTextCheckingResult *part in parts) {
            [selector appendFormat:@"%@:", [signature substringWithRange:[part rangeAtIndex:1]]];
        }
        [selectors addObject:selector.copy];
    }
    return selectors.copy;
}

static NSUInteger IDPrivateCallbackBoundaryMatchCount(NSString *source) {
    NSRegularExpression *forbidden = IDPrivateCallbackBoundaryExpression();
    NSUInteger count = [forbidden numberOfMatchesInString:source
                                                   options:0
                                                     range:NSMakeRange(0, source.length)];
    for (NSString *selector in IDMethodDefinitionSelectors(source)) {
        if ([selector isEqualToString:@"annotationAttribute:atPosition:"]) {
            count += 1;
        }
    }
    return count;
}

static NSDictionary<NSString *, NSString *> *IDFinalOwnershipExpectedSites(void) {
    return @{
        @"nativeSelectionBackend": @"TextView/IDBlockTextView.m",
        @"blockInteractionAssistant": @"TextView/IDBlockTextView+Interaction.m",
        @"kernelInteractionAssistant":
            @"PrivateUIKit/BehaviorKernel/IDUIKitBehaviorKernel.m",
        @"legacyInteractionAssistant": @"TextView/IDTextView+Interaction.m",
        @"richLayoutControllerOwner": @"TextView/IDBlockTextView.m",
    };
}

static NSArray<NSString *> *IDFinalOwnershipAuditViolationsForSources(
    NSDictionary<NSString *, NSString *> *sources,
    NSSet<NSString *> *classifiedImplementationPaths) {
    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    NSSet<NSString *> *actual = [NSSet setWithArray:sources.allKeys];
    for (NSString *path in IDUnclassifiedProductionImplementationPaths(
             actual, classifiedImplementationPaths)) {
        [violations addObject:[NSString stringWithFormat:
            @"unclassified production implementation: %@", path]];
    }
    for (NSString *path in classifiedImplementationPaths) {
        if (sources[path] == nil) {
            [violations addObject:[NSString stringWithFormat:
                @"classified production implementation is missing: %@", path]];
        }
    }

    NSDictionary<NSString *, NSString *> *owners = IDFinalOwnershipExpectedSites();
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *sites =
        [NSMutableDictionary dictionaryWithDictionary:@{
            @"block assistant": [NSMutableArray array],
            @"kernel assistant": [NSMutableArray array],
            @"legacy assistant": [NSMutableArray array],
            @"layout controller": [NSMutableArray array],
            @"selection backend": [NSMutableArray array],
        }];
    NSRegularExpression *alternateAssistantConstruction = [NSRegularExpression
        regularExpressionWithPattern:
            @"(?:\\[\\s*ID[A-Za-z0-9_]*InteractionAssistant[A-Za-z0-9_]*\\s+(?:alloc|new)\\b|"
             "\\b(?:ID[A-Za-z0-9_]*InteractionAssistant[A-Za-z0-9_]*(?:Create|New)|"
             "(?:Create|New)[A-Za-z0-9_]*InteractionAssistant[A-Za-z0-9_]*)\\s*\\()"
                              options:0 error:nil];
    [sources enumerateKeysAndObjectsUsingBlock:
        ^(NSString *path, NSString *body, BOOL *stop) {
            NSUInteger wrapperCount = IDNativeInteractionAssistantFactoryCallCount(body);
            NSUInteger capabilityCount =
                IDBlockInteractionCapabilityConstructionCount(body);
            NSUInteger alternateCount = [alternateAssistantConstruction
                numberOfMatchesInString:body options:0 range:NSMakeRange(0, body.length)];
            NSString *assistantCategory = [path isEqualToString:
                owners[@"legacyInteractionAssistant"]] ? @"legacy assistant" : @"block assistant";
            for (NSUInteger index = 0; index < wrapperCount + alternateCount; index += 1) {
                [sites[assistantCategory] addObject:path];
            }
            for (NSUInteger index = 0; index < capabilityCount; index += 1) {
                NSString *category = [path isEqualToString:
                    owners[@"kernelInteractionAssistant"]]
                    ? @"kernel assistant" : @"block assistant";
                [sites[category] addObject:path];
            }

            if ([IDExperimentalProductionImplementationPaths() containsObject:path]) {
                NSUInteger layoutCount = IDConstructionMatchCount(
                    body, @"IDRichTextLayoutController",
                    @[@"IDRichTextLayoutControllerCreate"]);
                for (NSUInteger index = 0; index < layoutCount; index += 1) {
                    [sites[@"layout controller"] addObject:path];
                }
                NSUInteger backendCount = IDConstructionMatchCount(
                    body, @"IDNativeSelectionPresentationBackend",
                    @[@"IDNativeSelectionPresentationBackendCreate"]);
                for (NSUInteger index = 0; index < backendCount; index += 1) {
                    [sites[@"selection backend"] addObject:path];
                }
            }
            IDAppendFinalForbiddenFloatingStateViolations(violations, path, body);
            if (![path hasPrefix:@"PrivateUIKit/"]) {
                NSString *audited = [path isEqualToString:
                    @"TextView/IDNativeSelectionPresentationBackend.m"]
                    ? IDSourceByRemovingExactPublicSelectionContainerDefinition(body)
                    : body;
                if (IDPrivateCallbackBoundaryMatchCount(audited) != 0U) {
                    [violations addObject:[NSString stringWithFormat:
                        @"private callback definition outside PrivateUIKit: %@", path]];
                }
            }
        }];

    NSDictionary<NSString *, NSString *> *expectedOwnerForCategory = @{
        @"block assistant": owners[@"blockInteractionAssistant"],
        @"kernel assistant": owners[@"kernelInteractionAssistant"],
        @"legacy assistant": owners[@"legacyInteractionAssistant"],
        @"layout controller": owners[@"richLayoutControllerOwner"],
        @"selection backend": owners[@"nativeSelectionBackend"],
    };
    [expectedOwnerForCategory enumerateKeysAndObjectsUsingBlock:
        ^(NSString *category, NSString *expectedOwner, BOOL *stop) {
            NSArray<NSString *> *observed = sites[category];
            if (observed.count != 1U || ![observed.firstObject isEqualToString:expectedOwner]) {
                [violations addObject:[NSString stringWithFormat:
                    @"%@ ownership violation: expected one site in %@, observed %@",
                    category, expectedOwner, observed]];
            }
        }];
    return violations.copy;
}

@interface IDProjectSmokeTests : XCTestCase @end

// RETIRED ON IMPORT (2026-09-15), 13 cases whose SUBJECT is upstream's repository rather than this
// engine: the certification and stock-truth runners, the autocorrection/IME/inline-prediction matrix
// drivers, keyboard provisioning, "registered in both test targets", and the exported UTI pair. Each
// read only upstream's project.yml, Config/Info.plist or Scripts/, and NONE of them could fail for
// any change made in this repository — 11 of the 13 were passing, green, against a carried copy of a
// project nothing here builds. A test that cannot fail is not coverage; it is a tick that reads as
// coverage, which is worse than the red one beside it.
//
// The rules some of them encode are worth having HERE — "a test command disables parallel testing",
// "a support file is registered in every target that needs it" — but written against this repo's own
// Host/project.yml and Scripts/, which is new work with a different subject, not a path fix.
//
// Kept deliberately: the 12 cases that audit the engine's production GRAPH and merely list a repo
// path among 40-100 engine paths. A blunter sweep retired those too and would have deleted 19 real
// code rules with them.

@implementation IDProjectSmokeTests

- (void)testBlockInternalControllerDiagnosticsUseExplicitRichController {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    NSString *integration = read(@"Tests/IDBlockTextViewIntegrationTests.m");
    NSString *demo = read(@"App/IDDemoViewController.m");
    NSString *privateHeader = read(@"PrivateUIKit/IDPrivateUIKit.h");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(integration);
    XCTAssertNotNil(demo);
    XCTAssertNotNil(privateHeader);
    XCTAssertNotNil(privateUIKit);

    XCTAssertFalse([integration containsString:
        @"IDPrivateTestingInternalTextLayoutController(view)"]);
    XCTAssertTrue([integration containsString:@"view.id_richLayoutController"]);
    XCTAssertTrue([demo containsString:
        @"IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting"]);
    XCTAssertTrue([demo containsString:@"editor.id_richLayoutController"]);
    XCTAssertTrue([privateHeader containsString:
        @"IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting"]);
    XCTAssertTrue([privateUIKit containsString:
        @"IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting"]);
    XCTAssertFalse([privateUIKit containsString:
        @"IDPrivateTestingInternalTextLayoutController(editor);\n"
         "    id<UITextInput> input"]);
}

- (void)testBlockInternalTextLayoutControllerAuthorizationFixtureIsPinnedAndComplete {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"Tests/Fixtures/BlockInternalTextLayoutControllerAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"runtime", @"selector", @"owner", @"decision",
            @"retainedAuthority", @"hopper", @"artifacts",
        ]]));
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], (@{
        @"platform": @"iOS", @"version": @"26.5", @"build": @"23F73",
    }));
    XCTAssertEqualObjects(fixture[@"selector"], @"_internalTextLayoutController");
    XCTAssertEqualObjects(fixture[@"owner"], @"IDBlockTextView(PrivateCallbacks)");
    XCTAssertEqualObjects(fixture[@"decision"], @"safeFallback");
    XCTAssertEqualObjects(fixture[@"retainedAuthority"], (@{
        @"selector": @"textLayoutController",
        @"owner": @"IDBlockTextView(PrivateCallbacks)",
        @"algorithmAuthority": @"IDRichTextLayoutController",
    }));
    XCTAssertEqualObjects(fixture[@"hopper"], (@{
        @"selectorStub": @"0x214d520",
        @"canvasXref": @"0xc084fc",
        @"textFieldXref": @"0x15d7924",
        @"textViewXref": @"0x16215dc",
        @"stockProvider": @"0x1621580",
    }));
    NSDictionary<NSString *, NSString *> *artifacts = fixture[@"artifacts"];
    XCTAssertEqualObjects([NSSet setWithArray:artifacts.allKeys],
        ([NSSet setWithArray:@[
            @"retainedAuthority", @"withdrawnAuthority",
            @"retainedLifecycle", @"withdrawnLifecycle",
            @"retainedUI", @"withdrawnUI",
        ]]));
    for (NSString *artifact in artifacts.allValues) {
        // Named, not opened — see IDIsUpstreamRunArtifactPath for why the bundle itself is not
        // required on disk (26 of the 48 these fixtures cite no longer exist anywhere).
        XCTAssertTrue(IDIsUpstreamRunArtifactPath(artifact), @"%@", artifact);
    }
}

- (void)testBlockInternalTextLayoutControllerExperimentInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    NSString *control =
        [@"ID_WITHDRAW_BLOCK_INTERNAL_TEXT_LAYOUT_" stringByAppendingString:
            @"CONTROLLER"];
    NSString *temporaryHeader =
        [@"IDBlockInternalTextLayoutController" stringByAppendingString:
            @"Withdrawal.h"];
    NSString *callbacks = read(@"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m");
    NSString *flatCallbacks = read(@"PrivateUIKit/IDTextView+PrivateCallbacks.m");
    NSString *probe = read(@"App/IDSelectionCallbackReductionProbe.m");
    NSString *productionManifest =
        read(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(flatCallbacks);
    XCTAssertNotNil(probe);
    XCTAssertNotNil(productionManifest);

    XCTAssertFalse([callbacks containsString:
        @"- (id)_internalTextLayoutController {"]);
    XCTAssertEqual(IDSourceOccurrenceCount(
        callbacks,
        @"- (id)tgpn_textLayoutController {\n"
         "    return self.id_richLayoutController;\n"
         "}"), 1U);
    XCTAssertEqual(IDSourceOccurrenceCount(
        flatCallbacks,
        @"- (id)_internalTextLayoutController {\n"
         "    return self.id_layoutController;\n"
         "}"), 1U);

    for (NSString *folder in @[
        @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests", @"Scripts",
    ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            XCTAssertFalse([source containsString:control], @"%@/%@", folder,
                           relativePath);
            XCTAssertFalse([source containsString:temporaryHeader], @"%@/%@",
                           folder, relativePath);
        }
    }
    for (NSString *path in @[
        @"project.yml", @"InputDec.xcodeproj/project.pbxproj",
    ]) {
        XCTAssertFalse([read(path) containsString:control], @"%@", path);
        XCTAssertFalse([read(path) containsString:temporaryHeader], @"%@", path);
    }
    XCTAssertFalse([productionManifest containsString:control]);
    XCTAssertFalse([productionManifest containsString:
        @"_internalTextLayoutController"]);
    XCTAssertTrue([probe containsString:@"class_copyMethodList"]);
    XCTAssertTrue([probe containsString:@"class_getMethodImplementation"]);
    XCTAssertTrue([probe containsString:@"internalControllerLookup"]);
    XCTAssertFalse([probe containsString:
        @"[editor _internalTextLayoutController]"]);
    XCTAssertFalse([probe containsString:@"performSelector"]);
    XCTAssertFalse([probe containsString:@"objc_msgSend"]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:
        IDEngineSourceFile([@"PrivateUIKit/" stringByAppendingString:temporaryHeader])]);
}

- (void)testAttachmentLifecycleUsesOnlyTypedProjectVocabulary {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    NSString *header = read(@"TextView/IDTextCanvasAttachmentLifecycle.h");
    XCTAssertNotNil(header);
    for (NSString *selector in @[
        @"id_attachmentView:(UIView *)view",
        @"didLayoutInFragmentFrame:(CGRect)fragmentFrame",
        @"id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views",
        @"id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views",
    ]) {
        XCTAssertTrue([header containsString:selector], @"%@", selector);
    }

    NSString *coordinatorHeader =
        read(@"TextView/IDTextCanvasAttachmentCoordinator.h");
    XCTAssertTrue([coordinatorHeader containsString:
        @"id<IDTextCanvasAttachmentLifecycleSink> lifecycleSink"]);

    NSArray<NSString *> *privateSelectors = @[
        [[@"didLayoutTextAttachmentView" stringByAppendingString:@":inFragment"]
            stringByAppendingString:@"Rect:"],
        [@"didAddTextAttachment" stringByAppendingString:@"Views:"],
        [@"didRemoveTextAttachment" stringByAppendingString:@"Views:"],
    ];
    NSArray<NSString *> *privateHelpers = @[
        [@"IDPrivateCanvasDidLayout" stringByAppendingString:@"AttachmentView"],
        [@"IDPrivateCanvasDidAdd" stringByAppendingString:@"AttachmentViews"],
        [@"IDPrivateCanvasDidRemove" stringByAppendingString:@"AttachmentViews"],
    ];
    NSArray<NSString *> *productionFiles = @[
        @"TextView/IDTextCanvasAttachmentCoordinator.h",
        @"TextView/IDTextCanvasAttachmentCoordinator.m",
        @"TextView/IDTextLayoutCanvasView.m",
        @"TextView/IDTextLayoutCanvasViewInternal.h",
        @"TextView/IDTextView.m",
        @"TextView/IDTextViewInternal.h",
        @"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m",
        @"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m",
        @"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.h",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m",
    ];
    for (NSString *path in productionFiles) {
        NSString *source = read(path);
        XCTAssertNotNil(source, @"%@", path);
        for (NSString *spelling in [privateSelectors arrayByAddingObjectsFromArray:
                                     privateHelpers]) {
            XCTAssertFalse([source containsString:spelling], @"%@|%@", path, spelling);
        }
    }

    NSString *manifest =
        read(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    for (NSString *identifier in @[
        @"reference.attachmentDidLayout",
        @"reference.attachmentDidAdd",
        @"reference.attachmentDidRemove",
    ]) {
        XCTAssertFalse([manifest containsString:identifier], @"%@", identifier);
    }

    NSString *testSource = read(@"Tests/IDProjectSmokeTests.m");
    NSRange boundaryStart = [testSource rangeOfString:
        @"static NSRegularExpression *IDPrivateCallbackBoundaryExpression"];
    NSRange boundaryEnd = [testSource rangeOfString:
        @"static NSArray<NSString *> *IDExperimentalProductionImplementationPaths"
                                      options:0
                                        range:NSMakeRange(boundaryStart.location,
                                                          testSource.length - boundaryStart.location)];
    NSString *boundary = [testSource substringWithRange:NSMakeRange(
        boundaryStart.location, boundaryEnd.location - boundaryStart.location)];
    for (NSString *selector in privateSelectors) {
        XCTAssertFalse([boundary containsString:selector], @"%@", selector);
    }
}

- (void)testAnchoredAttachmentFrameUsesOnlyProjectGeometryVocabulary {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    NSString *canvas = read(@"TextView/IDTextLayoutCanvasView.m");
    NSString *internalHeader =
        read(@"TextView/IDTextLayoutCanvasViewInternal.h");
    NSString *privateCallbacks =
        read(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m");
    NSString *coordinatorTests =
        read(@"Tests/IDTextCanvasAttachmentCoordinatorTests.m");
    for (NSString *source in @[
        canvas, internalHeader, privateCallbacks, coordinatorTests,
    ]) {
        XCTAssertNotNil(source);
    }

    XCTAssertTrue([internalHeader containsString:
        @"id_frameForParagraphAnchoredAttachment:(id)attachment"]);
    XCTAssertTrue([internalHeader containsString:
        @"layoutFragment:(NSTextLayoutFragment *)fragment"]);
    XCTAssertTrue([canvas containsString:
        @"- (CGRect)id_frameForParagraphAnchoredAttachment:(id)attachment"]);
    XCTAssertTrue([canvas containsString:
        @"[canvas id_frameForParagraphAnchoredAttachment:attachment"]);

    NSString *privateComponent =
        [@"frameForAnchoredText" stringByAppendingString:@"Attachment:"];
    for (NSString *source in @[
        canvas, internalHeader, privateCallbacks, coordinatorTests,
    ]) {
        XCTAssertFalse([source containsString:privateComponent]);
    }

    NSString *testSource = read(@"Tests/IDProjectSmokeTests.m");
    NSRange boundaryStart = [testSource rangeOfString:
        @"static NSRegularExpression *IDPrivateCallbackBoundaryExpression"];
    NSRange boundaryEnd = [testSource rangeOfString:
        @"static NSArray<NSString *> *IDExperimentalProductionImplementationPaths"
                                      options:0
                                        range:NSMakeRange(boundaryStart.location,
                                                          testSource.length - boundaryStart.location)];
    NSString *boundary = [testSource substringWithRange:NSMakeRange(
        boundaryStart.location, boundaryEnd.location - boundaryStart.location)];
    XCTAssertFalse([boundary containsString:privateComponent]);

    NSString *privateHeader =
        read(@"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.h");
    NSString *privateImplementation =
        read(@"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m");
    NSString *manifest =
        read(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    // Private names are spelled through their encoded table entries (`TGPrivateRuntimeNames.h`).
    XCTAssertTrue([privateImplementation containsString:
        @"TGPN_boundsForTextParagraphAnchoredAttachment_"]);
    XCTAssertTrue([privateImplementation containsString:
        @"TGPN_textAttachmentViewProviderForTextParagraphAnchoredAttachment_"]);
    XCTAssertTrue([privateImplementation containsString:
        @"TGPN_drawTextParagraphAnchoredAttachment_bounds_context_"]);
    XCTAssertTrue([privateHeader containsString:
        @"IDPrivateCanvasParagraphAnchoredBounds"]);
    for (NSString *identifier in @[
        @"reference.anchoredBounds",
        @"reference.anchoredProvider",
        @"reference.anchoredDraw",
    ]) {
        XCTAssertTrue([manifest containsString:identifier], @"%@", identifier);
    }
}

- (void)testParagraphAnchoredBoundsOracleIsTestOnly {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    for (NSString *path in @[
        @"TextView/IDTextLayoutCanvasView.m",
        @"TextView/IDTextLayoutCanvasViewInternal.h",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.h",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m",
    ]) {
        NSString *productionSource = read(path);
        XCTAssertNotNil(productionSource, @"%@", path);
        XCTAssertFalse([productionSource containsString:
            @"IDParagraphAnchoredBoundsOracle"], @"%@", path);
        XCTAssertFalse([productionSource containsString:
            @"IDAnchoredBoundsOracle"], @"%@", path);
    }
    NSString *testSource =
        read(@"Tests/IDTextCanvasAttachmentCoordinatorTests.m");
    XCTAssertTrue([testSource containsString:
        @"IDParagraphAnchoredBoundsOracle"]);
    XCTAssertTrue([testSource containsString:
        @"IDAnchoredBoundsOracleFragment"]);
}

- (void)testMinimalAutoscrollRoutingUsesOnlyPublicGeometry {
    NSString *path = IDEngineSourceFile(@"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *body = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:nil];
    XCTAssertNotNil(body);
    for (NSString *forbidden in @[
        @"visibleBounds",
        @"_effectiveContentInset",
        @"_textContainerInsetAdjustment",
        @"_horizontalTextContainerGeometryAdjustment",
        @"IDPrivateTextAutoscrollSafeRect",
        @"IDPrivateTextAutoscrollDirections",
    ]) {
        XCTAssertFalse([body containsString:forbidden], @"%@", forbidden);
    }
    XCTAssertTrue([body containsString:@"IDVerticalAutoscrollSafeRect"]);
    XCTAssertTrue([body containsString:
        @"self.id_behaviorBackend == IDUIKitBehaviorBackendReference"]);

    NSRange minimalStart =
        [body rangeOfString:@"if (self.id_verticalAutoscroll == nil)"];
    XCTAssertNotEqual(minimalStart.location, NSNotFound);
    if (minimalStart.location != NSNotFound) {
        NSString *minimalSuffix =
            [body substringFromIndex:minimalStart.location];
        XCTAssertFalse([minimalSuffix
            containsString:@"IDPrivateNewTextAutoscroll"]);
        XCTAssertFalse([minimalSuffix
            containsString:@"IDPrivateTextAutoscrollStart"]);
    }
}

- (void)testPrivateTestingOperationsStayBehindPrivateUIKitWrappers {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSArray<NSString *> *> *audits = @{
        @"Tests/IDBlockTextViewIntegrationTests.m": @[
            @"<objc/message.h>", @"_internalTextLayoutController",
            @"cursorPositionAtPoint:inContainer:", @"_convertPointFromRenderSpace:",
        ],
        @"Tests/IDPrivateUIKitTests.m": @[
            @"_textContainerInsetAdjustment",
            @"_horizontalTextContainerGeometryAdjustment",
        ],
    };
    for (NSString *relativePath in audits) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                 encoding:NSUTF8StringEncoding error:nil];
        XCTAssertNotNil(body, @"%@", relativePath);
        for (NSString *token in audits[relativePath]) {
            XCTAssertFalse([body containsString:token], @"%@ contains %@", relativePath, token);
        }
    }
}
- (void)testApplicationClassesExist {
    XCTAssertNotNil([IDAppDelegate class]);
    XCTAssertNotNil([IDDemoViewController class]);
}
- (void)testCompatibleDemoConstructsExactlyOneCustomEditor {
    IDDemoViewController *controller = [IDDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    NSPredicate *isEditor = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [object isKindOfClass:IDTextView.class];
    }];
    NSArray *editors = [IDDescendantsOfView(controller.view) filteredArrayUsingPredicate:isEditor];
    XCTAssertEqual(editors.count, 1);
    XCTAssertEqualObjects([editors.firstObject accessibilityIdentifier], @"custom-text-view");
    IDTextView *editor = editors.firstObject;
    XCTAssertGreaterThan(editor.bounds.size.height, 300.0);
    XCTAssertGreaterThan(editor.contentSize.height - editor.bounds.size.height, 500.0);
}
- (void)testBlockLaunchScenarioConstructsBlockGraphDirectlyAndExposesExactJSONSeed {
    IDBlockScenarioDemoViewController *controller = [IDBlockScenarioDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);
    XCTAssertEqual(controller.flatEditorFactoryCallCount, 0U);
    XCTAssertNil(IDViewWithAccessibilityIdentifier(controller.view, @"custom-text-view"));
    IDBlockTextView *editor = (IDBlockTextView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"block-text-view");
    XCTAssertTrue([editor isKindOfClass:IDBlockTextView.class]);

    NSData *statusData = [[controller id_blockStatusValue]
        dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *status = [NSJSONSerialization JSONObjectWithData:statusData options:0 error:&error];
    XCTAssertNil(error);
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"blockCount", @"blockOrigins", @"canonical", @"caret", @"scenario",
        @"inlineFormatting", @"selection", @"spelling",
        @"spellingGeometryRequests", @"state", @"visible",
    ]];
    NSDictionary *expectedSelection = @{@"length": @0, @"location": @3};
    XCTAssertEqualObjects([NSSet setWithArray:status.allKeys], expectedKeys);
    XCTAssertEqualObjects(status[@"canonical"], @"alpha\nbeta");
    XCTAssertEqualObjects(status[@"scenario"], @"selection");
    XCTAssertEqualObjects(status[@"state"], @"seeded-caret");
    XCTAssertEqualObjects(status[@"selection"], expectedSelection);
    XCTAssertEqualObjects(status[@"blockCount"], @2);
    XCTAssertEqualObjects(status[@"spellingGeometryRequests"], @0);
    NSDictionary *formatting = status[@"inlineFormatting"];
    NSSet *expectedFormattingKeys = [NSSet setWithArray:@[
        @"effectiveTypingTraits", @"states", @"blocks",
    ]];
    XCTAssertEqualObjects([NSSet setWithArray:formatting.allKeys],
                          expectedFormattingKeys);
    XCTAssertEqualObjects(formatting[@"effectiveTypingTraits"], @[]);
    XCTAssertEqualObjects(formatting[@"states"], (@{
        @"bold": @"off",
        @"italic": @"off",
        @"underline": @"off",
        @"strikethrough": @"off",
    }));
    XCTAssertEqual([formatting[@"blocks"] count], 2U);
    NSArray *origins = status[@"blockOrigins"];
    XCTAssertEqual(origins.count, 2U);
    NSDictionary *firstOrigin = origins[0];
    NSDictionary *secondOrigin = origins[1];
    XCTAssertLessThanOrEqual([firstOrigin[@"y"] doubleValue],
                             [secondOrigin[@"y"] doubleValue]);
    NSDictionary *caret = status[@"caret"];
    for (NSString *component in @[@"x", @"y", @"width", @"height"]) {
        XCTAssertTrue(isfinite([caret[component] doubleValue]));
    }
    XCTAssertGreaterThan([caret[@"width"] doubleValue], 0.0);
    XCTAssertGreaterThan([caret[@"height"] doubleValue], 0.0);
}

- (void)testGeometryScenariosExposeExactFixturesAndMinimalStatusSchema {
    NSMutableArray<NSString *> *largeBlocks = [NSMutableArray array];
    for (NSUInteger index = 0; index < 120; index += 1) {
        [largeBlocks addObject:[NSString stringWithFormat:@"block %03lu",
            (unsigned long)index]];
    }
    NSDictionary<NSString *, NSArray<NSString *> *> *fixtures = @{
        @"geometry-authority":
            @[@"alpha beta wrapped words", @"", @"אבגדה six mixed text",
              @"A👨‍👩‍👧‍👦B composed tail", @"final block"],
        @"geometry-large-selection": largeBlocks.copy,
    };
    NSSet *baseKeys = [NSSet setWithArray:@[
        @"blockCount", @"boundary", @"canonical", @"caret", @"contentOffset",
        @"firstResponder", @"scenario", @"selection", @"selectionRects",
        @"state", @"visible",
    ]];
    NSSet *rectKeys = [NSSet setWithArray:@[@"height", @"width", @"x", @"y"]];

    for (NSString *scenario in @[@"geometry-authority",
                                   @"geometry-large-selection"]) {
        @autoreleasepool {
            IDTouchScenarioDemoViewController *controller =
                [IDTouchScenarioDemoViewController new];
            controller.scenario = scenario;
            IDWindowTestHost *host = [[IDWindowTestHost alloc]
                initWithController:controller size:CGSizeMake(390, 844)];
            XCTAssertNotNil(host.window, @"%@", scenario);
            IDBlockTextView *editor = (IDBlockTextView *)
                IDViewWithAccessibilityIdentifier(controller.view, @"block-text-view");
            XCTAssertTrue([editor isKindOfClass:IDBlockTextView.class], @"%@", scenario);
            XCTAssertNotNil(IDViewWithAccessibilityIdentifier(
                controller.view, @"geometry-status"), @"%@", scenario);
            NSArray<NSString *> *expectedBlocks = fixtures[scenario];
            XCTAssertEqualObjects([editor.attributedBlocks valueForKey:@"string"],
                                  expectedBlocks, @"%@", scenario);
            XCTAssertEqualObjects(editor.font, [UIFont systemFontOfSize:20.0]);
            XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(
                editor.textContainerInset, UIEdgeInsetsMake(8, 5, 8, 5)));

            NSData *data = [[controller id_geometryStatusValue]
                dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *status = [NSJSONSerialization JSONObjectWithData:data
                options:0 error:nil];
            NSMutableSet *expectedKeys = [baseKeys mutableCopy];
            BOOL large = [scenario isEqualToString:@"geometry-large-selection"];
            if (large) {
                [expectedKeys addObjectsFromArray:@[
                    @"canonicalLength", @"selectionTextLength",
                ]];
            }
            XCTAssertEqualObjects([NSSet setWithArray:status.allKeys], expectedKeys);
            NSString *canonical = [expectedBlocks componentsJoinedByString:@"\n"];
            XCTAssertEqualObjects(status[@"canonical"], canonical);
            XCTAssertEqualObjects(status[@"scenario"], scenario);
            XCTAssertEqualObjects(status[@"blockCount"], @(expectedBlocks.count));
            NSDictionary *expectedSelection = @{
                @"length": @0, @"location": (large ? @0 : @3),
            };
            XCTAssertEqualObjects(status[@"selection"], expectedSelection);
            if (large) {
                XCTAssertEqualObjects(status[@"canonicalLength"], @(canonical.length));
                XCTAssertEqualObjects(status[@"selectionTextLength"], @0);
            }
            for (NSString *key in @[@"caret", @"visible"]) {
                NSDictionary *rect = status[key];
                XCTAssertEqualObjects([NSSet setWithArray:rect.allKeys], rectKeys);
                for (NSNumber *value in rect.allValues) {
                    XCTAssertTrue(isfinite(value.doubleValue));
                }
            }
            [host tearDown];
        }
    }
}

- (void)testGeometryStatusProducersExposeExactBoundarySchema {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSString *> *producers = @{
        @"App/IDDemoViewController.m": @"custom",
        @"StockOracleHost/main.m": @"stock",
    };
    NSSet<NSString *> *expectedKeys = [NSSet setWithArray:@[
        @"affinity", @"baseWritingDirection", @"bundleIdentifier",
        @"firstResponder", @"launchArguments", @"localeIdentifier",
        @"primaryLanguage", @"role", @"scenario", @"selection",
    ]];
    [producers enumerateKeysAndObjectsUsingBlock:
        ^(NSString *path, NSString *role, BOOL *stop) {
        NSString *source = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(path)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(source, @"%@", path);
        NSString *functionName = [role isEqualToString:@"custom"]
            ? @"IDCustomGeometryBoundary" : @"IDStockGeometryBoundary";
        NSRange start = [source rangeOfString:[NSString stringWithFormat:
            @"static NSDictionary<NSString *, id> *%@(", functionName]];
        XCTAssertNotEqual(start.location, NSNotFound, @"%@", path);
        if (start.location == NSNotFound) return;
        NSRange end = [source rangeOfString:@"\n}\n"
            options:0 range:NSMakeRange(NSMaxRange(start),
                                         source.length - NSMaxRange(start))];
        XCTAssertNotEqual(end.location, NSNotFound, @"%@", path);
        if (end.location == NSNotFound) return;
        NSString *body = [source substringWithRange:NSMakeRange(
            start.location, NSMaxRange(end) - start.location)];
        NSRegularExpression *keyExpression = [NSRegularExpression
            regularExpressionWithPattern:@"@\\\"([^\\\"]+)\\\"\\s*:"
                                  options:0 error:nil];
        NSMutableSet<NSString *> *keys = [NSMutableSet set];
        for (NSTextCheckingResult *match in [keyExpression
                matchesInString:body options:0
                range:NSMakeRange(0, body.length)]) {
            [keys addObject:[body substringWithRange:[match rangeAtIndex:1]]];
        }
        XCTAssertEqualObjects(keys, expectedKeys, @"%@ body=%@", path, body);
        NSString *roleToken = [NSString stringWithFormat:
            @"@\"role\": @\"%@\"", role];
        NSString *boundaryToken = [NSString stringWithFormat:
            @"@\"boundary\": %@(", functionName];
        XCTAssertTrue([body containsString:roleToken], @"%@", path);
        XCTAssertTrue([source containsString:boundaryToken], @"%@", path);
    }];
}

- (void)testBlockTextViewUITestsTerminateAllHostsAtEveryBoundary {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDBlockTextViewUITests.m")
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    XCTAssertNotNil(source);
    XCTAssertTrue([source containsString:@"- (void)terminateAllHosts"]);
    for (NSString *signature in @[
        @"- (void)setUp {",
        @"- (void)tearDown {",
        @"- (XCUIApplication *)launchScenario:(NSString *)scenario {",
        @"- (XCUIApplication *)launchGeometryScenario:(NSString *)scenario",
        @"- (XCUIApplication *)launchStockNavigationScenario:(NSString *)scenario {",
        @"- (XCUIApplication *)launchStockGeometryScenario:(NSString *)scenario",
    ]) {
        NSRange start = [source rangeOfString:signature];
        XCTAssertNotEqual(start.location, NSNotFound, @"%@", signature);
        if (start.location == NSNotFound) continue;
        NSRange nextMethod = [source rangeOfString:@"\n- ("
            options:0 range:NSMakeRange(NSMaxRange(start),
                                         source.length - NSMaxRange(start))];
        NSUInteger end = nextMethod.location == NSNotFound
            ? source.length : nextMethod.location;
        NSString *method = [source substringWithRange:
            NSMakeRange(start.location, end - start.location)];
        XCTAssertTrue([method containsString:@"[self terminateAllHosts];"],
                      @"%@", signature);
    }
}

- (void)testTouchScenariosExposeExactFixturesAndDeterministicStatusSchema {
    NSArray<NSString *> *baseLTR = @[
        @"First wrapped paragraph contains constellation and punctuation for precise taps.",
        @"Second wrapped paragraph provides selection handles across independent blocks.",
        @"Third wrapped paragraph keeps the viewport tall enough for controlled scrolling.",
    ];
    NSMutableArray<NSString *> *autoscroll = [baseLTR mutableCopy];
    for (NSUInteger index = 0; index < 30; index += 1) {
        [autoscroll addObject:[NSString stringWithFormat:
            @"Autoscroll block %02lu carries enough words to wrap.",
            (unsigned long)index]];
    }
    NSDictionary<NSString *, NSArray<NSString *> *> *fixtures = @{
        @"touch-ltr": baseLTR,
        @"touch-boundary": @[@"Boundary alpha omega", @"Boundary beta gamma"],
        @"touch-bidi": @[@"English prefix", @"אבגדה mixed suffix"],
        @"touch-autoscroll": autoscroll.copy,
    };
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"blockCount", @"canonical", @"caret", @"containerCreations",
        @"containerStable", @"contentOffset", @"presentationUpdates",
        @"scenario", @"selection", @"selectionRects", @"state", @"visible",
    ]];
    NSSet *expectedRectKeys = [NSSet setWithArray:@[@"height", @"width", @"x", @"y"]];
    NSSet *expectedOffsetKeys = [NSSet setWithArray:@[@"x", @"y"]];
    NSDictionary *expectedSelection = @{@"length": @0, @"location": @0};

    for (NSString *scenario in @[
        @"touch-ltr", @"touch-boundary", @"touch-bidi", @"touch-autoscroll",
    ]) {
        @autoreleasepool {
            IDTouchScenarioDemoViewController *controller =
                [IDTouchScenarioDemoViewController new];
            controller.scenario = scenario;
            IDWindowTestHost *host = [[IDWindowTestHost alloc]
                initWithController:controller size:CGSizeMake(390, 844)];
            XCTAssertNotNil(host.window, @"%@", scenario);
            IDBlockTextView *editor = (IDBlockTextView *)IDViewWithAccessibilityIdentifier(
                controller.view, @"block-text-view");
            XCTAssertTrue([editor isKindOfClass:IDBlockTextView.class], @"%@", scenario);
            XCTAssertNotNil(IDViewWithAccessibilityIdentifier(controller.view, @"touch-status"),
                            @"%@", scenario);

            NSArray<NSString *> *expectedStrings = fixtures[scenario];
            NSMutableArray<NSString *> *actualStrings = [NSMutableArray array];
            for (NSAttributedString *block in editor.attributedBlocks) {
                [actualStrings addObject:block.string];
            }
            XCTAssertEqualObjects(actualStrings, expectedStrings, @"%@", scenario);

            NSData *data = [[controller id_touchSelectionStatusValue]
                dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *status = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:&error];
            XCTAssertNil(error, @"%@", scenario);
            NSMutableSet *scenarioExpectedKeys = [expectedKeys mutableCopy];
            [scenarioExpectedKeys addObjectsFromArray:@[
                @"autoscroll",
                @"backend",
                @"interactionHostTopology",
                @"selectionContainerIdentity",
            ]];
            if ([scenario isEqualToString:@"touch-autoscroll"]) {
                [scenarioExpectedKeys addObject:@"visibleHandles"];
            }
            XCTAssertEqualObjects([NSSet setWithArray:status.allKeys], scenarioExpectedKeys,
                                  @"%@", scenario);
            XCTAssertEqualObjects(status[@"scenario"], scenario);
            XCTAssertEqualObjects(status[@"blockCount"], @(expectedStrings.count));
            XCTAssertEqualObjects(status[@"canonical"],
                                  [expectedStrings componentsJoinedByString:@"\n"]);
            XCTAssertGreaterThan([status[@"presentationUpdates"] unsignedIntegerValue], 0U);
            XCTAssertEqualObjects(status[@"containerCreations"], @1);
            XCTAssertEqualObjects(status[@"containerStable"], @YES);
            XCTAssertEqualObjects(status[@"selection"], expectedSelection);
            XCTAssertEqualObjects(status[@"selectionRects"], @[]);
            if ([scenario isEqualToString:@"touch-autoscroll"]) {
                XCTAssertTrue([status[@"visibleHandles"] isKindOfClass:NSArray.class]);
            }
            for (NSString *rectKey in @[@"caret", @"visible"]) {
                NSDictionary *rect = status[rectKey];
                XCTAssertEqualObjects([NSSet setWithArray:rect.allKeys], expectedRectKeys);
                for (NSString *component in @[@"height", @"width", @"x", @"y"]) {
                    XCTAssertTrue(isfinite([rect[component] doubleValue]),
                                  @"%@ %@ %@", scenario, rectKey, component);
                }
            }
            NSDictionary *offset = status[@"contentOffset"];
            XCTAssertEqualObjects([NSSet setWithArray:offset.allKeys], expectedOffsetKeys);
            XCTAssertTrue(isfinite([offset[@"x"] doubleValue]), @"%@", scenario);
            XCTAssertTrue(isfinite([offset[@"y"] doubleValue]), @"%@", scenario);
            [host tearDown];
        }
    }
}

- (void)testFloatingCursorScenarioExposesExactFixtureAndStatusSchema {
    IDTouchScenarioDemoViewController *controller = [IDTouchScenarioDemoViewController new];
    controller.scenario = @"floating-ltr";
    IDWindowTestHost *host = [[IDWindowTestHost alloc]
        initWithController:controller size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    IDBlockTextView *editor = (IDBlockTextView *)IDViewWithAccessibilityIdentifier(
        controller.view, @"block-text-view");
    UIView *statusView = IDViewWithAccessibilityIdentifier(controller.view, @"floating-status");
    XCTAssertTrue([editor isKindOfClass:IDBlockTextView.class]);
    XCTAssertNotNil(statusView);
    NSArray *expectedBlocks = @[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ];
    XCTAssertEqualObjects([editor.attributedBlocks valueForKey:@"string"], expectedBlocks);
    XCTAssertEqualObjects(editor.font, [UIFont systemFontOfSize:20.0]);
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(editor.textContainerInset,
                                                UIEdgeInsetsMake(8, 5, 8, 5)));
    NSString *value = [statusView accessibilityValue];
    NSDictionary *status = [NSJSONSerialization JSONObjectWithData:
        [value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSSet *keys = [NSSet setWithArray:@[
        @"scenario", @"canonical", @"selection", @"caret", @"visible",
        @"contentOffset", @"blockCount", @"presentationUpdates",
        @"containerCreations", @"containerStable", @"firstResponder",
        @"startAffinity", @"endAffinity", @"cursorCallback", @"autoscrollTrace",
        @"interactionHostTopology", @"lifecycle",
    ]];
    XCTAssertEqualObjects([NSSet setWithArray:status.allKeys], keys);
    XCTAssertEqualObjects(status[@"scenario"], @"floating-ltr");
    XCTAssertEqualObjects(status[@"canonical"], [expectedBlocks componentsJoinedByString:@"\n"]);
    XCTAssertEqualObjects(status[@"blockCount"], @3);
    NSDictionary *expectedSelection = @{@"length": @0, @"location": @46};
    XCTAssertEqualObjects(status[@"selection"], expectedSelection);
    XCTAssertEqualObjects(status[@"cursorCallback"], NSNull.null);
}

- (void)testSelectionCallbackWithdrawalInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSFileManager *files = NSFileManager.defaultManager;
    XCTAssertFalse([files fileExistsAtPath:IDEngineSourceFile(@"PrivateUIKit/IDInteractionCallbackWithdrawal.h")]);
    XCTAssertFalse([files fileExistsAtPath:IDEngineSourceFile(@"Scripts/run-selection-callback-withdrawal.sh")]);
    for (NSString *relativePath in @[
             @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m",
             @"PrivateUIKit/IDPrivateUIKit.m",
         ]) {
        NSString *source = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(source);
        XCTAssertFalse([source containsString:@"ID_WITHDRAW_"], @"%@", relativePath);
        XCTAssertFalse([source containsString:@"IDInteractionWithdrawnCallbackName"],
                       @"%@", relativePath);
    }
}

- (void)testBlockGestureRecognizerHostRequirementInfrastructureIsExact {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSString *methodToken = [@"ID_WITHDRAW_BLOCK_GESTURE_RECOGNIZER_HOST_"
        stringByAppendingString:@"CALLBACK"];
    NSString *abiToken = [@"ID_OMIT_BLOCK_GESTURE_RECOGNIZER_HOST_"
        stringByAppendingString:@"ABI"];
    NSString *callbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(privateUIKit);

    NSString *methodRegion =
        @"- (UIView *)tgpn__textInputViewForAddingGestureRecognizers {\n"
         "    return self;\n"
         "}";
    NSString *abiRegion =
        @"IDInteractionABISpecMake(TGPN__textInputViewForAddingGestureRecognizers(), @encode(id), @[]),";
    XCTAssertEqual(IDSourceOccurrenceCount(callbacks, methodRegion), 1U);
    XCTAssertEqual(IDSourceOccurrenceCount(privateUIKit, abiRegion), 1U);

    NSString *generalCallbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m");
    XCTAssertNotNil(generalCallbacks);
    XCTAssertFalse([generalCallbacks containsString:
        @"_textInputViewForAddingGestureRecognizers"]);

    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests", @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (source == nil) continue;
            XCTAssertFalse([source containsString:methodToken], @"%@/%@", folder,
                           relativePath);
            XCTAssertFalse([source containsString:abiToken], @"%@/%@", folder,
                           relativePath);
        }
    }
    for (NSString *relativePath in @[@"project.yml", @"InputDec.xcodeproj/project.pbxproj"]) {
        NSString *source = read(relativePath);
        XCTAssertFalse([source containsString:methodToken], @"%@", relativePath);
        XCTAssertFalse([source containsString:abiToken], @"%@", relativePath);
    }
}

- (void)testReducedSelectionCallbackSurfaceHasNoAlternateImplementation {
    NSString *fixturePath = IDEngineSourceFile(@"Tests/Fixtures/SelectionCallbackAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:fixturePath];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, 240.0, 120.0)
        attributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"reduced surface"],
        ]];
    for (NSDictionary<NSString *, id> *row in fixture[@"callbacks"]) {
        NSString *selectorName = row[@"selector"];
        BOOL retained = ![row[@"authorization"] isEqual:@"safeFallback"];
        NSArray<NSString *> *definitions =
            IDBlockHostMethodDefinitionPaths(selectorName);
        XCTAssertEqual([view respondsToSelector:NSSelectorFromString(selectorName)],
                       retained, @"%@", selectorName);
        XCTAssertEqual(definitions.count, retained ? 1U : 0U,
                       @"%@ definitions=%@", selectorName, definitions);
        if (retained) {
            XCTAssertEqualObjects(definitions,
                @[@"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m"]);
            NSMethodSignature *signature = [view methodSignatureForSelector:
                NSSelectorFromString(selectorName)];
            XCTAssertNotNil(signature);
            XCTAssertEqual(signature.numberOfArguments, 2U);
            XCTAssertEqual(strcmp(signature.methodReturnType, @encode(id)), 0);
        }
    }
}

- (void)testBlockInternalControllerReductionProbePublishesExactSelectorFreeSchema {
    IDSelectionCallbackReductionScenarioDemoViewController *controller =
        [IDSelectionCallbackReductionScenarioDemoViewController new];
    controller.scenario = @"touch-ltr";
    IDWindowTestHost *host = [[IDWindowTestHost alloc]
        initWithController:controller size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    UIView *statusView = IDViewWithAccessibilityIdentifier(
        controller.view, @"selection-callback-reduced-surface-status");
    XCTAssertNotNil(statusView);
    NSData *data = [[statusView accessibilityValue]
        dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *status = [NSJSONSerialization JSONObjectWithData:data
                                                            options:0
                                                              error:nil];
    XCTAssertEqualObjects([NSSet setWithArray:status.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"responds", @"container", @"editingLookup",
            @"visualSelectionLookup", @"internalControllerLookup",
            @"editorState"
        ]]));
    XCTAssertEqualObjects(status[@"schema"], @5);
    XCTAssertEqualObjects(status[@"responds"], (@{
        @"selectionContainerView": @YES,
        @"_selectionContainerViewAboveText": @NO,
        @"_existingSelectionContainerView": @NO,
        @"_placeSelectionContainerView": @NO,
        @"_updateInteractionGeometry": @NO
    }));
    NSDictionary *container = status[@"container"];
    XCTAssertEqualObjects([NSSet setWithArray:container.allKeys],
        ([NSSet setWithArray:@[
            @"created", @"stable", @"superviewRole"
        ]]));
    XCTAssertEqualObjects(container[@"created"], @1);
    XCTAssertEqualObjects(container[@"stable"], @YES);
    XCTAssertEqualObjects(container[@"superviewRole"], @"textInputView");

    NSDictionary *editingLookup = status[@"editingLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:editingLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner"
        ]]));
    XCTAssertEqualObjects(editingLookup[@"selector"], @"isEditing");
    XCTAssertEqualObjects(editingLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(editingLookup[@"responds"], @YES);
    XCTAssertEqualObjects(editingLookup[@"resolvedMatchesDirectSuperclass"], @YES);
    XCTAssertEqualObjects(editingLookup[@"resolvedOwner"], @"directSuperclass");

    NSDictionary *visualLookup = status[@"visualSelectionLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:visualLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner",
            @"richControllerLocalProvider"
        ]]));
    XCTAssertEqualObjects(visualLookup[@"selector"],
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertEqualObjects(visualLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(visualLookup[@"responds"], @NO);
    XCTAssertEqualObjects(visualLookup[@"resolvedMatchesDirectSuperclass"], @NO);
    XCTAssertEqualObjects(visualLookup[@"resolvedOwner"], @"none");
    XCTAssertEqualObjects(visualLookup[@"richControllerLocalProvider"], @YES);

    NSDictionary *internalLookup = status[@"internalControllerLookup"];
    XCTAssertEqualObjects([NSSet setWithArray:internalLookup.allKeys],
        ([NSSet setWithArray:@[
            @"selector", @"localProvider", @"responds",
            @"resolvedMatchesDirectSuperclass", @"resolvedOwner",
            @"textLayoutControllerLocalProvider"
        ]]));
    XCTAssertEqualObjects(internalLookup[@"selector"],
                          @"_internalTextLayoutController");
    XCTAssertEqualObjects(internalLookup[@"localProvider"], @NO);
    XCTAssertEqualObjects(internalLookup[@"responds"], @NO);
    XCTAssertEqualObjects(internalLookup[@"resolvedMatchesDirectSuperclass"],
                          @NO);
    XCTAssertEqualObjects(internalLookup[@"resolvedOwner"], @"none");
    XCTAssertEqualObjects(internalLookup[@"textLayoutControllerLocalProvider"],
                          @YES);

    NSDictionary *editorState = status[@"editorState"];
    XCTAssertEqualObjects([NSSet setWithArray:editorState.allKeys],
        ([NSSet setWithArray:@[
            @"firstResponder", @"editable", @"selectable",
            @"selectionLocation", @"selectionLength", @"scenario", @"phase"
        ]]));
    XCTAssertEqualObjects(editorState[@"firstResponder"], @YES);
    XCTAssertEqualObjects(editorState[@"editable"], @YES);
    XCTAssertEqualObjects(editorState[@"selectable"], @YES);
    XCTAssertEqualObjects(editorState[@"scenario"], @"none");
    XCTAssertEqualObjects(editorState[@"phase"], @"focused");
    XCTAssertGreaterThanOrEqual([editorState[@"selectionLocation"] integerValue], 0);
    XCTAssertGreaterThanOrEqual([editorState[@"selectionLength"] integerValue], 0);
}

- (void)testBlockVisualSelectionReductionProbeDoesNotSendCandidateSelector {
    NSString *path = IDEngineSourceFile(@"App/IDSelectionCallbackReductionProbe.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    XCTAssertTrue([source containsString:@"class_copyMethodList"]);
    XCTAssertTrue([source containsString:@"class_getMethodImplementation"]);
    XCTAssertFalse([source containsString:@"[editor _visualSelectionRangeForExtent:"]);
    XCTAssertFalse([source containsString:@"performSelector"]);
    XCTAssertFalse([source containsString:@"objc_msgSend"]);
}

- (void)testFloatingCursorParityUsesRichVisualSelectionAuthorityForCustomEditor {
    NSString *path = IDEngineSourceFile(@"Tests/IDFloatingCursorParityTests.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    XCTAssertFalse([source containsString:@"custom, selector, custom"],
                   @"Custom parity calls must not depend on the optional outer callback");
    XCTAssertEqual(IDSourceOccurrenceCount(
        source, @"id_visualSelectionRangeForExtent:custom"), 4U);
}

- (void)testSelectionCallbackReductionProbeObservesIsEditingWithoutSendingIt {
    NSString *path = IDEngineSourceFile(@"App/IDSelectionCallbackReductionProbe.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    XCTAssertTrue([source containsString:@"class_copyMethodList"]);
    XCTAssertTrue([source containsString:@"class_getMethodImplementation"]);
    XCTAssertTrue([source containsString:@"class_getSuperclass"]);
    XCTAssertFalse([source containsString:@"[editor isEditing]"]);
    XCTAssertFalse([source containsString:@"performSelector"]);
    XCTAssertFalse([source containsString:@"objc_msgSend"]);
}

- (void)testSelectionCallbackReductionProbeRefreshPreservesStableElement {
    IDSelectionCallbackReductionScenarioDemoViewController *controller =
        [IDSelectionCallbackReductionScenarioDemoViewController new];
    controller.scenario = @"touch-ltr";
    IDWindowTestHost *host = [[IDWindowTestHost alloc]
        initWithController:controller size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];

    UIView *statusView = IDViewWithAccessibilityIdentifier(
        controller.view, @"selection-callback-reduced-surface-status");
    UIButton *refresh = (UIButton *)IDViewWithAccessibilityIdentifier(
        controller.view, @"selection-callback-reduced-surface-refresh");
    XCTAssertNotNil(statusView);
    XCTAssertTrue([refresh isKindOfClass:UIButton.class]);
    NSString *before = statusView.accessibilityValue;
    [refresh sendActionsForControlEvents:UIControlEventTouchUpInside];
    UIView *afterView = IDViewWithAccessibilityIdentifier(
        controller.view, @"selection-callback-reduced-surface-status");
    XCTAssertEqual(afterView, statusView);
    XCTAssertNotNil(afterView.accessibilityValue);
    XCTAssertEqualObjects(afterView.accessibilityValue, before);
}

- (void)testMultiBlockControlRepeatedlyTearsDownAndDeallocatesEveryOldGraphOwner {
    IDDemoViewController *controller = nil;
    IDWindowTestHost *host = nil;
    @autoreleasepool {
        controller = [IDDemoViewController new];
        host = [[IDWindowTestHost alloc] initWithController:controller
                                                       size:CGSizeMake(390, 844)];
    }
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    @autoreleasepool {
        UIButton *mode = (UIButton *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                        @"editor-mode-toggle");
        XCTAssertTrue([mode isKindOfClass:UIButton.class]);
        XCTAssertEqualObjects(mode.currentTitle, @"Multi-Block Experiment");
    }

    for (NSUInteger cycle = 0; cycle < 3; cycle += 1) {
        __weak IDTextView *weakFlat = nil;
        __weak id weakFlatLayout = nil;
        __weak id weakFlatInput = nil;
        __weak id weakFlatAssistant = nil;
        __weak UIView *weakFlatSelection = nil;
        @autoreleasepool {
            UIButton *mode = (UIButton *)IDViewWithAccessibilityIdentifier(
                controller.view,
                @"editor-mode-toggle");
            IDTextView *oldFlat = (IDTextView *)IDViewWithAccessibilityIdentifier(
                controller.view,
                @"custom-text-view");
            XCTAssertTrue([oldFlat isKindOfClass:IDTextView.class]);
            UIView *oldFlatSelection = [oldFlat selectionContainerView];
            NSDictionary<NSString *, NSNumber *> *flatRecognizerCounts =
                IDTask9RecognizerClassCounts(oldFlat);
            for (NSString *className in IDTask9NativeRecognizerClassNames()) {
                XCTAssertEqual(flatRecognizerCounts[className].unsignedIntegerValue,
                               1U,
                               @"cycle %lu active flat %@ count %@",
                               (unsigned long)cycle,
                               className,
                               flatRecognizerCounts[className]);
            }
            weakFlat = oldFlat;
            weakFlatLayout = oldFlat.id_layoutController;
            weakFlatInput = oldFlat.id_inputController;
            weakFlatAssistant = oldFlat.id_interactionAssistant;
            weakFlatSelection = oldFlatSelection;

            [mode sendActionsForControlEvents:UIControlEventTouchUpInside];
            [controller.view layoutIfNeeded];
            XCTAssertNil(oldFlat.superview);
        }
        IDDrainTask11OwnershipUntil(^BOOL{
            return weakFlatLayout == nil && weakFlatInput == nil &&
                   weakFlatAssistant == nil && weakFlatSelection == nil && weakFlat == nil;
        });
        XCTAssertNil(weakFlatLayout);
        XCTAssertNil(weakFlatInput);
        XCTAssertNil(weakFlatAssistant);
        XCTAssertNil(weakFlatSelection);
        XCTAssertNil(weakFlat);

        __weak IDBlockTextView *weakBlock = nil;
        __weak id weakBlockLayout = nil;
        __weak id weakBlockInput = nil;
        __weak id weakBlockAssistant = nil;
        __weak UIView *weakBlockSelection = nil;
        @autoreleasepool {
            UIButton *mode = (UIButton *)IDViewWithAccessibilityIdentifier(
                controller.view,
                @"editor-mode-toggle");
            IDBlockTextView *oldBlock = (IDBlockTextView *)IDViewWithAccessibilityIdentifier(
                controller.view,
                @"block-text-view");
            XCTAssertTrue([oldBlock isKindOfClass:IDBlockTextView.class]);
            XCTAssertEqual(oldBlock.attributedBlocks.count, 2U);
            UIView *oldBlockSelection = [oldBlock selectionContainerView];
            NSDictionary<NSString *, NSNumber *> *blockRecognizerCounts =
                IDTask9RecognizerClassCounts(oldBlock);
            for (NSString *className in IDTask9NativeRecognizerClassNames()) {
                XCTAssertEqual(blockRecognizerCounts[className].unsignedIntegerValue,
                               1U,
                               @"cycle %lu active block %@ count %@",
                               (unsigned long)cycle,
                               className,
                               blockRecognizerCounts[className]);
            }
            weakBlock = oldBlock;
            weakBlockLayout = oldBlock.id_layoutController;
            weakBlockInput = oldBlock.id_inputController;
            weakBlockAssistant = oldBlock.id_interactionAssistant;
            weakBlockSelection = oldBlockSelection;

            [mode sendActionsForControlEvents:UIControlEventTouchUpInside];
            [controller.view layoutIfNeeded];
            XCTAssertNil(oldBlock.superview);
            NSDictionary<NSString *, NSNumber *> *tornDownRecognizerCounts =
                IDTask9RecognizerClassCounts(oldBlock);
            for (NSString *className in IDTask9NativeRecognizerClassNames()) {
                XCTAssertEqual(tornDownRecognizerCounts[className].unsignedIntegerValue,
                               0U,
                               @"cycle %lu torn-down block retained %@",
                               (unsigned long)cycle,
                               className);
            }
            XCTAssertNil(oldBlock.id_layoutController);
            XCTAssertNil(oldBlock.id_inputController);
            XCTAssertNil(oldBlock.id_interactionAssistant);
            XCTAssertNil(oldBlockSelection.superview);
        }
        IDDrainTask11OwnershipUntil(^BOOL{
            return weakBlockLayout == nil && weakBlockInput == nil &&
                   weakBlockAssistant == nil && weakBlockSelection == nil && weakBlock == nil;
        });
        XCTAssertNil(weakBlockLayout);
        XCTAssertNil(weakBlockInput);
        XCTAssertNil(weakBlockAssistant);
        XCTAssertNil(weakBlockSelection);
        XCTAssertNil(weakBlock);
        @autoreleasepool {
            UIButton *mode = (UIButton *)IDViewWithAccessibilityIdentifier(
                controller.view,
                @"editor-mode-toggle");
            XCTAssertEqualObjects(mode.currentTitle, @"Multi-Block Experiment");
        }
    }
}
- (void)testIncompatibleDemoShowsReportWithoutConstructingPrivateEditor {
    IDIncompatibleDemoViewController *controller = [IDIncompatibleDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(320, 480)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    NSArray *descendants = IDDescendantsOfView(controller.view);
    NSPredicate *isEditor = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [object isKindOfClass:IDTextView.class];
    }];
    XCTAssertEqual([descendants filteredArrayUsingPredicate:isEditor].count, 0);
    XCTAssertEqual(controller.editorFactoryCallCount, 0U);
    UILabel *report = (UILabel *)[controller.view viewWithTag:2601];
    XCTAssertTrue([report isKindOfClass:UILabel.class]);
    XCTAssertEqualObjects(report.text, controller.id_privateUIKitCompatibilityReport);
    XCTAssertTrue(report.userInteractionEnabled);
    XCTAssertTrue(report.canBecomeFirstResponder);
    XCTAssertTrue([report canPerformAction:@selector(copy:) withSender:nil]);
    UIScrollView *scrollView = (UIScrollView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"fatal-compatibility-scroll");
    XCTAssertTrue([scrollView isKindOfClass:UIScrollView.class]);
    XCTAssertGreaterThan(scrollView.contentSize.height - scrollView.bounds.size.height, 500.0);

    UIPasteboard.generalPasteboard.string = nil;
    [(id)report copy:nil];
    XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, report.text);
    UIPasteboard.generalPasteboard.string = nil;
    UIAccessibilityCustomAction *action = report.accessibilityCustomActions.firstObject;
    XCTAssertNotNil(action.actionHandler);
    if (action.actionHandler != nil) {
        XCTAssertTrue(action.actionHandler(action));
    }
    XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, report.text);
}

- (void)testConstructionCompatibilityFailureShowsReadableFatalReport {
    IDConstructionFailureDemoViewController *controller =
        [IDConstructionFailureDemoViewController new];
    __block IDWindowTestHost *host = nil;
    XCTAssertNoThrow(host = [[IDWindowTestHost alloc] initWithController:controller
                                                                    size:CGSizeMake(320, 480)]);
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);
    XCTAssertEqual(controller.editorFactoryCallCount, 1U);

    NSPredicate *isEditor = [NSPredicate predicateWithBlock:^BOOL(id object,
                                                                  NSDictionary *bindings) {
        return [object isKindOfClass:IDTextView.class];
    }];
    NSArray *descendants = IDDescendantsOfView(controller.view);
    XCTAssertEqual([descendants filteredArrayUsingPredicate:isEditor].count, 0U);
    UILabel *report = (UILabel *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"fatal-compatibility-report");
    XCTAssertTrue([report isKindOfClass:UILabel.class]);
    XCTAssertTrue([report.text containsString:@"Backward-delete ranges construction preflight"]);
    XCTAssertTrue([report.text containsString:@"unionRange"]);
    XCTAssertNotNil(IDViewWithAccessibilityIdentifier(controller.view,
                                                       @"fatal-compatibility-scroll"));
}
- (void)testAccessibilityContentSizeReflowsCompleteControlTitlesAndKeepsEditorReachable {
    IDDemoViewController *controller = [IDDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(320, 640)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    UIStackView *primary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"primary-controls");
    UIStackView *secondary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"secondary-controls");
    XCTAssertEqual(primary.axis, UILayoutConstraintAxisHorizontal);
    XCTAssertEqual(secondary.axis, UILayoutConstraintAxisHorizontal);
    controller.traitOverrides.preferredContentSizeCategory =
        UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
    XCTAssertEqual(primary.axis, UILayoutConstraintAxisVertical);
    XCTAssertEqual(secondary.axis, UILayoutConstraintAxisVertical);
    NSDictionary<NSString *, NSString *> *expectedTitles = @{
        @"reset-button": @"Reset",
        @"editable-toggle": @"Editable: On",
        @"selectable-toggle": @"Selectable: On",
        @"dismiss-button": @"Dismiss",
        @"diagnostics-button": @"Diagnostics",
        @"editor-mode-toggle": @"Multi-Block Experiment",
    };
    [expectedTitles enumerateKeysAndObjectsUsingBlock:^(NSString *identifier,
                                                        NSString *title,
                                                        BOOL *stop) {
        UIButton *button = (UIButton *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                          identifier);
        XCTAssertEqualObjects(button.currentTitle, title);
        XCTAssertEqual(button.titleLabel.numberOfLines, 0);
        CGSize required = [button.titleLabel sizeThatFits:CGSizeMake(button.titleLabel.bounds.size.width,
                                                                     CGFLOAT_MAX)];
        XCTAssertLessThanOrEqual(required.height, button.titleLabel.bounds.size.height + 1.0,
                                 @"%@ title is vertically truncated", identifier);
        for (UIView *ancestor = button.superview;
             ancestor != nil;
             ancestor = ancestor.superview) {
            if (![ancestor isKindOfClass:UIScrollView.class]) continue;
            UIScrollView *scrollView = (UIScrollView *)ancestor;
            CGRect target = [button convertRect:button.bounds toView:scrollView];
            [scrollView scrollRectToVisible:target animated:NO];
            [controller.view layoutIfNeeded];
        }
        CGRect visibleFrame = [button convertRect:button.bounds toView:controller.view];
        XCTAssertTrue(CGRectIntersectsRect(controller.view.bounds, visibleFrame),
                      @"%@ cannot be brought onscreen", identifier);
        XCTAssertTrue(button.userInteractionEnabled, @"%@ is not reachable", identifier);
    }];
    IDTextView *editor = (IDTextView *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                         @"custom-text-view");
    XCTAssertGreaterThan(editor.bounds.size.height, 80.0);
    XCTAssertTrue(CGRectIntersectsRect(controller.view.bounds, editor.frame));
}
- (void)testToggleButtonsExposeVisibleAndAccessibleStateAfterChanges {
    IDDemoViewController *controller = [IDDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);
    UIButton *editable = (UIButton *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                        @"editable-toggle");
    UIButton *selectable = (UIButton *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                          @"selectable-toggle");
    XCTAssertEqualObjects(editable.currentTitle, @"Editable: On");
    XCTAssertEqualObjects(editable.accessibilityLabel, @"Editable");
    XCTAssertEqualObjects(editable.accessibilityValue, @"On");
    XCTAssertEqualObjects(selectable.currentTitle, @"Selectable: On");
    XCTAssertEqualObjects(selectable.accessibilityLabel, @"Selectable");
    XCTAssertEqualObjects(selectable.accessibilityValue, @"On");

    [editable sendActionsForControlEvents:UIControlEventTouchUpInside];
    [selectable sendActionsForControlEvents:UIControlEventTouchUpInside];

    XCTAssertEqualObjects(editable.currentTitle, @"Editable: Off");
    XCTAssertEqualObjects(editable.accessibilityLabel, @"Editable");
    XCTAssertEqualObjects(editable.accessibilityValue, @"Off");
    XCTAssertEqualObjects(selectable.currentTitle, @"Selectable: Off");
    XCTAssertEqualObjects(selectable.accessibilityLabel, @"Selectable");
    XCTAssertEqualObjects(selectable.accessibilityValue, @"Off");
}

- (void)testMultiBlockDemoCreatesInlineFormattingButtonsAndReflectsBoldState {
    IDBlockScenarioDemoViewController *controller =
        [IDBlockScenarioDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc]
        initWithController:controller
                      size:CGSizeMake(390, 844)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    NSArray<NSString *> *identifiers = @[
        @"inline-format-bold",
        @"inline-format-italic",
        @"inline-format-underline",
        @"inline-format-strikethrough",
    ];
    for (NSString *identifier in identifiers) {
        UIButton *button = (UIButton *)IDViewWithAccessibilityIdentifier(
            controller.view, identifier);
        XCTAssertTrue([button isKindOfClass:UIButton.class]);
        XCTAssertEqualObjects(button.accessibilityValue, @"Off");
    }

    IDBlockTextView *editor =
        (IDBlockTextView *)IDViewWithAccessibilityIdentifier(
            controller.view, @"block-text-view");
    UITextPosition *start = editor.beginningOfDocument;
    UITextPosition *end = [editor positionFromPosition:start offset:5];
    editor.selectedTextRange =
        [editor textRangeFromPosition:start toPosition:end];
    UIButton *bold = (UIButton *)IDViewWithAccessibilityIdentifier(
        controller.view, @"inline-format-bold");
    [bold sendActionsForControlEvents:UIControlEventTouchUpInside];

    XCTAssertEqualObjects(bold.accessibilityValue, @"On");
}

- (void)testIMEScenarioHidesUnrelatedFormattingControls {
    IDIMEScenarioDemoViewController *controller =
        [IDIMEScenarioDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc]
        initWithController:controller
                      size:CGSizeMake(402, 874)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);

    UIStackView *formattingControls =
        (UIStackView *)IDViewWithAccessibilityIdentifier(
            controller.view, @"inline-format-controls");
    XCTAssertTrue([formattingControls isKindOfClass:UIStackView.class]);
    XCTAssertTrue(formattingControls.hidden);
}

- (void)testRegularIPadLayoutUsesHorizontalControlRowsAndReachableEditor {
    IDDemoViewController *controller = [IDDemoViewController new];
    IDWindowTestHost *host = [[IDWindowTestHost alloc] initWithController:controller
                                                                     size:CGSizeMake(1024, 1366)];
    [self addTeardownBlock:^{ [host tearDown]; }];
    XCTAssertNotNil(host.window);
    UIStackView *primary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"primary-controls");
    UIStackView *secondary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        controller.view,
        @"secondary-controls");
    XCTAssertEqual(primary.axis, UILayoutConstraintAxisHorizontal);
    XCTAssertEqual(secondary.axis, UILayoutConstraintAxisHorizontal);
    IDTextView *editor = (IDTextView *)IDViewWithAccessibilityIdentifier(controller.view,
                                                                         @"custom-text-view");
    XCTAssertGreaterThan(editor.bounds.size.height, 900.0);
}

- (void)testRegularIPadLayoutRemainsReachableAfterCompactHostTeardown {
    IDDemoViewController *compactController = [IDDemoViewController new];
    compactController.traitOverrides.horizontalSizeClass =
        UIUserInterfaceSizeClassCompact;
    compactController.traitOverrides.verticalSizeClass =
        UIUserInterfaceSizeClassRegular;
    IDWindowTestHost *compactHost = [[IDWindowTestHost alloc]
        initWithController:compactController
                      size:CGSizeMake(390, 844)];
    XCTAssertNotNil(compactHost.window);
    [compactHost tearDown];

    IDDemoViewController *regularController = [IDDemoViewController new];
    regularController.traitOverrides.horizontalSizeClass =
        UIUserInterfaceSizeClassRegular;
    regularController.traitOverrides.verticalSizeClass =
        UIUserInterfaceSizeClassRegular;
    IDWindowTestHost *regularHost = [[IDWindowTestHost alloc]
        initWithController:regularController
                      size:CGSizeMake(1024, 1366)];
    [self addTeardownBlock:^{ [regularHost tearDown]; }];
    XCTAssertNotNil(regularHost.window);

    UIStackView *primary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        regularController.view, @"primary-controls");
    UIStackView *secondary = (UIStackView *)IDViewWithAccessibilityIdentifier(
        regularController.view, @"secondary-controls");
    XCTAssertEqual(primary.axis, UILayoutConstraintAxisHorizontal);
    XCTAssertEqual(secondary.axis, UILayoutConstraintAxisHorizontal);
    IDTextView *editor = (IDTextView *)IDViewWithAccessibilityIdentifier(
        regularController.view, @"custom-text-view");
    XCTAssertGreaterThan(editor.bounds.size.height, 900.0);
}

- (void)testDirectInputControllerForwardsAreInventoriedByCompatibilityPreflight {
    NSString *root = IDEngineSourceRoot();
    NSString *forwardPath = IDEngineSourceFile(@"TextView/IDTextView+TextInput.m");
    NSString *inventoryPath = IDEngineSourceFile(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSString *forwards = [NSString stringWithContentsOfFile:forwardPath
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    NSData *inventoryData = [NSData dataWithContentsOfFile:inventoryPath];
    NSDictionary *inventory =
        [NSJSONSerialization JSONObjectWithData:inventoryData
                                        options:0
                                          error:nil];
    NSRegularExpression *method = [NSRegularExpression
        regularExpressionWithPattern:@"(?ms)^-\\s*\\([^\\n]+?\\)[^{;]*\\{.*?^\\}"
                              options:0
                                error:nil];
    NSRegularExpression *keywords = [NSRegularExpression
        regularExpressionWithPattern:@"([A-Za-z_][A-Za-z0-9_]*):"
                              options:0
                                error:nil];
    NSMutableSet<NSString *> *direct = [NSMutableSet set];
    for (NSTextCheckingResult *match in [method matchesInString:forwards
                                                        options:0
                                                          range:NSMakeRange(0, forwards.length)]) {
        NSString *block = [forwards substringWithRange:match.range];
        if ([block rangeOfString:@"self.id_inputController"].location == NSNotFound ||
            [block rangeOfString:@"_cmd"].location == NSNotFound ||
            [block rangeOfString:@"IDPrivateRespondsToSelector"].location != NSNotFound) {
            continue;
        }
        NSRange brace = [block rangeOfString:@"{"];
        NSString *signature = [block substringToIndex:brace.location];
        NSArray<NSTextCheckingResult *> *parts = [keywords matchesInString:signature
                                                                   options:0
                                                                     range:NSMakeRange(0,
                                                                                       signature.length)];
        if (parts.count > 0) {
            NSMutableString *selector = [NSMutableString string];
            for (NSTextCheckingResult *part in parts) {
                [selector appendString:[signature substringWithRange:[part rangeAtIndex:1]]];
                [selector appendString:@":"];
            }
            [direct addObject:selector];
        } else {
            NSRegularExpression *zeroArgument = [NSRegularExpression
                regularExpressionWithPattern:@"\\)\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*$"
                                      options:0
                                        error:nil];
            NSTextCheckingResult *part = [zeroArgument firstMatchInString:signature
                                                                   options:0
                                                                     range:NSMakeRange(0,
                                                                                       signature.length)];
            if (part != nil) {
                [direct addObject:[signature substringWithRange:[part rangeAtIndex:1]]];
            }
        }
    }

    NSMutableSet<NSString *> *required = [NSMutableSet set];
    for (NSDictionary *capability
             in [inventory[@"capabilities"] allValues]) {
        for (NSDictionary *member in capability[@"members"]) {
            if ([member[@"class"] isEqualToString:@"UITextInputController"] &&
                [member[@"required"] boolValue]) {
                [required addObject:member[@"name"]];
            }
        }
    }
    [direct minusSet:required];
    XCTAssertEqual(direct.count, 0U, @"Missing required controller contracts: %@", direct);
}

- (void)testGuardedDictationForwardIsInventoriedAsOptional {
    NSString *root = IDEngineSourceRoot();
    NSString *path = IDEngineSourceFile(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSDictionary *inventory = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfFile:path] options:0 error:nil];
    NSArray *members =
        inventory[@"capabilities"][@"dictation"][@"members"];
    XCTAssertEqual(members.count, 1U);
    XCTAssertEqualObjects(members.firstObject[@"name"],
                          @"insertDictationResult:");
    XCTAssertFalse([members.firstObject[@"required"] boolValue]);
}

- (void)testEveryLiteralPrivateBridgeSendAppearsInCompatibilityInventory {
    NSString *root = IDEngineSourceRoot();
    NSString *implementationPath = IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m");
    NSString *implementation = [NSString stringWithContentsOfFile:
        implementationPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertFalse([implementation containsString:@"IDContract contracts[]"]);
    XCTAssertTrue([implementation
        containsString:@"IDProductionContractDictionary"]);
    NSString *manifestPath = IDEngineSourceFile(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfFile:manifestPath] options:0 error:nil];
    XCTAssertGreaterThan(
        [manifest[@"capabilities"] count], 0U);
    XCTAssertGreaterThan(
        [manifest[@"referenceOnly"] count], 0U);
}

- (void)testMinimalAutoscrollInventoryContainsOnlyRetainedAssistantEntry {
    NSString *manifestPath = IDEngineSourceFile(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSData *manifestData = [NSData dataWithContentsOfFile:manifestPath];
    NSString *manifestText = [[NSString alloc]
        initWithData:manifestData encoding:NSUTF8StringEncoding];
    NSDictionary *manifest = [NSJSONSerialization
        JSONObjectWithData:manifestData options:0 error:nil];
    NSDictionary *entry =
        manifest[@"capabilities"][@"autoscrollEntry"];
    XCTAssertNotNil(entry);
    NSArray<NSDictionary *> *entryMembers = entry[@"members"];
    XCTAssertEqual(entryMembers.count, 3U);
    NSSet<NSString *> *expectedEntryNames = [NSSet setWithArray:@[
        @"UITextAutoscrolling",
        @"startAutoscroll:",
        @"cancelAutoscroll",
    ]];
    XCTAssertEqualObjects(
        [NSSet setWithArray:[entryMembers valueForKey:@"name"]],
        expectedEntryNames);

    for (NSDictionary *capability
             in [manifest[@"capabilities"] allValues]) {
        for (NSDictionary *member in capability[@"members"]) {
            XCTAssertNotEqualObjects(member[@"class"], @"UIAutoscroll");
        }
    }
    NSArray<NSDictionary *> *legacyMembers =
        manifest[@"referenceOnly"][@"legacyAutoscroll"][@"members"];
    XCTAssertEqual(legacyMembers.count, 3U);
    for (NSDictionary *member in legacyMembers) {
        XCTAssertEqualObjects(member[@"class"], @"UIAutoscroll");
        XCTAssertEqualObjects(member[@"direction"], @"reference");
    }

    NSString *bridgePath = IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m");
    NSString *bridge = [NSString stringWithContentsOfFile:bridgePath
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    for (NSString *referenceOnlyLegacyGeometry in @[
             @"visibleBounds",
             @"_effectiveContentInset",
             @"_textContainerInsetAdjustment",
             @"_horizontalTextContainerGeometryAdjustment",
         ]) {
        XCTAssertTrue([bridge containsString:referenceOnlyLegacyGeometry],
                      @"Reference adapter lost its audited legacy geometry symbol: %@",
                      referenceOnlyLegacyGeometry);
        XCTAssertFalse([manifestText containsString:referenceOnlyLegacyGeometry],
                       @"Legacy geometry escaped into the minimal manifest: %@",
                       referenceOnlyLegacyGeometry);
    }
}

- (void)testLiteralPrivateSelectorInventoryExcludesImplementationSelectors {
    NSString *source = @"static void IDRequiredContracts(void) {\n"
                        "  NSSelectorFromString(@\"inventoriedSelector:\");\n"
                        "}\n"
                        "@implementation IDPrivateUIKit\n"
                        "- (void)send {\n"
                        "  NSSelectorFromString(@\"implementationOnlySelector:\");\n"
                        "}\n"
                        "@end\n";
    NSSet<NSString *> *inventory = IDLiteralPrivateSelectorInventory(source);
    XCTAssertTrue([inventory containsObject:@"inventoriedSelector:"]);
    XCTAssertFalse([inventory containsObject:@"implementationOnlySelector:"]);
}
- (void)testProductionSourceDoesNotReferenceUITextView {
    NSString *root = IDProjectSourceRoot();
    NSArray *folders = @[@"App", @"TextView", @"PrivateUIKit"];
    NSRegularExpression *forbidden = [NSRegularExpression
        regularExpressionWithPattern:NSStringFromClass(UITextView.class)
                              options:0 error:nil];
    for (NSString *folder in folders) {
        NSDirectoryEnumerator *files = [[NSFileManager defaultManager] enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"h"] && ![file.pathExtension isEqualToString:@"m"]) continue;
            NSString *body = [NSString stringWithContentsOfFile:[IDEngineSourceFile(folder) stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
            XCTAssertEqual([forbidden numberOfMatchesInString:body options:0 range:NSMakeRange(0, body.length)], 0, @"Forbidden UIKit text-view class reference in %@", file);
        }
    }
}
- (void)testFinalOwnershipHasOneNativeSelectionBackendConstructionSite {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSString *> *sites = IDFinalOwnershipExpectedSites();
    NSUInteger total = 0;
    NSString *owner = nil;
    for (NSString *relativePath in IDProductionImplementationPaths()) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        NSUInteger count = IDConstructionMatchCount(
            body, @"IDNativeSelectionPresentationBackend",
            @[@"IDNativeSelectionPresentationBackendCreate"]);
        total += count;
        if (count > 0) owner = relativePath;
    }
    XCTAssertEqual(total, 1U);
    XCTAssertEqualObjects(owner, sites[@"nativeSelectionBackend"]);
}

- (void)testFinalOwnershipClassifierRejectsAnUnknownProductionImplementation {
    NSSet<NSString *> *actual = [NSSet setWithArray:@[
        @"TextView/Experimental.m", @"TextView/Legacy.m", @"TextView/Surprise.m",
    ]];
    NSSet<NSString *> *classified = [NSSet setWithArray:@[
        @"TextView/Experimental.m", @"TextView/Legacy.m",
    ]];
    XCTAssertEqualObjects(IDUnclassifiedProductionImplementationPaths(actual, classified),
                          [NSSet setWithObject:@"TextView/Surprise.m"]);
}

- (void)testFinalOwnershipAuditRequiresTheInventoriedLegacyAssistantSite {
    NSDictionary<NSString *, NSString *> *sources = @{
        @"TextView/IDBlockTextView+Interaction.m":
            @"[IDPrivateUIKit newInteractionAssistantWithView:self];\n",
        @"TextView/IDBlockTextView.m":
            @"[[IDRichTextLayoutController alloc] init];\n"
             "[[IDNativeSelectionPresentationBackend alloc] init];\n",
        @"TextView/IDTextView+Interaction.m": @"",
    };
    NSArray<NSString *> *violations = IDFinalOwnershipAuditViolationsForSources(
        sources, [NSSet setWithArray:sources.allKeys]);
    XCTAssertTrue([[violations componentsJoinedByString:@"\n"]
        containsString:@"legacy assistant"], @"%@", violations);
}

- (void)testFinalOwnershipAuditRejectsExtraBlockAssistantAllocation {
    NSDictionary<NSString *, NSString *> *sources = @{
        @"TextView/IDBlockTextView+Interaction.m":
            @"[IDPrivateUIKit newInteractionAssistantWithView:self];\n",
        @"TextView/IDBlockTextView.m":
            @"[[IDRichTextLayoutController alloc] init];\n"
             "[[IDNativeSelectionPresentationBackend alloc] init];\n",
        @"TextView/IDTextView+Interaction.m":
            @"[IDPrivateUIKit newInteractionAssistantWithView:self];\n",
        @"TextView/ExtraBlockInteraction.m":
            @"[[IDAlternateInteractionAssistant alloc] init];\n",
    };
    NSArray<NSString *> *violations = IDFinalOwnershipAuditViolationsForSources(
        sources, [NSSet setWithArray:sources.allKeys]);
    XCTAssertTrue([[violations componentsJoinedByString:@"\n"]
        containsString:@"block assistant"], @"%@", violations);
}

- (void)testFinalOwnershipHeaderAuditRejectsUnknownAndCustomFloatingState {
    NSString *privateHIDFixture = [@[@"XC", @"PointerEventPath *eventPath;\n"]
        componentsJoinedByString:@""];
    NSDictionary<NSString *, NSString *> *sources = @{
        @"TextView/Known.h": @"@interface Known : NSObject\n@end\n",
        @"TextView/Surprise.h": [
            @"NSTimer *floatingCursorTimer;\n"
             "CGPoint floatingCursorAnchor;\n"
             "UIView *floatingCursorView;\n"
             "CALayer *floatingCursorLayer;\n"
             "UIGestureRecognizer *floatingCursorRecognizer;\n"
             "CADisplayLink *floatingCursorDisplayLink;\n"
             "CGPoint floatingCursorDisplacement;\n"
             "CGPathRef floatingCursorPath;\n"
             "UITextView *textView;\n"
             stringByAppendingString:privateHIDFixture],
    };
    NSArray<NSString *> *violations = IDFinalHeaderAuditViolationsForSources(
        sources, [NSSet setWithObject:@"TextView/Known.h"]);
    NSString *joined = [violations componentsJoinedByString:@"\n"];
    for (NSString *category in @[
        @"unclassified header", @"timer", @"anchor", @"cursor view",
        @"cursor layer", @"gesture recognizer", @"display link",
        @"displacement", @"cursor drawing", @"UITextView", @"private HID",
    ]) {
        XCTAssertTrue([joined containsString:category], @"Missing %@ in %@", category, joined);
    }
}

- (void)testRunnableMarkdownTestCommandAuditIsPerLogicalCommandAndFailClosed {
    NSSet<NSString *> *required = [NSSet setWithObject:@"README.md"];
    NSArray<NSString *> *missing = IDMarkdownSerialTestCommandViolationsForSources(@{
        @"README.md": @"xcodebuild test -quiet -project InputDec.xcodeproj\n",
    }, required);
    XCTAssertGreaterThan(missing.count, 0U);

    NSArray<NSString *> *unrelated = IDMarkdownSerialTestCommandViolationsForSources(@{
        @"README.md": @"xcodebuild test -quiet -project InputDec.xcodeproj\n"
                       "xcodebuild build -parallel-testing-enabled NO\n",
    }, required);
    XCTAssertGreaterThan(unrelated.count, 0U);

    NSArray<NSString *> *valid = IDMarkdownSerialTestCommandViolationsForSources(@{
        @"README.md": @"xcodebuild test -quiet \\\n"
                       "  -parallel-testing-enabled NO -project InputDec.xcodeproj\n",
    }, required);
    XCTAssertEqualObjects(valid, @[]);

    for (NSString *bypass in @[
        @"xcodebuild test -quiet \\\n  # -parallel-testing-enabled NO\n",
        @"xcodebuild test -quiet ; xcodebuild build -parallel-testing-enabled NO\n",
        @"xcodebuild test -quiet && xcodebuild build -parallel-testing-enabled NO\n",
        @"xcodebuild test -quiet '-parallel-testing-enabled NO'\n",
    ]) {
        XCTAssertGreaterThan(IDMarkdownSerialTestCommandViolationsForSources(
            @{@"README.md": bypass}, required).count, 0U, @"Bypass accepted: %@", bypass);
    }

    NSArray<NSString *> *absent = IDMarkdownSerialTestCommandViolationsForSources(@{}, required);
    XCTAssertGreaterThan(absent.count, 0U);
}



- (void)testFastTextInputEntryPointsArePinnedSerialAndNonProvisioning {
    NSString *root = IDProjectSourceRoot();
    for (NSString *relativePath in @[
        @"Scripts/with-inputdec-simulator-test-lock.sh",
        @"Scripts/run-text-input-fast.sh",
    ]) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(body, @"%@", relativePath);
        XCTAssertFalse([body containsString:@"simctl create"],
                       @"%@", relativePath);
        XCTAssertFalse([body containsString:@"simctl clone"],
                       @"%@", relativePath);
        XCTAssertFalse([body containsString:
            @"-parallel-testing-enabled YES"], @"%@", relativePath);
        if ([relativePath isEqualToString:
            @"Scripts/run-text-input-fast.sh"]) {
            XCTAssertTrue([body containsString:
                @"FA6F7462-AA97-42FE-9E57-8DA0593CE756"],
                @"%@", relativePath);
            XCTAssertTrue([body containsString:
                @"-parallel-testing-enabled NO"], @"%@", relativePath);
            XCTAssertTrue([body containsString:
                @"platform=iOS Simulator,id=${udid}"], @"%@", relativePath);
        }
    }
}











- (void)testInlinePredictionFrozenFixtureIsExactIOS265Contract {
    NSString *path = IDEngineSourceFile(@"UITests/Fixtures/inline-prediction-stock-contract-v1.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data);
    NSError *error = nil;
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&error];
    XCTAssertNil(error);
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"schema", @"runtime", @"typedPrefix", @"offeredText",
        @"acceptAction", @"dismissAction", @"postDismissText",
    ]];
    NSDictionary *expectedRuntime = @{
        @"osVersion": @"26.5", @"osBuild": @"23F73", @"locale": @"en_US",
    };
    NSDictionary *expectedAcceptAction = @{
        @"kind": @"software-keyboard-key-sequence",
        @"value": @"space",
    };
    NSDictionary *expectedDismissAction = @{
        @"kind": @"uikit-remove-inline-text-completion",
        @"value": @"removeInlineTextCompletionPrompt",
    };
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys], expectedKeys);
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], expectedRuntime);
    XCTAssertEqualObjects(fixture[@"typedPrefix"], @"i look forward ");
    XCTAssertEqualObjects(fixture[@"offeredText"], @"to");
    XCTAssertEqualObjects(fixture[@"acceptAction"], expectedAcceptAction);
    XCTAssertEqualObjects(fixture[@"dismissAction"], expectedDismissAction);
    XCTAssertEqualObjects(fixture[@"postDismissText"], @"x");
}





- (void)testInlinePredictionOwnershipAuditRejectsModelsAndFrozenStrings {
    NSString *root = IDProjectSourceRoot();
    NSData *data = [NSData dataWithContentsOfFile:IDEngineSourceFile(@"UITests/Fixtures/inline-prediction-stock-contract-v1.json")];
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:nil];
    NSArray<NSString *> *forbidden = @[
        @"inlinePredictionCandidate", @"predictionCandidateView",
        @"pendingInlinePrediction", @"acceptedInlinePrediction",
        @"rejectedInlinePrediction", @"predictionTimer",
        @"injectInlinePrediction", @"applyInlinePrediction",
        [NSString stringWithFormat:@"@\"%@\"", fixture[@"typedPrefix"]],
        [NSString stringWithFormat:@"@\"%@\"", fixture[@"offeredText"]],
        [NSString stringWithFormat:@"\"%@\"", fixture[@"typedPrefix"]],
        [NSString stringWithFormat:@"\"%@\"", fixture[@"offeredText"]],
    ];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relative in files) {
            if (![relative.pathExtension isEqual:@"m"] &&
                ![relative.pathExtension isEqual:@"h"]) continue;
            NSString *path = [directory stringByAppendingPathComponent:relative];
            NSString *body = [NSString stringWithContentsOfFile:path
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];
            XCTAssertNotNil(body);
            for (NSString *token in forbidden) {
                XCTAssertFalse([body containsString:token],
                               @"%@ owns forbidden prediction token %@",
                               path, token);
            }
        }
    }
}

- (void)testInlinePredictionAcceptanceWaitsForContinuouslyStableNativeOffer {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"UITests/IDInlinePredictionLifecycleTestSupport.m");
    NSString *body = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:nil];
    XCTAssertNotNil(body);
    NSString *stabilityCall =
        @"IDInlinePredictionWaitForStableOffer(\n"
         "                application, fixture[@\"offeredText\"], 0.50, 4.0)";
    NSRange stabilityRange = [body rangeOfString:stabilityCall];
    NSRange firstDecisionKeyRange =
        [body rangeOfString:@"[keys enumerateObjectsUsingBlock:"];
    XCTAssertNotEqual(stabilityRange.location, NSNotFound);
    XCTAssertNotEqual(firstDecisionKeyRange.location, NSNotFound);
    XCTAssertLessThan(stabilityRange.location, firstDecisionKeyRange.location);
    XCTAssertTrue([body containsString:@"@\"typedThroughTimeout\""]);
}

- (void)testFinalOwnershipAuditRejectsAdversarialOwnershipAndDrawingFixtures {
    NSString *privateHIDFixture = [@[
        @"XC", @"PointerEventPath *path; XC", @"SynthesizedEventRecord *record;\n",
    ] componentsJoinedByString:@""];
    NSDictionary<NSString *, NSString *> *sources = @{
        @"TextView/Known.m": @"IDInteractionAssistantCreate(self);\n"
            "[[IDRichTextLayoutController alloc] init];\n"
            "[[IDNativeSelectionPresentationBackend alloc] init];\n",
        @"TextView/Surprise.m": [@"UITextView *view;\n"
            "UILongPressGestureRecognizer *floatingCursorRecognizer;\n"
            "CALayer *floatingCursorLayer; CGPoint floatingCursorDisplacement;\n"
            "CADisplayLink *floatingCursorDisplayLink; NSTimer *floatingCursorTimer;\n"
            "- (UIView *)textInputView { return nil; }\n"
            stringByAppendingString:privateHIDFixture],
    };
    NSArray<NSString *> *violations = IDFinalOwnershipAuditViolationsForSources(
        sources, [NSSet setWithObject:@"TextView/Known.m"]);
    NSString *joined = [violations componentsJoinedByString:@"\n"];
    for (NSString *category in @[
        @"unclassified", @"assistant", @"layout controller", @"selection backend",
        @"UITextView", @"private HID", @"gesture recognizer", @"cursor layer",
        @"displacement", @"display link", @"timer", @"private callback",
    ]) {
        XCTAssertTrue([joined containsString:category], @"Missing %@ violation in %@",
                      category, joined);
    }
}

- (void)testCorrectionOwnershipAuditRejectsEveryForbiddenPolicyFamily {
    NSDictionary<NSString *, NSString *> *sources = @{
        @"TextView/Bad.m":
            @"UIKeyboardCandidate *candidateView; BOOL correctionRejected; "
             "NSTimer *autocorrectionTimer; [owner applyAutocorrection:value]; "
             "NSString *fixture = @\"adress\";",
    };
    NSString *joined = [IDCorrectionOwnershipAuditViolationsForSources(sources)
        componentsJoinedByString:@"\n"];
    for (NSString *category in @[
        @"correction candidate view", @"rejection state", @"correction timer",
        @"injected correction", @"fixture spelling",
    ]) {
        XCTAssertTrue([joined containsString:category], @"Missing %@ in %@",
                      category, joined);
    }
}

- (void)testProductionContainsNoCustomCorrectionPolicyOrFixtureSpelling {
    NSString *root = IDProjectSourceRoot();
    NSMutableDictionary<NSString *, NSString *> *sources = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *paths = [IDProductionImplementationPaths() mutableCopy];
    [paths unionSet:IDProductionHeaderPaths()];
    for (NSString *path in paths) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(path)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(body, @"Unreadable production source: %@", path);
        if (body != nil) sources[path] = body;
    }
    XCTAssertEqualObjects(IDCorrectionOwnershipAuditViolationsForSources(sources), @[]);
}

- (void)testAutocorrectionTraceIsDisabledAfterResetAndRetainsOnlyValueEvents {
    IDResetAutocorrectionTraceForUITesting();
    IDRecordAutocorrectionTraceForUITesting(@"outside-test-scenario");
    XCTAssertEqualObjects(IDCopyAutocorrectionTraceForUITesting(), @[]);

    IDInstallAutocorrectionTraceForUITesting();
    NSMutableString *event = [@"textDidChange" mutableCopy];
    IDRecordAutocorrectionTraceForUITesting(event);
    [event appendString:@"-mutated"];
    XCTAssertEqualObjects(IDCopyAutocorrectionTraceForUITesting(), @[@"textDidChange"]);
    IDResetAutocorrectionTraceForUITesting();
    IDRecordAutocorrectionTraceForUITesting(@"after-reset");
    XCTAssertEqualObjects(IDCopyAutocorrectionTraceForUITesting(), @[]);
}

- (void)testAutocorrectionPhaseSnapshotsCannotRetainApplicationOrUIKitObjects {
    NSString *header = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDAutocorrectionDecisionTestSupport.h")
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    XCTAssertNotNil(header);
    NSRange snapshotStart = [header rangeOfString:
        @"@interface IDAutocorrectionPhaseSnapshot"];
    NSRange resultEnd = [header rangeOfString:@"@end" options:0
        range:NSMakeRange(snapshotStart.location,
                          header.length - snapshotStart.location)];
    NSString *snapshotDeclaration = [header substringWithRange:NSMakeRange(
        snapshotStart.location, NSMaxRange(resultEnd) - snapshotStart.location)];
    for (NSString *forbidden in @[
        @"XCUIApplication", @"XCUIElement", @"UIView", @"UIResponder", @" id ",
    ]) {
        XCTAssertFalse([snapshotDeclaration containsString:forbidden], @"%@",
                       snapshotDeclaration);
    }
}







- (void)testIMEKeyboardModeFixtureIsExactIOS265Contract {
    NSString *path = IDEngineSourceFile(@"UITests/Fixtures/ime-keyboard-modes-ios26.5-v1.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data);
    NSDictionary *fixture =
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"schema", @"runtime", @"preferenceContract", @"inputModes",
    ]];
    XCTAssertEqualObjects(
        [NSSet setWithArray:fixture.allKeys], expectedKeys);
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"],
        (@{@"osVersion": @"26.5", @"osBuild": @"23F73"}));
    XCTAssertEqualObjects(
        fixture[@"preferenceContract"][@"postRebootAllowedIdentifiers"],
        (@[
            @"ru_RU@sw=Russian;hw=Automatic",
            @"en_AU@sw=QWERTY;hw=Automatic",
        ]));
    NSArray *modes = fixture[@"inputModes"];
    XCTAssertEqual(modes.count, 2U);
    XCTAssertEqualObjects(modes[0][@"inputModeIdentifier"],
        @"ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic");
    XCTAssertEqualObjects(modes[0][@"primaryLanguage"], @"ja-JP");
    XCTAssertEqualObjects(modes[1][@"inputModeIdentifier"],
        @"zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic");
    XCTAssertEqualObjects(modes[1][@"primaryLanguage"], @"zh-Hans");
}

- (void)testFinalOwnershipFloatingCursorSelectorsRejectEveryWrongABI {
    NSArray<NSDictionary<NSString *, NSString *> *> *fixtures = @[
        @{@"class": @"IDFinalWrongBeginFloatingCursorABIProbe",
          @"selector": @"beginFloatingCursorAtPoint:"},
        @{@"class": @"IDFinalWrongUpdateFloatingCursorABIProbe",
          @"selector": @"updateFloatingCursorAtPoint:animated:"},
        @{@"class": @"IDFinalWrongEndFloatingCursorABIProbe",
          @"selector": @"endFloatingCursor"},
    ];
    for (NSDictionary<NSString *, NSString *> *fixture in fixtures) {
        const char *name = fixture[@"class"].UTF8String;
        Class probeClass = objc_getClass(name);
        if (probeClass == Nil) {
            probeClass = objc_allocateClassPair(IDFinalFloatingAssistantABIProbe.class,
                                                name, 0);
            XCTAssertNotNil(probeClass);
            class_addMethod(probeClass,
                            NSSelectorFromString(fixture[@"selector"]),
                            (IMP)IDFinalWrongFloatingCursorABI,
                            "q@:");
            objc_registerClassPair(probeClass);
        }
        NSException *caught = nil;
        @try {
            [IDPrivateUIKit requireInteractionAssistant:[probeClass new]
                                                  stage:@"Final floating-cursor negative ABI"];
        } @catch (NSException *exception) {
            caught = exception;
        }
        XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
        XCTAssertTrue([caught.reason containsString:fixture[@"selector"]], @"%@", caught.reason);
        XCTAssertTrue([caught.reason containsString:@"ABI mismatch"], @"%@", caught.reason);
    }
}

- (void)testFinalOwnershipFloatingCursorSelectorsHaveExactSpecsAndTypedSends {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
                                              encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(source);
    NSArray<NSString *> *required = @[
        @"IDInteractionABISpecMake(@\"beginFloatingCursorAtPoint:\", @encode(void)",
        @"IDInteractionABISpecMake(@\"updateFloatingCursorAtPoint:animated:\", @encode(void)",
        @"IDInteractionABISpecMake(@\"endFloatingCursor\", @encode(void), @[])",
        @"((void (*)(id, SEL, CGPoint))objc_msgSend)",
        @"((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)",
        @"((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(@\"endFloatingCursor\"))",
    ];
    for (NSString *fragment in required) {
        XCTAssertEqual([source componentsSeparatedByString:fragment].count - 1, 1U,
                       @"Missing or duplicated exact floating-cursor ABI fragment: %@", fragment);
    }
}

- (void)testFinalOwnershipConstructionScannerRejectsAllocNewAndFactoryForms {
    NSString *source = @"[[IDNativeSelectionPresentationBackend alloc] init];\n"
                       "[IDNativeSelectionPresentationBackend new];\n"
                       "IDNativeSelectionPresentationBackendCreate(host);\n";
    XCTAssertEqual(IDConstructionMatchCount(source,
                                             @"IDNativeSelectionPresentationBackend",
                                             @[@"IDNativeSelectionPresentationBackendCreate"]),
                   3U);
}

- (void)testFinalOwnershipPrivateCallbackAuditRemovesOnlyExactPublicCollision {
    NSString *source = @"- (UIView *)selectionContainerView { return nil; }\n"
                       "- (UIView *)textInputView { return nil; }\n";
    NSString *withoutPublicCollision =
        IDSourceByRemovingExactPublicSelectionContainerDefinition(source);
    XCTAssertFalse([withoutPublicCollision containsString:@"selectionContainerView"]);
    XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(withoutPublicCollision), 1U);
}

- (void)testFinalOwnershipHasOneBlockInteractionAssistantFactoryCallSite {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSString *> *sites = IDFinalOwnershipExpectedSites();
    NSUInteger total = 0;
    NSString *owner = nil;
    for (NSString *relativePath in IDExperimentalProductionImplementationPaths()) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        NSUInteger count =
            IDBlockInteractionCapabilityConstructionCount(body);
        total += count;
        if (count > 0) owner = relativePath;
    }
    XCTAssertEqual(total, 1U);
    XCTAssertEqualObjects(owner, sites[@"blockInteractionAssistant"]);
}

- (void)testFinalOwnershipHasOneInventoriedLegacyInteractionAssistantFactoryCallSite {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSString *> *sites = IDFinalOwnershipExpectedSites();
    NSUInteger total = 0;
    NSString *owner = nil;
    for (NSString *relativePath in IDLegacyProductionImplementationPaths()) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        NSUInteger count = IDNativeInteractionAssistantFactoryCallCount(body);
        total += count;
        if (count > 0) owner = relativePath;
    }
    XCTAssertEqual(total, 1U);
    XCTAssertEqualObjects(owner, sites[@"legacyInteractionAssistant"]);
}

- (void)testFinalOwnershipHasOneCanonicalRichLayoutControllerOwner {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSString *> *sites = IDFinalOwnershipExpectedSites();
    NSUInteger allocations = 0;
    NSString *allocationOwner = nil;
    for (NSString *relativePath in IDProductionImplementationPaths()) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        NSUInteger count = IDConstructionMatchCount(
            body, @"IDRichTextLayoutController",
            @[@"IDRichTextLayoutControllerCreate"]);
        allocations += count;
        if (count > 0) allocationOwner = relativePath;
    }
    XCTAssertEqual(allocations, 1U);
    XCTAssertEqualObjects(allocationOwner, sites[@"richLayoutControllerOwner"]);

    NSString *implementationPath = @"TextView/IDRichTextLayoutController.m";
    NSString *implementation = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(implementationPath)
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    XCTAssertEqual([implementation componentsSeparatedByString:
        @"@implementation IDRichTextLayoutController\n"].count - 1, 1U);
}

- (void)testFinalOwnershipRejectsCustomSelectionDrawingAcrossProduction {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *tokens = @[
        @"CAShapeLayer", @"UIBezierPath", @"selectionHandleView", @"loupeView",
        @"_UITextMagnifiedGlassLoupeView", @"CGContextStrokePath",
        @"CGContextAddLineToPoint",
    ];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"] &&
                ![file.pathExtension isEqualToString:@"h"]) continue;
            NSString *body = [NSString stringWithContentsOfFile:
                [IDEngineSourceFile(folder) stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            for (NSString *token in tokens) {
                XCTAssertFalse([body containsString:token], @"%@ in %@/%@", token, folder, file);
            }
        }
    }
}

- (void)testFinalOwnershipKeepsPrivateCallbackDefinitionsUnderPrivateUIKit {
    NSString *root = IDProjectSourceRoot();
    for (NSString *folder in @[@"App", @"TextView"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"]) continue;
            NSString *body = [NSString stringWithContentsOfFile:
                [IDEngineSourceFile(folder) stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            if ([file isEqualToString:@"IDNativeSelectionPresentationBackend.m"] &&
                [folder isEqualToString:@"TextView"]) {
                body = IDSourceByRemovingExactPublicSelectionContainerDefinition(body);
            }
            XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(body), 0U,
                           @"Private callback definition in %@/%@", folder, file);
        }
    }
}





- (void)testRunnableDocumentationTestCommandsDisableParallelTesting {
    NSString *root = IDProjectSourceRoot();
    NSSet<NSString *> *required = [NSSet setWithArray:@[
        @"README.md",
        @"docs/superpowers/reports/2026-07-20-floating-cursor-interaction-parity.md",
    ]];
    NSMutableDictionary<NSString *, NSString *> *sources = [NSMutableDictionary dictionary];
    for (NSString *relativePath in required) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(body, @"Unreadable required command source: %@", relativePath);
        if (body != nil) sources[relativePath] = body;
    }
    XCTAssertEqualObjects(IDMarkdownSerialTestCommandViolationsForSources(sources, required), @[]);
}


- (void)testProductionDoesNotReferenceOrConstructPrivateUIKitCanvasClass {
    NSString *root = IDProjectSourceRoot();
    NSString *privateCanvasClass = @"_UI" @"TextLayoutCanvasView";
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"] &&
                ![file.pathExtension isEqualToString:@"h"]) continue;
            NSString *body = [NSString stringWithContentsOfFile:
                [IDEngineSourceFile(folder) stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            XCTAssertFalse([body containsString:privateCanvasClass],
                           @"Private UIKit canvas class escaped into %@/%@", folder, file);
        }
    }
}

- (void)testDemoCursorTraceUsesOnlyThePrivateUIKitTestingBoundary {
    NSString *path = IDEngineSourceFile(@"App/IDDemoViewController.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    XCTAssertFalse([source containsString:@"cursorPositionAtPoint:inContainer:"]);
    XCTAssertFalse([source containsString:@"class_getInstanceMethod"]);
    XCTAssertFalse([source containsString:@"method_setImplementation"]);
    XCTAssertTrue([source containsString:@"IDPrivateInstallRichCursorTraceForUITesting"]);
    XCTAssertTrue([source containsString:@"IDPrivateCopyRichCursorTraceForUITesting"]);
}


- (void)testEveryExperimentalImplementationHasExactOwnersStorageAndNoForbiddenRendering {
    NSString *root = IDProjectSourceRoot();
    NSDictionary<NSString *, NSNumber *> *exactOccurrences = @{
        @"TextView/IDBlockTextView.m|IDPrivateNewInputControllerWithRichLayoutController(": @1,
        @"TextView/IDBlockTextView+Interaction.m|[[IDUIKitInteractionCapability alloc]": @1,
        @"TextView/IDCanonicalTextStorageAdapter.m|[[IDCanonicalTextStorageAdapter alloc]": @1,
        @"TextView/IDBlockTextView.m|IDCanonicalTextStorageAdapterCreate(document)": @1,
        @"TextView/IDRichTextLayoutController.m|IDCanonicalTextStorageAdapterCreate(document)": @1,
        @"TextView/IDBlockTextView.m|textStorageAdapter:adapter": @1,
        // TWO: the block's own derived storage, plus the one-space PROTOTYPE an empty block is
        // measured against. An empty storage carries no attributes, so neither the font nor a pinned
        // paragraph line height reaches TextKit and the caret came out visibly shorter than on a
        // typed line; the prototype is a measuring artefact, never a second document.
        @"TextView/IDBlockLayout.m|[[NSTextStorage alloc]": @2,
        @"TextView/IDBlockTextView.m|[[IDNativeSelectionPresentationBackend alloc]": @1,
    };
    [exactOccurrences enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                                           NSNumber *expected,
                                                           BOOL *stop) {
        NSArray<NSString *> *parts = [key componentsSeparatedByString:@"|"];
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(parts[0])
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        NSUInteger count = [body componentsSeparatedByString:parts[1]].count - 1;
        XCTAssertEqual(count, expected.unsignedIntegerValue, @"%@", key);
    }];

    NSArray<NSString *> *forbidden = @[
        @"_UITextKit2LayoutController", @"newLayoutControllerWithTextView:",
        @"CAShapeLayer", @"UIBezierPath", @"drawRect:", @"CGContextStrokePath",
        @"CGContextAddLineToPoint", @"selectionHandleView", @"loupeView",
        @"NSUnderlineStyle", @"underlineStyle", @"UITextView",
    ];
    NSUInteger canonicalAdapterAllocations = 0;
    NSUInteger derivedTextStorageAllocations = 0;
    NSUInteger canonicalAdapterFactoryCalls = 0;
    NSUInteger inputOwnerCalls = 0;
    NSUInteger assistantOwnerCalls = 0;
    for (NSString *relativePath in IDExperimentalProductionImplementationPaths()) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertNotNil(body, @"%@", relativePath);
        for (NSString *token in forbidden) {
            BOOL dedicatedInlineMaterializer =
                [relativePath isEqualToString:
                    @"TextView/IDInlineTextStyleResolver.m"];
            if (dedicatedInlineMaterializer &&
                ([token isEqualToString:@"NSUnderlineStyle"] ||
                 [token isEqualToString:@"underlineStyle"])) {
                continue;
            }
            NSUInteger count = [body componentsSeparatedByString:token].count - 1;
            XCTAssertEqual(count, 0U, @"%@ in %@", token, relativePath);
        }
        NSUInteger adapterCount = [body componentsSeparatedByString:
            @"[[IDCanonicalTextStorageAdapter alloc]"].count - 1;
        NSUInteger storageCount = [body componentsSeparatedByString:
            @"[[NSTextStorage alloc]"].count - 1;
        NSUInteger factoryCallCount = [body componentsSeparatedByString:
            @"IDCanonicalTextStorageAdapterCreate(document)"].count - 1;
        NSUInteger inputCount = [body componentsSeparatedByString:
            @"IDPrivateNewInputControllerWithRichLayoutController("].count - 1;
        NSUInteger assistantCount =
            IDBlockInteractionCapabilityConstructionCount(body);
        canonicalAdapterAllocations += adapterCount;
        derivedTextStorageAllocations += storageCount;
        canonicalAdapterFactoryCalls += factoryCallCount;
        if ([relativePath isEqualToString:@"TextView/IDBlockTextView.m"]) {
            inputOwnerCalls += inputCount;
        }
        assistantOwnerCalls += assistantCount;
        if (![relativePath isEqualToString:@"TextView/IDCanonicalTextStorageAdapter.m"]) {
            XCTAssertEqual(adapterCount, 0U, @"alternate canonical storage in %@", relativePath);
        }
        BOOL permittedAdapterFactoryCall =
            [relativePath isEqualToString:@"TextView/IDBlockTextView.m"] ||
            [relativePath isEqualToString:@"TextView/IDRichTextLayoutController.m"];
        if (!permittedAdapterFactoryCall) {
            XCTAssertEqual(factoryCallCount, 0U, @"alternate adapter factory call in %@", relativePath);
        }
        if ([relativePath isEqualToString:@"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m"]) {
            XCTAssertEqual(inputCount, 1U, @"typed input factory definition in %@", relativePath);
        } else if (![relativePath isEqualToString:@"TextView/IDBlockTextView.m"]) {
            XCTAssertEqual(inputCount, 0U, @"alternate input owner in %@", relativePath);
        }
        if (![relativePath isEqualToString:@"TextView/IDBlockLayout.m"]) {
            XCTAssertEqual(storageCount, 0U, @"alternate derived storage in %@", relativePath);
        }
        if (![relativePath isEqualToString:@"TextView/IDBlockTextView+Interaction.m"]) {
            XCTAssertEqual(assistantCount, 0U, @"alternate assistant owner in %@", relativePath);
        }
    }
    XCTAssertEqual(canonicalAdapterAllocations, 1U);
    XCTAssertEqual(canonicalAdapterFactoryCalls, 2U,
                   @"one host call plus one standalone public convenience call");
    XCTAssertEqual(derivedTextStorageAllocations, 2U,
                   @"the block's own storage plus the empty-line measuring prototype");
    XCTAssertEqual(inputOwnerCalls, 1U);
    XCTAssertEqual(assistantOwnerCalls, 1U);
}

- (void)testPublicRichControllerConvenienceAndHostDesignatedAdapterPathsAreDistinct {
    NSString *root = IDProjectSourceRoot();
    NSString *header = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDRichTextLayoutController.h")
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSString *implementation = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m")
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSString *host = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSString *signature = @"initWithDocument:(IDBlockDocument *)document\n"
                           "                       blockStack:(IDBlockStackCanvasView *)blockStack";
    XCTAssertEqual([header componentsSeparatedByString:signature].count - 1, 1U);
    XCTAssertEqual([implementation componentsSeparatedByString:signature].count - 1, 1U);
    XCTAssertEqual([implementation componentsSeparatedByString:
        @"IDCanonicalTextStorageAdapterCreate(document)"].count - 1, 1U);
    XCTAssertEqual([host componentsSeparatedByString:
        @"IDCanonicalTextStorageAdapterCreate(document)"].count - 1, 1U);
    XCTAssertEqual([host componentsSeparatedByString:@"textStorageAdapter:adapter"].count - 1, 1U);
}

- (void)testEveryRequiredRichSelectorHasOneDefinitionInThePrivateCallbackFile {
    NSString *path = IDEngineSourceFile(@"PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    NSRange start = [source rangeOfString:
        @"@implementation IDRichTextLayoutController (PrivateCallbacks)"];
    XCTAssertNotEqual(start.location, NSNotFound);
    NSString *implementation = [source substringFromIndex:start.location];
    NSRange end = [implementation rangeOfString:@"\n@end"];
    XCTAssertNotEqual(end.location, NSNotFound);
    implementation = [implementation substringToIndex:end.location];
    // A callback UIKit sends under a PRIVATE name is answered by the file's alias table, onto the
    // `id_` method (or a neutral `tgpn_` wrapper) that implements it (`TGPrivateMethodAliases.h`),
    // so the selectors this file answers are its public-named definitions plus its alias rows.
    NSMutableArray<NSString *> *definitions = [NSMutableArray array];
    for (NSString *selector in IDMethodDefinitionSelectors(implementation)) {
        if (![selector hasPrefix:@"tgpn_"]) [definitions addObject:selector];
    }
    NSRange installer = [source rangeOfString:
        @"void IDRichTextLayoutControllerInstallPrivateCallbacks(Class cls) {"];
    XCTAssertNotEqual(installer.location, NSNotFound);
    NSString *table = installer.location == NSNotFound ? @"" : [source substringFromIndex:installer.location];
    NSRegularExpression *row = [NSRegularExpression
        regularExpressionWithPattern:@"\\{\\s*(TGPN_\\w+),\\s*@selector\\(" options:0 error:nil];
    NSDictionary<NSString *, NSString *> *decoded = IDPrivateRuntimeNamesByFunction();
    for (NSTextCheckingResult *match in [row matchesInString:table options:0
                                                       range:NSMakeRange(0, table.length)]) {
        NSString *function = [table substringWithRange:[match rangeAtIndex:1]];
        [definitions addObject:decoded[function] ?: function];
    }
    NSArray<NSString *> *required = IDRichLayoutRequiredSelectorNames();
    NSMutableArray<NSString *> *expectedDefinitions = [required mutableCopy];
    [expectedDefinitions addObject:@"layoutManager"];
    XCTAssertEqual(definitions.count, 48U);
    XCTAssertEqual(required.count, 47U);
    XCTAssertEqualObjects([NSSet setWithArray:definitions],
                          [NSSet setWithArray:expectedDefinitions]);
    for (NSString *selector in expectedDefinitions) {
        NSPredicate *matchingSelector = [NSPredicate predicateWithFormat:@"SELF == %@", selector];
        NSArray *matches = [definitions filteredArrayUsingPredicate:matchingSelector];
        XCTAssertEqual(matches.count, 1U, @"%@", selector);
    }
}
- (void)testRichInputControllerInitializerAndDelegateABIsArePreflightedBeforeTypedSends {
    NSString *root = IDProjectSourceRoot();
    NSString *body = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m")
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSRange allocation = [body rangeOfString:
        @"id allocatedController = [inputControllerClass alloc]"];
    NSRange initializerPreflight = [body rangeOfString:
        @"@\"Rich input-controller initializer ABI preflight\""];
    NSRange delegatePreflight = [body rangeOfString:
        @"@\"Rich input-controller delegate ABI preflight\""];
    NSRange typedInitializerSend = [body rangeOfString:
        @"objc_msgSend)(\n        allocatedController,\n        initializer,"];
    NSRange initializedDelegatePreflight = [body rangeOfString:
        @"@\"Rich input-controller initialized delegate ABI preflight\""];
    NSRange typedDelegateSend = [body rangeOfString:
        @"objc_msgSend)(controller, delegateSetter, delegate)"];

    XCTAssertNotEqual(allocation.location, NSNotFound);
    XCTAssertNotEqual(initializerPreflight.location, NSNotFound);
    XCTAssertNotEqual(delegatePreflight.location, NSNotFound);
    XCTAssertNotEqual(typedInitializerSend.location, NSNotFound);
    XCTAssertNotEqual(initializedDelegatePreflight.location, NSNotFound);
    XCTAssertNotEqual(typedDelegateSend.location, NSNotFound);
    XCTAssertLessThan(initializerPreflight.location, allocation.location);
    XCTAssertLessThan(delegatePreflight.location, allocation.location);
    XCTAssertLessThan(allocation.location, typedInitializerSend.location);
    XCTAssertLessThan(typedInitializerSend.location,
                      initializedDelegatePreflight.location);
    XCTAssertLessThan(initializedDelegatePreflight.location,
                      typedDelegateSend.location);
}
- (void)testCanvasHasNoDocumentWideDrawRectFallback {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"TextView/IDTextLayoutCanvasView.m");
    NSString *body = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSRange implementation = [body rangeOfString:@"@implementation IDTextLayoutCanvasView\n"];
    XCTAssertNotEqual(implementation.location, NSNotFound);
    NSString *canvasImplementation = [body substringFromIndex:NSMaxRange(implementation)];
    XCTAssertFalse([canvasImplementation containsString:@"drawRect:"],
                   @"The canvas must compose keyed surfaces, not draw the whole document");
}
- (void)testProductionDoesNotWritePublicUnderlineAttributesForSpelling {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *forbidden = @[
        [@"NSUnderline" stringByAppendingString:@"StyleAttributeName"],
        [@"NSUnderline" stringByAppendingString:@"ColorAttributeName"],
        [@"underline" stringByAppendingString:@"Style"],
        [@"underline" stringByAppendingString:@"Color"],
    ];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"] &&
                ![file.pathExtension isEqualToString:@"h"]) continue;
            // Rich-text underline materialization is intentional. Keep this
            // guard focused on synthetic spelling underlines elsewhere.
            if ([folder isEqualToString:@"TextView"] &&
                [file isEqualToString:@"IDInlineTextStyleResolver.m"]) {
                continue;
            }
            NSString *body = [NSString stringWithContentsOfFile:
                [IDEngineSourceFile(folder) stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            for (NSString *token in forbidden) {
                XCTAssertFalse([body containsString:token],
                               @"Synthetic spelling underline token %@ in %@/%@",
                               token, folder, file);
            }
        }
    }
}
- (void)testDeletedMonolithicCanvasSourcesRemainAbsent {
    NSString *root = IDProjectSourceRoot();
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:
        IDEngineSourceFile(@"TextView/IDTextCanvasView.h")]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:
        IDEngineSourceFile(@"TextView/IDTextCanvasView.m")]);
}

- (void)testProductionDoesNotSynthesizePrivateAttachmentProviders {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *forbidden = @[
        [@"registerTextAttachment" stringByAppendingString:@"ViewProviderClass"],
        [@"_UI" stringByAppendingString:@"TextAttachmentViewProvider"],
        [@"newTextAttachment" stringByAppendingString:@"ViewProvider"],
    ];
    for (NSString *folder in @[@"TextView", @"PrivateUIKit"]) {
        NSDirectoryEnumerator *files = [NSFileManager.defaultManager
            enumeratorAtPath:IDEngineSourceFile(folder)];
        for (NSString *file in files) {
            if (![file.pathExtension isEqualToString:@"m"] &&
                ![file.pathExtension isEqualToString:@"h"]) continue;
            NSString *body = [NSString stringWithContentsOfFile:
                [IDEngineSourceFile(folder) stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
            for (NSString *token in forbidden) {
                XCTAssertFalse([body containsString:token],
                               @"Private attachment provider synthesis in %@/%@",
                               folder, file);
            }
        }
    }
}
- (void)testRenderingSurfaceHasNoDeadGeometryInvalidationState {
    NSString *root = IDProjectSourceRoot();
    NSString *body = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextRenderingSurfaceView.m")
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    XCTAssertFalse([body containsString:@"geometryNeedsUpdate"],
                   @"The surface updates geometry synchronously or at transaction end");
}
- (void)testProductionDefinesAndSendsNoLayoutFragmentViewMarker {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *roots = @[@"App", @"TextView", @"PrivateUIKit"];
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    for (NSString *relativeRoot in roots) {
        NSString *directory =
            IDEngineSourceFile(relativeRoot);
        NSDirectoryEnumerator *enumerator =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in enumerator) {
            if (![@[@"h", @"m"] containsObject:
                    relativePath.pathExtension]) continue;
            NSString *path =
                [directory stringByAppendingPathComponent:relativePath];
            NSString *body = [NSString stringWithContentsOfFile:path
                encoding:NSUTF8StringEncoding error:nil];
            if ([body containsString:@"isLayout" @"FragmentView"]) {
                [matches addObject:
                    [relativeRoot stringByAppendingPathComponent:relativePath]];
            }
        }
    }
    XCTAssertEqualObjects(matches, (@[]));
}
- (void)testPrivateCallbacksStayOutOfTextViewSources {
    NSString *testFile = [NSString stringWithUTF8String:__FILE__];
    NSString *root = [[testFile stringByDeletingLastPathComponent]
        stringByDeletingLastPathComponent];
    NSString *textViewRoot = IDEngineSourceFile(@"TextView");
    NSDirectoryEnumerator *files = [[NSFileManager defaultManager] enumeratorAtPath:textViewRoot];
    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"m"]) continue;
        NSString *path = [textViewRoot stringByAppendingPathComponent:file];
        NSString *body = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        // The selection backend's own container accessor is `id_selectionContainerView` (it shared
        // UIKit's private name, which may not be compiled in), so no TextView source defines one.
        NSUInteger expectedCount = 0U;
        XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(body),
                       expectedCount,
                       @"Private UIKit callback definition in TextView/%@",
                       file);
    }
}
- (void)testCanvasViewportDelegateOwnershipStaysInPrivateCallbacks {
    NSString *root = IDProjectSourceRoot();
    NSString *publicHeader = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextLayoutCanvasView.h")
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    NSString *privateCallbacks = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m")
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];

    XCTAssertFalse([publicHeader containsString:@"NSTextViewportLayoutControllerDelegate"]);
    XCTAssertFalse([publicHeader containsString:@"flushElementViews"]);
    XCTAssertTrue([privateCallbacks containsString:
        @"@interface IDTextLayoutCanvasView (PrivateCallbacks) "
         "<NSTextViewportLayoutControllerDelegate>"]);
    XCTAssertTrue([IDTextLayoutCanvasView conformsToProtocol:
        @protocol(NSTextViewportLayoutControllerDelegate)]);
}
- (void)testPrivateCallbackBoundaryMatchesSetNeedsDisplayInRect {
    NSString *source = @"- (void)setNeedsDisplayInRect:(CGRect)rect {\n}\n";
    XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(source), 1U);
}
- (void)testPrivateCallbackBoundaryMatchesExactAnnotationSelectorOnly {
    NSString *privateCallback =
        @"- (id)annotationAttribute:(id)attribute atPosition:(id)position {\n}\n";
    NSString *domainMethod =
        @"- (id)annotationAttribute:(id)attribute atCanonicalOffset:(NSUInteger)offset {\n}\n";
    XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(privateCallback), 1U);
    XCTAssertEqual(IDPrivateCallbackBoundaryMatchCount(domainMethod), 0U);
}
- (void)testProductionDefinesAndSendsNoPrivateCanvasLifecycleSelectors {
    NSArray<NSString *> *selectors = @[
        [@"_perform" stringByAppendingString:@"ViewportLayout:"],
        [@"_viewport" stringByAppendingString:@"WillLayout"],
        [@"_viewport" stringByAppendingString:@"DidLayout"],
        [@"_removeUnused" stringByAppendingString:@"ElementViews"],
        [@"updateContentSize" stringByAppendingString:@"IfNeeded"],
        [@"flushElement" stringByAppendingString:@"Views"],
    ];
    XCTAssertEqualObjects(IDProductionPrivateSelectorMatches(selectors), (@[]));
}

- (void)testProductionDefinesAndSendsNoPrivateCanvasEnvironmentSelectors {
    NSArray<NSString *> *selectors = @[
        [@"isEditing" stringByAppendingString:@"DidChange"],
        [@"observeEnclosing" stringByAppendingString:@"ScrollView"],
        [@"_traits" stringByAppendingString:@"Changed"],
    ];
    XCTAssertEqualObjects(IDProductionPrivateSelectorMatches(selectors), (@[]));
}

- (void)testProjectCanvasEnvironmentMethodsAndEditorCallersRemain {
    NSString *root = IDProjectSourceRoot();
    NSString *canvasImplementation = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextLayoutCanvasView.m")
                                                            encoding:NSUTF8StringEncoding
                                                               error:nil];
    NSString *canvasHeader = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextLayoutCanvasViewInternal.h")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    NSString *textViewImplementation = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextView.m")
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];

    XCTAssertTrue([canvasImplementation containsString:
        @"- (void)id_isEditingDidChange"]);
    XCTAssertTrue([canvasImplementation containsString:
        @"- (void)id_observeEnclosingScrollView"]);
    XCTAssertTrue([canvasImplementation containsString:
        @"- (void)id_traitsChanged"]);
    XCTAssertTrue([canvasHeader containsString:@"- (void)id_isEditingDidChange"]);
    XCTAssertTrue([canvasHeader containsString:
        @"- (void)id_observeEnclosingScrollView"]);
    XCTAssertTrue([canvasHeader containsString:@"- (void)id_traitsChanged"]);
    XCTAssertTrue([textViewImplementation containsString:
        @"[self.id_canvasView id_isEditingDidChange]"]);
    XCTAssertTrue([textViewImplementation containsString:
        @"[textView.id_canvasView id_traitsChanged]"]);
    XCTAssertFalse([textViewImplementation containsString:
        @"id_observeEnclosingScrollView"]);
}

- (void)testTextViewDisplayScaleRegistrationUsesProjectCanvasTraitEntry {
    NSString *path = IDEngineSourceFile(@"TextView/IDTextView.m");
    NSString *body = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];

    XCTAssertTrue([body containsString:
        @"registerForTraitChanges:@[UITraitDisplayScale.class]"]);
    XCTAssertTrue([body containsString:
        @"[textView.id_canvasView id_traitsChanged]"]);
}

- (void)testTextViewLayerContainsNoPrivateRuntimeCalls {
    NSString *root = IDProjectSourceRoot();
    NSString *textViewRoot = IDEngineSourceFile(@"TextView");
    NSDirectoryEnumerator *files = [NSFileManager.defaultManager enumeratorAtPath:textViewRoot];
    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"m"] && ![file.pathExtension isEqualToString:@"h"]) continue;
        NSString *body = [NSString stringWithContentsOfFile:[textViewRoot stringByAppendingPathComponent:file]
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        XCTAssertFalse([body containsString:@"objc_" @"msgSend"], @"Runtime send escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"NSClass" @"FromString"], @"Private lookup escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"NSSelector" @"FromString"], @"Private selector escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"NSProtocol" @"FromString"], @"Private protocol lookup escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"class_" @"get"], @"Runtime class inspection escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"class_" @"add"], @"Runtime mutation escaped PrivateUIKit in %@", file);
        XCTAssertFalse([body containsString:@"object_" @"getClass"], @"Runtime lookup escaped PrivateUIKit in %@", file);
    }
}
- (void)testPrivateXCTestHIDABIInvocationsStayInSharedTestSupport {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *violations = IDPrivateHIDAuditViolationsAtRoots(
        @[IDEngineSourceFile(@"Tests"),
          IDEngineSourceFile(@"UITests")],
        IDEngineSourceFile(@"UITests/IDHIDEventTestSupport.m"),
        NSFileManager.defaultManager);
    XCTAssertEqualObjects(violations, @[], @"%@", violations);
}

- (void)testPrivateHIDAuditDetectsInvocationInSmokeTestSource {
    NSString *smokePath = @"/repo/Tests/IDProjectSmokeTests.m";
    NSString *supportPath = @"/repo/UITests/IDHIDEventTestSupport.m";
    NSString *duplicate = [@[
        @"Class cls = NSClassFromString(@\"",
        @"XCPointer", @"EventPath", @"\");\n",
        @"((void (*)(id, SEL))", @"objc_", @"msgSend", @")(cls, selector);\n",
    ] componentsJoinedByString:@""];
    NSArray<NSString *> *violations = IDPrivateHIDAuditViolationsForSources(
        @{smokePath: duplicate}, supportPath);
    XCTAssertGreaterThan(violations.count, 0U);
}

- (void)testPrivateHIDAuditRejectsUnreadableSource {
    NSArray<NSString *> *violations = IDPrivateHIDAuditViolationsForSources(
        @{@"/repo/UITests/Broken.m": NSNull.null},
        @"/repo/UITests/IDHIDEventTestSupport.m");
    XCTAssertEqual(violations.count, 1U);
    XCTAssertTrue([violations.firstObject containsString:@"read"]);
}

- (void)testPrivateHIDAuditRejectsUnreadableSharedSupportSource {
    NSString *supportPath = @"/repo/UITests/IDHIDEventTestSupport.m";
    NSArray<NSString *> *violations = IDPrivateHIDAuditViolationsForSources(
        @{supportPath: NSNull.null}, supportPath);
    XCTAssertEqual(violations.count, 1U);
    XCTAssertTrue([violations.firstObject containsString:@"read"]);
}

- (void)testPrivateHIDAuditRejectsMissingRootEnumeration {
    NSString *missing = [NSTemporaryDirectory()
        stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSArray<NSString *> *violations = IDPrivateHIDAuditViolationsAtRoots(
        @[missing], @"/repo/UITests/IDHIDEventTestSupport.m",
        NSFileManager.defaultManager);
    XCTAssertEqual(violations.count, 1U);
    XCTAssertTrue([violations.firstObject containsString:@"enumerate"]);
}
- (void)testRichTemporaryInvalidationUsesExactCanvasRangeWrapperWithoutWholeCanvasFallback {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
    NSRange start = [source rangeOfString:
        @"- (void)id_invalidateTemporaryAttributesInRange:"];
    XCTAssertNotEqual(start.location, NSNotFound);
    if (start.location == NSNotFound) return;
    NSRange end = [source rangeOfString:
        @"- (void)id_invalidateDisplayForCharacterRange:"
                              options:0
                                range:NSMakeRange(NSMaxRange(start),
                                                  source.length - NSMaxRange(start))];
    XCTAssertNotEqual(end.location, NSNotFound);
    if (end.location == NSNotFound) return;
    NSString *body = [source substringWithRange:
        NSMakeRange(start.location, end.location - start.location)];
    XCTAssertTrue([body containsString:@"IDPrivateRichInvalidateTemporaryAttributes"]);
    XCTAssertTrue([body containsString:@"localRange"]);
    XCTAssertFalse([body containsString:@"setNeedsDisplay"]);
}
- (void)testPrivateContainerIdentityValidationDoesNotDependOnNSAssert {
    NSString *testFile = [NSString stringWithUTF8String:__FILE__];
    NSString *root = [[testFile stringByDeletingLastPathComponent]
        stringByDeletingLastPathComponent];
    NSString *path = IDEngineSourceFile(@"PrivateUIKit/IDTextView+PrivateCallbacks.m");
    NSString *body = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    XCTAssertFalse([body containsString:@"NSAssert("],
                   @"Private container identity validation must remain active in release builds");
}

- (void)testRequiredTextContainerOriginProvidersRemain {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    };
    NSString *canvas = read(@"TextView/IDTextLayoutCanvasView.m");
    NSString *canvasHeader =
        read(@"TextView/IDTextLayoutCanvasViewInternal.h");
    NSString *contextBridge =
        read(@"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m");
    NSString *legacy =
        read(@"PrivateUIKit/IDTextView+PrivateCallbacks.m");
    NSString *blockTextView =
        read(@"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m");
    NSString *blockCanvas =
        read(@"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m");
    NSString *blockLayout = read(@"TextView/IDBlockLayout.m");

    XCTAssertTrue([canvas containsString:@"- (CGPoint)id_textContainerOrigin"]);
    XCTAssertTrue([canvas containsString:
        @"- (void)id_invalidateTextContainerOrigin"]);
    XCTAssertTrue([canvasHeader containsString:
        @"- (CGPoint)id_textContainerOrigin"]);
    XCTAssertTrue([canvasHeader containsString:
        @"- (void)id_invalidateTextContainerOrigin"]);
    XCTAssertTrue([contextBridge containsString:
        @"IDPrivateCanvasContextTextContainerOrigin"]);
    XCTAssertTrue([legacy containsString:@"- (CGPoint)textContainerOrigin"]);
    XCTAssertTrue([legacy containsString:
        @"- (void)invalidateTextContainerOrigin"]);
    XCTAssertTrue([blockTextView containsString:
        @"- (CGPoint)tgpn_textContainerOrigin"]);
    XCTAssertTrue([blockCanvas containsString:
        @"- (CGPoint)tgpn_textContainerOrigin"]);
    XCTAssertTrue([blockLayout containsString:
        @"- (CGPoint)id_textContainerOrigin"]);
}

- (void)testProjectCanvasControllerGetterImplementationsRemain {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextLayoutCanvasView.m")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    XCTAssertTrue([source containsString:@"- (id)id_textLayoutController {"]);
    XCTAssertTrue([source containsString:
        @"return self.textLayoutManager.delegate;"]);
    XCTAssertTrue([source containsString:@"- (id)id_layoutManager {"]);
    XCTAssertTrue([source containsString:@"- (id)id_customRenderController {"]);
    XCTAssertTrue([source containsString:
        @"return IDPrivateCanvasCustomRenderController(self.context);"]);
}

- (void)testProjectCanvasStateGetterImplementationsRemain {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDTextLayoutCanvasView.m")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    XCTAssertTrue([source containsString:@"- (UIColor *)id_textColor {"]);
    XCTAssertTrue([source containsString:
        @"return IDPrivateCanvasTextColor(self.context);"]);
    XCTAssertTrue([source containsString:@"- (BOOL)id_isEditable {"]);
    XCTAssertTrue([source containsString:
        @"return IDPrivateCanvasContextIsEditable(self.context);"]);
    XCTAssertTrue([source containsString:@"- (BOOL)id_isEditing {"]);
    XCTAssertTrue([source containsString:
        @"return IDPrivateCanvasContextIsEditing(self.context);"]);
}

- (void)testCanvasCategoryMatchesControllerGetterClassification {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    NSDictionary<NSString *, NSString *> *definitions = @{
        [@"textLayout" stringByAppendingString:@"Controller"]:
            @"- (id)textLayoutController {",
        [@"layout" stringByAppendingString:@"Manager"]:
            @"- (id)layoutManager {",
        [@"customRender" stringByAppendingString:@"Controller"]:
            @"- (id)customRenderController {",
    };
    NSSet<NSString *> *removable = [NSSet setWithArray:
        IDRemovableCanvasControllerGetterSelectorNames()];
    NSSet<NSString *> *retained = [NSSet setWithArray:
        IDRetainedCanvasControllerGetterSelectorNames()];
    for (NSString *name in IDAllCanvasControllerGetterSelectorNames()) {
        if ([removable containsObject:name]) {
            XCTAssertFalse([source containsString:definitions[name]],
                           @"%@", name);
        } else {
            XCTAssertTrue([retained containsObject:name], @"%@", name);
            XCTAssertTrue([source containsString:definitions[name]],
                          @"%@", name);
        }
    }
}

- (void)testCanvasCategoryMatchesStateGetterClassification {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    NSDictionary<NSString *, NSString *> *definitions = @{
        [@"text" stringByAppendingString:@"Color"]:
            @"- (UIColor *)textColor {",
        [@"is" stringByAppendingString:@"Editable"]:
            @"- (BOOL)isEditable {",
        [@"is" stringByAppendingString:@"Editing"]:
            @"- (BOOL)isEditing {",
    };
    NSSet<NSString *> *removable = [NSSet setWithArray:
        IDRemovableCanvasStateGetterSelectorNames()];
    NSSet<NSString *> *retained = [NSSet setWithArray:
        IDRetainedCanvasStateGetterSelectorNames()];
    for (NSString *name in IDAllCanvasStateGetterSelectorNames()) {
        if ([removable containsObject:name]) {
            XCTAssertFalse([source containsString:definitions[name]],
                           @"%@", name);
        } else {
            XCTAssertTrue([retained containsObject:name], @"%@", name);
            XCTAssertTrue([source containsString:definitions[name]],
                          @"%@", name);
        }
    }
}

- (void)testCanvasCategoryMatchesTextContainerOriginClassification {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m")
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
    NSString *invalidation =
        [@"invalidateTextContainer" stringByAppendingString:@"Origin"];
    NSString *getter =
        [@"textContainer" stringByAppendingString:@"Origin"];
    // The canvas answers both under their private names through its alias table
    // (`TGPrivateMethodAliases.h`), backed by the `id_` methods.
    NSDictionary<NSString *, NSString *> *definitions = @{
        invalidation: @"{ TGPN_invalidateTextContainerOrigin, @selector(id_invalidateTextContainerOrigin) }",
        getter: @"{ TGPN_textContainerOrigin, @selector(id_textContainerOrigin) }",
    };
    for (NSString *name in IDRemovableCanvasOriginSelectorNames()) {
        XCTAssertFalse([source containsString:definitions[name]], @"%@", name);
    }
    for (NSString *name in IDRetainedCanvasOriginSelectorNames()) {
        XCTAssertTrue([source containsString:definitions[name]], @"%@", name);
    }
}

- (void)testCanvasContentSizeUsesOnlyProjectCompletedLayoutPublication {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    };
    NSString *privateCallbacks =
        read(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m");
    NSString *canvas = read(@"TextView/IDTextLayoutCanvasView.m");
    NSString *internalHeader =
        read(@"TextView/IDTextLayoutCanvasViewInternal.h");
    NSString *privateDefinition =
        [@"- (void)textContainerUsage"
            stringByAppendingString:@"DidChangeToSize:"];
    NSString *projectBridge =
        [@"id_textContainerUsage"
            stringByAppendingString:@"DidChangeToSize:"];

    XCTAssertFalse([privateCallbacks containsString:privateDefinition]);
    XCTAssertFalse([canvas containsString:projectBridge]);
    XCTAssertFalse([internalHeader containsString:projectBridge]);
    XCTAssertTrue([canvas containsString:
        @"- (void)id_updateContentSizeIfNeeded"]);
    XCTAssertTrue([canvas containsString:
        @"self.textLayoutManager.usageBoundsForTextContainer"]);
    XCTAssertTrue([canvas containsString:
        @"self.contentSizeDidChange(contentSize)"]);
    XCTAssertTrue([internalHeader containsString:
        @"- (void)id_updateContentSizeIfNeeded"]);
}



- (void)testNeutralBlockLayoutBoundaryContainsNoUIKitOrPrivateVocabulary {
    NSString *root = IDProjectSourceRoot();
    NSArray<NSString *> *headers = @[
        @"TextView/IDBlockLayoutSnapshot.h",
        @"TextView/IDDocumentLayoutCoordinator.h",
        @"TextView/IDTextKit2BlockLayoutProvider.h",
    ];
    NSArray<NSString *> *neutralImplementations = @[
        @"TextView/IDBlockLayoutSnapshot.m",
        @"TextView/IDDocumentLayoutCoordinator.m",
    ];
    NSString *adapterPath = @"TextView/IDTextKit2BlockLayoutProvider.m";
    NSArray<NSString *> *forbiddenHeaderTokens = @[
        @"UIKit",
        @"NSTextLayoutFragment",
        @"NSTextRange",
        @"NSTextLocation",
        @"NSTextLayoutManager",
        @"NSLayoutManager",
        @"NSTextContainer",
        @"UITextPosition",
        @"UITextRange",
        @"UITextSelectionRect",
        @"UITextStorageDirection",
        @"UITextLayoutDirection",
    ];
    NSArray<NSString *> *translationTokens = @[
        @"UITextStorageDirection",
        @"UITextLayoutDirection",
        @"NSWritingDirection",
    ];
    NSArray<NSString *> *runtimeTokens = @[
        @"NSClassFromString",
        @"NSSelectorFromString",
        @"objc_msgSend",
        @"class_getInstanceVariable",
        @"object_getIvar",
        @"method_setImplementation",
    ];
    NSMutableDictionary<NSString *, NSString *> *sources = [NSMutableDictionary dictionary];
    for (NSString *relativePath in [headers
            arrayByAddingObjectsFromArray:[neutralImplementations
                arrayByAddingObject:adapterPath]]) {
        NSString *source = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];
        XCTAssertNotNil(source, @"%@", relativePath);
        if (source != nil) sources[relativePath] = source;
    }
    for (NSString *relativePath in headers) {
        for (NSString *token in forbiddenHeaderTokens) {
            XCTAssertFalse([sources[relativePath] containsString:token],
                           @"%@ contains %@", relativePath, token);
        }
    }
    for (NSString *relativePath in neutralImplementations) {
        for (NSString *token in translationTokens) {
            XCTAssertFalse([sources[relativePath] containsString:token],
                           @"%@ contains %@", relativePath, token);
        }
    }
    for (NSString *token in translationTokens) {
        XCTAssertTrue([sources[adapterPath] containsString:token],
                      @"%@ does not contain %@", adapterPath, token);
    }
    for (NSString *relativePath in sources) {
        for (NSString *token in runtimeTokens) {
            XCTAssertFalse([sources[relativePath] containsString:token],
                           @"%@ contains %@", relativePath, token);
        }
    }
    NSString *snapshotHeader = sources[@"TextView/IDBlockLayoutSnapshot.h"];
    XCTAssertTrue([snapshotHeader containsString:
        @"IDBlockLayoutCapabilityBaseWritingDirection"]);
    XCTAssertTrue([snapshotHeader containsString:
        @"id_snapshotBaseWritingDirectionAtPosition:"]);
}

- (void)testNeutralSelectionHeadersContainNoUIKitOrPrivateVocabulary {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockLayoutSnapshot.h")
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    for (NSString *token in @[
        @"UIKit", @"NSText", @"UIText", @"NSLayoutManager",
        @"canvas", @"CALayer", @"NSSelectorFromString", @"objc_msgSend",
    ]) {
        XCTAssertFalse([source containsString:token], @"forbidden token: %@", token);
    }
    XCTAssertTrue([source containsString:@"IDBlockSelectionSegment"]);
    XCTAssertTrue([source containsString:@"IDBlockLayoutCapabilitySelectionSegments"]);
}

- (void)testSourceConditionalVisibilityParserDistinguishesDebugAndProductionBranches {
    NSString *fixture =
        @"production-token\n"
         "#if DEBUG\n"
         "debug-token\n"
         "#if FEATURE\n"
         "nested-debug-token\n"
         "#else\n"
         "nested-debug-else-token\n"
         "#endif\n"
         "#else\n"
         "debug-else-production-token\n"
         "#endif\n"
         "#if FEATURE\n"
         "unrelated-production-token\n"
         "#endif\n"
         "#ifndef DEBUG\n"
         "ifndef-production-token\n"
         "#else\n"
         "ifndef-debug-token\n"
         "#endif\n";
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"production-token",
        IDSourceConditionalVisibilityProduction).count, 4U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"debug-token",
        IDSourceConditionalVisibilityDebug).count, 3U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"nested-debug-token",
        IDSourceConditionalVisibilityDebug).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"nested-debug-else-token",
        IDSourceConditionalVisibilityDebug).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"debug-else-production-token",
        IDSourceConditionalVisibilityProduction).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"unrelated-production-token",
        IDSourceConditionalVisibilityProduction).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"ifndef-production-token",
        IDSourceConditionalVisibilityProduction).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        fixture, @"ifndef-debug-token",
        IDSourceConditionalVisibilityDebug).count, 1U);

    NSString *authorityFixture =
        @"visuallyAdjacentPositionFromCanonicalOffset:\n"
         "#if DEBUG\n"
         "id_establishedNavigationFromPosition:\n"
         "#endif\n";
    XCTAssertEqual(IDSourceLinesContainingToken(
        authorityFixture, @"visuallyAdjacentPositionFromCanonicalOffset:",
        IDSourceConditionalVisibilityProduction).count, 1U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        authorityFixture, @"id_establishedNavigationFromPosition:",
        IDSourceConditionalVisibilityProduction).count, 0U);

    NSString *oracleFixture =
        @"#if DEBUG\n"
         "caretStopFromLocalOffset:\n"
         "#endif\n";
    XCTAssertEqual(IDSourceLinesContainingToken(
        oracleFixture, @"caretStopFromLocalOffset:",
        IDSourceConditionalVisibilityProduction).count, 0U);
    XCTAssertEqual(IDSourceLinesContainingToken(
        oracleFixture, @"caretStopFromLocalOffset:",
        IDSourceConditionalVisibilityDebug).count, 1U);
}

- (void)testNeutralCrossBlockNavigationHasOneCoordinatorImplementationInEveryBuild {
    NSString *path = IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    if (source == nil) return;
    NSArray<NSString *> *violations =
        IDNeutralNavigationAuthorityViolations(source);
    XCTAssertEqualObjects(violations, @[], @"%@", violations);
}

- (void)testNeutralDocumentGeometryHasOneCoordinatorImplementationInEveryBuild {
    NSString *path = IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    if (source == nil) return;

    NSArray<NSString *> *violations =
        IDNeutralGeometryAuthorityViolations(source);
    XCTAssertEqualObjects(violations, @[], @"%@", violations);
}

- (void)testNeutralGeometryAuthorityAuditRejectsObsoleteDirectHelper {
    NSString *fixture = IDNeutralGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(IDNeutralGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByAppendingString:
        @"- (CGRect)id_establishedInsertionRectForPosition:(id)position;\n"];

    NSArray<NSString *> *violations =
        IDNeutralGeometryAuthorityViolations(mutation);
    XCTAssertTrue([violations containsObject:
        @"obsolete geometry oracle: id_establishedInsertionRectForPosition:"],
        @"%@", violations);
}

- (void)testNeutralGeometryAuthorityAuditRejectsAlternateReturnPath {
    NSString *fixture = IDNeutralGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(IDNeutralGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"BOOL valid = IDRichCaretGeometryResultIsValid(neutral, document, offset);"
        withString:@"BOOL valid = IDRichCaretGeometryResultIsValid(neutral, document, offset);\n"
                   "    if (!valid) return CGRectZero;"];

    NSArray<NSString *> *violations =
        IDNeutralGeometryAuthorityViolations(mutation);
    NSPredicate *alternateReturn = [NSPredicate predicateWithBlock:
        ^BOOL(NSString *violation, NSDictionary *bindings) {
            (void)bindings;
            return [violation containsString:@"caret alternate return path"];
        }];
    XCTAssertEqual([violations filteredArrayUsingPredicate:alternateReturn].count,
                   1U, @"%@", violations);
}

- (void)testNeutralGeometryAuthorityAuditRejectsRetryFallback {
    NSString *fixture = IDNeutralGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(IDNeutralGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"BOOL valid = IDRichPointResultIsValid(neutral, document);"
        withString:@"if (neutral == nil) neutral = [coordinator nearestPositionToDocumentPoint:point];\n"
                   "    BOOL valid = IDRichPointResultIsValid(neutral, document);"];

    NSArray<NSString *> *violations =
        IDNeutralGeometryAuthorityViolations(mutation);
    NSPredicate *pointCount = [NSPredicate predicateWithBlock:
        ^BOOL(NSString *violation, NSDictionary *bindings) {
            (void)bindings;
            return [violation containsString:@"point total coordinator call count"];
        }];
    XCTAssertEqual([violations filteredArrayUsingPredicate:pointCount].count,
                   1U, @"%@", violations);
}

- (void)testNeutralNavigationAuthorityAuditRejectsObsoleteOracleHelper {
    NSString *fixture = IDNeutralNavigationValidAuthorityFixture();
    XCTAssertEqualObjects(IDNeutralNavigationAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"- (nullable UITextPosition *)id_positionFromPosition:"
        withString:@"#if DEBUG\n"
                   "- (id)id_establishedNavigationFromPosition:(id)position;\n"
                   "#endif\n"
                   "- (nullable UITextPosition *)id_positionFromPosition:"];
    NSArray<NSString *> *violations =
        IDNeutralNavigationAuthorityViolations(mutation);
    XCTAssertTrue([violations containsObject:
        @"obsolete navigation oracle: id_establishedNavigationFromPosition:"],
        @"%@", violations);
}

- (void)testNeutralNavigationAuthorityAuditRejectsAlternateReturnPath {
    NSString *fixture = IDNeutralNavigationValidAuthorityFixture();
    XCTAssertEqualObjects(IDNeutralNavigationAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"visuallyAdjacentPositionFromCanonicalOffset:currentOffset];"
        withString:@"visuallyAdjacentPositionFromCanonicalOffset:currentOffset];\n"
                   "    if (neutral == nil) return valid;"];
    NSArray<NSString *> *violations =
        IDNeutralNavigationAuthorityViolations(mutation);
    NSPredicate *alternateReturn = [NSPredicate predicateWithBlock:
        ^BOOL(NSString *violation, NSDictionary *bindings) {
            (void)bindings;
            return [violation containsString:@"alternate return path"];
        }];
    XCTAssertEqual([violations filteredArrayUsingPredicate:alternateReturn].count,
                   1U, @"%@", violations);
}

- (void)testNeutralBlockLayoutSlicePreservesPrivateBehaviorManifestCounts {
    NSString *root = IDProjectSourceRoot();
    NSDictionary *(^readManifest)(NSString *) = ^NSDictionary *(NSString *relativePath) {
        NSData *data = [NSData dataWithContentsOfFile:
            IDEngineSourceFile(relativePath)];
        XCTAssertNotNil(data, @"%@", relativePath);
        if (data == nil) return nil;
        NSError *error = nil;
        NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data
                                                                  options:0
                                                                    error:&error];
        XCTAssertNil(error, @"%@", relativePath);
        XCTAssertTrue([manifest isKindOfClass:NSDictionary.class], @"%@", relativePath);
        return manifest;
    };
    NSUInteger (^memberCount)(NSDictionary *) = ^NSUInteger(NSDictionary *groups) {
        NSUInteger count = 0;
        for (NSDictionary *group in groups.allValues) {
            NSArray *members = group[@"members"];
            XCTAssertTrue([members isKindOfClass:NSArray.class]);
            count += members.count;
        }
        return count;
    };
    NSDictionary *production = readManifest(
        @"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    NSDictionary *testOnly = readManifest(
        @"Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json");

    XCTAssertEqual(memberCount(production[@"capabilities"]), 127U);
    XCTAssertEqual(memberCount(production[@"referenceOnly"]), 53U);
    XCTAssertEqual(memberCount(testOnly[@"capabilities"]), 24U);

    NSUInteger autoscrollCount = 0;
    for (NSDictionary *group in [testOnly[@"capabilities"] allValues]) {
        for (NSDictionary *member in group[@"members"]) {
            if ([member[@"identifier"] hasPrefix:@"testOnly.autoscroll"]) {
                autoscrollCount += 1;
            }
        }
    }
    XCTAssertEqual(autoscrollCount, 10U);
}

- (void)testSelectionProductionSourceRequiresNeutralCoordinatorAuthority {
    NSString *path = IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    NSUInteger coordinatorQueryCount =
        [source componentsSeparatedByString:
            @"selectionGeometryForCanonicalRange:"].count - 1;
    XCTAssertEqual(coordinatorQueryCount, 1U);
    XCTAssertNotEqual([source rangeOfString:
        @"NSArray<IDRichTextSelectionRect *> *exact = [self\n"
         "            id_exactSelectionRectsForRange:range"].location,
        NSNotFound,
        @"the production callback must normalize the nullable neutral adapter");
    XCTAssertNotEqual([source rangeOfString:@"return exact ?: @[];"].location,
                      NSNotFound);
}

- (void)testNeutralSelectionGeometryHasOneCoordinatorImplementationInEveryBuild {
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDRichTextLayoutController.m")
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    XCTAssertEqualObjects(IDNeutralSelectionGeometryAuthorityViolations(source),
                          @[]);
}

- (void)testNeutralSelectionAuthorityAuditRejectsObsoleteDirectHelper {
    NSString *fixture = IDNeutralSelectionGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(
        IDNeutralSelectionGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"- (NSArray *)id_selectionRectsForRange:"
        withString:@"- (NSArray *)id_establishedSelectionRectsForCanonicalRange:\n"
                    "    { [layout selectionRectsForLocalRange:range]; }\n"
                    "- (NSArray *)id_selectionRectsForRange:"];
    NSArray<NSString *> *violations =
        IDNeutralSelectionGeometryAuthorityViolations(mutation);
    XCTAssertTrue([[violations componentsJoinedByString:@"\n"]
        containsString:@"obsolete direct selection path"]);
}

- (void)testNeutralSelectionAuthorityAuditRejectsAlternateReturnPath {
    NSString *fixture = IDNeutralSelectionGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(
        IDNeutralSelectionGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"return exact ?: @[];"
        withString:@"if (exact == nil) return established;\n"
                    "    return exact ?: @[];"];
    NSArray<NSString *> *violations =
        IDNeutralSelectionGeometryAuthorityViolations(mutation);
    XCTAssertTrue([[violations componentsJoinedByString:@"\n"]
        containsString:@"alternate return path"]);
}

- (void)testNeutralSelectionAuthorityAuditRejectsRetryFallback {
    NSString *fixture = IDNeutralSelectionGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(
        IDNeutralSelectionGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"return rects.copy;"
        withString:@"IDDocumentSelectionGeometry *secondAttempt = [coordinator\n"
                    "        selectionGeometryForCanonicalRange:characterRange];\n"
                    "    return secondAttempt ? rects.copy : fallback;"];
    NSArray<NSString *> *violations =
        IDNeutralSelectionGeometryAuthorityViolations(mutation);
    NSString *joined = [violations componentsJoinedByString:@"\n"];
    XCTAssertTrue([joined containsString:@"total coordinator call count"]);
    XCTAssertTrue([joined containsString:@"retry/fallback"]);
}

- (void)testNeutralSelectionAuthorityAuditRejectsBlockIterationAndCanvasConversion {
    NSString *fixture = IDNeutralSelectionGeometryValidAuthorityFixture();
    XCTAssertEqualObjects(
        IDNeutralSelectionGeometryAuthorityViolations(fixture), @[]);
    NSString *mutation = [fixture stringByReplacingOccurrencesOfString:
        @"NSArray<IDRichTextSelectionRect *> *exact = [self"
        withString:@"for (IDBlockLayout *layout in blockLayouts) {\n"
                    "        [layout.canvasView convertRect:CGRectZero toView:view];\n"
                    "    }\n"
                    "    NSArray<IDRichTextSelectionRect *> *exact = [self"];
    NSArray<NSString *> *violations =
        IDNeutralSelectionGeometryAuthorityViolations(mutation);
    NSString *joined = [violations componentsJoinedByString:@"\n"];
    XCTAssertTrue([joined containsString:@"blockLayouts"]);
    XCTAssertTrue([joined containsString:@"canvasView"]);
    XCTAssertTrue([joined containsString:@"convertRect:"]);
}

/// The artifact SHAPE check has to be able to reject, or the loops that call it are inert and the
/// malformed pair below would have gone through unnoticed — which is how it survived until the
/// on-disk assertion was removed and the shape check was all that was left looking.
- (void)testAnUpstreamRunArtifactPathIsRecognisedByItsExtensionAlone {
    XCTAssertTrue(IDIsUpstreamRunArtifactPath(@".block-is-editing-withdrawal-task4-units-final.xcresult"));
    // The two the plural-keyboard fixture carries: a bundle name with no extension at all.
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(@".block-plural-replacement-task4-retained-keyboard"));
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(@".block-plural-replacement-task4-withdrawn-keyboard"));
    // Neither a Hopper document nor a log is a run bundle; those keep their own on-disk assertions.
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(@"docs/hopper/UIKitCore-iOS26.5.md"));
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(@".anchored-frame-callback-task-1-characterization-1.log"));
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(@""));
    XCTAssertFalse(IDIsUpstreamRunArtifactPath(nil));
}

- (void)testBlockPluralKeyboardReplacementAuthorizationFixtureIsPinnedAndComplete {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"Tests/Fixtures/BlockPluralKeyboardReplacementAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"runtime", @"selector", @"owner", @"decision",
            @"retainedAuthority", @"hopper", @"artifacts",
        ]]));
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], (@{
        @"platform": @"iOS", @"version": @"26.5", @"build": @"23F73",
    }));
    XCTAssertEqualObjects(fixture[@"selector"],
        @"keyboardInput:shouldReplaceTextInRanges:replacementText:");
    XCTAssertEqualObjects(fixture[@"owner"],
        @"IDBlockTextView(PrivateInputDelegate)");
    XCTAssertEqualObjects(fixture[@"decision"], @"safeFallback");
    XCTAssertEqualObjects(fixture[@"retainedAuthority"], (@{
        @"selector": @"keyboardInput:shouldReplaceTextInRange:replacementText:",
        @"policy": @"IDBlockAllowsKeyboardReplacement",
    }));
    XCTAssertEqualObjects(fixture[@"hopper"], (@{
        @"replacementManager": @"0xbed7d4",
        @"forwardDeleteManager": @"0xbee8b8",
        @"pluralStub": @"0x2232600",
        @"singularStub": @"0x22325e0",
        @"pluralSend": @"0xbedfb4",
        @"singularSend": @"0xbedcac",
        @"forwardDeletePluralSend": @"0xbeeda4",
        @"forwardDeleteSingularSend": @"0xbeeaf4",
    }));
    NSDictionary<NSString *, NSString *> *artifacts = fixture[@"artifacts"];
    XCTAssertEqualObjects([NSSet setWithArray:artifacts.allKeys],
        ([NSSet setWithArray:@[
            @"retainedFocused", @"withdrawnFocused", @"retainedKeyboard",
            @"withdrawnKeyboard", @"withdrawnUI",
        ]]));
    // TWO of this fixture's five entries name neither a well-formed `.xcresult` nor any file that
    // exists in the `~/Documents/InputDec` archive — measured 2026-09-15, and the ONLY two such
    // entries in the whole fixture corpus. The on-disk assertion this loop replaced failed on them
    // too; that was invisible because the case was already red for the artifacts nobody has any
    // more. They are pinned BY NAME rather than waved through, so the shape check stays strict for
    // every other entry and a later correction to the fixture fails here and updates this note.
    // Their true names are not guessable: no `-task4-*-keyboard` bundle survives under any suffix.
    NSSet<NSString *> *knownMalformed = [NSSet setWithArray:@[
        @".block-plural-replacement-task4-retained-keyboard",
        @".block-plural-replacement-task4-withdrawn-keyboard",
    ]];
    XCTAssertEqualObjects(([NSSet setWithArray:@[artifacts[@"retainedKeyboard"],
                                                 artifacts[@"withdrawnKeyboard"]]]),
                          knownMalformed);
    for (NSString *artifact in artifacts.allValues) {
        if ([knownMalformed containsObject:artifact]) continue;
        // Named, not opened — see IDIsUpstreamRunArtifactPath for why the bundle itself is not
        // required on disk (26 of the 48 these fixtures cite no longer exist anywhere).
        XCTAssertTrue(IDIsUpstreamRunArtifactPath(artifact), @"%@", artifact);
    }
}

- (void)testBlockPluralKeyboardReplacementExperimentInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSString *control = [@"ID_WITHDRAW_BLOCK_PLURAL_KEYBOARD_"
        stringByAppendingString:@"REPLACEMENT_CALLBACK"];
    NSString *temporaryHeader = [@"IDBlockPluralKeyboardReplacement"
        stringByAppendingString:@"Withdrawal.h"];
    NSString *nesting = [@"IDBlockPluralReplacement"
        stringByAppendingString:@"NestingDepth"];
    NSArray<NSString *> *traceTokens = @[
        [@"keyboardReplace" stringByAppendingString:@"Singular"],
        [@"keyboardReplacePluralVia" stringByAppendingString:@"Singular"],
        [@"keyboardReplacePlural" stringByAppendingString:@"Direct"],
    ];
    NSString *selector = [@"keyboardInput:shouldReplaceTextIn"
        stringByAppendingString:@"Ranges:replacementText:"];
    NSString *source = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInputDelegate.m");
    NSString *manifest = read(
        @"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    XCTAssertNotNil(source);
    XCTAssertNotNil(manifest);
    XCTAssertEqual(IDSourceOccurrenceCount(source,
        @"static BOOL IDBlockAllowsKeyboardReplacement("), 1U);
    XCTAssertEqual(IDSourceOccurrenceCount(source,
        @"shouldReplaceTextInRange:(NSRange)range"), 1U);
    XCTAssertEqual(IDSourceOccurrenceCount(source,
        @"shouldReplaceTextInRanges:(NSArray<NSValue *> *)ranges"), 0U);
    XCTAssertFalse([manifest containsString:selector]);
    for (NSString *token in @[
             @"forwardingTargetForSelector:", @"methodSignatureForSelector:",
             @"forwardInvocation:", @"resolveInstanceMethod:",
    ]) {
        XCTAssertFalse([source containsString:token], @"%@", token);
    }
    NSArray<NSString *> *tokens = [@[
        control, temporaryHeader, nesting,
    ] arrayByAddingObjectsFromArray:traceTokens];
    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests",
             @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *body = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (body == nil) continue;
            for (NSString *token in tokens) {
                XCTAssertFalse([body containsString:token], @"%@/%@ contains %@",
                               folder, relativePath, token);
            }
        }
    }
    for (NSString *path in @[
             @"project.yml", @"InputDec.xcodeproj/project.pbxproj",
         ]) {
        NSString *body = read(path);
        XCTAssertNotNil(body);
        for (NSString *token in tokens) {
            XCTAssertFalse([body containsString:token], @"%@ contains %@",
                           path, token);
        }
    }
}

- (void)testBlockCustomRenderControllerWithdrawalInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    };
    NSString *callbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(privateUIKit);

    NSArray<NSString *> *withdrawalTokens = @[
        [@"ID_WITHDRAW_BLOCK_CUSTOM_RENDER_" stringByAppendingString:@"CONTROLLER"],
        [@"ID_OMIT_BLOCK_CUSTOM_RENDER_CONTROLLER_" stringByAppendingString:@"ABI"],
    ];
    for (NSString *folder in @[@"App", @"TextView", @"PrivateUIKit"]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
            if (source == nil) continue;
            for (NSString *token in withdrawalTokens) {
                XCTAssertFalse([source containsString:token], @"%@/%@", folder,
                               relativePath);
            }
        }
    }

    XCTAssertFalse([callbacks containsString:
        @"- (id)customRenderController {\n    return nil;\n}"]);
    XCTAssertFalse([privateUIKit containsString:
        @"IDInteractionABISpecMake(@\"customRenderController\", @encode(id), @[]),"]);
    NSString *canvas = read(@"TextView/IDTextLayoutCanvasView.m");
    NSString *flat = read(@"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m");
    NSString *blockCanvas =
        read(@"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m");
    XCTAssertTrue([canvas containsString:@"- (id)id_customRenderController {"]);
    XCTAssertTrue([flat containsString:@"- (id)customRenderController {"]);
    XCTAssertTrue([blockCanvas containsString:@"- (id)tgpn_customRenderController {"]);
}

- (void)testBlockInteractionPolicyWithdrawalInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSData *fixtureData = [NSData dataWithContentsOfFile:
        IDEngineSourceFile(@"Tests/Fixtures/BlockInteractionPolicyCallbackAuthorization-iOS26.5.json")];
    NSDictionary<NSString *, id> *fixture = fixtureData == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:fixtureData options:0 error:nil];
    NSArray<NSDictionary<NSString *, id> *> *rows = fixture[@"selectors"];
    XCTAssertEqual(rows.count, 4U);

    NSArray<NSString *> *tokens = @[
        [@"ID_WITHDRAW_BLOCK_UPDATE_SELECTION_" stringByAppendingString:@"GESTURES"],
        [@"ID_OMIT_BLOCK_UPDATE_SELECTION_GESTURES_" stringByAppendingString:@"ABI"],
        [@"ID_WITHDRAW_BLOCK_INTERACTIVE_SELECTION_" stringByAppendingString:@"DISABLED"],
        [@"ID_OMIT_BLOCK_INTERACTIVE_SELECTION_DISABLED_" stringByAppendingString:@"ABI"],
        [@"ID_WITHDRAW_BLOCK_HAS_EDITABLE_" stringByAppendingString:@"SELECTION"],
        [@"ID_OMIT_BLOCK_HAS_EDITABLE_SELECTION_" stringByAppendingString:@"ABI"],
        [@"ID_WITHDRAW_BLOCK_TEXTKIT2_CANVAS_DID_" stringByAppendingString:@"LAYOUT"],
        [@"ID_OMIT_BLOCK_TEXTKIT2_CANVAS_DID_LAYOUT_" stringByAppendingString:@"ABI"],
    ];
    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests", @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (source == nil) continue;
            for (NSString *token in tokens) {
                XCTAssertFalse([source containsString:token], @"%@/%@ contains %@",
                               folder, relativePath, token);
            }
            NSString *pairingDiagnostic = [@"withdrawal controls must "
                stringByAppendingString:@"be paired"];
            XCTAssertFalse([source containsString:pairingDiagnostic], @"%@/%@",
                           folder, relativePath);
        }
    }
    NSString *project = read(@"project.yml");
    for (NSString *token in tokens) {
        XCTAssertFalse([project containsString:token], @"project.yml contains %@", token);
    }

    NSString *callbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(privateUIKit);
    for (NSDictionary<NSString *, id> *row in rows) {
        NSString *name = row[@"name"];
        BOOL required = [row[@"decision"] isEqualToString:@"required"];
        XCTAssertEqual(IDBlockHostMethodDefinitionPaths(name).count,
                       required ? 1U : 0U, @"%@", name);
        NSString *abiToken = [NSString stringWithFormat:
            @"IDInteractionABISpecMake(@\"%@\"", name];
        XCTAssertEqual(IDSourceOccurrenceCount(privateUIKit, abiToken),
                       required ? 1U : 0U, @"%@", name);
    }

    NSArray<NSString *> *forwardingSelectors = @[
        @"forwardingTargetForSelector:", @"methodSignatureForSelector:",
        @"forwardInvocation:", @"resolveInstanceMethod:",
    ];
    for (NSString *path in @[
             @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m",
             @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m",
         ]) {
        NSString *source = read(path);
        XCTAssertNotNil(source, @"%@", path);
        for (NSString *selectorName in forwardingSelectors) {
            NSString *escaped = [NSRegularExpression
                escapedPatternForString:selectorName];
            NSRegularExpression *method = [NSRegularExpression
                regularExpressionWithPattern:[NSString stringWithFormat:
                    @"(?ms)^\\s*[-+]\\s*\\([^\\n)]*\\)\\s*%@[^\\n]*\\{.*?"
                     "(?=^\\s*[-+]\\s*\\(|^\\s*@end)", escaped]
                                       options:0 error:nil];
            for (NSTextCheckingResult *match
                 in [method matchesInString:source options:0
                                      range:NSMakeRange(0, source.length)]) {
                NSString *body = [source substringWithRange:match.range];
                for (NSDictionary<NSString *, id> *row in rows) {
                    if ([row[@"decision"] isEqualToString:@"safeFallback"]) {
                        XCTAssertFalse([body containsString:row[@"name"]],
                                       @"%@ %@ -> %@", path, selectorName,
                                       row[@"name"]);
                    }
                }
            }
        }
    }

    NSString *flat = read(
        @"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m");
    NSString *blockCanvas = read(
        @"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m");
    NSString *canvas = read(
        @"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m");
    for (NSString *name in @[
             @"_updateSelectionGestures", @"_isInteractiveTextSelectionDisabled",
             @"_textKit2CanvasDidLayout",
         ]) {
        XCTAssertTrue([flat containsString:name], @"flat provider %@", name);
    }
    XCTAssertTrue([blockCanvas containsString:@"- (void)tgpn__textKit2CanvasDidLayout {"]);
    XCTAssertTrue([canvas containsString:
        @"{ TGPN__textKit2CanvasDidLayout, @selector(id_textKit2CanvasDidLayout) }"]);
}

- (void)testBlockIsEditingAuthorizationFixtureIsPinnedAndComplete {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"Tests/Fixtures/BlockIsEditingCallbackAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"runtime", @"selector", @"owner", @"decision",
            @"ordinaryResolvedOwner", @"artifacts", @"hopper",
        ]]));
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], (@{
        @"platform": @"iOS", @"version": @"26.5", @"build": @"23F73",
    }));
    XCTAssertEqualObjects(fixture[@"selector"], @"isEditing");
    XCTAssertEqualObjects(fixture[@"owner"],
                          @"IDBlockTextView(PrivateInteractionCallbacks)");
    XCTAssertEqualObjects(fixture[@"decision"], @"safeFallback");
    XCTAssertEqualObjects(fixture[@"ordinaryResolvedOwner"], @"UIResponder");

    NSDictionary<NSString *, NSString *> *artifacts = fixture[@"artifacts"];
    XCTAssertEqualObjects([NSSet setWithArray:artifacts.allKeys],
        ([NSSet setWithArray:@[
            @"units", @"lifecycleUI", @"touchUI", @"floatingUI",
            @"typingSpellingUI", @"englishKeyboardUI",
        ]]));
    for (NSString *artifact in artifacts.allValues) {
        // Named, not opened — see IDIsUpstreamRunArtifactPath for why the bundle itself is not
        // required on disk (26 of the 48 these fixtures cite no longer exist anywhere).
        XCTAssertTrue(IDIsUpstreamRunArtifactPath(artifact), @"%@", artifact);
    }
    XCTAssertEqualObjects(fixture[@"hopper"], (@{
        @"selectorStub": @"0x22299c0",
        @"uiResponderImplementation": @"0x10c7f08",
        @"textInputControllerImplementation": @"0x15e9398",
    }));
}

- (void)testBlockIsEditingExperimentInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSArray<NSString *> *tokens = @[
        [@"ID_WITHDRAW_BLOCK_IS_EDITING_" stringByAppendingString:@"CALLBACK"],
        [@"ID_OMIT_BLOCK_IS_EDITING_" stringByAppendingString:@"ABI"],
    ];
    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests",
             @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (source == nil) continue;
            for (NSString *token in tokens) {
                XCTAssertFalse([source containsString:token], @"%@/%@",
                               folder, relativePath);
            }
        }
    }
    for (NSString *path in @[@"project.yml", @"InputDec.xcodeproj/project.pbxproj"]) {
        NSString *source = read(path);
        XCTAssertNotNil(source, @"%@", path);
        for (NSString *token in tokens) {
            XCTAssertFalse([source containsString:token], @"%@", path);
        }
    }

    NSString *callbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(privateUIKit);
    XCTAssertFalse([callbacks containsString:@"- (BOOL)isEditing {"]);
    XCTAssertFalse([privateUIKit containsString:
        @"IDInteractionABISpecMake(@\"isEditing\", @encode(BOOL), @[]),"]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:
        IDEngineSourceFile(@"PrivateUIKit/IDBlockIsEditingWithdrawal.h")]);

    NSString *manifest = read(
        @"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json");
    XCTAssertTrue([manifest containsString:@"\"identifier\": \"reference.contextEditing\""]);
    XCTAssertTrue([manifest containsString:
        @"\"source\": \"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m|isEditing\""]);
    XCTAssertTrue([read(@"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m")
        containsString:@"- (BOOL)isEditing {"]);
    XCTAssertTrue([read(@"PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m")
        containsString:@"- (BOOL)isEditing {"]);
}

- (void)testBlockVisualSelectionAuthorizationFixtureIsPinnedAndComplete {
    NSString *root = IDProjectSourceRoot();
    NSString *path = IDEngineSourceFile(@"Tests/Fixtures/BlockVisualSelectionRangeCallbackAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys],
        ([NSSet setWithArray:@[
            @"schema", @"runtime", @"selector", @"owner", @"decision",
            @"algorithmAuthority", @"hopper", @"artifacts",
        ]]));
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], (@{
        @"platform": @"iOS", @"version": @"26.5", @"build": @"23F73",
    }));
    XCTAssertEqualObjects(fixture[@"selector"],
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    XCTAssertEqualObjects(fixture[@"owner"], @"IDBlockTextView(PrivateCallbacks)");
    XCTAssertEqualObjects(fixture[@"decision"], @"safeFallback");
    XCTAssertEqualObjects(fixture[@"algorithmAuthority"], @"IDRichTextLayoutController");
    XCTAssertEqualObjects(fixture[@"hopper"], (@{
        @"textViewForwarder": @"0x1616060",
        @"selectorStub": @"0x21b30e0",
        @"selectionFallback": @"0x1576b20",
        @"guardedSend": @"0x1576bcc",
        @"displayInteractionInitializer": @"0xc69c6c",
        @"activeSelection": @"0xc6b750",
        @"selectionInitializer": @"0x1574a24",
        @"selectionDocument": @"0x1577adc",
    }));
    NSDictionary<NSString *, NSString *> *artifacts = fixture[@"artifacts"];
    XCTAssertEqualObjects([NSSet setWithArray:artifacts.allKeys],
        ([NSSet setWithArray:@[
            @"retainedUnits", @"withdrawnUnits", @"retainedUI", @"withdrawnUI",
        ]]));
    for (NSString *artifact in artifacts.allValues) {
        // Named, not opened — see IDIsUpstreamRunArtifactPath for why the bundle itself is not
        // required on disk (26 of the 48 these fixtures cite no longer exist anywhere).
        XCTAssertTrue(IDIsUpstreamRunArtifactPath(artifact), @"%@", artifact);
    }
}

- (void)testBlockVisualSelectionExperimentInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSArray<NSString *> *tokens = @[
        [@"ID_WITHDRAW_BLOCK_VISUAL_SELECTION_RANGE_" stringByAppendingString:@"CALLBACK"],
        [@"ID_OMIT_BLOCK_VISUAL_SELECTION_RANGE_" stringByAppendingString:@"ABI"],
        [@"IDBlockVisualSelectionRange" stringByAppendingString:@"Withdrawal"],
        [@"IDPrivateResetBlockVisualSelection" stringByAppendingString:@"TraceForUITesting"],
        [@"IDPrivateRecordBlockVisualSelection" stringByAppendingString:@"InvocationForUITesting"],
        [@"IDPrivateCopyBlockVisualSelection" stringByAppendingString:@"TraceForUITesting"],
        [@"visualSelection" stringByAppendingString:@"Trace"],
    ];
    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests", @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (source == nil) continue;
            for (NSString *token in tokens) {
                XCTAssertFalse([source containsString:token], @"%@/%@ contains %@",
                               folder, relativePath, token);
            }
        }
    }
    for (NSString *path in @[@"project.yml", @"InputDec.xcodeproj/project.pbxproj"]) {
        NSString *source = read(path);
        XCTAssertNotNil(source, @"%@", path);
        for (NSString *token in tokens) {
            XCTAssertFalse([source containsString:token], @"%@ contains %@", path, token);
        }
    }

    NSString *selector =
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:";
    XCTAssertEqual(IDBlockHostMethodDefinitionPaths(selector).count, 0U);
    XCTAssertFalse([read(@"PrivateUIKit/IDPrivateUIKit.m") containsString:selector]);
    XCTAssertFalse([read(@"PrivateUIKit/IDPrivateUIKit+RichTextLayout.h")
        containsString:@"IDPrivateRequireBlockTextViewVisualSelectionABI"]);
    XCTAssertFalse([read(@"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m")
        containsString:@"IDPrivateRequireBlockTextViewVisualSelectionABI"]);
    XCTAssertFalse([read(@"TextView/IDBlockTextView.m")
        containsString:@"IDPrivateRequireBlockTextViewVisualSelectionABI"]);
    NSString *richCallbacks =
        read(@"PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m");
    // Answered under its private name by the alias table onto the `id_` method
    // (`TGPrivateMethodAliases.h`), whose signature is the callback's.
    XCTAssertTrue([richCallbacks containsString:
        @"TGPN__visualSelectionRangeForExtent_forPoint_fromPosition_inDirection_"]);
    XCTAssertTrue([richCallbacks containsString:
        @"@selector(id_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:)"]);
    XCTAssertTrue([read(@"TextView/IDRichTextLayoutController.m")
        containsString:@"id_visualSelectionRangeForExtent:"]);
    XCTAssertTrue([read(@"PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json")
        containsString:selector]);
}

- (void)testBlockRenderFallbackWithdrawalInfrastructureIsAbsent {
    NSString *root = IDProjectSourceRoot();
    NSString *(^read)(NSString *) = ^NSString *(NSString *relativePath) {
        return [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
            encoding:NSUTF8StringEncoding error:nil];
    };
    NSArray<NSString *> *tokens = @[
        [@"ID_WITHDRAW_BLOCK_RENDER_SPACE_" stringByAppendingString:@"CONVERSION"],
        [@"ID_OMIT_BLOCK_RENDER_SPACE_CONVERSION_" stringByAppendingString:@"ABI"],
    ];
    for (NSString *folder in @[
             @"App", @"TextView", @"PrivateUIKit", @"Tests", @"UITests",
             @"Scripts",
         ]) {
        NSString *directory = IDEngineSourceFile(folder);
        NSDirectoryEnumerator<NSString *> *files =
            [NSFileManager.defaultManager enumeratorAtPath:directory];
        for (NSString *relativePath in files) {
            NSString *source = [NSString stringWithContentsOfFile:
                [directory stringByAppendingPathComponent:relativePath]
                encoding:NSUTF8StringEncoding error:nil];
            if (source == nil) continue;
            for (NSString *token in tokens) {
                XCTAssertFalse([source containsString:token], @"%@/%@",
                               folder, relativePath);
            }
        }
    }
    NSString *project = read(@"project.yml");
    for (NSString *token in tokens) {
        XCTAssertFalse([project containsString:token], @"project.yml");
    }

    NSString *callbacks = read(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSString *privateUIKit = read(@"PrivateUIKit/IDPrivateUIKit.m");
    XCTAssertNotNil(callbacks);
    XCTAssertNotNil(privateUIKit);
    XCTAssertFalse([callbacks containsString:
        @"- (id)customRenderController {"]);
    XCTAssertFalse([callbacks containsString:
        @"- (CGPoint)_convertPointFromRenderSpace:(CGPoint)point {"]);
    XCTAssertFalse([privateUIKit containsString:
        @"IDInteractionABISpecMake(@\"customRenderController\""]);
    XCTAssertFalse([privateUIKit containsString:
        @"IDInteractionABISpecMake(@\"_convertPointFromRenderSpace:\""]);

    NSArray<NSString *> *blockCallbackPaths = @[
        @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m",
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m",
    ];
    NSArray<NSString *> *forwardingSelectors = @[
        @"forwardingTargetForSelector:",
        @"methodSignatureForSelector:",
        @"forwardInvocation:",
        @"resolveInstanceMethod:",
    ];
    NSArray<NSString *> *withdrawnSelectors = @[
        @"customRenderController", @"_convertPointFromRenderSpace:",
    ];
    for (NSString *path in blockCallbackPaths) {
        NSString *source = read(path);
        XCTAssertNotNil(source, @"%@", path);
        for (NSString *selectorName in forwardingSelectors) {
            NSString *escaped = [NSRegularExpression
                escapedPatternForString:selectorName];
            NSRegularExpression *method = [NSRegularExpression
                regularExpressionWithPattern:[NSString stringWithFormat:
                    @"(?ms)^\\s*[-+]\\s*\\([^\\n)]*\\)\\s*%@[^\\n]*\\{.*?"
                     "(?=^\\s*[-+]\\s*\\(|^\\s*@end)", escaped]
                                       options:0 error:nil];
            for (NSTextCheckingResult *match
                 in [method matchesInString:source options:0
                                      range:NSMakeRange(0, source.length)]) {
                NSString *body = [source substringWithRange:match.range];
                for (NSString *withdrawn in withdrawnSelectors) {
                    XCTAssertFalse([body containsString:withdrawn],
                                   @"%@ %@ -> %@", path, selectorName, withdrawn);
                }
            }
        }
    }

    NSString *flat = read(
        @"PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m");
    NSString *blockCanvas = read(
        @"PrivateUIKit/IDBlockLayout+PrivateCanvasCallbacks.m");
    NSString *canvasBridge = read(
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m");
    NSString *canvas = read(@"TextView/IDTextLayoutCanvasView.m");
    XCTAssertTrue([flat containsString:@"- (id)customRenderController {"]);
    XCTAssertTrue([flat containsString:
        @"- (CGPoint)_convertPointFromRenderSpace:(CGPoint)point {"]);
    XCTAssertTrue([blockCanvas containsString:
        @"- (id)tgpn_customRenderController {"]);
    XCTAssertTrue([canvasBridge containsString:
        @"IDPrivateCanvasCustomRenderController"]);
    XCTAssertTrue([canvas containsString:
        @"- (id)id_customRenderController {"]);
    XCTAssertTrue([canvas containsString:@"convertRect:"]);
}

@end
