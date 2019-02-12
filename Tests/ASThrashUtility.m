//
//  ASTableViewThrashTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASThrashUtility.h"
#import <AsyncDisplayKit/ASTableViewInternal.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>

static NSString *ASThrashArrayDescription(NSArray *array)
{
  NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
  NSInteger i = 0;
  for (id obj in array) {
    [str appendFormat:@"\t[%ld]: \"%@\",\n", (long)i, obj];
    i += 1;
  }
  [str appendString:@")"];
  return str;
}

@implementation ASThrashTestItem

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _itemID = atomic_fetch_add(&ASThrashTestItemNextID, 1);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil) {
        _itemID = [aDecoder decodeIntegerForKey:@"itemID"];
        NSAssert(_itemID > 0, @"Failed to decode %@", self);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:_itemID forKey:@"itemID"];
}

+ (NSMutableArray <ASThrashTestItem *> *)itemsWithCount:(NSInteger)count
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i += 1) {
        [result addObject:[[ASThrashTestItem alloc] init]];
    }
    return result;
}

- (CGFloat)rowHeight
{
    return (self.itemID % 400) ?: 44;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Item %lu>", (unsigned long)_itemID];
}

@end

static atomic_uint ASThrashTestSectionNextID = 1;
@implementation ASThrashTestSection

/// Create an array of sections with the given count
+ (NSMutableArray <ASThrashTestSection *> *)sectionsWithCount:(NSInteger)count
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i += 1) {
        [result addObject:[[ASThrashTestSection alloc] initWithCount:kInitialItemCount]];
    }
    return result;
}

- (instancetype)initWithCount:(NSInteger)count
{
    self = [super init];
    if (self != nil) {
        _sectionID = atomic_fetch_add(&ASThrashTestSectionNextID, 1);
        _items = [ASThrashTestItem itemsWithCount:count];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithCount:0];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil) {
        _items = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"items"];
        _sectionID = [aDecoder decodeIntegerForKey:@"sectionID"];
        NSAssert(_sectionID > 0, @"Failed to decode %@", self);
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_items forKey:@"items"];
    [aCoder encodeInteger:_sectionID forKey:@"sectionID"];
}

- (CGFloat)headerHeight
{
    return self.sectionID % 400 ?: 44;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Section %lu: itemCount=%lu, items=%@>", (unsigned long)_sectionID, (unsigned long)self.items.count, ASThrashArrayDescription(self.items)];
}

- (id)copyWithZone:(NSZone *)zone
{
    ASThrashTestSection *copy = [[ASThrashTestSection alloc] init];
    copy->_sectionID = _sectionID;
    copy->_items = [_items mutableCopy];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[ASThrashTestSection class]]) {
        return [(ASThrashTestSection *)object sectionID] == _sectionID;
    } else {
        return NO;
    }
}

@end

@implementation NSIndexSet (ASThrashHelpers)

- (NSArray <NSIndexPath *> *)indexPathsInSection:(NSInteger)section
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [result addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
    }];
    return result;
}

/// `insertMode` means that for each index selected, the max goes up by one.
+ (NSMutableIndexSet *)randomIndexesLessThan:(NSInteger)max probability:(float)probability insertMode:(BOOL)insertMode
{
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];
    u_int32_t cutoff = probability * 100;
    for (NSInteger i = 0; i < max; i++) {
        if (arc4random_uniform(100) < cutoff) {
            [indexes addIndex:i];
            if (insertMode) {
                max += 1;
            }
        }
    }
    return indexes;
}

@end

@implementation ASThrashDataSource

