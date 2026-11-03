#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<UIView *> *IDTextSurfacesIntersectingCanvasRect(
    NSMapTable<NSTextLayoutFragment *, UIView *> *surfaces,
    CGRect rect);
FOUNDATION_EXPORT BOOL IDTextFragmentIntersectsDocumentRange(
    NSTextLayoutManager *layoutManager,
    NSTextLayoutFragment *fragment,
    NSRange documentRange);

NS_ASSUME_NONNULL_END

#endif
