@import XCTest;

@class IDTextLayoutCanvasView;

NS_ASSUME_NONNULL_BEGIN

@interface IDTextCanvasFixture : NSObject

@property(nonatomic, readonly) NSTextContentStorage *contentStorage;
@property(nonatomic, readonly) NSTextLayoutManager *layoutManager;
@property(nonatomic, readonly) NSTextContainer *textContainer;
@property(nonatomic, readonly) IDTextLayoutCanvasView *canvas;

- (instancetype)initWithText:(NSString *)text size:(CGSize)size;

@end

FOUNDATION_EXPORT BOOL IDWaitForCondition(NSTimeInterval timeout,
                                          BOOL (^condition)(void));
FOUNDATION_EXPORT UIImage *IDRenderView(UIView *view);
FOUNDATION_EXPORT NSUInteger IDCountRedPixels(UIImage *image, CGRect rect);
FOUNDATION_EXPORT NSArray<NSNumber *> *
IDRedPixelCountsByRow(UIImage *image, CGRect rect);
FOUNDATION_EXPORT NSUInteger IDCountNontransparentPixels(UIImage *image, CGRect rect);

NS_ASSUME_NONNULL_END
