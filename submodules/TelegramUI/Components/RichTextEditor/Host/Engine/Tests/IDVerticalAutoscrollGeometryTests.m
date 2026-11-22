#import <XCTest/XCTest.h>

#import "IDVerticalAutoscrollGeometry.h"

@interface IDVerticalAutoscrollGeometryTests : XCTestCase
@end

@implementation IDVerticalAutoscrollGeometryTests

- (void)testPhoneAndTabletSafeBandsUseCallerSuppliedEdgeInset {
    CGRect bounds = CGRectMake(0, 0, 320, 200);

    CGRect phone = IDVerticalAutoscrollSafeRect(
        bounds, UIEdgeInsetsZero, UIEdgeInsetsZero, 8.0);
    CGRect tablet = IDVerticalAutoscrollSafeRect(
        bounds, UIEdgeInsetsZero, UIEdgeInsetsZero, 32.0);

    XCTAssertTrue(CGRectEqualToRect(
        phone, CGRectMake(8, 8, 304, 184)));
    XCTAssertTrue(CGRectEqualToRect(
        tablet, CGRectMake(32, 32, 256, 136)));
}

- (void)testSafeRectComposesAdjustedLayoutAndEdgeInsets {
    CGRect safe = IDVerticalAutoscrollSafeRect(
        CGRectMake(10, 20, 300, 200),
        UIEdgeInsetsMake(44, 2, 34, 3),
        UIEdgeInsetsMake(8, 5, 9, 6),
        8.0);

    XCTAssertTrue(CGRectEqualToRect(
        safe, CGRectMake(25, 80, 268, 89)));
}

- (void)testDirectionsClassifyUpperLowerAndInsideBands {
    CGRect safe = CGRectMake(0, 20, 100, 60);

    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 19), safe, 50, 0, 100),
        IDVerticalAutoscrollDirectionUp);
    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 81), safe, 50, 0, 100),
        IDVerticalAutoscrollDirectionDown);
    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 50), safe, 50, 0, 100),
        0U);
}

- (void)testDirectionsRemoveExhaustedBoundaries {
    CGRect safe = CGRectMake(0, 20, 100, 60);

    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 0), safe, -20, -20, 100),
        0U);
    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 100), safe, 100, -20, 100),
        0U);
}

- (void)testShortContentClampsMaximumOffsetToMinimum {
    CGFloat minimumOffsetY = -20.0;
    CGFloat contentHeight = 50.0;
    CGFloat boundsHeight = 100.0;
    CGFloat adjustedBottom = 10.0;
    CGFloat maximumOffsetY = MAX(
        minimumOffsetY,
        contentHeight - boundsHeight + adjustedBottom);

    XCTAssertEqual(maximumOffsetY, minimumOffsetY);
    XCTAssertEqual(
        IDVerticalAutoscrollDirectionsForPoint(
            CGPointMake(50, 100),
            CGRectMake(0, 20, 100, 60),
            minimumOffsetY,
            minimumOffsetY,
            maximumOffsetY),
        0U);
}

- (void)testStepTargetsDirectionalPublicBoundary {
    IDVerticalAutoscrollRampState upState = {0};
    IDVerticalAutoscrollStep up = IDVerticalAutoscrollMakeStep(
        40, -20, 100, IDVerticalAutoscrollDirectionUp, 1, &upState);
    IDVerticalAutoscrollRampState downState = {0};
    IDVerticalAutoscrollStep down = IDVerticalAutoscrollMakeStep(
        40, -20, 100, IDVerticalAutoscrollDirectionDown, 1, &downState);

    XCTAssertTrue(up.shouldContinue);
    XCTAssertEqual(up.targetOffsetY, -20);
    XCTAssertTrue(down.shouldContinue);
    XCTAssertEqual(down.targetOffsetY, 100);
}

