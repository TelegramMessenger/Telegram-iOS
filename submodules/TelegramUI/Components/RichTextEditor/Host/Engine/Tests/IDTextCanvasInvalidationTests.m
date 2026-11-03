@import XCTest;

#import "IDTextCanvasTestSupport.h"
#import "IDTextCanvasInvalidation.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDPrivateUIKit.h"

@interface IDTask4DisplayProbeSurface : IDTextRenderingSurfaceView
@property(nonatomic) NSUInteger displayCount;
- (void)resetDisplayCount;
@end

@interface IDTask4RangeAdapter : NSObject
@property(nonatomic, copy) NSArray *textKit2Ranges;
@end

@implementation IDTask4RangeAdapter
@end

@interface IDTask4RangeRenderer : NSObject
@property(nonatomic, strong) NSMutableArray *invalidatedRanges;
@end

@implementation IDTask4RangeRenderer
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _invalidatedRanges = [NSMutableArray array];
    }
    return self;
}
- (void)invalidateTemporaryAttributesInRange:(id)range {
    [self.invalidatedRanges addObject:range];
}
@end

@interface IDTask4DisplayRenderer : NSObject
@property(nonatomic) NSUInteger displayCount;
@end

@implementation IDTask4DisplayRenderer
- (void)setNeedsDisplay {
    self.displayCount += 1;
}
@end

@interface IDTask4InertRenderer : NSObject
@end

@implementation IDTask4InertRenderer
@end

@interface IDTask4FrameProbeView : UIView
@property(nonatomic) CGRect probeFrame;
@end

@implementation IDTask4FrameProbeView
- (CGRect)frame {
    return self.probeFrame;
}
@end

@interface IDTask4ExplodingLayoutManager : NSTextLayoutManager
@end

@implementation IDTask4ExplodingLayoutManager
- (NSTextContentManager *)textContentManager {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Invalid document range reached TextKit"
                                 userInfo:nil];
}
@end

@interface IDTask4LaidOutFragment : NSTextLayoutFragment
@end

@implementation IDTask4LaidOutFragment
- (NSTextLayoutFragmentState)state {
    return NSTextLayoutFragmentStateLayoutAvailable;
}
@end

@interface IDTask4CustomContext : NSObject
@property(nonatomic, strong) id customRenderController;
@end

@implementation IDTask4CustomContext
@end

@implementation IDTask4DisplayProbeSurface
- (void)setNeedsDisplay {
    self.displayCount += 1;
    [super setNeedsDisplay];
}
- (void)resetDisplayCount {
    self.displayCount = 0;
}
@end

@interface IDTextCanvasInvalidationTests : XCTestCase
@end

@implementation IDTextCanvasInvalidationTests

- (IDTextCanvasFixture *)multiFragmentFixture {
    NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
    for (NSUInteger index = 0; index < 8; index++) {
        [paragraphs addObject:[NSString stringWithFormat:@"paragraph %lu", (unsigned long)index]];
    }
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:[paragraphs componentsJoinedByString:@"\n"]
                size:CGSizeMake(220, 240)];
    fixture.canvas.nativeSurfaceViewClass = IDTask4DisplayProbeSurface.class;
    return fixture;
}

- (void)testRectInvalidationDirtiesOnlyIntersectingMappedSurfaces {
    IDTextCanvasFixture *fixture = [self multiFragmentFixture];
    [fixture.canvas performViewportLayout];
    NSArray<IDTask4DisplayProbeSurface *> *surfaces =
        (NSArray<IDTask4DisplayProbeSurface *> *)[fixture.canvas.visibleSurfaces
        sortedArrayUsingComparator:^NSComparisonResult(UIView *left, UIView *right) {
            CGFloat leftY = CGRectGetMinY(left.frame);
            CGFloat rightY = CGRectGetMinY(right.frame);
            return leftY < rightY ? NSOrderedAscending
                : leftY > rightY ? NSOrderedDescending
                                 : NSOrderedSame;
        }];
    XCTAssertGreaterThan(surfaces.count, 1U);
    // Fragment rendering bounds intentionally bleed by a point. Inset far enough
    // to isolate this surface from the adjacent fragment's rendering bounds.
    CGRect target = CGRectInset(surfaces.firstObject.frame, 2, 2);
    [surfaces makeObjectsPerformSelector:@selector(resetDisplayCount)];
    [fixture.canvas setNeedsDisplayInRect:target];
    XCTAssertGreaterThan(surfaces.firstObject.displayCount, 0U);
    for (IDTask4DisplayProbeSurface *surface in
         [surfaces subarrayWithRange:NSMakeRange(1, surfaces.count - 1)]) {
        XCTAssertEqual(surface.displayCount,
                       0U,
                       @"target %@ unexpectedly intersected surface %@; all frames %@",
                       NSStringFromCGRect(target),
                       NSStringFromCGRect(surface.frame),
                       [surfaces valueForKey:@"frame"]);
    }
}

