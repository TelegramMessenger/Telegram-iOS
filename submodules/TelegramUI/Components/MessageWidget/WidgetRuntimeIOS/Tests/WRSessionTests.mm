// The session facade (M1d plan, Task 7): boot, steps, taps, the bridge, the stops, the source cap, the failure latch
// and teardown, through the Objective-C surface Swift calls.
#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import <WidgetRuntimeIOS/WRSession.h>

#include <algorithm>
#include <atomic>
#include <string>
#include <thread>
#include <vector>

@interface WRRecordingDelegate : NSObject <WRSessionDelegate>
@property (nonatomic) NSMutableArray<NSString *> *diagnostics;
@property (nonatomic) NSMutableArray<NSString *> *bridgeCalls;
/// Each storage commit as "area key=value key=value", in order.
@property (nonatomic) NSMutableArray<NSString *> *storageCommits;
@property (nonatomic) uint64_t lastWork;
@property (nonatomic) NSUInteger workReports;
/// Called from each work report, inside the step that reports it.
@property (nonatomic, copy) void (^onWork)(WRSession *session);
@end

@implementation WRRecordingDelegate
- (instancetype)init {
    if ((self = [super init])) {
        _diagnostics = [NSMutableArray array];
        _bridgeCalls = [NSMutableArray array];
        _storageCommits = [NSMutableArray array];
    }
    return self;
}
- (void)session:(WRSession *)session diagnostic:(NSString *)kind detail:(NSString *)detail {
    [self.diagnostics addObject:[NSString stringWithFormat:@"%@:%@", kind, detail]];
}
- (void)session:(WRSession *)session log:(NSInteger)level text:(NSString *)text {
}
- (void)session:(WRSession *)session bridge:(NSString *)method args:(NSString *)argsJson {
    [self.bridgeCalls addObject:[NSString stringWithFormat:@"%@ %@", method, argsJson]];
}
- (void)session:(WRSession *)session storageCommit:(NSString *)area entries:(NSArray<NSArray<NSString *> *> *)entries {
    NSMutableString* line = [area mutableCopy];
    for (NSArray<NSString *>* entry in entries) {
        [line appendFormat:@" %@=%@", entry[0], entry[1]];
    }
    [self.storageCommits addObject:line];
}
- (void)session:(WRSession *)session didWork:(uint64_t)totalUnits {
    self.lastWork = totalUnits;
    self.workReports++;
    if (self.onWork) {
        self.onWork(session);
    }
}
@end

namespace {

double now() {
    return CACurrentMediaTime() * 1000;
}

// The colour (RGBA) at a CSS px point of a tree painted at 2×.
std::vector<uint8_t> colourAt(WRTree* tree, CGFloat x, CGFloat y) {
    CGImageRef image = [tree copyImageOfRect:CGRectMake(x, y, 1, 1) scale:2 effects:nil];
    std::vector<uint8_t> pixel(4 * 4, 0);
    if (!image) {
        return pixel;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixel.data(), 2, 2, 8, 8, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, 2, 2), image);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    CGImageRelease(image);
    return pixel;
}

void drain(WRSession* session) {
    for (int i = 0; i < 1000 && [session hasRunnableTaskAt:now()]; i++) {
        [session setWorkLimitAfter:28000000];
        [session runNextTaskAt:now()];
    }
}

} // namespace

@interface WRSession (Testing)
/// Throws a C++ exception inside a guarded call (WRSession.mm).
- (void)throwForTesting;
/// Latches `reason` on the runtime outside any step, as a refused allocation in an entry that queues a task does.
- (void)stopForTesting:(WRStopReason)reason;
@end

@interface WRSessionTests : XCTestCase
@end

@implementation WRSessionTests

- (WRSession*)sessionWith:(WRRecordingDelegate*)delegate {
    return [[WRSession alloc] initWithWidth:300 dark:NO scale:2 delegate:delegate];
}

- (void)testBootRendersAndSizes {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head>"
                                            "<body><div style=\"width:200px;height:80px;background:#ff0000\"></div>"
                                            "</body></html>"]);
    // The author's `body{margin:0}` wins over the host's `body { margin: 8px }` (LHDocument's MasterWithCSS): the box
    // alone.
    XCTAssertEqualWithAccuracy(session.contentSize.width, 200, 0.5);
    XCTAssertEqualWithAccuracy(session.contentSize.height, 80, 0.5);
    WRTree* tree = [session tree];
    XCTAssertNotNil(tree);
    std::vector<uint8_t> pixel = colourAt(tree, 100, 40);
    XCTAssertEqual(pixel[0], 255);
    XCTAssertEqual(pixel[1], 0);
    XCTAssertEqual(pixel[3], 255);
    XCTAssertNil([session changedRects]);
}

