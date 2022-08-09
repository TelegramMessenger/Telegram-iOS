#import "TGMediaSelectionContext.h"

@interface TGMediaSelectionChange ()

+ (instancetype)changeWithItem:(id<TGMediaSelectableItem>)item selected:(bool)selected animated:(bool)animated sender:(id)sender;

@end


@interface TGMediaSelectionContext ()
{
    NSMutableArray *_savedSelectedIdentifiers;
    
    NSMutableArray *_selectedIdentifiers;
    NSMutableDictionary *_selectionMap;
    
    SPipe *_pipe;
    SMetaDisposable *_itemSourceUpdatedDisposable;
    
    SPipe *_groupingChangedPipe;
}
@end

@implementation TGMediaSelectionContext

- (instancetype)init
{
    return [self initWithGroupingAllowed:false selectionLimit:100];
}

- (instancetype)initWithGroupingAllowed:(bool)allowGrouping selectionLimit:(int)selectionLimit
{
    self = [super init];
    if (self != nil)
    {
        _selectedIdentifiers = [[NSMutableArray alloc] init];
        _selectionMap = [[NSMutableDictionary alloc] init];
        
        _pipe = [[SPipe alloc] init];
        _itemSourceUpdatedDisposable = [[SMetaDisposable alloc] init];
        
        _groupingChangedPipe = [[SPipe alloc] init];
        
        _allowGrouping = allowGrouping;
        _selectionLimit = selectionLimit;
    }
    return self;
}

- (void)dealloc
{
    [_itemSourceUpdatedDisposable dispose];
}

- (void)toggleGrouping
{
    _grouping = !_grouping;
    _groupingChangedPipe.sink(@(_grouping));
}

- (SSignal *)groupingChangedSignal
{
    return _groupingChangedPipe.signalProducer();
}

- (bool)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected
{
    return [self setItem:item selected:selected animated:false sender:nil];
}

- (bool)setItem:(id<TGMediaSelectableItem>)item selected:(bool)selected animated:(bool)animated sender:(id)sender
{
    if (![(id)item conformsToProtocol:@protocol(TGMediaSelectableItem)])
        return false;
    
    NSString *identifier = item.uniqueIdentifier;
    if (selected)
    {
        if ([_selectedIdentifiers containsObject:identifier]) {
            return false;
        }
        
        if (_selectedIdentifiers.count >= _selectionLimit) {
            if (_selectionLimitExceeded) {
                _selectionLimitExceeded();
            }
            return false;
        }
        
        _selectionMap[identifier] = item;
        [_selectedIdentifiers addObject:identifier];
    }
    else
    {
        if (_selectionMap[identifier] == nil)
            return false;
        
        [_selectedIdentifiers removeObject:identifier];
    }
    
    _pipe.sink([TGMediaSelectionChange changeWithItem:item selected:selected animated:animated sender:sender]);
    
    return true;
}

- (NSUInteger)indexOfItem:(id<TGMediaSelectableItem>)item
{
    if (![(id)item conformsToProtocol:@protocol(TGMediaSelectableItem)])
        return NSNotFound;
    
    NSString *identifier = item.uniqueIdentifier;
    if (_selectionMap[identifier] == nil)
        return NSNotFound;
    
    NSUInteger index = [_selectedIdentifiers indexOfObject:identifier];
    if (index == NSNotFound)
        return index;
    
    return index + 1;
}

- (void)clear
{
    NSArray *items = self.selectedItems;

    for (id<TGMediaSelectableItem> item in items)
        [self setItem:item selected:false animated:false sender:self];
}

- (bool)isItemSelected:(id<TGMediaSelectableItem>)item
{
    return [self isIdentifierSelected:item.uniqueIdentifier];
}

- (bool)isIdentifierSelected:(NSString *)identifier
{
    return [_selectedIdentifiers containsObject:identifier];
}

- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item success:(bool *)success
{
    return [self toggleItemSelection:item animated:false sender:nil success:success];
}

- (bool)toggleItemSelection:(id<TGMediaSelectableItem>)item animated:(bool)animated sender:(id)sender success:(bool *)success
{
    bool newValue = ![self isItemSelected:item];
    bool result = [self setItem:item selected:newValue animated:animated sender:sender];
    if (success) {
        *success = result;
    }
    
    return newValue;
}

- (void)moveItem:(id<TGMediaSelectableItem>)item toIndex:(NSUInteger)index {
    NSUInteger sourceIndex = [self indexOfItem:item] - 1;
    
    [_selectedIdentifiers removeObjectAtIndex:sourceIndex];
    [_selectedIdentifiers insertObject:item.uniqueIdentifier atIndex:index - 1];
    
    _pipe.sink([TGMediaSelectionChange changeWithItem:item selected:true animated:false sender:nil]);
}

- (SSignal *)itemSelectedSignal:(id<TGMediaSelectableItem>)item
{
    return [[self itemInformativeSelectedSignal:item] map:^NSNumber *(TGMediaSelectionChange *change)
    {
        return @(change.selected);
    }];
}

