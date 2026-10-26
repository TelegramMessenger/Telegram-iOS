@import XCTest;

#import "IDTextInputStateRecorder.h"

@interface IDInlineFormattingOracleTextView : UITextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@end

@implementation IDInlineFormattingOracleTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

@end

@interface IDInlineFormattingStockOracleTests : XCTestCase
@property(nonatomic, weak) UIWindow *window;
@property(nonatomic, strong) IDInlineFormattingOracleTextView *view;
@end

@implementation IDInlineFormattingStockOracleTests

- (void)setUp {
    [super setUp];
    UIWindowScene *scene = nil;
    for (UIScene *candidate in
         UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    XCTAssertNotNil(scene);
    self.window = scene.keyWindow;
    XCTAssertNotNil(self.window);
    XCTAssertNotNil(self.window.rootViewController);
    self.view = [[IDInlineFormattingOracleTextView alloc]
        initWithFrame:CGRectMake(20, 100, 350, 500)];
    self.view.font = [UIFont systemFontOfSize:17.0];
    [self.window.rootViewController.view addSubview:self.view];
    XCTAssertTrue([self.view becomeFirstResponder]);
}

- (void)tearDown {
    [self.view resignFirstResponder];
    [self.view removeFromSuperview];
    self.view = nil;
    self.window = nil;
    [super tearDown];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesWithBold:(BOOL)bold
                                                        italic:(BOOL)italic
                                                     underline:(BOOL)underline
                                                        strike:(BOOL)strike {
    UIFontDescriptorSymbolicTraits traits = 0;
    if (bold) traits |= UIFontDescriptorTraitBold;
    if (italic) traits |= UIFontDescriptorTraitItalic;
    UIFontDescriptor *descriptor =
        [[UIFont systemFontOfSize:17.0].fontDescriptor
            fontDescriptorWithSymbolicTraits:traits];
    NSMutableDictionary<NSAttributedStringKey, id> *attributes =
        [@{NSFontAttributeName:
               [UIFont fontWithDescriptor:descriptor size:17.0]}
            mutableCopy];
    if (underline) {
        attributes[NSUnderlineStyleAttributeName] =
            @(NSUnderlineStyleSingle);
    }
    if (strike) {
        attributes[NSStrikethroughStyleAttributeName] =
            @(NSUnderlineStyleSingle);
    }
    return attributes.copy;
}

- (NSDictionary<NSString *, id> *)snapshot:(NSString *)phase {
    NSDictionary *snapshot = @{
        @"phase": phase,
        @"text": self.view.text ?: @"",
        @"selection": NSStringFromRange(self.view.selectedRange),
        @"typing":
            IDNormalizedInlineTraitNames(self.view.typingAttributes ?: @{}),
        @"runs": IDNormalizedInlineRuns(self.view.textStorage),
        @"canUndo": @(self.view.undoManager.canUndo),
        @"canRedo": @(self.view.undoManager.canRedo),
    };
    NSLog(@"IDInlineFormattingStockOracle %@", snapshot);
    return snapshot;
}

- (void)testStockCaretTypingAttributesAtStartInteriorEndAndMixedBoundary {
    self.view.text = @"abcd";
    [self.view.textStorage
        setAttributes:[self attributesWithBold:YES
                                        italic:NO
                                     underline:NO
                                        strike:NO]
                range:NSMakeRange(0, 2)];
    [self.view.textStorage
        setAttributes:[self attributesWithBold:NO
                                        italic:YES
                                     underline:NO
                                        strike:NO]
                range:NSMakeRange(2, 2)];

    NSMutableArray *snapshots = [NSMutableArray array];
    for (NSNumber *offset in @[@0, @1, @2, @4]) {
        self.view.selectedRange =
            NSMakeRange(offset.unsignedIntegerValue, 0);
        [snapshots addObject:
            [self snapshot:[@"caret-" stringByAppendingString:
                offset.stringValue]]];
    }

    XCTAssertEqualObjects([snapshots valueForKey:@"selection"],
                          (@[@"{0, 0}", @"{1, 0}",
                             @"{2, 0}", @"{4, 0}"]));
    XCTAssertEqualObjects([snapshots[0] objectForKey:@"text"], @"abcd");
}

- (void)testStockExplicitCaretToggleThenInsertAndReturn {
    self.view.text = @"ab";
    self.view.selectedRange = NSMakeRange(1, 0);
    self.view.typingAttributes =
        [self attributesWithBold:YES
                          italic:NO
                       underline:NO
                          strike:NO];
    NSMutableArray *snapshots =
        [NSMutableArray arrayWithObject:[self snapshot:@"explicit-bold"]];

    [self.view insertText:@"X"];
    [snapshots addObject:[self snapshot:@"insert-X"]];
    [self.view insertText:@"\n"];
    [snapshots addObject:[self snapshot:@"insert-return"]];
    [self.view insertText:@"Y"];
    [snapshots addObject:[self snapshot:@"insert-Y"]];

    XCTAssertEqualObjects(self.view.text, @"aX\nYb");
    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(
            [self.view.textStorage attributesAtIndex:1
                                      effectiveRange:NULL]),
        (@[@"bold"]));
    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(
            [self.view.textStorage attributesAtIndex:3
                                      effectiveRange:NULL]),
        (@[]));
    XCTAssertEqualObjects([snapshots[2] objectForKey:@"typing"], (@[]));
    XCTAssertEqualObjects([snapshots[3] objectForKey:@"typing"], (@[]));
    XCTAssertEqualObjects(
        [IDNormalizedInlineRuns(self.view.textStorage)[2]
            objectForKey:@"traits"],
        (@[]));
    XCTAssertEqual(snapshots.count, 4U);
}