/// The conformance runner reads a widget's result from its `<html data-conformance>` attribute (widget-sandbox v0.1.0,
/// CLIENTS.md): the live DOM's value, no script run and nothing charged.
- (void)testDocumentElementAttributeReadsTheLiveDOM {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html data-test=\"fixture\"><head></head><body><script>"
                                            "setTimeout(() => document.documentElement.setAttribute('data-conformance', "
                                            "'{\"status\":\"done\"}'), 10);</script></body></html>"]);
    XCTAssertEqualObjects([session documentElementAttribute:@"data-test"], @"fixture");
    XCTAssertNil([session documentElementAttribute:@"data-conformance"]);
    // No script runs: only the name's string is allocated in the widget's heap (a few units).
    uint64_t before = session.workUnits;
    XCTAssertEqualObjects([session documentElementAttribute:@"data-test"], @"fixture");
    XCTAssertLessThan(session.workUnits - before, uint64_t(1000));
    NSNumber* deadline = [session nextTimerDeadline];
    XCTAssertNotNil(deadline);
    [session setWorkLimitAfter:28000000];
    [session runNextTaskAt:deadline.doubleValue + 1];
    XCTAssertEqualObjects([session documentElementAttribute:@"data-conformance"], @"{\"status\":\"done\"}");
    [session teardown];
    XCTAssertNil([session documentElementAttribute:@"data-test"]);
}

/// A step whose script queries the layout mid-step publishes twice (the query's flush, then the step's own): its changed
/// rects are the union of both publishes, or the first change's tiles are never redrawn (V3 plan, Task 3).
- (void)testChangedRectsOfAStepAreTheUnionOfItsPublishes {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                                            "<div id=a style=\"height:40px\">a</div><div id=b style=\"height:40px\">b</div>"
                                            "<script>setTimeout(() => { const a = document.getElementById('a'), "
                                            "b = document.getElementById('b'); a.setAttribute('style', 'height:40px;background:#f00'); "
                                            "a.offsetHeight; b.setAttribute('style', 'height:40px;background:#00f'); }, 10);"
                                            "</script></body></html>"]);
    XCTAssertNil([session changedRects]);
    NSNumber* deadline = [session nextTimerDeadline];
    XCTAssertNotNil(deadline);
    [session setWorkLimitAfter:28000000];
    [session runNextTaskAt:deadline.doubleValue + 1];
    NSArray<NSValue*>* rects = [session changedRects];
    XCTAssertNotNil(rects);
    BOOL coversA = NO, coversB = NO;
    for (NSValue* value in rects) {
        // Away from the 40 px boundary, which each rect's 2 px padding crosses.
        coversA = coversA || CGRectIntersectsRect(value.CGRectValue, CGRectMake(0, 0, 300, 30));
        coversB = coversB || CGRectIntersectsRect(value.CGRectValue, CGRectMake(0, 50, 300, 30));
    }
    XCTAssertTrue(coversA, @"%@", rects);
    XCTAssertTrue(coversB, @"%@", rects);
}

- (void)testHangingBootShowsTheParsedMarkupFrozen {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                                            "<p style=\"margin:0;background:#00ff00\">"
                                            "hi</p><script>for(;;);</script></body></html>"]);
    XCTAssertEqual(session.stopReason, WRStopReasonBudget);
    WRTree* tree = [session tree];
    XCTAssertNotNil(tree);
    XCTAssertGreaterThan(tree.size.height, 0);
    std::vector<uint8_t> pixel = colourAt(tree, 50, 10);
    XCTAssertEqual(pixel[1], 255);
}

- (void)testTasksTimersAndFrames {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "setTimeout(() => TelegramWidget.ready(), 50);"
                                            "requestAnimationFrame(() => TelegramWidget.ready());"
                                            "</script></body></html>"]);
    NSNumber* deadline = [session nextTimerDeadline];
    XCTAssertNotNil(deadline);
    XCTAssertTrue([session wantsAnimationFrame]);
    [session setWorkLimitAfter:28000000];
    [session runAnimationFrameAt:now()];
    // The frame's call (a link would need a press: SDK v1 §2.5).
    XCTAssertEqualObjects(delegate.bridgeCalls, (@[ @"ready []" ]));
    [session setWorkLimitAfter:28000000];
    XCTAssertEqual([session runNextTaskAt:deadline.doubleValue + 1], WRStepResultRan);
    XCTAssertEqualObjects(delegate.bridgeCalls, (@[ @"ready []", @"ready []" ]));
}