- (void)testFirstTickStoresUIKitNormalizationAndMinimumRamp {
    IDVerticalAutoscrollRampState state = {0};

    IDVerticalAutoscrollStep step = IDVerticalAutoscrollMakeStep(
        0, 0, 100, IDVerticalAutoscrollDirectionDown, 1, &state);

    XCTAssertTrue(step.shouldContinue);
    XCTAssertEqual(state.normalizationDistance, 200);
    XCTAssertEqual(state.rampTicks, 5U);
    XCTAssertEqualWithAccuracy(step.animationDuration, 2.5, 0.000001);
}

- (void)testFirstTickUsesSquareRootRampAboveMinimum {
    IDVerticalAutoscrollRampState state = {0};

    IDVerticalAutoscrollStep step = IDVerticalAutoscrollMakeStep(
        0, 0, 2500, IDVerticalAutoscrollDirectionDown, 1, &state);

    XCTAssertTrue(step.shouldContinue);
    XCTAssertEqual(state.normalizationDistance, 5000);
    XCTAssertEqual(state.rampTicks, 10U);
    XCTAssertEqualWithAccuracy(step.animationDuration, 5.0, 0.000001);
}

- (void)testRampMultiplierStopsAfterRampTicksAndIsMonotonic {
    IDVerticalAutoscrollRampState state = {0};
    NSMutableArray<NSNumber *> *durations = [NSMutableArray array];

    for (NSUInteger count = 1; count <= 7; count += 1) {
        IDVerticalAutoscrollStep step =
            IDVerticalAutoscrollMakeStep(
                0,
                0,
                100,
                IDVerticalAutoscrollDirectionDown,
                count,
                &state);
        XCTAssertTrue(step.shouldContinue);
        XCTAssertGreaterThanOrEqual(step.animationDuration, 0.0);
        [durations addObject:@(step.animationDuration)];
    }

    XCTAssertEqualObjects(
        durations,
        (@[@2.5, @2.0, @1.5, @1.0, @0.5, @0.5, @0.5]));
}

- (void)testStepRejectsCombinedDirectionAndExhaustedBoundary {
    IDVerticalAutoscrollRampState state = {0};
    IDVerticalAutoscrollDirection combined =
        IDVerticalAutoscrollDirectionUp |
        IDVerticalAutoscrollDirectionDown;

    XCTAssertFalse(IDVerticalAutoscrollMakeStep(
        50, 0, 100, combined, 1, &state).shouldContinue);
    XCTAssertFalse(IDVerticalAutoscrollMakeStep(
        0, 0, 100, IDVerticalAutoscrollDirectionUp, 1, &state)
        .shouldContinue);
    XCTAssertFalse(IDVerticalAutoscrollMakeStep(
        100, 0, 100, IDVerticalAutoscrollDirectionDown, 1, &state)
        .shouldContinue);
}

- (void)testStepClampsOutOfBoundsOffsetsWithoutNegativeDuration {
    IDVerticalAutoscrollRampState state = {0};

    IDVerticalAutoscrollStep below = IDVerticalAutoscrollMakeStep(
        -10, 0, 100, IDVerticalAutoscrollDirectionUp, 1, &state);
    IDVerticalAutoscrollStep above = IDVerticalAutoscrollMakeStep(
        110, 0, 100, IDVerticalAutoscrollDirectionDown, 1, &state);

    XCTAssertFalse(below.shouldContinue);
    XCTAssertEqual(below.targetOffsetY, 0);
    XCTAssertGreaterThanOrEqual(below.animationDuration, 0.0);
    XCTAssertFalse(above.shouldContinue);
    XCTAssertEqual(above.targetOffsetY, 100);
    XCTAssertGreaterThanOrEqual(above.animationDuration, 0.0);
}

- (void)testRangeMaximumOnlyChangeSelectsLogicalEnd {
    XCTAssertEqual(
        IDVerticalAutoscrollResolveActiveEndpoint(
            NSMakeRange(5, 5),
            NSMakeRange(5, 7),
            CGPointZero,
            CGRectZero,
            CGRectZero,
            IDVerticalAutoscrollSelectionEndpointStart),
        IDVerticalAutoscrollSelectionEndpointEnd);
}

