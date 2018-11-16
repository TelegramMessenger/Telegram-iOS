//
//  ASCollectionNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASCollectionNode+Beta.h>

#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASCollectionInternal.h>
#import <AsyncDisplayKit/ASCollectionLayout.h>
#import <AsyncDisplayKit/ASCollectionViewLayoutFacilitatorProtocol.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASSectionContext.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASAbstractLayoutController+FrameworkPrivate.h>

#pragma mark - _ASCollectionPendingState

@interface _ASCollectionPendingState : NSObject {
@public
  std::vector<std::vector<ASRangeTuningParameters>> _tuningParameters;
}
@property (nonatomic, weak) id <ASCollectionDelegate>   delegate;
@property (nonatomic, weak) id <ASCollectionDataSource> dataSource;
@property (nonatomic) UICollectionViewLayout *collectionViewLayout;
@property (nonatomic) ASLayoutRangeMode rangeMode;
@property (nonatomic) BOOL allowsSelection; // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO
@property (nonatomic) BOOL inverted; //default is NO
@property (nonatomic) BOOL usesSynchronousDataLoading;
@property (nonatomic) CGFloat leadingScreensForBatching;
@property (nonatomic, weak) id <ASCollectionViewLayoutInspecting> layoutInspector;
@property (nonatomic) BOOL alwaysBounceVertical;
@property (nonatomic) BOOL alwaysBounceHorizontal;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) CGPoint contentOffset;
@property (nonatomic) BOOL animatesContentOffset;
@property (nonatomic) BOOL showsVerticalScrollIndicator;
@property (nonatomic) BOOL showsHorizontalScrollIndicator;
@end

@implementation _ASCollectionPendingState

#pragma mark Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self) {
    _rangeMode = ASLayoutRangeModeUnspecified;
    _tuningParameters = [ASAbstractLayoutController defaultTuningParameters];
    _allowsSelection = YES;
    _allowsMultipleSelection = NO;
    _inverted = NO;
    _contentInset = UIEdgeInsetsZero;
    _contentOffset = CGPointZero;
    _animatesContentOffset = NO;
    _showsVerticalScrollIndicator = YES;
    _showsHorizontalScrollIndicator = YES;
  }
  return self;
}

#pragma mark Tuning Parameters

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  return [self setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeMode][rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Setting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeMode][rangeType] = tuningParameters;
}

@end

#pragma mark - ASCollectionNode

@interface ASCollectionNode ()
{
  ASDN::RecursiveMutex _environmentStateLock;
  Class _collectionViewClass;
  id<ASBatchFetchingDelegate> _batchFetchingDelegate;
}
@property (nonatomic) _ASCollectionPendingState *pendingState;
@property (nonatomic, weak) ASRangeController *rangeController;
@end

@implementation ASCollectionNode

#pragma mark Lifecycle

- (Class)collectionViewClass
{
  return _collectionViewClass ? : [ASCollectionView class];
}

- (void)setCollectionViewClass:(Class)collectionViewClass
{
  if (_collectionViewClass != collectionViewClass) {
    ASDisplayNodeAssert([collectionViewClass isSubclassOfClass:[ASCollectionView class]] || collectionViewClass == Nil, @"ASCollectionNode requires that .collectionViewClass is an ASCollectionView subclass");
    ASDisplayNodeAssert([self isNodeLoaded] == NO, @"ASCollectionNode's .collectionViewClass cannot be changed after the view is loaded");
    _collectionViewClass = collectionViewClass;
  }
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:CGRectZero collectionViewLayout:layout layoutFacilitator:nil];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:frame collectionViewLayout:layout layoutFacilitator:nil];
}