- (void)testPointerTapClicks {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0;padding:0} button{position:"
                                            "absolute;left:0;top:0;width:100px;height:40px}</style></head><body><button "
                                            "onclick=\"TelegramWidget.openLink('https://example.org/tapped')\">b</button></body></html>"]);
    [session pointer:WRPointerPhaseDown at:CGPointMake(50, 20) pointerId:1 primary:YES];
    [session pointer:WRPointerPhaseUp at:CGPointMake(50, 20) pointerId:1 primary:YES];
    drain(session);
    XCTAssertTrue([delegate.bridgeCalls containsObject:@"openLink [\"https://example.org/tapped\"]"]);
}

/// sdk-v1 §5.5: a press reports the drag axes and the hold the widget takes (touch-action: none claims the hold too,
/// widget-sandbox v0.1.2; never the vertical axis, v0.1.3) and whether it takes taps, once its down task has run.
- (void)testAPressReportsItsGestureClaim {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0;padding:0} div{position:"
                                            "absolute;top:0;width:40px;height:40px}</style></head><body>"
                                            "<div style='left:0'></div><div style='left:50px;touch-action:pan-y'></div>"
                                            "<div style='left:100px;touch-action:none'></div>"
                                            "<button style='position:absolute;top:0;left:150px;width:40px;height:40px;padding:0;border:0'></button>"
                                            "</body></html>"]);
    XCTAssertEqual(session.gestureClaim, (WRGestureAxes)0);
    XCTAssertFalse(session.pressTakesTaps);
    const CGFloat xs[] = {20, 70, 120, 170};
    const WRGestureAxes expected[] = {0, WRGestureAxesHorizontal, WRGestureAxesHorizontal | WRGestureAxesHold, 0};
    const BOOL takesTaps[] = {NO, YES, YES, YES};
    for (int i = 0; i < 4; i++) {
        [session pointer:WRPointerPhaseDown at:CGPointMake(xs[i], 20) pointerId:1 primary:YES];
        drain(session);
        XCTAssertEqual(session.gestureClaim, expected[i]);
        XCTAssertEqual(session.pressTakesTaps, takesTaps[i]);
        [session pointer:WRPointerPhaseUp at:CGPointMake(xs[i], 20) pointerId:1 primary:YES];
        drain(session);
    }
}

/// widget-sandbox v0.1.3 (sdk-v1 §2.12): the session reports the widget's resize anchor with its height, `top` until the
/// widget sets one.
- (void)testTheSessionReportsTheAnchor {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* plain = [self sessionWith:delegate];
    XCTAssertTrue([plain bootWithSource:@"<!doctype html><html><body><p>top</p></body></html>"]);
    XCTAssertEqual(plain.resizeAnchor, WRResizeAnchorTop);
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><body><p>up</p><script>TelegramWidget.setResizeAnchor('bottom');"
                                            "</script></body></html>"]);
    drain(session);
    XCTAssertEqual(session.resizeAnchor, WRResizeAnchorBottom);
}

static std::vector<WRSelectableRun> runsOf(WRSelectableText* text) {
    std::vector<WRSelectableRun> runs(text.runs.length / sizeof(WRSelectableRun));
    if (!runs.empty()) {
        [text.runs getBytes:runs.data() length:runs.size() * sizeof(WRSelectableRun)];
    }
    return runs;
}

static std::vector<float> caretsOf(WRSelectableText* text, const WRSelectableRun& run) {
    std::vector<float> carets(run.length + 1);
    [text.carets getBytes:carets.data() range:NSMakeRange(run.caretIndex * sizeof(float), carets.size() * sizeof(float))];
    return carets;
}

static WRSelectableText* selectable(WRSession* session, NSString* body) {
    NSString* source = [NSString stringWithFormat:@"<!doctype html><html><head><style>body{margin:0} p{margin:0}</style></head>"
                                                  "<body>%@</body></html>", body];
    if (![session bootWithSource:source]) {
        return nil;
    }
    return [session selectableTextWithBudget:UINT64_MAX visibleHeight:600];
}

