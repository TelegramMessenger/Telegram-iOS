#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDVerticalAutoscrollGeometry.h"

#include <math.h>

CGRect IDVerticalAutoscrollSafeRect(
    CGRect bounds,
    UIEdgeInsets adjustedContentInset,
    UIEdgeInsets layoutInset,
    CGFloat edgeInset) {
    CGRect safe =
        UIEdgeInsetsInsetRect(bounds, adjustedContentInset);
    safe = UIEdgeInsetsInsetRect(safe, layoutInset);
    return CGRectInset(safe, edgeInset, edgeInset);
}

IDVerticalAutoscrollDirection
IDVerticalAutoscrollDirectionsForPoint(
    CGPoint point,
    CGRect safeRect,
    CGFloat currentOffsetY,
    CGFloat minimumOffsetY,
    CGFloat maximumOffsetY) {
    if (point.y < CGRectGetMinY(safeRect) &&
        currentOffsetY > minimumOffsetY) {
        return IDVerticalAutoscrollDirectionUp;
    }
    if (point.y > CGRectGetMaxY(safeRect) &&
        currentOffsetY < maximumOffsetY) {
        return IDVerticalAutoscrollDirectionDown;
    }
    return 0;
}

const CGFloat IDVerticalAutoscrollStockSessionEdgeBuffer = 32.0;

BOOL IDVerticalAutoscrollStockSessionWouldStart(
    CGPoint point,
    CGRect bounds,
    UIEdgeInsets adjustedContentInset,
    UIEdgeInsets layoutInset,
    CGFloat contentHeight) {
    CGRect interior = IDVerticalAutoscrollSafeRect(
        bounds, adjustedContentInset, layoutInset, 0.0);
    if (CGRectGetHeight(interior) >= contentHeight) {
        return NO;
    }
    CGRect band = CGRectInset(
        interior,
        IDVerticalAutoscrollStockSessionEdgeBuffer,
        IDVerticalAutoscrollStockSessionEdgeBuffer);
    // An interior shorter than two buffers insets to the null rect: there is no middle, so every
    // point is in an edge band. Spelled out rather than left to the null rect's infinite origin.
    if (CGRectIsNull(band) || CGRectIsEmpty(band)) {
        return YES;
    }
    return point.y > CGRectGetMaxY(band) || point.y < CGRectGetMinY(band);
}

IDVerticalAutoscrollStep IDVerticalAutoscrollMakeStep(
    CGFloat currentOffsetY,
    CGFloat minimumOffsetY,
    CGFloat maximumOffsetY,
    IDVerticalAutoscrollDirection direction,
    NSUInteger count,
    IDVerticalAutoscrollRampState *state) {
    IDVerticalAutoscrollStep step = {
        .shouldContinue = NO,
        .targetOffsetY = currentOffsetY,
        .animationDuration = 0.0,
    };
    if (direction != IDVerticalAutoscrollDirectionUp &&
        direction != IDVerticalAutoscrollDirectionDown) {
        return step;
    }

    CGFloat targetOffsetY =
        direction == IDVerticalAutoscrollDirectionUp
            ? minimumOffsetY
            : maximumOffsetY;
    step.targetOffsetY = targetOffsetY;
    CGFloat distance =
        direction == IDVerticalAutoscrollDirectionUp
            ? currentOffsetY - targetOffsetY
            : targetOffsetY - currentOffsetY;
    if (distance <= 0.0) {
        return step;
    }

    IDVerticalAutoscrollRampState localState = {0};
    IDVerticalAutoscrollRampState *mutableState =
        state == NULL ? &localState : state;
    if (count == 1) {
        mutableState->normalizationDistance =
            2.0 * distance;
        mutableState->rampTicks = MAX(
            (NSUInteger)floor(sqrt(distance) / 5.0),
            5U);
    }

    NSTimeInterval duration = 0.0;
    if (mutableState->normalizationDistance > 0.0) {
        duration =
            distance / mutableState->normalizationDistance;
        if (count < mutableState->rampTicks) {
            duration *=
                mutableState->rampTicks - count + 1;
        }
    }
    step.shouldContinue = YES;
    step.animationDuration = MAX(duration, 0.0);
    return step;
}

static CGFloat IDVerticalAutoscrollDistanceToRect(
    CGPoint point,
    CGRect rect) {
    CGFloat nearestX = MIN(
        MAX(point.x, CGRectGetMinX(rect)),
        CGRectGetMaxX(rect));
    CGFloat nearestY = MIN(
        MAX(point.y, CGRectGetMinY(rect)),
        CGRectGetMaxY(rect));
    CGFloat deltaX = point.x - nearestX;
    CGFloat deltaY = point.y - nearestY;
    return sqrt(deltaX * deltaX + deltaY * deltaY);
}

IDVerticalAutoscrollSelectionEndpoint
IDVerticalAutoscrollResolveActiveEndpoint(
    NSRange previousSelection,
    NSRange currentSelection,
    CGPoint dragPoint,
    CGRect logicalStartRect,
    CGRect logicalEndRect,
    IDVerticalAutoscrollSelectionEndpoint fallback) {
    BOOL locationChanged =
        previousSelection.location != currentSelection.location;
    BOOL maximumChanged =
        NSMaxRange(previousSelection) !=
        NSMaxRange(currentSelection);
    if (maximumChanged && !locationChanged) {
        return IDVerticalAutoscrollSelectionEndpointEnd;
    }
    if (locationChanged && !maximumChanged) {
        return IDVerticalAutoscrollSelectionEndpointStart;
    }

    CGFloat startDistance =
        IDVerticalAutoscrollDistanceToRect(
            dragPoint, logicalStartRect);
    CGFloat endDistance =
        IDVerticalAutoscrollDistanceToRect(
            dragPoint, logicalEndRect);
    if (startDistance < endDistance) {
        return IDVerticalAutoscrollSelectionEndpointStart;
    }
    if (endDistance < startDistance) {
        return IDVerticalAutoscrollSelectionEndpointEnd;
    }
    return fallback;
}

#endif