- (instancetype)initWithLayoutDelegate:(id<ASCollectionLayoutDelegate>)layoutDelegate layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator
{
  return [self initWithFrame:CGRectZero collectionViewLayout:[[ASCollectionLayout alloc] initWithLayoutDelegate:layoutDelegate] layoutFacilitator:layoutFacilitator];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator
{
  if (self = [super init]) {
    // Must call the setter here to make sure pendingState is created and the layout is configured.
    [self setCollectionViewLayout:layout];
    
    __weak __typeof__(self) weakSelf = self;
    [self setViewBlock:^{
      __typeof__(self) strongSelf = weakSelf;
      return [[[strongSelf collectionViewClass] alloc] _initWithFrame:frame collectionViewLayout:strongSelf->_pendingState.collectionViewLayout layoutFacilitator:layoutFacilitator owningNode:strongSelf eventLog:ASDisplayNodeGetEventLog(strongSelf)];
    }];
  }
  return self;
}

#if ASDISPLAYNODE_ASSERTIONS_ENABLED
- (void)dealloc
{
  if (self.nodeLoaded) {
    __weak UIView *view = self.view;
    ASPerformBlockOnMainThread(^{
      ASDisplayNodeCAssertNil(view.superview, @"Node's view should be removed from hierarchy.");
    });
  }
}
#endif

#pragma mark ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *view = self.view;
  view.collectionNode    = self;
 
  _rangeController = view.rangeController;
  
  if (_pendingState) {
    _ASCollectionPendingState *pendingState = _pendingState;
    self.pendingState                   = nil;
    view.asyncDelegate                  = pendingState.delegate;
    view.asyncDataSource                = pendingState.dataSource;
    view.inverted                       = pendingState.inverted;
    view.allowsSelection                = pendingState.allowsSelection;
    view.allowsMultipleSelection        = pendingState.allowsMultipleSelection;
    view.usesSynchronousDataLoading     = pendingState.usesSynchronousDataLoading;
    view.layoutInspector                = pendingState.layoutInspector;
    view.showsVerticalScrollIndicator   = pendingState.showsVerticalScrollIndicator;
    view.showsHorizontalScrollIndicator = pendingState.showsHorizontalScrollIndicator;

    // Only apply these flags if they're enabled; the view might come with them turned on.
    if (pendingState.alwaysBounceVertical) {
      view.alwaysBounceVertical = YES;
    }
    if (pendingState.alwaysBounceHorizontal) {
      view.alwaysBounceHorizontal = YES;
    }

    UIEdgeInsets contentInset = pendingState.contentInset;
    if (!UIEdgeInsetsEqualToEdgeInsets(contentInset, UIEdgeInsetsZero)) {
      view.contentInset = contentInset;
    }

    CGPoint contentOffset = pendingState.contentOffset;
    if (!CGPointEqualToPoint(contentOffset, CGPointZero)) {
      [view setContentOffset:contentOffset animated:pendingState.animatesContentOffset];
    }
    
    let tuningParametersVector = pendingState->_tuningParameters;
    let tuningParametersVectorSize = tuningParametersVector.size();
    for (NSInteger rangeMode = 0; rangeMode < tuningParametersVectorSize; rangeMode++) {
      let tuningparametersRangeModeVector = tuningParametersVector[rangeMode];
      let tuningParametersVectorRangeModeSize = tuningparametersRangeModeVector.size();
      for (NSInteger rangeType = 0; rangeType < tuningParametersVectorRangeModeSize; rangeType++) {
        ASRangeTuningParameters tuningParameters = tuningparametersRangeModeVector[rangeType];
        [_rangeController setTuningParameters:tuningParameters
                                 forRangeMode:(ASLayoutRangeMode)rangeMode
                                    rangeType:(ASLayoutRangeType)rangeType];
      }
    }
    
    if (pendingState.rangeMode != ASLayoutRangeModeUnspecified) {
      [_rangeController updateCurrentRangeWithMode:pendingState.rangeMode];
    }
    
    // Don't need to set collectionViewLayout to the view as the layout was already used to init the view in view block.
  }
}

- (ASCollectionView *)view
{
  return (ASCollectionView *)[super view];
}