/// Text selection (sdk-v1 §5.10): the session exports what the widget marked user-select: text (visual/16-selection).
- (void)testTheSelectableTextIsTheMarkedText {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    WRSelectableText* text = selectable(session, @"<div style='user-select:text'>You can select this sentence, <b>this bold "
                                                 "word</b> too, and copy it.</div><div>This sentence cannot be selected.</div>");
    XCTAssertEqualObjects(text.text, @"You can select this sentence, this bold word too, and copy it.");
    XCTAssertGreaterThan(runsOf(text).size(), 0u);
}

/// Each run's caret offsets start at 0, rise, and end where layout measured the word, on both of LHContainer's drawing
/// paths: the simple shaper (at most 64 printable ASCII bytes) and the CTLine.
- (void)testCaretOffsetsMatchTheDrawnGlyphs {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    NSString* longWord = [@"" stringByPaddingToLength:80 withString:@"abcdefgh" startingAtIndex:0];
    WRSelectableText* text = selectable(session, [NSString stringWithFormat:@"<p style='user-select:text;width:2000px'>"
                                                                            "simpleword %@</p>", longWord]);
    const std::vector<WRSelectableRun> runs = runsOf(text);
    XCTAssertEqual(runs.size(), 2u);
    for (const WRSelectableRun& run : runs) {
        const std::vector<float> carets = caretsOf(text, run);
        XCTAssertEqualWithAccuracy(carets.front(), 0, 0.01);
        for (size_t i = 1; i < carets.size(); i++) {
            XCTAssertGreaterThan(carets[i], carets[i - 1]);
        }
        XCTAssertEqualWithAccuracy(carets.back(), run.box.size.width, 0.5);
    }
}

/// Review Focus 1: a boundary inside a surrogate pair is at the pair's start, so nothing lands between its halves.
- (void)testCaretOffsetsOfAnEmojiPair {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    WRSelectableText* text = selectable(session, @"<p style='user-select:text'>a\U0001F600b</p>");
    const std::vector<WRSelectableRun> runs = runsOf(text);
    XCTAssertEqual(runs.size(), 1u);
    if (runs.size() == 1) {
        const std::vector<float> carets = caretsOf(text, runs[0]);
        XCTAssertEqual(carets.size(), 5u);
        XCTAssertEqual(carets[2], carets[1]);
        XCTAssertGreaterThan(carets[3], carets[1]);
    }
}

/// Review Focus 3: a right-to-left word's offsets descend from its right edge.
- (void)testAnRTLRunMapsPointsToItsCharacters {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    WRSelectableText* text = selectable(session, @"<p dir=rtl style='user-select:text'>שלום</p>");
    const std::vector<WRSelectableRun> runs = runsOf(text);
    XCTAssertEqual(runs.size(), 1u);
    if (runs.size() == 1) {
        const std::vector<float> carets = caretsOf(text, runs[0]);
        XCTAssertEqualWithAccuracy(carets.front(), runs[0].box.size.width, 0.5);
        XCTAssertEqualWithAccuracy(carets.back(), 0, 0.5);
        for (size_t i = 1; i < carets.size(); i++) {
            XCTAssertLessThan(carets[i], carets[i - 1]);
        }
    }
}

/// The text is what is drawn: an uppercase ß is SS, and the run's length is the drawn text's.
- (void)testTextTransformChangesTheDrawnLength {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    WRSelectableText* text = selectable(session, @"<p style='user-select:text;text-transform:uppercase'>straße</p>");
    XCTAssertEqualObjects(text.text, @"STRASSE");
    const std::vector<WRSelectableRun> runs = runsOf(text);
    XCTAssertEqual(runs.size(), 1u);
    if (runs.size() == 1) {
        XCTAssertEqual(runs[0].length, 7u);
        XCTAssertEqual(runs[0].nodeOffset, 0u);
    }
}

/// The export is the host's: no work counted to the widget, no stop, nothing a script can see.
- (void)testTheExportDoesNotTouchTheWidget {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    XCTAssertNotNil(selectable(session, @"<p style='user-select:text'>some words to select</p>"));
    [session setWorkLimitAfter:1000000];
    NSString* before = [session evaluateForTesting:@"String(getSelection())"];
    const uint64_t units = session.workUnits;
    XCTAssertNil([session selectableTextWithBudget:10 visibleHeight:600]);
    XCTAssertNotNil([session selectableTextWithBudget:UINT64_MAX visibleHeight:600]);
    XCTAssertEqual(session.workUnits, units);
    XCTAssertEqual(session.stopReason, WRStopReasonNone);
    XCTAssertFalse(session.failed);
    XCTAssertEqualObjects([session evaluateForTesting:@"String(getSelection())"], before);
}

