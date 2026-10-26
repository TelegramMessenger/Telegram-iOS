#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface IDSelectionPresentationSnapshot : NSObject
@property(nonatomic, readonly) NSRange canonicalSelection;
@property(nonatomic, readonly) CGRect caretRect;
@property(nonatomic, copy, readonly) NSArray<UITextSelectionRect *> *selectionRects;
@property(nonatomic, readonly) CGRect visibleBounds;
@property(nonatomic, readonly) CGPoint contentOffset;
- (instancetype)initWithCanonicalSelection:(NSRange)selection
                                  caretRect:(CGRect)caretRect
                             selectionRects:(NSArray<UITextSelectionRect *> *)rects
                              visibleBounds:(CGRect)visibleBounds
                              contentOffset:(CGPoint)contentOffset
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@protocol IDSelectionPresentationBackend <NSObject>
@property(nonatomic, readonly, nullable) UIView *existingSelectionContainerView;
@property(nonatomic, readonly) NSUInteger presentationUpdateCount;
@property(nonatomic, readonly) NSUInteger selectionContainerCreationCount;
- (UIView *)id_selectionContainerView;
- (void)placeSelectionContainerView;
- (void)updateWithSnapshot:(IDSelectionPresentationSnapshot *)snapshot;
- (void)tearDown;
@end

@class IDBlockTextView;
/// Gated with `IDBlockTextView`, which it takes as its parameter. Clang accepts an availability
/// attribute on a typedef, which is what this needs — compiling the typedef OUT at a lower floor
/// would leave `IDBlockTextViewInternal.h`'s initialiser referencing an undefined type.
typedef id<IDSelectionPresentationBackend> _Nonnull
    (^IDSelectionPresentationBackendFactory)(IDBlockTextView *hostView) API_AVAILABLE(ios(18.4));

NS_ASSUME_NONNULL_END

#endif