- (instancetype)initTableViewDataSourceWithData:(NSArray <ASThrashTestSection *> *)data
{
    self = [super init];
    if (self != nil) {
        _data = [[NSArray alloc] initWithArray:data copyItems:YES];
        _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _tableView = [[TableView alloc] initWithFrame:_window.bounds style:UITableViewStylePlain];
        _allNodes = [[ASWeakSet alloc] init];
        [_window addSubview:_tableView];
#if USE_UIKIT_REFERENCE
        _tableView.dataSource = self;
        _tableView.delegate = self;
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseID];
#else
        _tableView.asyncDelegate = self;
        _tableView.asyncDataSource = self;
        [_tableView reloadData];
        [_tableView waitUntilAllUpdatesAreCommitted];
#endif
        [_tableView layoutIfNeeded];
    }
    return self;
}

- (instancetype)initCollectionViewDataSourceWithData:(NSArray <ASThrashTestSection *> *)data
{
  self = [super init];
  if (self != nil) {
    _data = data != nil ? [[NSArray alloc] initWithArray:data copyItems:YES] : [[NSArray alloc] init];
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _collectionView = [[CollectionView alloc] initWithCollectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
    _allNodes = [[ASWeakSet alloc] init];
    [_window addSubview:_tableView];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
#if USE_UIKIT_REFERENCE
    [_collectionView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseID];
#else
    [_collectionView reloadData];
    [_collectionView waitUntilAllUpdatesAreProcessed];
#endif
    [_collectionView layoutIfNeeded];
  }
  return self;
}

- (void)setData:(NSArray<ASThrashTestSection *> *)data
{
  _data = data;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.data[section].items.count;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.data.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return self.data[section].headerHeight;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return self.data[section].items.count;
}


- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
{
  return self.data.count;
}

/// Object passed into predicate is ignored.
- (NSPredicate *)predicateForDeallocatedHierarchy
{
    ASWeakSet *allNodes = self.allNodes;
    __weak UIWindow *window = _window;
    __weak ASTableView *view = _tableView;
    return [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return window == nil && view == nil && allNodes.isEmpty;
    }];
}

#if USE_UIKIT_REFERENCE

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:kCellReuseID forIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ASThrashTestItem *item = self.data[indexPath.section].items[indexPath.item];
    return item.rowHeight;
}

#else

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASThrashTestNode *node = [[ASThrashTestNode alloc] init];
  node.item = self.data[indexPath.section].items[indexPath.row];
  [self.allNodes addObject:node];
  return node;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ASThrashTestNode *node = [[ASThrashTestNode alloc] init];
    node.item = self.data[indexPath.section].items[indexPath.item];
    [self.allNodes addObject:node];
    return node;
}

#endif

@end

#if !USE_UIKIT_REFERENCE
@implementation ASThrashTestNode

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDisplayNodeAssertFalse(isinf(constrainedSize.width));
  return CGSizeMake(constrainedSize.width, 44);
}

@end
#endif

