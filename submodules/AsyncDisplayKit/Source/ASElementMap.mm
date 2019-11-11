//
//  ASElementMap.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASElementMap.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/ASMutableElementMap.h>
#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@interface ASElementMap () <ASDescriptionProvider>

@property (nonatomic, readonly) NSArray<ASSection *> *sections;

// Element -> IndexPath
@property (nonatomic, readonly) NSMapTable<ASCollectionElement *, NSIndexPath *> *elementToIndexPathMap;

// The items, in a 2D array
@property (nonatomic, readonly) ASCollectionElementTwoDimensionalArray *sectionsOfItems;

@property (nonatomic, readonly) ASSupplementaryElementDictionary *supplementaryElements;

@end

@implementation ASElementMap

- (instancetype)init
{
  return [self initWithSections:@[] items:@[] supplementaryElements:@{}];
}

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements
{
  NSCParameterAssert(items.count == sections.count);

  if (self = [super init]) {
    _sections = [sections copy];
    _sectionsOfItems = [[NSArray alloc] initWithArray:items copyItems:YES];
    _supplementaryElements = [[NSDictionary alloc] initWithDictionary:supplementaryElements copyItems:YES];

    // Setup our index path map
    _elementToIndexPathMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableCopyIn];
    NSInteger s = 0;
    for (NSArray *section in _sectionsOfItems) {
      NSInteger i = 0;
      for (ASCollectionElement *element in section) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:s];
        [_elementToIndexPathMap setObject:indexPath forKey:element];
        i++;
      }
      s++;
    }
    for (NSDictionary *supplementariesForKind in [_supplementaryElements objectEnumerator]) {
      [supplementariesForKind enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *_Nonnull indexPath, ASCollectionElement * _Nonnull element, BOOL * _Nonnull stop) {
        [_elementToIndexPathMap setObject:indexPath forKey:element];
      }];
    }
  }
  return self;
}

- (NSUInteger)count
{
  return _elementToIndexPathMap.count;
}

- (NSArray<NSIndexPath *> *)itemIndexPaths
{
  return ASIndexPathsForTwoDimensionalArray(_sectionsOfItems);
}

- (NSArray<ASCollectionElement *> *)itemElements
{
  return ASElementsInTwoDimensionalArray(_sectionsOfItems);
}

- (NSInteger)numberOfSections
{
  return _sectionsOfItems.count;
}

- (NSArray<NSString *> *)supplementaryElementKinds
{
  return _supplementaryElements.allKeys;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
  if (![self sectionIndexIsValid:section assert:YES]) {
    return 0;
  }

  return _sectionsOfItems[section].count;
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  if (![self sectionIndexIsValid:section assert:NO]) {
    return nil;
  }

  return _sections[section].context;
}

- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element
{
  return element ? [_elementToIndexPathMap objectForKey:element] : nil;
}

- (nullable NSIndexPath *)indexPathForElementIfCell:(ASCollectionElement *)element
{
  if (element.supplementaryElementKind == nil) {
    return [self indexPathForElement:element];
  } else {
    return nil;
  }
}

- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath
{
  NSInteger section, item;
  if (![self itemIndexPathIsValid:indexPath assert:NO item:&item section:&section]) {
    return nil;
  }

  return _sectionsOfItems[section][item];
}

- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath
{
  return _supplementaryElements[supplementaryElementKind][indexPath];
}

- (ASCollectionElement *)elementForLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  switch (layoutAttributes.representedElementCategory) {
    case UICollectionElementCategoryCell:
      // Cell
      return [self elementForItemAtIndexPath:layoutAttributes.indexPath];
    case UICollectionElementCategorySupplementaryView:
      // Supplementary element.
      return [self supplementaryElementOfKind:layoutAttributes.representedElementKind atIndexPath:layoutAttributes.indexPath];
    case UICollectionElementCategoryDecorationView:
      // No support for decoration views.
      return nil;
  }
}

- (NSIndexPath *)convertIndexPath:(NSIndexPath *)indexPath fromMap:(ASElementMap *)map
{
  if (indexPath.item == NSNotFound) {
    // Section index path
    NSInteger result = [self convertSection:indexPath.section fromMap:map];
    return (result != NSNotFound ? [NSIndexPath indexPathWithIndex:result] : nil);
  } else {
    // Item index path
    ASCollectionElement *element = [map elementForItemAtIndexPath:indexPath];
    return [self indexPathForElement:element];
  }
}

- (NSInteger)convertSection:(NSInteger)sectionIndex fromMap:(ASElementMap *)map
{
  if (![map sectionIndexIsValid:sectionIndex assert:YES]) {
    return NSNotFound;
  }

  ASSection *section = map.sections[sectionIndex];
  return [_sections indexOfObjectIdenticalTo:section];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

// NSMutableCopying conformance is declared in ASMutableElementMap.h, so that most consumers of ASElementMap don't bother with it.
#pragma mark - NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone
{
  return [[ASMutableElementMap alloc] initWithSections:_sections items:_sectionsOfItems supplementaryElements:_supplementaryElements];
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id  _Nullable __unsafe_unretained [])buffer count:(NSUInteger)len
{
  return [_elementToIndexPathMap countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)smallDescription
{
  NSMutableArray *sectionDescriptions = [NSMutableArray array];

  NSUInteger i = 0;
  for (NSArray *section in _sectionsOfItems) {
    [sectionDescriptions addObject:[NSString stringWithFormat:@"<S%tu: %tu>", i, section.count]];
    i++;
  }
  return ASObjectDescriptionMakeWithoutObject(@[ @{ @"itemCounts": sectionDescriptions }]);
}

#pragma mark - ASDescriptionProvider

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [NSMutableArray array];
  [result addObject:@{ @"items" : _sectionsOfItems }];
  [result addObject:@{ @"supplementaryElements" : _supplementaryElements }];
  return result;
}

#pragma mark - Internal

/**
 * Fails assert + return NO if section is out of bounds.
 */
- (BOOL)sectionIndexIsValid:(NSInteger)section assert:(BOOL)assert
{
  NSInteger sectionCount = _sectionsOfItems.count;
  if (section >= sectionCount || section < 0) {
    if (assert) {
      ASDisplayNodeFailAssert(@"Invalid section index %ld when there are only %ld sections!", (long)section, (long)sectionCount);
    }
    return NO;
  } else {
    return YES;
  }
}

/**
 * If indexPath is nil, just returns NO.
 * If indexPath is invalid, fails assertion and returns NO.
 * Otherwise returns YES and sets the item & section.
 */
- (BOOL)itemIndexPathIsValid:(NSIndexPath *)indexPath assert:(BOOL)assert item:(out NSInteger *)outItem section:(out NSInteger *)outSection
{
  if (indexPath == nil) {
    return NO;
  }

  NSInteger section = indexPath.section;
  if (![self sectionIndexIsValid:section assert:assert]) {
    return NO;
  }

  NSInteger itemCount = _sectionsOfItems[section].count;
  NSInteger item = indexPath.item;
  if (item >= itemCount || item < 0) {
    if (assert) {
      ASDisplayNodeFailAssert(@"Invalid item index %ld in section %ld which only has %ld items!", (long)item, (long)section, (long)itemCount);
    }
    return NO;
  }
  *outItem = item;
  *outSection = section;
  return YES;
}

@end

#endif