/// The cost suite's reference loop (third-party/quickjs-ng tests/quickjs_work_cost_test.c): wall time per unit of work,
/// best of three, in this process.
- (double)referenceNanosecondsPerUnit {
    double best = INFINITY;
    for (int i = 0; i < 3; i++) {
        WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
        XCTAssertTrue([session bootWithSource:@"<!doctype html><p>x</p>"]);
        [session setWorkLimitAfter:20000000];
        const uint64_t before = session.workUnits;
        const CFTimeInterval t0 = CACurrentMediaTime();
        [session evaluateForTesting:@"let s = 0; for (;;) s = (s + 1) | 0;"];
        const double seconds = CACurrentMediaTime() - t0;
        best = MIN(best, seconds * 1e9 / (double)MAX(session.workUnits - before, (uint64_t)1));
    }
    return best;
}

/// Wall time per charged unit of the selectable text export of `body`, best of three.
- (double)exportNanosecondsPerUnit:(NSString*)body {
    double best = INFINITY;
    for (int i = 0; i < 3; i++) {
        WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
        XCTAssertNotNil(selectable(session, body));
        const CFTimeInterval t0 = CACurrentMediaTime();
        WRSelectableText* text = [session selectableTextWithBudget:UINT64_MAX visibleHeight:1e9];
        const double seconds = CACurrentMediaTime() - t0;
        // It measured an export: text was selected, and in quantity.
        XCTAssertGreaterThan(text.runs.length / sizeof(WRSelectableRun), 0u);
        XCTAssertGreaterThan(text.text.length, 4000u);
        best = MIN(best, seconds * 1e9 / (double)MAX(text.units, (uint64_t)1));
    }
    return best;
}

/// Final review C1: the export is charged in proportion to its work on CoreText, so a hostile page cannot make it run
/// long for little charge: at most twice the reference's wall time per unit. One long run on the CTLine path (no
/// wrapping, so one run: a caret query per character made it quadratic, ~2 minutes at the text cap for ~0.1M units),
/// and many words past the simple shaper's 64 bytes.
- (void)testTheSelectableExportCostsNoMorePerUnitThanJS {
    const double js = [self referenceNanosecondsPerUnit];
    NSString* longRun = [NSString stringWithFormat:@"<p style='user-select:text;white-space:nowrap'>%@</p>",
                                                   [@"" stringByPaddingToLength:32768 withString:@"a" startingAtIndex:0]];
    NSString* word = [@"" stringByPaddingToLength:100 withString:@"bcdefghij" startingAtIndex:0];
    NSMutableString* words = [NSMutableString stringWithString:@"<p style='user-select:text'>"];
    // A Text node each: one value is capped at 65,536 units, and a page past it exports nothing (and measures nothing).
    for (int i = 0; i < 1000; i++) {
        [words appendFormat:@"<span>%@%d</span> ", word, i];
    }
    [words appendString:@"</p>"];
    const double run = [self exportNanosecondsPerUnit:longRun];
    const double many = [self exportNanosecondsPerUnit:words];
    NSLog(@"ns per unit: js %.2f, one long run %.2f (%.2fx), long words %.2f (%.2fx)", js, run, run / js, many, many / js);
    XCTAssertLessThan(run, 2.0 * js);
    XCTAssertLessThan(many, 2.0 * js);
}

- (void)testMemoryStopIsFatal {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>kept</p><script>"
                                            "const a = []; for (;;) a.push(new Float64Array(1 << 20));"
                                            "</script></body></html>"]);
    XCTAssertEqual(session.stopReason, WRStopReasonMemory);
    XCTAssertNotNil([session tree]);
    // The runtime is gone, not only stopped: a stopped one would still answer.
    XCTAssertNil([session evaluateForTesting:@"1"]);
    XCTAssertEqual([session runNextTaskAt:now()], WRStepResultStopped);
    CGImageRef image = [[session tree] copyImageOfRect:CGRectMake(0, 0, 100, 20) scale:2 effects:nil];
    XCTAssertTrue(image != nullptr);
    CGImageRelease(image);
}

/// The client adds no size check of its own (widget-sandbox integration.md, "The widget payload"): the server bounds
/// the HTML, and the memory limit and the parse ceiling guard the runtime.
- (void)testALargeSourceIsNotRefused {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:[@"" stringByPaddingToLength:256 * 1024 + 1 withString:@"a" startingAtIndex:0]]);
}