- (void)clearContents
{
  [super clearContents];
  [self.rangeController clearContents];
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  [super interfaceStateDidChange:newState fromState:oldState];
  [ASRangeController layoutDebugOverlayIfNeeded];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  // ASCollectionNode is often nested inside of other collections. In this case, ASHierarchyState's RangeManaged bit will be set.
  // Intentionally allocate the view here and trigger a layout pass on it, which in turn will trigger the intial data load.
  // We can get rid of this call later when ASDataController, ASRangeController and ASCollectionLayout can operate without the view.
  // TODO (ASCL) If this node supports async layout, kick off the initial data load without allocating the view
  if (ASHierarchyStateIncludesRangeManaged(self.hierarchyState) && CGRectEqualToRect(self.bounds, CGRectZero) == NO) {
    [self.view layoutIfNeeded];
  }
}

#if ASRangeControllerLoggingEnabled
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  NSLog(@"%@ - visible: YES", self);
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];
  NSLog(@"%@ - visible: NO", self);
}
#endif

- (void)didExitPreloadState
{
  [super didExitPreloadState];
  [self.rangeController clearPreloadedData];
}

#pragma mark Setter / Getter

// TODO: Implement this without the view. Then revisit ASLayoutElementCollectionTableSetTraitCollection
- (ASDataController *)dataController
{
  return self.view.dataController;
}

- (_ASCollectionPendingState *)pendingState
{
  if (!_pendingState && ![self isNodeLoaded]) {
    self.pendingState = [[_ASCollectionPendingState alloc] init];
  }
  ASDisplayNodeAssert(![self isNodeLoaded] || !_pendingState, @"ASCollectionNode should not have a pendingState once it is loaded");
  return _pendingState;
}

- (void)setInverted:(BOOL)inverted
{
  self.transform = inverted ? CATransform3DMakeScale(1, -1, 1)  : CATransform3DIdentity;
  if ([self pendingState]) {
    _pendingState.inverted = inverted;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.inverted = inverted;
  }
}

- (BOOL)inverted
{
  if ([self pendingState]) {
    return _pendingState.inverted;
  } else {
    return self.view.inverted;
  }
}

- (void)setLayoutInspector:(id<ASCollectionViewLayoutInspecting>)layoutInspector
{
  if ([self pendingState]) {
    _pendingState.layoutInspector = layoutInspector;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.layoutInspector = layoutInspector;
  }
}

- (id<ASCollectionViewLayoutInspecting>)layoutInspector
{
  if ([self pendingState]) {
    return _pendingState.layoutInspector;
  } else {
    return self.view.layoutInspector;
  }
}

- (void)setLeadingScreensForBatching:(CGFloat)leadingScreensForBatching
{
  if ([self pendingState]) {
    _pendingState.leadingScreensForBatching = leadingScreensForBatching;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.leadingScreensForBatching = leadingScreensForBatching;
  }
}

- (CGFloat)leadingScreensForBatching
{
  if ([self pendingState]) {
    return _pendingState.leadingScreensForBatching;
  } else {
    return self.view.leadingScreensForBatching;
  }
}

- (void)setDelegate:(id <ASCollectionDelegate>)delegate
{
  if ([self pendingState]) {
    _pendingState.delegate = delegate;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASCollectionView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDelegate = delegate;
    });
  }
}

- (id <ASCollectionDelegate>)delegate
{
  if ([self pendingState]) {
    return _pendingState.delegate;
  } else {
    return self.view.asyncDelegate;
  }
}

- (void)setDataSource:(id <ASCollectionDataSource>)dataSource
{
  if ([self pendingState]) {
    _pendingState.dataSource = dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASCollectionView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDataSource = dataSource;
    });
  }
}

- (id <ASCollectionDataSource>)dataSource
{
  if ([self pendingState]) {
    return _pendingState.dataSource;
  } else {
    return self.view.asyncDataSource;
  }
}

- (void)setAllowsSelection:(BOOL)allowsSelection
{
  if ([self pendingState]) {
    _pendingState.allowsSelection = allowsSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.allowsSelection = allowsSelection;
  }
}

