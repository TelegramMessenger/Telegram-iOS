#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface IDTextLayoutCanvasView : UIView

@property(nonatomic, strong, readonly) NSTextLayoutManager *textLayoutManager;
@property(nonatomic, strong, readonly) NSTextContainer *textContainer;
@property(nonatomic, strong, readonly) NSTextViewportLayoutController *textViewportLayoutController;
@property(nonatomic, weak, nullable) id context;
@property(nonatomic, strong, nullable) UIView *id_selectionContainerView;
@property(nonatomic, copy, nullable) void (^contentSizeDidChange)(CGSize size);

- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)layoutManager
                            textContainer:(NSTextContainer *)textContainer NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)performViewportLayout;
- (void)viewportBoundsDidChange;

@end

NS_ASSUME_NONNULL_END

#endif