/// SDK v1 §2.9: the locale set before the boot is navigator.language; a malformed one is en-US.
- (void)testTheLocaleIsNavigatorLanguage {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    [session setLocale:@"pt-BR"];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><p>x</p>"]);
    XCTAssertEqualObjects([session evaluateForTesting:@"navigator.language + ':' + navigator.languages.join()"], @"pt-BR:pt-BR");
    [session setLocale:@"pt_BR"];
    XCTAssertEqualObjects([session evaluateForTesting:@"navigator.language"], @"en-US");
}

- (void)testBridgeCallsReachTheDelegate {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    // A link outside a press is dropped (SDK v1 §2.5; testPointerTapClicks posts one from a tap).
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "TelegramWidget.openLink('https://x.org/'); TelegramWidget.ready();"
                                            "setTimeout(() => TelegramWidget.ready(), 0);"
                                            "</script></body></html>"]);
    drain(session);
    XCTAssertEqualObjects(delegate.bridgeCalls, (@[ @"ready []", @"ready []" ]));
}

/// SDK v1 §3.1 (V2b plan, Task 3): the client's preload is there at the widget's first read.
- (void)testThePreloadIsReadAtFirstTouch {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    [session setStoragePreloadLocal:@[ @[ @"k", @"v" ] ] session:@[ @[ @"s", @"1" ] ]];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><p>x</p>"]);
    XCTAssertEqualObjects([session evaluateForTesting:@"localStorage.getItem('k') + ':' + sessionStorage.getItem('s')"], @"v:1");
}

/// §3.2: an area a task changed reaches the delegate once, at the task's end, with its entries in insertion order.
- (void)testACommitReachesTheDelegateInOrder {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "setTimeout(() => { localStorage.setItem('b', '2'); localStorage.setItem('a', '1'); }, 0);"
                                            "</script></body></html>"]);
    drain(session);
    XCTAssertEqualObjects(delegate.storageCommits, (@[ @"local b=2 a=1" ]));
}

/// §2.3 and §2.4: the palette, the button and the text tokens given at creation are in the first build.
- (void)testThePaletteReachesTheWidget {
    WRSession* session = [[WRSession alloc] initWithWidth:300
                                                     dark:NO
                                              themeParams:@{ @"bg_color" : @"#102030" }
                                             buttonTokens:@{ @"bg" : @"#112233" }
                                               textTokens:@{ @"fontSize" : @17, @"lineHeight" : @1.3, @"padding" : @"6px 11px" }
                                                    scale:2
                                                 delegate:[WRRecordingDelegate new]];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><p>x</p>"]);
    XCTAssertEqualObjects([session evaluateForTesting:@"(s => [TelegramWidget.themeParams.bg_color, s.getPropertyValue('--tg-theme-bg-color').trim(),"
                                                       " s.getPropertyValue('--tg-button-bg').trim(), s.fontSize, s.lineHeight,"
                                                       " getComputedStyle(document.body).marginLeft].join())(getComputedStyle(document.documentElement))"],
                          @"#102030,#102030,#112233,17px,22.1px,11px");
}

/// §2.4: a text-size change alone is a theme change: one themeChanged, and the root's font follows it; a token of the
/// wrong type or out of its grammar is the reference value.
- (void)testATextSizeChangeFiresThemeChanged {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "window.n = 0; TelegramWidget.onEvent('themeChanged', () => n++);</script></body></html>"]);
    drain(session);
    [session setDark:NO themeParams:@{} buttonTokens:@{} textTokens:@{ @"fontSize" : @19, @"lineHeight" : @"1.3", @"padding" : @"6px" }];
    drain(session);
    XCTAssertEqualObjects([session evaluateForTesting:@"(s => [n, s.fontSize, s.getPropertyValue('--tg-text-line-height').trim(),"
                                                       " s.getPropertyValue('--tg-text-padding').trim()].join())(getComputedStyle(document.documentElement))"],
                          @"1,19px,1.35,6px");
    [session setDark:NO themeParams:@{} buttonTokens:@{} textTokens:@{ @"fontSize" : @19, @"padding" : @"6px" }];
    drain(session);
    XCTAssertEqualObjects([session evaluateForTesting:@"n"], @"1");
}

/// A new palette in the same scheme is a theme change: one themeChanged, the new colour in themeParams.
- (void)testAPaletteChangeFiresThemeChanged {
    WRSession* session = [self sessionWith:[WRRecordingDelegate new]];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "window.n = 0; TelegramWidget.onEvent('themeChanged', () => n++);</script></body></html>"]);
    drain(session);
    [session setDark:NO themeParams:@{ @"bg_color" : @"#102030" } buttonTokens:@{} textTokens:@{}];
    drain(session);
    XCTAssertEqualObjects([session evaluateForTesting:@"n + ':' + TelegramWidget.themeParams.bg_color"], @"1:#102030");
}

