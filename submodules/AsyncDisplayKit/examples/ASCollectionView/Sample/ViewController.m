//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"
#import "AppDelegate.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "SupplementaryNode.h"
#import "ItemNode.h"

#define ASYNC_COLLECTION_LAYOUT 0

static CGSize const kItemSize = (CGSize){180, 90};

@interface ViewController () <ASCollectionDataSource, ASCollectionDelegateFlowLayout, ASCollectionGalleryLayoutPropertiesProviding>

@property (nonatomic, strong) ASCollectionNode *collectionNode;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSString *> *> *data;
@property (nonatomic, strong) UILongPressGestureRecognizer *moveRecognizer;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.moveRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress)];
  [self.view addGestureRecognizer:self.moveRecognizer];
  
#if ASYNC_COLLECTION_LAYOUT
  ASCollectionGalleryLayoutDelegate *layoutDelegate = [[ASCollectionGalleryLayoutDelegate alloc] initWithScrollableDirections:ASScrollDirectionVerticalDirections];
  layoutDelegate.propertiesProvider = self;
  self.collectionNode = [[ASCollectionNode alloc] initWithLayoutDelegate:layoutDelegate layoutFacilitator:nil];
#else
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.headerReferenceSize = CGSizeMake(50.0, 50.0);
  layout.footerReferenceSize = CGSizeMake(50.0, 50.0);
  layout.itemSize = kItemSize;
  self.collectionNode = [[ASCollectionNode alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
  [self.collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [self.collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
#endif
  
  self.collectionNode.dataSource = self;
  self.collectionNode.delegate = self;
  
  self.collectionNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.collectionNode.backgroundColor = [UIColor whiteColor];
  
  [self.view addSubnode:self.collectionNode];
  self.collectionNode.frame = self.view.bounds;
  
#if !SIMULATE_WEB_RESPONSE
  self.navigationItem.leftItemsSupplementBackButton = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                        target:self
                                                                                        action:@selector(reloadTapped)];
  [self loadData];
#else
  __weak typeof(self) weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [weakSelf handleSimulatedWebResponse];
  });
#endif
}

- (void)handleSimulatedWebResponse
{
  [self.collectionNode performBatchUpdates:^{
    [self loadData];
    [self.collectionNode insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.data.count)]];
  } completion:nil];
}

- (void)loadData
{
  // Form our data array
  typeof(self.data) data = [NSMutableArray array];
  for (NSInteger s = 0; s < 100; s++) {
    NSMutableArray *items = [NSMutableArray array];
    for (NSInteger i = 0; i < 10; i++) {
      items[i] = [NSString stringWithFormat:@"[%zd.%zd] says hi", s, i];
    }
    data[s] = items;
  }
  self.data = data;
}

#pragma mark - Button Actions

- (void)reloadTapped
{
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  [self.collectionNode reloadData];
}

#pragma mark - ASCollectionGalleryLayoutPropertiesProviding

- (CGSize)galleryLayoutDelegate:(ASCollectionGalleryLayoutDelegate *)delegate sizeForElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  return kItemSize;
}

- (void)handleLongPress
{
  UICollectionView *collectionView = self.collectionNode.view;
  CGPoint location = [self.moveRecognizer locationInView:collectionView];
  switch (self.moveRecognizer.state) {
    case UIGestureRecognizerStateBegan: {
      NSIndexPath *indexPath = [collectionView indexPathForItemAtPoint:location];
      if (indexPath) {
        [collectionView beginInteractiveMovementForItemAtIndexPath:indexPath];
      }
      break;
    }
    case UIGestureRecognizerStateChanged:
      [collectionView updateInteractiveMovementTargetPosition:location];
      break;
    case UIGestureRecognizerStateEnded:
      [collectionView endInteractiveMovement];
      break;
    case UIGestureRecognizerStateFailed:
    case UIGestureRecognizerStateCancelled:
      [collectionView cancelInteractiveMovement];
      break;
    case UIGestureRecognizerStatePossible:
      // nop
      break;
  }
}

#pragma mark - ASCollectionDataSource

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;
{
  NSString *text = self.data[indexPath.section][indexPath.item];
  return ^{
    return [[ItemNode alloc] initWithString:text];
  };
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [kind isEqualToString:UICollectionElementKindSectionHeader] ? @"Header" : @"Footer";
  SupplementaryNode *node = [[SupplementaryNode alloc] initWithText:text];
  BOOL isHeaderSection = [kind isEqualToString:UICollectionElementKindSectionHeader];
  node.backgroundColor = isHeaderSection ? [UIColor blueColor] : [UIColor redColor];
  return node;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return self.data[section].count;
}

- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
{
  return self.data.count;
}

- (BOOL)collectionNode:(ASCollectionNode *)collectionNode canMoveItemWithNode:(ASCellNode *)node
{
  return YES;
}

- (void)collectionNode:(ASCollectionNode *)collectionNode moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
  __auto_type sectionArray = self.data[sourceIndexPath.section];
  __auto_type object = sectionArray[sourceIndexPath.item];
  [sectionArray removeObjectAtIndex:sourceIndexPath.item];
  [self.data[destinationIndexPath.section] insertObject:object atIndex:destinationIndexPath.item];
}

#pragma mark - ASCollectionDelegate

- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [context completeBatchFetching:YES];
}

@end
