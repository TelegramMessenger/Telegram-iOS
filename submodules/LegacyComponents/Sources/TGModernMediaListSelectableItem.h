#import <Foundation/Foundation.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@protocol TGModernMediaListItem;

@protocol TGModernMediaListSelectableItem <TGModernMediaListItem, NSCopying>

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;

- (id<TGMediaSelectableItem>)selectableMediaItem;

@end
