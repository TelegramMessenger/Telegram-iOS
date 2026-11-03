#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextCanvasInvalidation.h"

#include <math.h>

static BOOL IDTextInvalidationRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

NSArray<UIView *> *IDTextSurfacesIntersectingCanvasRect(
    NSMapTable<NSTextLayoutFragment *, UIView *> *surfaces,
    CGRect rect) {
    if (!IDTextInvalidationRectIsFinite(rect)) {
        return @[];
    }
    CGRect target = CGRectStandardize(rect);
    if (CGRectIsEmpty(target) || CGRectIsNull(target) || CGRectIsInfinite(target)) {
        return @[];
    }

    NSMutableArray<UIView *> *matches = [NSMutableArray array];
    for (UIView *surface in surfaces.objectEnumerator.allObjects) {
        CGRect frame = surface.frame;
        if (!IDTextInvalidationRectIsFinite(frame) || CGRectIsEmpty(frame) ||
            CGRectIsNull(frame) || CGRectIsInfinite(frame)) {
            continue;
        }
        if (CGRectIntersectsRect(frame, target)) {
            [matches addObject:surface];
        }
    }
    return matches.copy;
}

BOOL IDTextFragmentIntersectsDocumentRange(NSTextLayoutManager *layoutManager,
                                            NSTextLayoutFragment *fragment,
                                            NSRange documentRange) {
    if (documentRange.location == NSNotFound || documentRange.length == 0 ||
        documentRange.location > (NSUInteger)NSIntegerMax ||
        documentRange.length > NSUIntegerMax - documentRange.location ||
        documentRange.length > (NSUInteger)NSIntegerMax - documentRange.location ||
        fragment.state < NSTextLayoutFragmentStateLayoutAvailable) {
        return NO;
    }
    NSTextContentManager *contentManager = layoutManager.textContentManager;
    NSTextRange *contentRange = contentManager.documentRange;
    NSTextRange *fragmentRange = fragment.rangeInElement;
    if (contentManager == nil || contentRange == nil || fragmentRange == nil) {
        return NO;
    }

    @try {
        NSInteger start = [contentManager offsetFromLocation:contentRange.location
                                                  toLocation:fragmentRange.location];
        NSInteger end = [contentManager offsetFromLocation:contentRange.location
                                                toLocation:fragmentRange.endLocation];
        if (start == NSNotFound || end == NSNotFound || start < 0 || end <= start) {
            return NO;
        }
        NSRange fragmentDocumentRange = NSMakeRange((NSUInteger)start,
                                                    (NSUInteger)(end - start));
        return NSIntersectionRange(fragmentDocumentRange, documentRange).length > 0;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

#endif