- (BOOL)allowsSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsSelection;
  } else {
    return self.view.allowsSelection;
  }
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelection = allowsMultipleSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.allowsMultipleSelection = allowsMultipleSelection;
  }
}

- (BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsMultipleSelection;
  } else {
    return self.view.allowsMultipleSelection;
  }
}

- (void)setAlwaysBounceVertical:(BOOL)alwaysBounceVertical
{
  if ([self pendingState]) {
    _pendingState.alwaysBounceVertical = alwaysBounceVertical;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.alwaysBounceVertical = alwaysBounceVertical;
  }
}

- (BOOL)alwaysBounceVertical
{
  if ([self pendingState]) {
    return _pendingState.alwaysBounceVertical;
  } else {
    return self.view.alwaysBounceVertical;
  }
}

- (void)setAlwaysBounceHorizontal:(BOOL)alwaysBounceHorizontal
{
  if ([self pendingState]) {
    _pendingState.alwaysBounceHorizontal = alwaysBounceHorizontal;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.alwaysBounceHorizontal = alwaysBounceHorizontal;
  }
}

- (BOOL)alwaysBounceHorizontal
{
  if ([self pendingState]) {
    return _pendingState.alwaysBounceHorizontal;
  } else {
    return self.view.alwaysBounceHorizontal;
  }
}

- (void)setShowsVerticalScrollIndicator:(BOOL)showsVerticalScrollIndicator
{
  if ([self pendingState]) {
    _pendingState.showsVerticalScrollIndicator = showsVerticalScrollIndicator;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.showsVerticalScrollIndicator = showsVerticalScrollIndicator;
  }
}

- (BOOL)showsVerticalScrollIndicator
{
  if ([self pendingState]) {
    return _pendingState.showsVerticalScrollIndicator;
  } else {
    return self.view.showsVerticalScrollIndicator;
  }
}

- (void)setShowsHorizontalScrollIndicator:(BOOL)showsHorizontalScrollIndicator
{
  if ([self pendingState]) {
    _pendingState.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator;
  }
}

- (BOOL)showsHorizontalScrollIndicator
{
  if ([self pendingState]) {
    return _pendingState.showsHorizontalScrollIndicator;
  } else {
    return self.view.showsHorizontalScrollIndicator;
  }
}

- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout
{
  if ([self pendingState]) {
    [self _configureCollectionViewLayout:layout];
    _pendingState.collectionViewLayout = layout;
  } else {
    [self _configureCollectionViewLayout:layout];
    self.view.collectionViewLayout = layout;
  }
}

- (UICollectionViewLayout *)collectionViewLayout
{
  if ([self pendingState]) {
    return _pendingState.collectionViewLayout;
  } else {
    return self.view.collectionViewLayout;
  }
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
  if ([self pendingState]) {
    _pendingState.contentInset = contentInset;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.contentInset = contentInset;
  }
}

- (UIEdgeInsets)contentInset
{
  if ([self pendingState]) {
    return _pendingState.contentInset;
  } else {
    return self.view.contentInset;
  }
}

- (void)setContentOffset:(CGPoint)contentOffset
{
  [self setContentOffset:contentOffset animated:NO];
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
  if ([self pendingState]) {
    _pendingState.contentOffset = contentOffset;
    _pendingState.animatesContentOffset = animated;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    [self.view setContentOffset:contentOffset animated:animated];
  }
}

- (CGPoint)contentOffset
{
  if ([self pendingState]) {
    return _pendingState.contentOffset;
  } else {
    return self.view.contentOffset;
  }
}

- (ASScrollDirection)scrollDirection
{
  return [self isNodeLoaded] ? self.view.scrollDirection : ASScrollDirectionNone;
}

- (ASScrollDirection)scrollableDirections
{
  return [self isNodeLoaded] ? self.view.scrollableDirections : ASScrollDirectionNone;
}

