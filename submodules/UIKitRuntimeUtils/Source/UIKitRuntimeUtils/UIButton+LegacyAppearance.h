#import <UIKit/UIKit.h>

/// Accessors for the `UIButton` appearance properties that iOS 15 deprecated in favour of
/// `UIButtonConfiguration`.
///
/// The buttons these wrap are custom-drawn and deliberately do not adopt a `UIButtonConfiguration`,
/// so UIKit still honours the underlying properties — the deprecation only means "ignored when a
/// configuration is set", which is not the case here. Routing the access through this category keeps
/// the behaviour identical while letting callers (in particular Swift ones, which have no
/// per-statement diagnostic pragma) build under `-warnings-as-errors`.
@interface UIButton (LegacyAppearance)

@property (nonatomic) BOOL legacyAdjustsImageWhenHighlighted;
@property (nonatomic) BOOL legacyAdjustsImageWhenDisabled;
@property (nonatomic) UIEdgeInsets legacyContentEdgeInsets;
@property (nonatomic) UIEdgeInsets legacyImageEdgeInsets;

@end
