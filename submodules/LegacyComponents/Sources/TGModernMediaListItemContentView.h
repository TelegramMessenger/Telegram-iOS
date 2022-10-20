#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernMediaListItem.h>

@interface TGModernMediaListItemContentView : UIView

@property (nonatomic, strong) id<TGModernMediaListItem> item;
@property (nonatomic) bool isHidden;

- (void)prepareForReuse;
- (void)updateItem;

- (void)setItem:(id<TGModernMediaListItem>)item synchronously:(bool)synchronously;

- (void)setHidden:(bool)hidden animated:(bool)animated;

@end