- (ASElementMap *)visibleElements
{
  ASDisplayNodeAssertMainThread();
  // TODO Own the data controller when view is not yet loaded
  return self.dataController.visibleMap;
}

- (id<ASCollectionLayoutDelegate>)layoutDelegate
{
  UICollectionViewLayout *layout = self.collectionViewLayout;
  if ([layout isKindOfClass:[ASCollectionLayout class]]) {
    return ((ASCollectionLayout *)layout).layoutDelegate;
  }
  return nil;
}

- (void)setBatchFetchingDelegate:(id<ASBatchFetchingDelegate>)batchFetchingDelegate
{
  _batchFetchingDelegate = batchFetchingDelegate;
}

- (id<ASBatchFetchingDelegate>)batchFetchingDelegate
{
  return _batchFetchingDelegate;
}

- (BOOL)usesSynchronousDataLoading
{
  if ([self pendingState]) {
    return _pendingState.usesSynchronousDataLoading; 
  } else {
    return self.view.usesSynchronousDataLoading;
  }
}

- (void)setUsesSynchronousDataLoading:(BOOL)usesSynchronousDataLoading
{
  if ([self pendingState]) {
    _pendingState.usesSynchronousDataLoading = usesSynchronousDataLoading; 
  } else {
    self.view.usesSynchronousDataLoading = usesSynchronousDataLoading;
  }
}

#pragma mark - Range Tuning

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [self setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  if ([self pendingState]) {
    return [_pendingState tuningParametersForRangeMode:rangeMode rangeType:rangeType];
  } else {
    return [self.rangeController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
  }
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  if ([self pendingState]) {
    [_pendingState setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
  } else {
    return [self.rangeController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
  }
}

#pragma mark - Selection

- (NSArray<NSIndexPath *> *)indexPathsForSelectedItems
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *view = self.view;
  return [view convertIndexPathsToCollectionNode:view.indexPathsForSelectedItems];
}

- (void)selectItemAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
  } else {
    NSLog(@"Failed to select item at index path %@ because the item never reached the view.", indexPath);
  }
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView deselectItemAtIndexPath:indexPath animated:animated];
  } else {
    NSLog(@"Failed to deselect item at index path %@ because the item never reached the view.", indexPath);
  }
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  } else {
    NSLog(@"Failed to scroll to item at index path %@ because the item never reached the view.", indexPath);
  }
}

#pragma mark - Querying Data

- (void)reloadDataInitiallyIfNeeded
{
  if (!self.dataController.initialReloadDataHasBeenCalled) {
    [self reloadData];
  }
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap numberOfItemsInSection:section];
}

- (NSInteger)numberOfSections
{
  [self reloadDataInitiallyIfNeeded];
  return self.dataController.pendingMap.numberOfSections;
}

- (NSArray<__kindof ASCellNode *> *)visibleNodes
{
  ASDisplayNodeAssertMainThread();
  return self.isNodeLoaded ? [self.view visibleNodes] : @[];
}

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap elementForItemAtIndexPath:indexPath].node;
}

- (id)nodeModelForItemAtIndexPath:(NSIndexPath *)indexPath
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap elementForItemAtIndexPath:indexPath].nodeModel;
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self.dataController.pendingMap indexPathForElement:cellNode.collectionElement];
}

- (NSArray<NSIndexPath *> *)indexPathsForVisibleItems
{
  ASDisplayNodeAssertMainThread();
  NSMutableArray *indexPathsArray = [NSMutableArray new];
  for (ASCellNode *cell in [self visibleNodes]) {
    NSIndexPath *indexPath = [self indexPathForNode:cell];
    if (indexPath) {
      [indexPathsArray addObject:indexPath];
    }
  }
  return indexPathsArray;
}

- (nullable NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  NSIndexPath *indexPath = [collectionView indexPathForItemAtPoint:point];
  if (indexPath != nil) {
    return [collectionView convertIndexPathToCollectionNode:indexPath];
  }
  return indexPath;
}

