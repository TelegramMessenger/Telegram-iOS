#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDSelectionPresentation.h"

#include <math.h>

static BOOL IDSelectionPresentationRectIsFinite(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect) &&
        isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static void IDSelectionPresentationRaise(NSString *reason) {
    [NSException raise:NSInvalidArgumentException
                format:@"Invalid selection presentation snapshot: %@", reason];
}

@implementation IDSelectionPresentationSnapshot

- (instancetype)initWithCanonicalSelection:(NSRange)selection
                                  caretRect:(CGRect)caretRect
                             selectionRects:(NSArray<UITextSelectionRect *> *)rects
                              visibleBounds:(CGRect)visibleBounds
                              contentOffset:(CGPoint)contentOffset {
    if (selection.location == NSNotFound) {
        IDSelectionPresentationRaise(@"canonical selection is not found");
    }
    if (!IDSelectionPresentationRectIsFinite(visibleBounds)) {
        IDSelectionPresentationRaise(@"visible bounds are not finite");
    }
    if (!isfinite(contentOffset.x) || !isfinite(contentOffset.y)) {
        IDSelectionPresentationRaise(@"content offset is not finite");
    }
    if (selection.length == 0) {
        if (!IDSelectionPresentationRectIsFinite(caretRect)) {
            IDSelectionPresentationRaise(@"collapsed selection requires a finite caret");
        }
    } else if (!CGRectIsNull(caretRect)) {
        IDSelectionPresentationRaise(@"nonempty selection requires a null caret");
    }
    if (rects == nil) {
        IDSelectionPresentationRaise(@"selection rectangles are nil");
    }
    for (UITextSelectionRect *selectionRect in rects) {
        if (![selectionRect isKindOfClass:UITextSelectionRect.class] ||
            !IDSelectionPresentationRectIsFinite(selectionRect.rect)) {
            IDSelectionPresentationRaise(@"selection rectangle geometry is invalid");
        }
    }

    self = [super init];
    if (self != nil) {
        _canonicalSelection = selection;
        _caretRect = caretRect;
        _selectionRects = [rects copy];
        _visibleBounds = visibleBounds;
        _contentOffset = contentOffset;
    }
    return self;
}

@end

#endif
