#import <SSignalKit/SSignalKit.h>

@protocol TGMediaSelectableItem

@property (nonatomic, readonly) NSString *uniqueIdentifier;

@end

@interface TGMediaSelectionContext : NSObject

- (instancetype)initWithGroupingAllowed:(bool)allowGrouping selectionLimit:(int)selectionLimit;

@property (nonatomic, readonly) bool allowGrouping;
@property (nonatomic, readonly) int selectionLimit;
@property (nonatomic, copy) void (^selectionLimitExceeded)(void);

@property (nonatomic, assign) bool grouping;
- (SSignal *)groupingChangedSignal;
- (void)toggleGrouping;

@property (nonatomic, copy) SSignal *(^updatedItemsSignal)(NSArray *items);
- (void)setItemSourceUpdatedSignal:(SSignal *)signal;

- (bool)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected;
- (bool)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected animated:(bool)animated sender:(id)sender;

- (NSUInteger)indexOfItem:(id<TGMediaSelectableItem>)item;

- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item success:(bool *)success;
- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item animated:(bool)animated sender:(id)sender success:(bool *)success;

- (void)moveItem:(id<TGMediaSelectableItem>)item toIndex:(NSUInteger)index;

- (void)clear;

- (bool)isItemSelected:(id<TGMediaSelectableItem>)item;
- (bool)isIdentifierSelected:(NSString *)identifier;

- (SSignal *)itemSelectedSignal:(id<TGMediaSelectableItem>)item;
- (SSignal *)itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item;
- (SSignal *)selectionChangedSignal;

- (void)enumerateSelectedItems:(void (^)(id<TGMediaSelectableItem>))enumerationBlock;
- (void)enumerateDeselectedItems:(void (^)(id<TGMediaSelectableItem>))enumerationBlock;

- (NSOrderedSet *)selectedItemsIdentifiers;
- (NSArray *)selectedItems;

- (void)saveState;
- (void)restoreState;
- (void)clearSavedState;

- (NSUInteger)savedStateDifference;

- (NSUInteger)count;

+ (SSignal *)combinedSelectionChangedSignalForContexts:(NSArray *)contexts;

@end


@interface TGMediaSelectionChange : NSObject

@property (nonatomic, readonly) NSObject <TGMediaSelectableItem> *item;
@property (nonatomic, readonly) bool selected;
@property (nonatomic, readonly) bool animated;
@property (nonatomic, readonly, strong) id sender;

@end
