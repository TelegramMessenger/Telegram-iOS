#import "TGModernGalleryModel.h"

#import "LegacyComponentsInternal.h"

@implementation TGModernGalleryModel

- (void)_transitionCompleted
{
}

- (void)_replaceItems:(NSArray *)items focusingOnItem:(id<TGModernGalleryItem>)item
{
    TGDispatchOnMainThread(^
    {
        _items = items;
        _focusItem = item;
        
        if (_itemsUpdated)
            _itemsUpdated(item);
    });
}

- (void)_focusOnItem:(id<TGModernGalleryItem>)item synchronously:(bool)synchronously
{
    TGDispatchOnMainThread(^
    {
        _focusItem = item;
        
        if (_focusOnItem)
            _focusOnItem(item, synchronously);
    });
}

- (void)_interItemTransitionProgressChanged:(CGFloat)__unused progress
{

}

- (bool)_shouldAutorotate
{
    return true;
}

- (UIView<TGModernGalleryInterfaceView> *)createInterfaceView
{
    return nil;
}

- (UIView<TGModernGalleryDefaultHeaderView> *)createDefaultHeaderView
{
    return nil;
}

- (UIView<TGModernGalleryDefaultFooterView> *)createDefaultFooterView
{
    return nil;
}

- (UIView<TGModernGalleryDefaultFooterAccessoryView> *)createDefaultLeftAccessoryView
{
    return nil;
}

- (UIView<TGModernGalleryDefaultFooterAccessoryView> *)createDefaultRightAccessoryView
{
    return nil;
}

@end