- (void)testRangeLocationOnlyChangeSelectsLogicalStartAcrossStructuralNewline {
    XCTAssertEqual(
        IDVerticalAutoscrollResolveActiveEndpoint(
            NSMakeRange(8, 4),
            NSMakeRange(7, 5),
            CGPointZero,
            CGRectZero,
            CGRectZero,
            IDVerticalAutoscrollSelectionEndpointEnd),
        IDVerticalAutoscrollSelectionEndpointStart);
}

- (void)testAmbiguousChangeChoosesNearestLogicalRect {
    XCTAssertEqual(
        IDVerticalAutoscrollResolveActiveEndpoint(
            NSMakeRange(5, 5),
            NSMakeRange(4, 8),
            CGPointMake(92, 20),
            CGRectMake(10, 10, 10, 20),
            CGRectMake(90, 10, 10, 20),
            IDVerticalAutoscrollSelectionEndpointStart),
        IDVerticalAutoscrollSelectionEndpointEnd);
}

- (void)testExactDistanceTiePreservesFallback {
    XCTAssertEqual(
        IDVerticalAutoscrollResolveActiveEndpoint(
            NSMakeRange(5, 5),
            NSMakeRange(5, 5),
            CGPointMake(50, 20),
            CGRectMake(10, 10, 10, 20),
            CGRectMake(80, 10, 10, 20),
            IDVerticalAutoscrollSelectionEndpointEnd),
        IDVerticalAutoscrollSelectionEndpointEnd);
}

- (void)testNearestRectUsesLogicalIdentityWithReversedRTLGeometry {
    XCTAssertEqual(
        IDVerticalAutoscrollResolveActiveEndpoint(
            NSMakeRange(5, 5),
            NSMakeRange(4, 8),
            CGPointMake(95, 20),
            CGRectMake(90, 10, 10, 20),
            CGRectMake(10, 10, 10, 20),
            IDVerticalAutoscrollSelectionEndpointEnd),
        IDVerticalAutoscrollSelectionEndpointStart);
}

// The stock session rule (`IDVerticalAutoscrollStockSessionWouldStart`), measured on the composer
// harness, 2026-09-24: a 54pt engine field, text-container inset 5 top and bottom, content 54 tall.
- (void)testStockSessionStartsEverywhereInAFieldShorterThanTwoBands {
    CGRect bounds = CGRectMake(0, 0, 317, 54);
    UIEdgeInsets layout = UIEdgeInsetsMake(5, 0, 5, 50);
    for (CGFloat y = 0.0; y <= 54.0; y += 6.0) {
        XCTAssertTrue(IDVerticalAutoscrollStockSessionWouldStart(
            CGPointMake(95, y), bounds, UIEdgeInsetsZero, layout, 54.0), @"y=%f", y);
    }
}

- (void)testStockSessionNeedsContentTallerThanTheInterior {
    CGRect bounds = CGRectMake(0, 0, 317, 54);
    XCTAssertFalse(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(95, 40), bounds, UIEdgeInsetsZero, UIEdgeInsetsZero, 54.0));
    XCTAssertFalse(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(95, 40), bounds, UIEdgeInsetsZero, UIEdgeInsetsMake(5, 0, 5, 0), 44.0));
    XCTAssertTrue(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(95, 40), bounds, UIEdgeInsetsZero, UIEdgeInsetsMake(5, 0, 5, 0), 44.5));
}

- (void)testStockSessionInATallFieldStartsOnlyInItsEdgeBands {
    CGRect bounds = CGRectMake(0, 100, 320, 200);
    UIEdgeInsets layout = UIEdgeInsetsMake(8, 0, 8, 0);
    // Interior 108..292; bands above 140 and below 260.
    XCTAssertTrue(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(10, 139), bounds, UIEdgeInsetsZero, layout, 1000.0));
    XCTAssertFalse(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(10, 200), bounds, UIEdgeInsetsZero, layout, 1000.0));
    XCTAssertTrue(IDVerticalAutoscrollStockSessionWouldStart(
        CGPointMake(10, 261), bounds, UIEdgeInsetsZero, layout, 1000.0));
}

@end
