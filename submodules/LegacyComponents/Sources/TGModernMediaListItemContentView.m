
#import "TGModernMediaListItemContentView.h"

@implementation TGModernMediaListItemContentView

- (void)prepareForReuse
{
}

- (void)updateItem
{
}

- (void)setItem:(id<TGModernMediaListItem>)item
{
    [self setItem:item synchronously:false];
}

- (void)setItem:(id<TGModernMediaListItem>)item synchronously:(bool)__unused synchronously
{
    _item = item;
}

- (void)setHidden:(bool)__unused hidden animated:(bool)__unused animated {
}

@end
