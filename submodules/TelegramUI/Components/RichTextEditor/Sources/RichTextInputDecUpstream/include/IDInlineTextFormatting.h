#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, IDInlineTextTraits) {
    IDInlineTextTraitBold          = 1 << 0,
    IDInlineTextTraitItalic        = 1 << 1,
    IDInlineTextTraitUnderline     = 1 << 2,
    IDInlineTextTraitStrikethrough = 1 << 3,
};

typedef NS_ENUM(NSInteger, IDInlineTextTraitState) {
    IDInlineTextTraitStateOff,
    IDInlineTextTraitStateOn,
    IDInlineTextTraitStateMixed,
};

FOUNDATION_EXPORT NSAttributedStringKey const
    IDInlineTextBoldAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const
    IDInlineTextItalicAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const
    IDInlineTextUnderlineAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const
    IDInlineTextStrikethroughAttributeName;

NS_ASSUME_NONNULL_END

#endif