- (void)testSurfaceIntersectionStandardizesNegativeTargetAndEnumeratesMapValues {
    NSMapTable<NSTextLayoutFragment *, UIView *> *surfaces =
        [NSMapTable strongToStrongObjectsMapTable];
    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@"probe"]];
    NSTextLayoutFragment *fragment = [[NSTextLayoutFragment alloc]
        initWithTextElement:paragraph range:nil];
    UIView *surface = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 10, 10)];
    [surfaces setObject:surface forKey:fragment];

    NSArray<UIView *> *matches = IDTextSurfacesIntersectingCanvasRect(
        surfaces,
        CGRectMake(18, 18, -6, -6));

    XCTAssertEqualObjects(matches, (@[surface]));
}

- (void)testSurfaceIntersectionRejectsInvalidTargets {
    NSMapTable<NSTextLayoutFragment *, UIView *> *surfaces =
        [NSMapTable strongToStrongObjectsMapTable];
    NSArray<NSValue *> *targets = @[
        [NSValue valueWithCGRect:CGRectMake(NAN, 0, 1, 1)],
        [NSValue valueWithCGRect:CGRectMake(0, INFINITY, 1, 1)],
        [NSValue valueWithCGRect:CGRectNull],
        [NSValue valueWithCGRect:CGRectInfinite],
        [NSValue valueWithCGRect:CGRectZero],
    ];

    for (NSValue *target in targets) {
        XCTAssertEqual(IDTextSurfacesIntersectingCanvasRect(surfaces,
                                                             target.CGRectValue).count,
                       0U,
                       @"target %@",
                       target);
    }
}

- (void)testSurfaceIntersectionSkipsInvalidSurfaceFrames {
    NSMapTable<NSTextLayoutFragment *, UIView *> *surfaces =
        [NSMapTable strongToStrongObjectsMapTable];
    NSArray<NSValue *> *frames = @[
        [NSValue valueWithCGRect:CGRectMake(NAN, 0, 1, 1)],
        [NSValue valueWithCGRect:CGRectMake(0, INFINITY, 1, 1)],
        [NSValue valueWithCGRect:CGRectNull],
        [NSValue valueWithCGRect:CGRectInfinite],
        [NSValue valueWithCGRect:CGRectZero],
    ];
    NSMutableArray *keys = [NSMutableArray array];
    for (NSValue *frame in frames) {
        NSTextParagraph *paragraph = [[NSTextParagraph alloc]
            initWithAttributedString:[[NSAttributedString alloc] initWithString:@"probe"]];
        NSTextLayoutFragment *fragment = [[NSTextLayoutFragment alloc]
            initWithTextElement:paragraph range:nil];
        IDTask4FrameProbeView *surface = [IDTask4FrameProbeView new];
        surface.probeFrame = frame.CGRectValue;
        [keys addObject:fragment];
        [surfaces setObject:surface forKey:fragment];
    }

    XCTAssertEqual(IDTextSurfacesIntersectingCanvasRect(
                       surfaces,
                       CGRectMake(-10, -10, 100, 100)).count,
                   0U);
}

- (void)testRecoveredDisplayFlagSchedulesNativeSurfaceRedraw {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"mispelled word" size:CGSizeMake(220, 80)];
    fixture.canvas.nativeSurfaceViewClass = IDTask4DisplayProbeSurface.class;
    [fixture.canvas performViewportLayout];
    IDTask4DisplayProbeSurface *surface =
        (IDTask4DisplayProbeSurface *)fixture.canvas.visibleSurfaces.firstObject;
    [surface resetDisplayCount];
    [fixture.canvas setLayoutFragmentViewsNeedDisplay:YES];
    XCTAssertTrue(fixture.canvas.layoutFragmentViewsNeedDisplay);
    [fixture.canvas performViewportLayout];
    XCTAssertFalse(fixture.canvas.layoutFragmentViewsNeedDisplay);
    XCTAssertGreaterThan(surface.displayCount, 0U);
}

- (void)testNativeTemporaryAttributeCallbackDoesNotCreatePersistentAttributes {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"mispelled word" size:CGSizeMake(220, 80)];
    [fixture.canvas tgpn_invalidateTemporaryAttributesInRange:
        [NSValue valueWithRange:NSMakeRange(0, 9)]];
    NSDictionary *attributes = [fixture.contentStorage.textStorage
        attributesAtIndex:1 effectiveRange:NULL];
    XCTAssertNil(attributes[NSUnderlineStyleAttributeName]);
    XCTAssertNil(attributes[NSUnderlineColorAttributeName]);
}

- (void)testCustomTemporaryAttributeCallbackExpandsEveryTextKit2Range {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom range" size:CGSizeMake(220, 80)];
    IDTask4RangeRenderer *renderer = [IDTask4RangeRenderer new];
    IDTask4CustomContext *context = [IDTask4CustomContext new];
    context.customRenderController = renderer;
    fixture.canvas.context = context;
    IDTask4RangeAdapter *adapter = [IDTask4RangeAdapter new];
    adapter.textKit2Ranges = @[@"first", @"second"];

    [fixture.canvas tgpn_invalidateTemporaryAttributesInRange:adapter];

    XCTAssertEqualObjects(renderer.invalidatedRanges, adapter.textKit2Ranges);
}

