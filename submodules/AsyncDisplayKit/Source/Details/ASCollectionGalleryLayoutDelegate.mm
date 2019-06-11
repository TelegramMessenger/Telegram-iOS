//
//  ASCollectionGalleryLayoutDelegate.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionGalleryLayoutDelegate.h>

#import <AsyncDisplayKit/_ASCollectionGalleryLayoutInfo.h>
#import <AsyncDisplayKit/_ASCollectionGalleryLayoutItem.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollections.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASCollectionLayoutDefines.h>
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>

#pragma mark - ASCollectionGalleryLayoutDelegate

@implementation ASCollectionGalleryLayoutDelegate {
  ASScrollDirection _scrollableDirections;

  struct {
    unsigned int minimumLineSpacingForElements:1;
    unsigned int minimumInteritemSpacingForElements:1;
    unsigned int sectionInsetForElements:1;
  } _propertiesProviderFlags;
}

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections
{
  self = [super init];
  if (self) {
    // Scrollable directions must be either vertical or horizontal, but not both
    ASDisplayNodeAssertTrue(ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                            || ASScrollDirectionContainsHorizontalDirection(scrollableDirections));
    ASDisplayNodeAssertFalse(ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                             && ASScrollDirectionContainsHorizontalDirection(scrollableDirections));
    _scrollableDirections = scrollableDirections;
  }
  return self;
}

- (ASScrollDirection)scrollableDirections
{
  ASDisplayNodeAssertMainThread();
  return _scrollableDirections;
}

- (void)setPropertiesProvider:(id<ASCollectionGalleryLayoutPropertiesProviding>)propertiesProvider
{
  ASDisplayNodeAssertMainThread();
  if (propertiesProvider == nil) {
    _propertiesProvider = nil;
    _propertiesProviderFlags = {};
  } else {
    _propertiesProvider = propertiesProvider;
    _propertiesProviderFlags.minimumLineSpacingForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:minimumLineSpacingForElements:)];
    _propertiesProviderFlags.minimumInteritemSpacingForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:minimumInteritemSpacingForElements:)];
    _propertiesProviderFlags.sectionInsetForElements = [_propertiesProvider respondsToSelector:@selector(galleryLayoutDelegate:sectionInsetForElements:)];
  }
}

- (id)additionalInfoForLayoutWithElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  id<ASCollectionGalleryLayoutPropertiesProviding> propertiesProvider = _propertiesProvider;
  if (propertiesProvider == nil) {
    return nil;
  }

  CGSize itemSize = [propertiesProvider galleryLayoutDelegate:self sizeForElements:elements];
  UIEdgeInsets sectionInset = _propertiesProviderFlags.sectionInsetForElements ? [propertiesProvider galleryLayoutDelegate:self sectionInsetForElements:elements] : UIEdgeInsetsZero;
  CGFloat lineSpacing = _propertiesProviderFlags.minimumLineSpacingForElements ? [propertiesProvider galleryLayoutDelegate:self minimumLineSpacingForElements:elements] : 0.0;
  CGFloat interitemSpacing = _propertiesProviderFlags.minimumInteritemSpacingForElements ? [propertiesProvider galleryLayoutDelegate:self minimumInteritemSpacingForElements:elements] : 0.0;
  return [[_ASCollectionGalleryLayoutInfo alloc] initWithItemSize:itemSize
                                               minimumLineSpacing:lineSpacing
                                          minimumInteritemSpacing:interitemSpacing
                                                     sectionInset:sectionInset];
}

+ (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context
{
  ASElementMap *elements = context.elements;
  CGSize pageSize = context.viewportSize;
  ASScrollDirection scrollableDirections = context.scrollableDirections;

  _ASCollectionGalleryLayoutInfo *info = ASDynamicCast(context.additionalInfo, _ASCollectionGalleryLayoutInfo);
  CGSize itemSize = info.itemSize;
  if (info == nil || CGSizeEqualToSize(CGSizeZero, itemSize)) {
    return [[ASCollectionLayoutState alloc] initWithContext:context];
  }

  NSArray<_ASGalleryLayoutItem *> *children = ASArrayByFlatMapping(elements.itemElements,
                                                                   ASCollectionElement *element,
                                                                   [[_ASGalleryLayoutItem alloc] initWithItemSize:itemSize collectionElement:element]);
  if (children.count == 0) {
    return [[ASCollectionLayoutState alloc] initWithContext:context];
  }

  // Use a stack spec to calculate layout content size and frames of all elements without actually measuring each element
  ASStackLayoutDirection stackDirection = ASScrollDirectionContainsVerticalDirection(scrollableDirections)
                                              ? ASStackLayoutDirectionHorizontal
                                              : ASStackLayoutDirectionVertical;
  ASStackLayoutSpec *stackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:stackDirection
                                                                         spacing:info.minimumInteritemSpacing
                                                                  justifyContent:ASStackLayoutJustifyContentStart
                                                                      alignItems:ASStackLayoutAlignItemsStart
                                                                        flexWrap:ASStackLayoutFlexWrapWrap
                                                                    alignContent:ASStackLayoutAlignContentStart
                                                                     lineSpacing:info.minimumLineSpacing
                                                                        children:children];
  stackSpec.concurrent = YES;

  ASLayoutSpec *finalSpec = stackSpec;
  UIEdgeInsets sectionInset = info.sectionInset;
  if (UIEdgeInsetsEqualToEdgeInsets(sectionInset, UIEdgeInsetsZero) == NO) {
    finalSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:sectionInset child:stackSpec];
  }

  ASLayout *layout = [finalSpec layoutThatFits:ASSizeRangeForCollectionLayoutThatFitsViewportSize(pageSize, scrollableDirections)];

  return [[ASCollectionLayoutState alloc] initWithContext:context layout:layout getElementBlock:^ASCollectionElement * _Nullable(ASLayout * _Nonnull sublayout) {
    _ASGalleryLayoutItem *item = ASDynamicCast(sublayout.layoutElement, _ASGalleryLayoutItem);
    return item ? item.collectionElement : nil;
  }];
}

@end

#endif
