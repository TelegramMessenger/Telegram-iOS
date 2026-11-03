#import <LegacyComponents/TGModernGalleryItemView.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGModernGalleryDefaultFooterView.h>
#import <LegacyComponents/TGModernGalleryDefaultFooterAccessoryView.h>

@implementation TGModernGalleryItemView

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _gesturesEnabled = true;
    }
    return self;
}

- (SSignal *)readyForTransitionIn {
    return [SSignal single:@true];
}

- (void)reset
{
}

- (void)prepareForRecycle
{
}

- (void)prepareForReuse
{
}

- (void)setIsVisible:(bool)__unused isVisible
{
}

- (void)setIsCurrent:(bool)__unused isCurrent
{
}

- (void)setFocused:(bool)isFocused
{
    if (isFocused)
    {
        if ([[self defaultFooterView] respondsToSelector:@selector(setContentHidden:)])
            [[self defaultFooterView] setContentHidden:false];
        else
            [self defaultFooterView].hidden = false;
    }
}

- (UIView *)headerView
{
    return nil;
}

- (UIView *)footerView
{
    return nil;
}

- (UIView *)transitionView
{
    return nil;
}

- (CGRect)transitionViewContentRect
{
    return [self transitionView].bounds;
}

- (bool)dismissControllerNowOrSchedule
{
    return true;
}

- (void)_setItem:(id<TGModernGalleryItem>)item
{
    _item = item;
}

- (void)setItem:(id<TGModernGalleryItem>)item
{
    [self setItem:item synchronously:false];
}

- (void)setItem:(id<TGModernGalleryItem>)item synchronously:(bool)__unused synchronously
{
    _item = item;
    [self.defaultFooterAccessoryLeftView setItem:item];
    [self.defaultFooterAccessoryRightView setItem:item];
}

- (bool)allowsScrollingAtPoint:(CGPoint)__unused point
{
    return _gesturesEnabled;
}

- (SSignal *)contentAvailabilityStateSignal
{
    return nil;
}

- (UIView *)transitionContentView {
    return nil;
}

@end
