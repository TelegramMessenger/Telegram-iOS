#import "UIMenuItem+Icons.h"

#import "NSBag.h"
#import <ObjCRuntimeUtils/RuntimeUtils.h>

static const void *imageKey = &imageKey;
static const void *imageViewKey = &imageViewKey;
static NSString *const imageItemIdetifier = @"\uFEFF\u200B";

@interface UIMenuController (Icons)

@end

@implementation UIMenuController (Icons)

- (UIMenuItem *)findImageItemByTitle:(NSString *)title {
    if ([title hasSuffix:imageItemIdetifier]) {
        for (UIMenuItem *item in self.menuItems) {
            if ([item.title isEqualToString:title]) {
                return item;
            }
        }
    }
    return nil;
}

@end


@implementation UIMenuItem (Icons)

- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon action:(SEL)action {
    NSString *combinedTitle = title;
    if (icon != nil) {
        combinedTitle = [NSString stringWithFormat:@"%@%@", title, imageItemIdetifier];
    }
    self = [self initWithTitle:combinedTitle action:action];
    if (self != nil) {
        if (icon != nil) {
            [self _tg_setImage:icon];
        }
    }
    return self;
}

- (UIImage *)_tg_image {
    return (UIImage *)[self associatedObjectForKey:imageKey];
}

- (void)_tg_setImage:(UIImage *)image {
    [self setAssociatedObject:image forKey:imageKey associationPolicy:NSObjectAssociationPolicyRetain];
}

@end

@interface NSString (Items)

@end

@implementation NSString (Items)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[NSString class] currentSelector:@selector(sizeWithAttributes:) newSelector:@selector(_78724db9_sizeWithAttributes:)];
    });
}

- (CGSize)_78724db9_sizeWithAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs {
    UIMenuItem *item = [[UIMenuController sharedMenuController] findImageItemByTitle:self];
    UIImage *image = item._tg_image;
    if (image != nil) {
        return image.size;
    } else {
        return [self _78724db9_sizeWithAttributes:attrs];
    }
}

@end


@interface UILabel (Icons)

@end

static UIColor *DateLabelColor = nil;


@implementation UILabel (DateLabel)

+ (void)setDateLabelColor:(UIColor *)color
{
    DateLabelColor = color;
}

@end

@implementation UILabel (Icons)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UILabel class] currentSelector:@selector(drawTextInRect:) newSelector:@selector(_78724db9_drawTextInRect:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UILabel class] currentSelector:@selector(layoutSubviews) newSelector:@selector(_78724db9_layoutSubviews)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UILabel class] currentSelector:@selector(setFrame:) newSelector:@selector(_78724db9_setFrame:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UILabel class] currentSelector:@selector(setTextColor:) newSelector:@selector(_78724db9_setTextColor:)];
    });
}

- (void)_78724db9_drawTextInRect:(CGRect)rect {
    UIMenuItem *item = [[UIMenuController sharedMenuController] findImageItemByTitle:self.text];
    UIImage *image = item._tg_image;
    if (image == nil) {
        [self _78724db9_drawTextInRect:rect];
    }
}

- (void)_78724db9_setTextColor:(UIColor *)color {
    if ([NSStringFromClass(self.superview.class) hasPrefix:@"UIDatePicker"] && DateLabelColor != nil) {
        [self _78724db9_setTextColor:DateLabelColor];
    } else {
        [self _78724db9_setTextColor:color];
    }
}

- (void)_78724db9_layoutSubviews {
    if ([NSStringFromClass(self.superview.class) hasPrefix:@"UIDatePicker"] && DateLabelColor != nil) {
        [self _78724db9_setTextColor:DateLabelColor];
    }
    
    UIMenuItem *item = [[UIMenuController sharedMenuController] findImageItemByTitle:self.text];
    UIImage *image = item._tg_image;
    if (image == nil) {
        [self _78724db9_layoutSubviews];
        return;
    }
    
    CGPoint point = CGPointMake(ceil((self.bounds.size.width - image.size.width) / 2.0), ceil((self.bounds.size.height - image.size.height) / 2.0));
    UIImageView *imageView = [self associatedObjectForKey:imageViewKey];
    if (imageView == nil) {
        imageView = [[UIImageView alloc] init];
        [self addSubview:imageView];
        [self setAssociatedObject:imageView forKey:imageViewKey associationPolicy:NSObjectAssociationPolicyRetain];
    }
    
    imageView.image = image;
    imageView.frame = CGRectMake(point.x, point.y, image.size.width, image.size.height);
}

- (void)_78724db9_setFrame:(CGRect)frame
{
    bool hasImage = [[UIMenuController sharedMenuController] findImageItemByTitle:self.text]._tg_image != nil;
    CGRect rect = frame;
    if (hasImage && self.superview != nil) {
        rect = self.superview.bounds;
    }
    [self _78724db9_setFrame:rect];
}

@end