@implementation ASThrashUpdate

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data
{
  self = [super init];
  if (self != nil) {
    _data = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
    _oldData = [[NSArray alloc] initWithArray:data copyItems:YES];

    _deletedItemIndexes = [NSMutableArray array];
    _replacedItemIndexes = [NSMutableArray array];
    _insertedItemIndexes = [NSMutableArray array];
    _replacingItems = [NSMutableArray array];
    _insertedItems = [NSMutableArray array];

    // Randomly reload some items
    for (ASThrashTestSection *section in _data) {
      NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO];
      NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
      [section.items replaceObjectsAtIndexes:indexes withObjects:newItems];
      [_replacingItems addObject:newItems];
      [_replacedItemIndexes addObject:indexes];
    }

    // Randomly replace some sections
    _replacedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO];
    _replacingSections = [ASThrashTestSection sectionsWithCount:_replacedSectionIndexes.count];
    [_data replaceObjectsAtIndexes:_replacedSectionIndexes withObjects:_replacingSections];

    // Randomly delete some items
    [_data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
      if (section.items.count >= kMinimumItemCount) {
        NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO];

        /// Cannot reload & delete the same item.
        [indexes removeIndexes:_replacedItemIndexes[idx]];

        [section.items removeObjectsAtIndexes:indexes];
        [_deletedItemIndexes addObject:indexes];
      } else {
        [_deletedItemIndexes addObject:[NSMutableIndexSet indexSet]];
      }
    }];

    // Randomly delete some sections
    if (_data.count >= kMinimumSectionCount) {
      _deletedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO];
    } else {
      _deletedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    // Cannot replace & delete the same section.
    [_deletedSectionIndexes removeIndexes:_replacedSectionIndexes];

    // Cannot delete/replace item in deleted/replaced section
    [_deletedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    [_replacedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    [_data removeObjectsAtIndexes:_deletedSectionIndexes];

    // Randomly insert some sections
    _insertedSectionIndexes = [NSIndexSet randomIndexesLessThan:(_data.count + 1) probability:kFickleness insertMode:YES];
    _insertedSections = [ASThrashTestSection sectionsWithCount:_insertedSectionIndexes.count];
    [_data insertObjects:_insertedSections atIndexes:_insertedSectionIndexes];

    // Randomly insert some items
    for (ASThrashTestSection *section in _data) {
      // Only insert items into the old sections – not replaced/inserted sections.
      if ([_oldData containsObject:section]) {
        NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:(section.items.count + 1) probability:kFickleness insertMode:YES];
        NSArray *newItems = [ASThrashTestItem itemsWithCount:indexes.count];
        [section.items insertObjects:newItems atIndexes:indexes];
        [_insertedItems addObject:newItems];
        [_insertedItemIndexes addObject:indexes];
      } else {
        [_insertedItems addObject:@[]];
        [_insertedItemIndexes addObject:[NSMutableIndexSet indexSet]];
      }
    }
  }
  return self;
}

+ (BOOL)supportsSecureCoding
{
  return YES;
}

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64
{
  return [NSKeyedUnarchiver unarchiveObjectWithData:[[NSData alloc] initWithBase64EncodedString:base64 options:kNilOptions]];
}

- (NSString *)base64Representation
{
  return [[NSKeyedArchiver archivedDataWithRootObject:self] base64EncodedStringWithOptions:kNilOptions];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
  NSDictionary *dict = [self dictionaryWithValuesForKeys:@[
                                                           @"oldData",
                                                           @"data",
                                                           @"deletedSectionIndexes",
                                                           @"replacedSectionIndexes",
                                                           @"replacingSections",
                                                           @"insertedSectionIndexes",
                                                           @"insertedSections",
                                                           @"deletedItemIndexes",
                                                           @"replacedItemIndexes",
                                                           @"replacingItems",
                                                           @"insertedItemIndexes",
                                                           @"insertedItems"
                                                           ]];
  [aCoder encodeObject:dict forKey:@"_dict"];
  [aCoder encodeInteger:ASThrashUpdateCurrentSerializationVersion forKey:@"_version"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self != nil) {
    NSAssert(ASThrashUpdateCurrentSerializationVersion == [aDecoder decodeIntegerForKey:@"_version"], @"This thrash update was archived from a different version and can't be read. Sorry.");
    NSDictionary *dict = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"_dict"];
    [self setValuesForKeysWithDictionary:dict];
  }
  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<ASThrashUpdate %p:\nOld data: %@\nDeleted items: %@\nDeleted sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@>", self, ASThrashArrayDescription(_oldData), ASThrashArrayDescription(_deletedItemIndexes), _deletedSectionIndexes, ASThrashArrayDescription(_replacedItemIndexes), _replacedSectionIndexes, ASThrashArrayDescription(_insertedItemIndexes), _insertedSectionIndexes, ASThrashArrayDescription(_data)];
}

- (NSString *)logFriendlyBase64Representation
{
  return [NSString stringWithFormat:@"\n\n**********\nBase64 Representation:\n**********\n%@\n**********\nEnd Base64 Representation\n**********", self.base64Representation];
}

@end