- (SSignal *)itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item
{
    return [_pipe.signalProducer() filter:^bool(TGMediaSelectionChange *change)
    {
        return [change.item.uniqueIdentifier isEqualToString:item.uniqueIdentifier];
    }];
}

- (SSignal *)selectionChangedSignal
{
    return _pipe.signalProducer();
}

- (void)enumerateSelectedItems:(void (^)(id<TGMediaSelectableItem>))enumerationBlock
{
    if (enumerationBlock == nil)
        return;
    
    for (NSString *identifier in _selectedIdentifiers)
    {
        NSObject<TGMediaSelectableItem> *item = _selectionMap[identifier];
        if (item != nil) {
            enumerationBlock(item);
        }
    }
}

- (void)enumerateDeselectedItems:(void (^)(id<TGMediaSelectableItem>))enumerationBlock
{
    if (enumerationBlock == nil || _savedSelectedIdentifiers == nil)
        return;
    
    for (NSString *identifier in _savedSelectedIdentifiers)
    {
        if (![_selectedIdentifiers containsObject:identifier]) {
            NSObject<TGMediaSelectableItem> *item = _selectionMap[identifier];
            if (item != nil) {
                enumerationBlock(item);
            }
        }
    }
}

- (NSOrderedSet *)selectedItemsIdentifiers
{
    return [[NSOrderedSet alloc] initWithArray:_selectedIdentifiers];
}

- (NSArray *)selectedItems
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSArray *identifier in _selectedIdentifiers)
    {
        NSObject<TGMediaSelectableItem> *item = _selectionMap[identifier];
        if (item != nil)
            [items addObject:item];
    }
    return items;
}

- (NSUInteger)count
{
    return _selectedIdentifiers.count;
}

- (void)saveState {
    if (_savedSelectedIdentifiers == nil) {
        _savedSelectedIdentifiers = [_selectedIdentifiers mutableCopy];
    }
}

- (void)restoreState {
    _selectedIdentifiers = _savedSelectedIdentifiers;
    _savedSelectedIdentifiers = nil;
    
    _pipe.sink([TGMediaSelectionChange changeWithItem:nil selected:false animated:false sender:nil]);
}

- (void)clearSavedState {
    _savedSelectedIdentifiers = nil;
}

- (NSUInteger)savedStateDifference {
    if (_savedSelectedIdentifiers != nil) {
        return _savedSelectedIdentifiers.count - _selectedIdentifiers.count;
    } else {
        return 0;
    }
}

#pragma mark - 

- (void)setItemSourceUpdatedSignal:(SSignal *)signal
{
    __weak TGMediaSelectionContext *weakSelf = self;
    [_itemSourceUpdatedDisposable setDisposable:[[[signal mapToSignal:^SSignal *(__unused id value)
    {
        __strong TGMediaSelectionContext *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        NSArray *selectedItems = strongSelf.selectedItems;
        if (strongSelf.updatedItemsSignal != nil)
            return strongSelf.updatedItemsSignal(selectedItems);
        
        return [SSignal fail:nil];
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        __strong TGMediaSelectionContext *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        NSMutableArray *deletedItemsIdentifiers = [strongSelf->_selectedIdentifiers mutableCopy];
        NSDictionary *previousItemsMap = [strongSelf->_selectionMap copy];
        
        [strongSelf->_selectedIdentifiers removeAllObjects];
        [strongSelf->_selectionMap removeAllObjects];
        
        for (id<TGMediaSelectableItem> item in next)
        {
            [strongSelf->_selectedIdentifiers addObject:item.uniqueIdentifier];
            strongSelf->_selectionMap[item.uniqueIdentifier] = item;
            
            [deletedItemsIdentifiers removeObject:item.uniqueIdentifier];
        }
        
        for (NSString *identifier in deletedItemsIdentifiers)
            strongSelf->_pipe.sink([TGMediaSelectionChange changeWithItem:previousItemsMap[identifier] selected:false animated:false sender:nil]);
    }]];
}

#pragma mark - 

+ (SSignal *)combinedSelectionChangedSignalForContexts:(NSArray *)contexts
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
     
        for (TGMediaSelectionContext *context in contexts)
        {
            SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
            [compositeDisposable add:currentDisposable];
            
            [currentDisposable setDisposable:[[context selectionChangedSignal] startWithNext:^(id next)
            {
                [subscriber putNext:next];
            }]];
        }
        
        return compositeDisposable;
    }];
}

@end


@implementation TGMediaSelectionChange

+ (instancetype)changeWithItem:(id<TGMediaSelectableItem>)item selected:(bool)selected animated:(bool)animated sender:(id)sender
{
    TGMediaSelectionChange *change = [[TGMediaSelectionChange alloc] init];
    change->_item = (NSObject<TGMediaSelectableItem> *)item;
    change->_selected = selected;
    change->_animated = animated;
    change->_sender = sender;
    return change;
}

@end