- (void)testStockSelectionReplacementFormatting {
    self.view.text = @"abcd";
    self.view.selectedRange = NSMakeRange(1, 2);
    self.view.typingAttributes =
        [self attributesWithBold:NO
                          italic:YES
                       underline:YES
                          strike:NO];
    [self snapshot:@"selected"];
    [self.view insertText:@"Z"];
    NSDictionary *snapshot = [self snapshot:@"replaced"];

    XCTAssertEqualObjects(self.view.text, @"aZd");
    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(
            [self.view.textStorage attributesAtIndex:1
                                      effectiveRange:NULL]),
        (@[@"italic", @"underline"]));
    XCTAssertEqualObjects(snapshot[@"selection"], @"{2, 0}");
}

- (void)testStockExplicitTypingOverrideMovementAndReturnAtEnd {
    self.view.text = @"ab";
    [self.view.textStorage
        setAttributes:[self attributesWithBold:NO
                                        italic:YES
                                     underline:NO
                                        strike:NO]
                range:NSMakeRange(1, 1)];
    self.view.selectedRange = NSMakeRange(0, 0);
    self.view.typingAttributes =
        [self attributesWithBold:YES
                          italic:NO
                       underline:NO
                          strike:NO];
    NSDictionary *explicit = [self snapshot:@"movement-explicit-bold"];

    self.view.selectedRange = NSMakeRange(2, 0);
    NSDictionary *moved = [self snapshot:@"movement-to-italic-end"];

    self.view.typingAttributes =
        [self attributesWithBold:YES
                          italic:NO
                       underline:NO
                          strike:NO];
    [self.view insertText:@"\n"];
    NSDictionary *returned = [self snapshot:@"return-at-end"];
    [self.view insertText:@"Y"];
    NSDictionary *typed = [self snapshot:@"type-after-end-return"];

    XCTAssertEqualObjects(explicit[@"typing"], (@[@"bold"]));
    XCTAssertEqualObjects(moved[@"typing"], (@[@"italic"]));
    XCTAssertEqualObjects(self.view.text, @"ab\nY");
    XCTAssertEqualObjects(returned[@"selection"], @"{3, 0}");
    XCTAssertEqualObjects(returned[@"typing"], (@[@"bold"]));
    XCTAssertEqualObjects(typed[@"selection"], @"{4, 0}");
    XCTAssertEqualObjects(typed[@"typing"], (@[@"bold"]));
    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(
            [self.view.textStorage attributesAtIndex:3
                                      effectiveRange:NULL]),
        (@[@"bold"]));
}

- (void)testStockDeleteAcrossRunBoundaryReconcilesTypingAttributes {
    self.view.text = @"ab";
    [self.view.textStorage
        setAttributes:[self attributesWithBold:YES
                                        italic:NO
                                     underline:NO
                                        strike:NO]
                range:NSMakeRange(0, 1)];
    [self.view.textStorage
        setAttributes:[self attributesWithBold:NO
                                        italic:YES
                                     underline:NO
                                        strike:NO]
                range:NSMakeRange(1, 1)];
    self.view.selectedRange = NSMakeRange(1, 0);
    NSDictionary *before = [self snapshot:@"before-delete"];
    [self.view deleteBackward];
    NSDictionary *after = [self snapshot:@"after-delete"];

    XCTAssertEqualObjects(self.view.text, @"b");
    XCTAssertEqualObjects(after[@"selection"], @"{0, 0}");
    XCTAssertNotEqualObjects(before[@"runs"], after[@"runs"]);
}

- (void)testStockUndoRedoRestoresFormattingAndTypingState {
    self.view.text = @"ab";
    self.view.selectedRange = NSMakeRange(1, 0);
    self.view.typingAttributes =
        [self attributesWithBold:YES
                          italic:NO
                       underline:NO
                          strike:YES];
    [self.view.undoManager beginUndoGrouping];
    [self.view insertText:@"X"];
    [self.view.undoManager endUndoGrouping];
    NSDictionary *inserted = [self snapshot:@"inserted"];

    XCTAssertTrue(self.view.undoManager.canUndo);
    [self.view.undoManager undo];
    NSDictionary *undone = [self snapshot:@"undone"];
    XCTAssertEqualObjects(self.view.text, @"ab");
    XCTAssertTrue(self.view.undoManager.canRedo);

    [self.view.undoManager redo];
    NSDictionary *redone = [self snapshot:@"redone"];
    XCTAssertEqualObjects(self.view.text, @"aXb");
    XCTAssertEqualObjects(inserted[@"runs"], redone[@"runs"]);
    XCTAssertNotEqualObjects(inserted[@"runs"], undone[@"runs"]);
}

@end
