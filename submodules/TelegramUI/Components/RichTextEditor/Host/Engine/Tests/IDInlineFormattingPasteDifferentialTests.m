@import XCTest;
@import UniformTypeIdentifiers;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDTextInputStateRecorder.h"

@interface UIResponder (IDPasteDifferentialActions)
- (void)paste:(nullable id)sender;
@end

@interface IDBlockTextView (IDPasteDifferentialInputCallbacks)
- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text;
- (void)textInputDidChange:(id)input;
- (void)textInputDidChangeSelection:(id)input;
@end

@interface IDPasteOracleTextView : UITextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@end

@implementation IDPasteOracleTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

@end

@interface IDPasteDifferentialBlockTextView : IDBlockTextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@property(nonatomic, strong) NSMutableArray<NSString *> *id_callbackEvents;
@end

@implementation IDPasteDifferentialBlockTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

- (NSMutableArray<NSString *> *)id_callbackEvents {
    if (_id_callbackEvents == nil) {
        _id_callbackEvents = [NSMutableArray array];
    }
    return _id_callbackEvents;
}

- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text {
    [self.id_callbackEvents addObject:@"should"];
    return [super textInput:input
        shouldChangeCharactersInRanges:ranges
                   replacementText:text];
}

- (void)textInputDidChange:(id)input {
    [self.id_callbackEvents addObject:@"change"];
    [super textInputDidChange:input];
}

- (void)textInputDidChangeSelection:(id)input {
    [self.id_callbackEvents addObject:@"selection"];
    [super textInputDidChangeSelection:input];
}

@end

@interface IDPasteDifferentialDelegate : NSObject <UITextViewDelegate>
@property(nonatomic, strong) NSMutableArray<NSString *> *events;
@end

@implementation IDPasteDifferentialDelegate

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _events = [NSMutableArray array];
    }
    return self;
}

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
    [self.events addObject:@"should"];
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self.events addObject:@"change"];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    [self.events addObject:@"selection"];
}

@end

@interface IDInlineFormattingPasteDifferentialTests : XCTestCase
@property(nonatomic, strong) UIWindow *testWindow;
@property(nonatomic, strong) IDPasteOracleTextView *stock;
@property(nonatomic, strong) IDPasteDifferentialBlockTextView *custom;
@property(nonatomic, strong) IDPasteDifferentialDelegate *stockDelegate;
@end

@implementation IDInlineFormattingPasteDifferentialTests

- (void)clearEditors {
    [self.stock resignFirstResponder];
    [self.custom resignFirstResponder];
    [self.stock removeFromSuperview];
    [self.custom removeFromSuperview];
    self.stock.delegate = nil;
    self.stock = nil;
    self.custom = nil;
    self.stockDelegate = nil;
    UIPasteboard.generalPasteboard.items = @[];
    self.testWindow.hidden = YES;
    self.testWindow = nil;
}

- (void)tearDown {
    [self clearEditors];
    [super tearDown];
}

- (NSDictionary<NSAttributedStringKey, id> *)baseAttributes {
    return @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.blackColor,
    };
}