- (void)testTeardownDuringATaskKeepsTheLastTree {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                                            "<p style=\"margin:0;background:#0000ff\">"
                                            "t</p><script>setTimeout(() => { for (let i = 0; i < 3000000; i++); }, 0);"
                                            "</script></body></html>"]);
    WRTree* before = [session tree];
    std::atomic<bool> running{false};
    std::thread worker([&] {
        running = true;
        [session setWorkLimitAfter:28000000];
        [session runNextTaskAt:now() + 10];
    });
    while (!running) {
        std::this_thread::yield();
    }
    [session teardown];
    worker.join();
    WRTree* after = [session tree];
    XCTAssertNotNil(after);
    XCTAssertNotNil(before);
    std::vector<uint8_t> pixel = colourAt(after, 20, 10);
    XCTAssertEqual(pixel[2], 255);
    XCTAssertEqual([session runNextTaskAt:now()], WRStepResultStopped);
}

- (void)testWorkReachesTheDelegate {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><script>"
                                            "let s = 0; for (let i = 0; i < 300000; i++) s += i;</script></body></html>"]);
    XCTAssertGreaterThan(delegate.workReports, NSUInteger(10));
    XCTAssertEqual(delegate.lastWork <= session.workUnits, true);
}

- (void)testChangedRectsFollowPatches {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head>"
                                            "<body><div style=\"height:40px\">a</div><div id=b style=\"height:40px\">b"
                                            "</div><script>setTimeout(() => document.getElementById('b').setAttribute('style', "
                                            "'height:40px;background:#00f'), 100);</script></body></html>"]);
    XCTAssertNil([session changedRects]);
    NSNumber* deadline = [session nextTimerDeadline];
    XCTAssertNotNil(deadline);
    [session setWorkLimitAfter:28000000];
    XCTAssertEqual([session runNextTaskAt:deadline.doubleValue + 1], WRStepResultRan);
    NSArray<NSValue*>* rects = [session changedRects];
    XCTAssertNotNil(rects);
    XCTAssertGreaterThan(rects.count, NSUInteger(0));
    for (NSValue* value : rects) {
        CGRect rect = CGRectZero;
        [value getValue:&rect size:sizeof(rect)];
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(rect), 0);
        XCTAssertLessThanOrEqual(CGRectGetMaxY(rect), session.contentSize.height + 0.5);
    }
    XCTAssertEqual([session changedRects].count, NSUInteger(0));
}

- (void)testFailureIsLatched {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"]);
    WRTree* tree = [session tree];
    [session throwForTesting];
    XCTAssertTrue(session.failed);
    XCTAssertEqual([session runNextTaskAt:now()], WRStepResultStopped);
    XCTAssertFalse([session wantsAnimationFrame]);
    [session pointer:WRPointerPhaseDown at:CGPointMake(1, 1) pointerId:1 primary:YES];
    XCTAssertTrue([session tree] == tree);
}

// Review C1: a memory stop latched outside a step (a tap's task allocation refused), then teardown.
- (void)testTeardownAfterAMemoryStopOutsideAStep {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"]);
    [session stopForTesting:WRStopReasonMemory];
    [session teardown];
    XCTAssertNotNil([session tree]);
    XCTAssertEqual(session.stopReason, WRStopReasonMemory);
}

// Review I1: an entry that only queues a task drops the runtime when a memory stop is latched, as a step does.
- (void)testAMemoryStopOutsideAStepDropsTheRuntime {
    for (int entry = 0; entry < 3; entry++) {
        WRRecordingDelegate* delegate = [WRRecordingDelegate new];
        WRSession* session = [self sessionWith:delegate];
        XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"]);
        [session stopForTesting:WRStopReasonMemory];
        switch (entry) {
        case 0:
            [session pointer:WRPointerPhaseDown at:CGPointMake(1, 1) pointerId:1 primary:YES];
            break;
        case 1:
            [session setVisible:NO];
            break;
        default:
            [session setDark:YES];
            break;
        }
        XCTAssertNil([session evaluateForTesting:@"1"], @"entry %d", entry);
        XCTAssertNotNil([session tree], @"entry %d", entry);
    }
}

