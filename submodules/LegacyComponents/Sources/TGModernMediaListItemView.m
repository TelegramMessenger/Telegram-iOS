#import "TGModernMediaListItemView.h"

#import "TGModernMediaListItemContentView.h"

@implementation TGModernMediaListItemView

- (void)prepareForReuse
{
    [self _recycleItemContentView];

    [super prepareForReuse];
}

- (void)_recycleItemContentView
{
    if (_itemContentView != nil)
    {
        [_itemContentView removeFromSuperview];
        
        if (_recycleItemContentView)
            _recycleItemContentView(_itemContentView);
        
        _itemContentView = nil;
    }
}

- (TGModernMediaListItemContentView *)_takeItemContentView
{
    if (_itemContentView != nil)
    {
        [_itemContentView removeFromSuperview];
        TGModernMediaListItemContentView *result = _itemContentView;
        _itemContentView = nil;
        
        return result;
    }
    
    return nil;
}

- (void)setItemContentView:(TGModernMediaListItemContentView *)itemContentView
{
    [self _recycleItemContentView];
    
    _itemContentView = itemContentView;
    
    if (_itemContentView != nil)
    {
        [self addSubview:_itemContentView];
        _itemContentView.frame = self.bounds;
    }
}

- (void)layoutSubviews
{
    _itemContentView.frame = self.bounds;
}

@end
