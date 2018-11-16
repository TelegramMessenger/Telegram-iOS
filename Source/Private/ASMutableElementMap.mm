//
//  ASMutableElementMap.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASMutableElementMap.h>

#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

typedef NSMutableArray<NSMutableArray<ASCollectionElement *> *> ASMutableCollectionElementTwoDimensionalArray;

typedef NSMutableDictionary<NSString *, NSMutableDictionary<NSIndexPath *, ASCollectionElement *> *> ASMutableSupplementaryElementDictionary;

@implementation ASMutableElementMap {
  ASMutableSupplementaryElementDictionary *_supplementaryElements;
  NSMutableArray<ASSection *> *_sections;
  ASMutableCollectionElementTwoDimensionalArray *_sectionsOfItems;
}

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements
{
  if (self = [super init]) {
    _sections = [sections mutableCopy];
    _sectionsOfItems = (id)ASTwoDimensionalArrayDeepMutableCopy(items);
    _supplementaryElements = [ASMutableElementMap deepMutableCopyOfElementsDictionary:supplementaryElements];
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[ASElementMap alloc] initWithSections:_sections items:_sectionsOfItems supplementaryElements:_supplementaryElements];
}

- (void)removeAllSections
{
  [_sections removeAllObjects];
}

- (void)insertSection:(ASSection *)section atIndex:(NSInteger)index
{
  [_sections insertObject:section atIndex:index];
}

- (void)removeItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(_sectionsOfItems, indexPaths);
}

- (void)removeSectionsAtIndexes:(NSIndexSet *)indexes
{
  [_sections removeObjectsAtIndexes:indexes];
}

- (void)removeSupplementaryElementsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths kind:(NSString *)kind
{
  [_supplementaryElements[kind] removeObjectsForKeys:indexPaths];
}

- (void)removeAllElements
{
  [_sectionsOfItems removeAllObjects];
  [_supplementaryElements removeAllObjects];
}

- (void)removeSectionsOfItems:(NSIndexSet *)itemSections
{
  [_sectionsOfItems removeObjectsAtIndexes:itemSections];
}

- (void)insertEmptySectionsOfItemsAtIndexes:(NSIndexSet *)sections
{
  [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [_sectionsOfItems insertObject:[[NSMutableArray alloc] init]  atIndex:idx];
  }];
}

- (void)insertElement:(ASCollectionElement *)element atIndexPath:(NSIndexPath *)indexPath
{
  NSString *kind = element.supplementaryElementKind;
  if (kind == nil) {
    [_sectionsOfItems[indexPath.section] insertObject:element atIndex:indexPath.item];
  } else {
    NSMutableDictionary *supplementariesForKind = _supplementaryElements[kind];
    if (supplementariesForKind == nil) {
      supplementariesForKind = [[NSMutableDictionary alloc] init];
      _supplementaryElements[kind] = supplementariesForKind;
    }
    supplementariesForKind[indexPath] = element;
  }
}

- (void)migrateSupplementaryElementsWithSectionMapping:(ASIntegerMap *)mapping
{
  // Fast-path, no section changes.
  if (mapping == ASIntegerMap.identityMap) {
    return;
  }

  // For each element kind,
  [_supplementaryElements enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull supps, BOOL * _Nonnull stop) {
    
    // For each index path of that kind, move entries into a new dictionary.
    // Note: it's tempting to update the dictionary in-place but because of the likely collision between old and new index paths,
    // subtle bugs are possible. Note that this process is rare (only on section-level updates),
    // that this work is done off-main, and that the typical supplementary element use case is just 1-per-section (header).
    NSMutableDictionary *newSupps = [[NSMutableDictionary alloc] init];
    [supps enumerateKeysAndObjectsUsingBlock:^(NSIndexPath * _Nonnull oldIndexPath, ASCollectionElement * _Nonnull obj, BOOL * _Nonnull stop) {
      NSInteger oldSection = oldIndexPath.section;
      NSInteger newSection = [mapping integerForKey:oldSection];
      
      if (oldSection == newSection) {
        // Index path stayed the same, just copy it over.
        newSupps[oldIndexPath] = obj;
      } else if (newSection != NSNotFound) {
        // Section index changed, move it.
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:oldIndexPath.item inSection:newSection];
        newSupps[newIndexPath] = obj;
      }
    }];
    [supps setDictionary:newSupps];
  }];
}

#pragma mark - Helpers

+ (ASMutableSupplementaryElementDictionary *)deepMutableCopyOfElementsDictionary:(ASSupplementaryElementDictionary *)originalDict
{
  NSMutableDictionary *deepCopy = [[NSMutableDictionary alloc] initWithCapacity:originalDict.count];
  [originalDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary<NSIndexPath *,ASCollectionElement *> * _Nonnull obj, BOOL * _Nonnull stop) {
    deepCopy[key] = [obj mutableCopy];
  }];
  
  return deepCopy;
}

@end

#endif