// Review I2: a boot stopped before anything was published has nothing to show: it did not start.
- (void)testABootStoppedBeforeAnyPublishDidNotStart {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertFalse([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"
                                parseUnits:1
                                 bootUnits:48000000]);
    XCTAssertNil([session tree]);
}

// Review I3: the content's own width is part of the size: a change of it alone repaints everything.
- (void)testANaturalWidthChangeRepaintsEverything {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                                            "<div id=b style=\"width:100px;height:20px;background:red\"></div><script>"
                                            "setTimeout(() => document.getElementById('b').setAttribute('style', "
                                            "'width:150px;height:20px;background:red'), 100);</script></body></html>"]);
    const CGFloat before = session.contentSize.width;
    XCTAssertNil([session changedRects]);
    [session setWorkLimitAfter:28000000];
    XCTAssertEqual([session runNextTaskAt:[session nextTimerDeadline].doubleValue + 1], WRStepResultRan);
    XCTAssertEqualWithAccuracy(session.contentSize.width, before + 50, 0.5);
    XCTAssertNil([session changedRects]);
}

// The changed rects reach as far as the tree does (the layout width), not only the content's own width: a block with no
// content of its own is as narrow as its padding by that measure and as wide as the layout on screen.
- (void)testChangedRectsCoverTheLayoutWidth {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head><body>"
                                            "<div id=b style=\"height:40px;background:#f00\"></div><script>"
                                            "setTimeout(() => document.getElementById('b').setAttribute('style', "
                                            "'height:40px;background:#00f'), 100);</script></body></html>"]);
    XCTAssertLessThan(session.contentSize.width, 100);
    XCTAssertNil([session changedRects]);
    [session setWorkLimitAfter:28000000];
    XCTAssertEqual([session runNextTaskAt:[session nextTimerDeadline].doubleValue + 1], WRStepResultRan);
    CGFloat right = 0;
    for (NSValue* value : [session changedRects]) {
        CGRect rect = CGRectZero;
        [value getValue:&rect size:sizeof(rect)];
        right = std::max(right, CGRectGetMaxX(rect));
    }
    XCTAssertGreaterThan(right, 280);
    XCTAssertLessThanOrEqual(right, 300);
}

// Tests only: an element's border box by selector, at the current layout; null when nothing matches or it has no box.
- (void)testBorderBoxForTesting {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head><style>body{margin:0}</style></head>"
                                            "<body><div style=\"height:30px\"></div><button id=b style=\"display:block;"
                                            "width:100px;height:40px\">b</button></body></html>"]);
    CGRect box = [session borderBoxForTesting:@"#b"];
    XCTAssertEqualWithAccuracy(box.origin.y, 30, 0.5);
    XCTAssertEqualWithAccuracy(box.size.width, 100, 0.5);
    XCTAssertEqualWithAccuracy(box.size.height, 40, 0.5);
    XCTAssertTrue(CGRectIsNull([session borderBoxForTesting:@"#missing"]));
    XCTAssertTrue(CGRectIsNull([session borderBoxForTesting:@"[["]));
    XCTAssertFalse(session.failed);
}

// Review M5: the same published tree is the same object.
- (void)testTheTreeKeepsItsIdentity {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"]);
    XCTAssertTrue([session tree] == [session tree]);
}

// Review M6: a session boots once.
- (void)testASecondBootDoesNotStart {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p></body></html>"]);
    XCTAssertFalse([session bootWithSource:@"<!doctype html><html><head></head><body><p>y</p></body></html>"]);
    XCTAssertEqual(session.stopReason, WRStopReasonNone);
}

// Review M3: a delegate that calls back into the session (against the contract) gets nothing done, and breaks nothing.
- (void)testADelegateCallingBackIsANoOp {
    WRRecordingDelegate* delegate = [WRRecordingDelegate new];
    delegate.onWork = ^(WRSession* session) {
        [session teardown];
        [session runNextTaskAt:now()];
        [session setWidth:100];
    };
    WRSession* session = [self sessionWith:delegate];
    XCTAssertTrue([session bootWithSource:@"<!doctype html><html><head></head><body><p>x</p><script>"
                                            "let s = 0; for (let i = 0; i < 300000; i++) s += i;</script></body></html>"]);
    XCTAssertGreaterThan(delegate.workReports, NSUInteger(0));
    XCTAssertFalse(session.failed);
    XCTAssertEqual(session.stopReason, WRStopReasonNone);
    XCTAssertEqualObjects([session evaluateForTesting:@"String(s)"], @"44999850000");
}

@end
