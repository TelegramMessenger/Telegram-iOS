@import XCTest;

#import "IDTextCanvasTestSupport.h"
#import "IDTextLayoutCanvasView.h"
#import "IDSpellingReadinessProbe.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"

@interface IDTextView (IDContinuousSpellingTesting)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
- (BOOL)isContinuousSpellCheckingEnabled;
@end

@interface IDSpellingIntegrationTests : XCTestCase
@property(nonatomic, strong) UIWindow *testWindow;
@end

@implementation IDSpellingIntegrationTests

- (void)tearDown {
    [self.testWindow resignKeyWindow];
    self.testWindow.hidden = YES;
    self.testWindow = nil;
    [super tearDown];
}

- (IDTextView *)installedEditableView {
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    self.testWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.testWindow.frame = CGRectMake(0, 0, 320, 240);
    UIViewController *controller = [UIViewController new];
    self.testWindow.rootViewController = controller;
    [self.testWindow makeKeyAndVisible];

    IDTextView *view = [[IDTextView alloc] initWithFrame:CGRectMake(10, 10, 300, 120)];
    view.spellCheckingType = UITextSpellCheckingTypeYes;
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    [controller.view addSubview:view];
    [controller.view layoutIfNeeded];
    [view layoutIfNeeded];
    return view;
}

- (BOOL)waitForRedMarkerInView:(IDTextView *)view {
    return IDWaitForCondition(3.0, ^BOOL{
        [view setNeedsLayout];
        [view layoutIfNeeded];
        [view.id_canvasView performViewportLayout];
        return IDCountRedPixels(IDRenderView(view.id_canvasView),
                                view.id_canvasView.bounds) > 0;
    });
}

- (void)testLeavingMisspelledWordRendersNativeTemporaryMarkerWithoutPersistentUnderline {
    if (!IDAssertEnglishCheckerAvailable(self)) return;
    IDTextView *view = [self installedEditableView];
    XCTAssertTrue([view becomeFirstResponder]);
    [view setContinuousSpellCheckingEnabled:YES];
    XCTAssertTrue(view.isContinuousSpellCheckingEnabled);
    [view insertText:@"mispelled "];

    XCTAssertTrue([self waitForRedMarkerInView:view]);

    NSDictionary *persistent = [view.id_textContentStorage.textStorage
        attributesAtIndex:1 effectiveRange:NULL];
    XCTAssertNil(persistent[NSUnderlineStyleAttributeName]);
    XCTAssertNil(persistent[NSUnderlineColorAttributeName]);
    UIImage *image = IDRenderView(view.id_canvasView);
    UITextPosition *wordEnd =
        [view positionFromPosition:view.beginningOfDocument offset:9];
    UITextRange *wordRange =
        [view textRangeFromPosition:view.beginningOfDocument toPosition:wordEnd];
    CGRect firstRect = [view firstRectForRange:wordRange];
    CGRect roi = CGRectIntersection(CGRectInset(firstRect, -3, -5), view.bounds);
    NSUInteger red = IDCountRedPixels(image, roi);
    IDAttachSpellingObservation(self, @"id-text-view-misspelled", @{
        @"role": @"custom",
        @"text": view.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect(firstRect),
        @"roi": NSStringFromCGRect(roi),
        @"redTotal": @(red),
        @"redRows": IDRedPixelCountsByRow(image, roi),
        @"temporaryRenderingAttributesObserved": @(red > 0),
    }, image);
}

- (void)testCorrectingMisspelledWordRemovesTemporaryMarker {
    if (!IDAssertEnglishCheckerAvailable(self)) return;
    IDTextView *view = [self installedEditableView];
    XCTAssertTrue([view becomeFirstResponder]);
    [view setContinuousSpellCheckingEnabled:YES];
    [view insertText:@"mispelled "];
    XCTAssertTrue([self waitForRedMarkerInView:view]);
    UITextPosition *end = [view positionFromPosition:view.beginningOfDocument offset:9];
    view.selectedTextRange = [view textRangeFromPosition:view.beginningOfDocument toPosition:end];
    [view replaceRange:view.selectedTextRange withText:@"misspelled"];
    XCTAssertTrue(IDWaitForCondition(3.0, ^BOOL{
        [view setNeedsLayout];
        [view layoutIfNeeded];
        [view.id_canvasView performViewportLayout];
        return IDCountRedPixels(IDRenderView(view.id_canvasView),
                                view.id_canvasView.bounds) == 0;
    }));
    UIImage *correctedImage = IDRenderView(view.id_canvasView);
    UITextPosition *correctedEnd =
        [view positionFromPosition:view.beginningOfDocument offset:10];
    UITextRange *correctedRange =
        [view textRangeFromPosition:view.beginningOfDocument
                         toPosition:correctedEnd];
    CGRect correctedRect = [view firstRectForRange:correctedRange];
    CGRect correctedROI =
        CGRectIntersection(CGRectInset(correctedRect, -3, -5), view.bounds);
    IDAttachSpellingObservation(self, @"id-text-view-corrected", @{
        @"role": @"custom",
        @"text": view.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @10 },
        @"firstRect": NSStringFromCGRect(correctedRect),
        @"roi": NSStringFromCGRect(correctedROI),
        @"redTotal": @(IDCountRedPixels(correctedImage, correctedROI)),
        @"redRows": IDRedPixelCountsByRow(correctedImage, correctedROI),
        @"temporaryRenderingAttributesObserved": @NO,
    }, correctedImage);
}

@end
