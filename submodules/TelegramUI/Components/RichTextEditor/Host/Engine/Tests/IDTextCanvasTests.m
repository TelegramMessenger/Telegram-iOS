@import XCTest;

#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

@interface IDTextView (IDCanvasPrivateCallbackTesting)
- (UIView *)textInputView;
@end

@interface IDTextCanvasTests : XCTestCase
@end

@implementation IDTextCanvasTests

- (void)testEditorOwnsTextKit2StackAndCanvas {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    XCTAssertNotNil(view.id_textContentStorage);
    XCTAssertNotNil(view.id_textLayoutManager);
    XCTAssertNotNil(view.id_textContainer);
    XCTAssertNotNil(view.id_canvasView);
    XCTAssertTrue([view.id_textLayoutManager.textContentManager isEqual:view.id_textContentStorage]);
}

- (void)testEditorRegistersItsCanvasAsThePrivateTextInputView {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];

    XCTAssertEqual(IDPrivateRegisteredTextLayoutCanvas(view.id_layoutController,
                                                        view.id_textContainer),
                   view.id_canvasView);
    XCTAssertEqual([view textInputView], view.id_canvasView);
}

- (void)testPlainTextPropertiesApplyUniformly {
    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    view.text = @"alpha\nbeta";
    view.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    view.textColor = UIColor.systemRedColor;
    view.textAlignment = NSTextAlignmentCenter;

    NSAttributedString *value = view.id_textContentStorage.textStorage;
    [value enumerateAttributesInRange:NSMakeRange(0, value.length)
                              options:0
                           usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes,
                                        NSRange range,
                                        BOOL *stop) {
        XCTAssertEqualObjects(attributes[NSFontAttributeName], view.font);
        XCTAssertEqualObjects(attributes[NSForegroundColorAttributeName], view.textColor);
        XCTAssertEqual([attributes[NSParagraphStyleAttributeName] alignment], NSTextAlignmentCenter);
    }];
}

@end