- (nullable UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];
  if (indexPath == nil) {
    return nil;
  }
  return [collectionView cellForItemAtIndexPath:indexPath];
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [self.dataController.pendingMap contextForSection:section];
}

#pragma mark - Editing

- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind
{
  [self.view registerSupplementaryNodeOfKind:elementKind];
}

- (void)performBatchAnimated:(BOOL)animated updates:(NS_NOESCAPE void (^)())updates completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view performBatchAnimated:animated updates:updates completion:completion];
  } else {
    if (updates) {
      updates();
    }
    if (completion) {
      completion(YES);
    }
  }
}

- (void)performBatchUpdates:(NS_NOESCAPE void (^)())updates completion:(void (^)(BOOL))completion
{
  [self performBatchAnimated:UIView.areAnimationsEnabled updates:updates completion:completion];
}

- (BOOL)isProcessingUpdates
{
  return (self.nodeLoaded ? [self.view isProcessingUpdates] : NO);
}

- (void)onDidFinishProcessingUpdates:(void (^)())completion
{
  if (!completion) {
    return;
  }
  if (!self.nodeLoaded) {
    completion();
  } else {
    [self.view onDidFinishProcessingUpdates:completion];
  }
}

- (BOOL)isSynchronized
{
  return (self.nodeLoaded ? [self.view isSynchronized] : YES);
}

- (void)onDidFinishSynchronizing:(void (^)())completion
{
  if (!completion) {
    return;
  }
  if (!self.nodeLoaded) {
    completion();
  } else {
    [self.view onDidFinishSynchronizing:completion];
  }
}

- (void)waitUntilAllUpdatesAreProcessed
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view waitUntilAllUpdatesAreCommitted];
  }
}

- (void)waitUntilAllUpdatesAreCommitted
{
  [self waitUntilAllUpdatesAreProcessed];
}

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssertMainThread();
  if (!self.nodeLoaded) {
    return;
  }
  
  [self performBatchUpdates:^{
    [self.view.changeSet reloadData];
  } completion:^(BOOL finished){
    if (completion) {
      completion();
    }
  }];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)relayoutItems
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
  	[self.view relayoutItems];
  }
}

- (void)beginUpdates
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view beginUpdates];
  }
}

- (void)endUpdatesAnimated:(BOOL)animated
{
  [self endUpdatesAnimated:animated completion:nil];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view endUpdatesAnimated:animated completion:completion];
  }
}

- (void)invalidateFlowLayoutDelegateMetrics {
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view invalidateFlowLayoutDelegateMetrics];
  }
}

- (void)insertSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertSections:sections];
  }
}

- (void)deleteSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteSections:sections];
  }
}

- (void)reloadSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadSections:sections];
  }
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveSection:section toSection:newSection];
  }
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertItemsAtIndexPaths:indexPaths];
  }
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteItemsAtIndexPaths:indexPaths];
  }
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadItemsAtIndexPaths:indexPaths];
  }
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
  }
}

#pragma mark - ASRangeControllerUpdateRangeProtocol

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;
{
  if ([self pendingState]) {
    _pendingState.rangeMode = rangeMode;
  } else {
    [self.rangeController updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark - ASPrimitiveTraitCollection

ASLayoutElementCollectionTableSetTraitCollection(_environmentStateLock)

#pragma mark - Debugging (Private)

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [super propertiesForDebugDescription];
  [result addObject:@{ @"dataSource" : ASObjectDescriptionMakeTiny(self.dataSource) }];
  [result addObject:@{ @"delegate" : ASObjectDescriptionMakeTiny(self.delegate) }];
  return result;
}

#pragma mark - Private methods

- (void)_configureCollectionViewLayout:(UICollectionViewLayout *)layout
{
  if ([layout isKindOfClass:[ASCollectionLayout class]]) {
    ASCollectionLayout *collectionLayout = (ASCollectionLayout *)layout;
    collectionLayout.collectionNode = self;
  }
}

@end

#endif