- (void)testCustomRendererWithoutRangeInvalidationFallsBackToFullDisplay {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"custom fallback" size:CGSizeMake(220, 80)];
    IDTask4DisplayRenderer *renderer = [IDTask4DisplayRenderer new];
    IDTask4CustomContext *context = [IDTask4CustomContext new];
    context.customRenderController = renderer;
    fixture.canvas.context = context;

    [fixture.canvas tgpn_invalidateTemporaryAttributesInRange:[IDTask4RangeAdapter new]];

    XCTAssertEqual(renderer.displayCount, 1U);
}

- (void)testCustomRendererWithoutRangeOrDisplayInvalidationThrowsReadableContractFailure {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"inert custom fallback" size:CGSizeMake(220, 80)];
    IDTask4CustomContext *context = [IDTask4CustomContext new];
    context.customRenderController = [IDTask4InertRenderer new];
    fixture.canvas.context = context;
    NSException *caught = nil;

    @try {
        [fixture.canvas tgpn_invalidateTemporaryAttributesInRange:[IDTask4RangeAdapter new]];
    } @catch (NSException *exception) {
        caught = exception;
    }

    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Custom renderer display invalidation contract"],
                  @"%@",
                  caught.reason);
    XCTAssertTrue([caught.reason containsString:@"setNeedsDisplay"], @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:IDPrivateUIKit.compatibilityReport],
                  @"%@",
                  caught.reason);
}

- (void)testInvalidDocumentRangesAreRejectedBeforeTextKitCalls {
    IDTask4ExplodingLayoutManager *layoutManager = [IDTask4ExplodingLayoutManager new];
    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@"probe"]];
    IDTask4LaidOutFragment *fragment = [[IDTask4LaidOutFragment alloc]
        initWithTextElement:paragraph range:nil];
    NSArray<NSValue *> *invalidRanges = @[
        [NSValue valueWithRange:NSMakeRange(NSNotFound, 1)],
        [NSValue valueWithRange:NSMakeRange(1, NSUIntegerMax)],
        [NSValue valueWithRange:NSMakeRange((NSUInteger)NSIntegerMax + 1, 1)],
        [NSValue valueWithRange:NSMakeRange((NSUInteger)NSIntegerMax, 1)],
    ];

    for (NSValue *range in invalidRanges) {
        XCTAssertFalse(IDTextFragmentIntersectsDocumentRange(layoutManager,
                                                              fragment,
                                                              range.rangeValue),
                       @"range %@",
                       range);
    }
}

- (void)testBoundaryValidDocumentRangesDoNotOverflow {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"boundary" size:CGSizeMake(220, 80)];
    [fixture.canvas performViewportLayout];
    NSTextLayoutFragment *fragment = fixture.canvas.visibleFragments.firstObject;

    XCTAssertTrue(IDTextFragmentIntersectsDocumentRange(
        fixture.layoutManager,
        fragment,
        NSMakeRange(0, (NSUInteger)NSIntegerMax)));
    XCTAssertFalse(IDTextFragmentIntersectsDocumentRange(
        fixture.layoutManager,
        fragment,
        NSMakeRange((NSUInteger)NSIntegerMax, 0)));
    XCTAssertFalse(IDTextFragmentIntersectsDocumentRange(
        fixture.layoutManager,
        fragment,
        NSMakeRange((NSUInteger)NSIntegerMax - 1, 1)));
}

- (void)testDocumentRangeIntersectionRejectsUnlaidFragmentAndFindsLaidOutFragment {
    IDTextCanvasFixture *fixture = [[IDTextCanvasFixture alloc]
        initWithText:@"first paragraph\nsecond paragraph" size:CGSizeMake(220, 100)];
    [fixture.canvas performViewportLayout];
    NSTextLayoutFragment *laidOut = fixture.canvas.visibleFragments.firstObject;
    XCTAssertNotNil(laidOut);
    NSInteger start = [fixture.contentStorage offsetFromLocation:
        fixture.contentStorage.documentRange.location
                                                   toLocation:laidOut.rangeInElement.location];
    XCTAssertNotEqual(start, NSNotFound);
    XCTAssertTrue(IDTextFragmentIntersectsDocumentRange(fixture.layoutManager,
                                                         laidOut,
                                                         NSMakeRange((NSUInteger)start, 1)));
    XCTAssertFalse(IDTextFragmentIntersectsDocumentRange(fixture.layoutManager,
                                                          laidOut,
                                                          NSMakeRange(1000, 1)));

    NSTextParagraph *paragraph = [[NSTextParagraph alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@"unlaid"]];
    NSTextLayoutFragment *unlaid = [[NSTextLayoutFragment alloc]
        initWithTextElement:paragraph range:nil];
    XCTAssertFalse(IDTextFragmentIntersectsDocumentRange(fixture.layoutManager,
                                                          unlaid,
                                                          NSMakeRange(0, 1)));
}

@end