- (NSDictionary<NSAttributedStringKey, id> *)boldAttributes {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *descriptor = [font.fontDescriptor
        fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return @{
        NSFontAttributeName:
            [UIFont fontWithDescriptor:descriptor size:font.pointSize],
        NSForegroundColorAttributeName: UIColor.blackColor,
    };
}

- (NSDictionary<NSAttributedStringKey, id> *)richAttributes {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *descriptor = [font.fontDescriptor
        fontDescriptorWithSymbolicTraits:
            UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic];
    return @{
        NSFontAttributeName:
            [UIFont fontWithDescriptor:descriptor size:font.pointSize],
        NSForegroundColorAttributeName: UIColor.blackColor,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
    };
}

- (UIWindowScene *)windowScene {
    for (UIScene *scene in
         UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (void)installEditorsWithSmartInsertDeleteType:
    (UITextSmartInsertDeleteType)smartType {
    UIWindowScene *scene = [self windowScene];
    XCTAssertNotNil(scene);
    self.testWindow = [[UIWindow alloc] initWithWindowScene:scene];
    self.testWindow.frame = CGRectMake(0, 0, 700, 360);
    UIViewController *controller = [UIViewController new];
    self.testWindow.rootViewController = controller;

    self.stock = [[IDPasteOracleTextView alloc]
        initWithFrame:CGRectMake(20, 30, 280, 240)];
    self.stock.font = [UIFont systemFontOfSize:17.0];
    self.stock.textColor = UIColor.blackColor;
    self.stock.backgroundColor = UIColor.whiteColor;
    self.stock.textContainerInset = UIEdgeInsetsMake(11, 9, 13, 9);
    self.stock.smartInsertDeleteType = smartType;
    self.stock.attributedText = [[NSAttributedString alloc]
        initWithString:@"A" attributes:self.baseAttributes];
    self.stock.selectedRange = NSMakeRange(1, 0);
    self.stockDelegate = [IDPasteDifferentialDelegate new];
    self.stock.delegate = self.stockDelegate;

    self.custom = [[IDPasteDifferentialBlockTextView alloc]
        initWithFrame:CGRectMake(360, 30, 280, 240)
      attributedBlocks:@[
          [[NSAttributedString alloc]
              initWithString:@"A" attributes:self.baseAttributes],
      ]];
    self.custom.font = [UIFont systemFontOfSize:17.0];
    self.custom.textColor = UIColor.blackColor;
    self.custom.backgroundColor = UIColor.whiteColor;
    self.custom.textContainerInset = UIEdgeInsetsMake(11, 9, 13, 9);
    self.custom.smartInsertDeleteType = smartType;
    UITextPosition *end = self.custom.endOfDocument;
    self.custom.selectedTextRange =
        [self.custom textRangeFromPosition:end toPosition:end];

    [controller.view addSubview:self.stock];
    [controller.view addSubview:self.custom];
    [self.testWindow makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [self.stock layoutIfNeeded];
    [self.custom layoutIfNeeded];
}

- (NSData *)richRTFData {
    NSAttributedString *rich = [[NSAttributedString alloc]
        initWithString:@"X" attributes:self.richAttributes];
    NSError *error = nil;
    NSData *data = [rich dataFromRange:NSMakeRange(0, rich.length)
                    documentAttributes:@{
                        NSDocumentTypeDocumentAttribute:
                            NSRTFTextDocumentType,
                    }
                                 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    return data;
}

- (NSArray<NSDictionary<NSString *, id> *> *)pasteboardItemsForRich:
    (BOOL)rich {
    if (!rich) {
        return @[@{UTTypePlainText.identifier: @"X"}];
    }
    NSData *data = [self richRTFData];
    return data == nil
        ? @[]
        : @[@{UTTypeRTF.identifier: data}];
}

- (BOOL)waitForTextChangeInEditor:(id)editor {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while ([[editor text] isEqualToString:@"A"] &&
           deadline.timeIntervalSinceNow > 0) {
        [NSRunLoop.mainRunLoop
            runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return ![[editor text] isEqualToString:@"A"];
}

- (NSRange)customSelection {
    UITextRange *selection = self.custom.selectedTextRange;
    NSInteger location = [self.custom
        offsetFromPosition:self.custom.beginningOfDocument
                toPosition:selection.start];
    NSInteger length = [self.custom
        offsetFromPosition:selection.start
                toPosition:selection.end];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (NSDictionary<NSString *, id> *)stockSnapshot {
    return @{
        @"text": self.stock.text ?: @"",
        @"selection": NSStringFromRange(self.stock.selectedRange),
        @"runs": IDNormalizedInlineRuns(self.stock.textStorage),
        @"typing": IDNormalizedInlineTraitNames(
            self.stock.typingAttributes ?: @{}),
        @"canUndo": @(self.stock.undoManager.canUndo),
        @"callbacks": self.stockDelegate.events.copy,
    };
}

- (NSDictionary<NSString *, id> *)customSnapshot {
    UITextRange *wholeRange = [self.custom
        textRangeFromPosition:self.custom.beginningOfDocument
                   toPosition:self.custom.endOfDocument];
    NSAttributedString *presentation =
        [self.custom.id_richLayoutController
            id_attributedTextInRange:wholeRange];
    NSTextStorage *storage = [[NSTextStorage alloc]
        initWithAttributedString:presentation];
    return @{
        @"text": self.custom.text ?: @"",
        @"selection": NSStringFromRange([self customSelection]),
        @"runs": IDNormalizedInlineRuns(storage),
        @"typing": IDNormalizedInlineTraitNames(
            IDPrivateInputTypingAttributes(
                self.custom.id_inputController)),
        @"canUndo": @(self.custom.undoManager.canUndo),
        @"callbacks": self.custom.id_callbackEvents.copy,
    };
}

- (void)assertPasteParityWithSmartInsertDeleteType:
    (UITextSmartInsertDeleteType)smartType
                                         rich:(BOOL)rich {
    [self installEditorsWithSmartInsertDeleteType:smartType];
    self.stock.allowsEditingTextAttributes = rich;
    NSArray<NSDictionary<NSString *, id> *> *items =
        [self pasteboardItemsForRich:rich];
    NSString *row = [NSString stringWithFormat:@"smart=%ld rich=%@",
        (long)smartType, rich ? @"YES" : @"NO"];

    if (!rich) {
        self.stock.typingAttributes = self.boldAttributes;
        [self.custom toggleInlineTextTrait:IDInlineTextTraitBold];
    }

    XCTAssertTrue([self.stock becomeFirstResponder], @"%@", row);
    [self.stockDelegate.events removeAllObjects];
    UIPasteboard.generalPasteboard.items = items;
    [self.stock paste:nil];
    XCTAssertTrue([self waitForTextChangeInEditor:self.stock], @"%@", row);
    [self.stock resignFirstResponder];

    XCTAssertTrue([self.custom becomeFirstResponder], @"%@", row);
    [self.custom.id_callbackEvents removeAllObjects];
    UIPasteboard.generalPasteboard.items = items;
    [self.custom paste:nil];
    XCTAssertTrue([self waitForTextChangeInEditor:self.custom], @"%@", row);

    NSDictionary<NSString *, id> *stock = [self stockSnapshot];
    NSDictionary<NSString *, id> *custom = [self customSnapshot];
    NSLog(@"IDPasteDifferential %@ stock=%@ custom=%@",
          row, stock, custom);
    for (NSString *key in @[
        @"text", @"selection", @"runs", @"typing",
        @"canUndo", @"callbacks",
    ]) {
        XCTAssertEqualObjects(custom[key], stock[key],
                              @"%@ key=%@", row, key);
    }

    XCTAssertTrue(self.stock.undoManager.canUndo, @"%@", row);
    XCTAssertTrue(self.custom.undoManager.canUndo, @"%@", row);
    [self.stock.undoManager undo];
    [self.custom.undoManager undo];
    XCTAssertEqualObjects(self.custom.text, self.stock.text, @"%@", row);
    XCTAssertEqualObjects(self.custom.text, @"A", @"%@", row);

    [self clearEditors];
}

- (void)testSmartInsertDeletePasteMatrixMatchesStock {
    for (NSNumber *smartValue in @[
        @(UITextSmartInsertDeleteTypeNo),
        @(UITextSmartInsertDeleteTypeYes),
    ]) {
        for (NSNumber *richValue in @[@NO, @YES]) {
            [self
                assertPasteParityWithSmartInsertDeleteType:
                    (UITextSmartInsertDeleteType)smartValue.integerValue
                                                   rich:richValue.boolValue];
        }
    }
}

@end
