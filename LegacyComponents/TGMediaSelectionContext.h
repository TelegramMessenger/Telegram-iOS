#import <SSignalKit/SSignalKit.h>

@protocol TGMediaSelectableItem

@property (nonatomic, readonly) NSString *uniqueIdentifier;

@end

@interface TGMediaSelectionContext : NSObject

- (instancetype)initWithGroupingAllowed:(bool)allowGrouping;
@property (nonatomic, readonly) bool allowGrouping;

@property (nonatomic, assign) bool grouping;
- (SSignal *)groupingChangedSignal;
- (void)toggleGrouping;

@property (nonatomic, copy) SSignal *(^updatedItemsSignal)(NSArray *items);
- (void)setItemSourceUpdatedSignal:(SSignal *)signal;

- (void)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected;
- (void)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected animated:(bool)animated sender:(id)sender;

- (NSUInteger)indexOfItem:(id<TGMediaSelectableItem>)item;

- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item;
- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item animated:(bool)animated sender:(id)sender;

- (void)clear;

- (bool)isItemSelected:(id<TGMediaSelectableItem>)item;

- (SSignal *)itemSelectedSignal:(id<TGMediaSelectableItem>)item;
- (SSignal *)itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item;
- (SSignal *)selectionChangedSignal;

- (void)enumerateSelectedItems:(void (^)(id<TGMediaSelectableItem>))enumerationBlock;

- (NSOrderedSet *)selectedItemsIdentifiers;
- (NSArray *)selectedItems;

- (NSUInteger)count;

+ (SSignal *)combinedSelectionChangedSignalForContexts:(NSArray *)contexts;

@end


@interface TGMediaSelectionChange : NSObject

@property (nonatomic, readonly) id<TGMediaSelectableItem> item;
@property (nonatomic, readonly) bool selected;
@property (nonatomic, readonly) bool animated;
@property (nonatomic, readonly, strong) id sender;

@end
