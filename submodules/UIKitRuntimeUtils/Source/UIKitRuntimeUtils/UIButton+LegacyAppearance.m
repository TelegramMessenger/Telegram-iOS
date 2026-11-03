#import <UIKitRuntimeUtils/UIButton+LegacyAppearance.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIButton (LegacyAppearance)

- (BOOL)legacyAdjustsImageWhenHighlighted {
    return self.adjustsImageWhenHighlighted;
}

- (void)setLegacyAdjustsImageWhenHighlighted:(BOOL)value {
    self.adjustsImageWhenHighlighted = value;
}

- (BOOL)legacyAdjustsImageWhenDisabled {
    return self.adjustsImageWhenDisabled;
}

- (void)setLegacyAdjustsImageWhenDisabled:(BOOL)value {
    self.adjustsImageWhenDisabled = value;
}

- (UIEdgeInsets)legacyContentEdgeInsets {
    return self.contentEdgeInsets;
}

- (void)setLegacyContentEdgeInsets:(UIEdgeInsets)value {
    self.contentEdgeInsets = value;
}

- (UIEdgeInsets)legacyImageEdgeInsets {
    return self.imageEdgeInsets;
}

- (void)setLegacyImageEdgeInsets:(UIEdgeInsets)value {
    self.imageEdgeInsets = value;
}

@end

#pragma clang diagnostic pop
