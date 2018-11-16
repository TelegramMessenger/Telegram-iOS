//
//  ASTableNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASTableNode.h>
#import <AsyncDisplayKit/ASTableNode+Beta.h>

#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASTableViewInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASAbstractLayoutController+FrameworkPrivate.h>

#pragma mark - _ASTablePendingState

@interface _ASTablePendingState : NSObject {
@public
  std::vector<std::vector<ASRangeTuningParameters>> _tuningParameters;
}
@property (nonatomic, weak) id <ASTableDelegate>   delegate;
@property (nonatomic, weak) id <ASTableDataSource> dataSource;
@property (nonatomic) ASLayoutRangeMode rangeMode;
@property (nonatomic) BOOL allowsSelection;
@property (nonatomic) BOOL allowsSelectionDuringEditing;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic) BOOL allowsMultipleSelectionDuringEditing;
@property (nonatomic) BOOL inverted;
@property (nonatomic) CGFloat leadingScreensForBatching;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) CGPoint contentOffset;
@property (nonatomic) BOOL animatesContentOffset;
@property (nonatomic) BOOL automaticallyAdjustsContentOffset;

@end

@implementation _ASTablePendingState

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self) {
    _rangeMode = ASLayoutRangeModeUnspecified;
    _tuningParameters = [ASAbstractLayoutController defaultTuningParameters];
    _allowsSelection = YES;
    _allowsSelectionDuringEditing = NO;
    _allowsMultipleSelection = NO;
    _allowsMultipleSelectionDuringEditing = NO;
    _inverted = NO;
    _leadingScreensForBatching = 2;
    _contentInset = UIEdgeInsetsZero;
    _contentOffset = CGPointZero;
    _animatesContentOffset = NO;
    _automaticallyAdjustsContentOffset = NO;
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

#pragma mark - ASTableView

@interface ASTableNode ()
{
  ASDN::RecursiveMutex _environmentStateLock;
  id<ASBatchFetchingDelegate> _batchFetchingDelegate;
}

@property (nonatomic) _ASTablePendingState *pendingState;
@property (nonatomic, weak) ASRangeController *rangeController;
@end

@implementation ASTableNode

#pragma mark Lifecycle

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  if (self = [super init]) {
    __weak __typeof__(self) weakSelf = self;
    [self setViewBlock:^{
      // Variable will be unused if event logging is off.
      __unused __typeof__(self) strongSelf = weakSelf;
      return [[ASTableView alloc] _initWithFrame:CGRectZero style:style dataControllerClass:nil owningNode:strongSelf eventLog:ASDisplayNodeGetEventLog(strongSelf)];
    }];
  }
  return self;
}

- (instancetype)init
{
  return [self initWithStyle:UITableViewStylePlain];
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
  
  ASTableView *view = self.view;
  view.tableNode    = self;
  
  _rangeController = view.rangeController;

  if (_pendingState) {
    _ASTablePendingState *pendingState        = _pendingState;
    self.pendingState                         = nil;
    view.asyncDelegate                        = pendingState.delegate;
    view.asyncDataSource                      = pendingState.dataSource;
    view.inverted                             = pendingState.inverted;
    view.allowsSelection                      = pendingState.allowsSelection;
    view.allowsSelectionDuringEditing         = pendingState.allowsSelectionDuringEditing;
    view.allowsMultipleSelection              = pendingState.allowsMultipleSelection;
    view.allowsMultipleSelectionDuringEditing = pendingState.allowsMultipleSelectionDuringEditing;

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
  }
}

- (ASTableView *)view
{
  return (ASTableView *)[super view];
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
  // Intentionally allocate the view here and trigger a layout pass on it, which in turn will trigger the intial data load.
  // We can get rid of this call later when ASDataController, ASRangeController and ASCollectionLayout can operate without the view.
  [self.view layoutIfNeeded];
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

- (_ASTablePendingState *)pendingState
{
  if (!_pendingState && ![self isNodeLoaded]) {
    _pendingState = [[_ASTablePendingState alloc] init];
  }
  ASDisplayNodeAssert(![self isNodeLoaded] || !_pendingState, @"ASTableNode should not have a pendingState once it is loaded");
  return _pendingState;
}

- (void)setInverted:(BOOL)inverted
{
  self.transform = inverted ? CATransform3DMakeScale(1, -1, 1)  : CATransform3DIdentity;
  if ([self pendingState]) {
    _pendingState.inverted = inverted;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
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

- (void)setLeadingScreensForBatching:(CGFloat)leadingScreensForBatching
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    pendingState.leadingScreensForBatching = leadingScreensForBatching;
  } else {
    ASDisplayNodeAssert(self.nodeLoaded, @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.leadingScreensForBatching = leadingScreensForBatching;
  }
}

- (CGFloat)leadingScreensForBatching
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    return pendingState.leadingScreensForBatching;
  } else {
    return self.view.leadingScreensForBatching;
  }
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    pendingState.contentInset = contentInset;
  } else {
    ASDisplayNodeAssert(self.nodeLoaded, @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.contentInset = contentInset;
  }
}

- (UIEdgeInsets)contentInset
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    return pendingState.contentInset;
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
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    pendingState.contentOffset = contentOffset;
    pendingState.animatesContentOffset = animated;
  } else {
    ASDisplayNodeAssert(self.nodeLoaded, @"ASTableNode should be loaded if pendingState doesn't exist");
    [self.view setContentOffset:contentOffset animated:animated];
  }
}

- (CGPoint)contentOffset
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    return pendingState.contentOffset;
  } else {
    return self.view.contentOffset;
  }
}

- (void)setAutomaticallyAdjustsContentOffset:(BOOL)automaticallyAdjustsContentOffset
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    pendingState.automaticallyAdjustsContentOffset = automaticallyAdjustsContentOffset;
  } else {
    ASDisplayNodeAssert(self.nodeLoaded, @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.automaticallyAdjustsContentOffset = automaticallyAdjustsContentOffset;
  }
}

- (BOOL)automaticallyAdjustsContentOffset
{
  _ASTablePendingState *pendingState = self.pendingState;
  if (pendingState) {
    return pendingState.automaticallyAdjustsContentOffset;
  } else {
    return self.view.automaticallyAdjustsContentOffset;
  }
}

- (void)setDelegate:(id <ASTableDelegate>)delegate
{
  if ([self pendingState]) {
    _pendingState.delegate = delegate;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASTableView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDelegate = delegate;
    });
  }
}

- (id <ASTableDelegate>)delegate
{
  if ([self pendingState]) {
    return _pendingState.delegate;
  } else {
    return self.view.asyncDelegate;
  }
}

- (void)setDataSource:(id <ASTableDataSource>)dataSource
{
  if ([self pendingState]) {
    _pendingState.dataSource = dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASTableView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDataSource = dataSource;
    });
  }
}

- (id <ASTableDataSource>)dataSource
{
  if ([self pendingState]) {
    return _pendingState.dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    return self.view.asyncDataSource;
  }
}

- (void)setAllowsSelection:(BOOL)allowsSelection
{
  if ([self pendingState]) {
    _pendingState.allowsSelection = allowsSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
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

- (void)setAllowsSelectionDuringEditing:(BOOL)allowsSelectionDuringEditing
{
  if ([self pendingState]) {
    _pendingState.allowsSelectionDuringEditing = allowsSelectionDuringEditing;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsSelectionDuringEditing = allowsSelectionDuringEditing;
  }
}

- (BOOL)allowsSelectionDuringEditing
{
  if ([self pendingState]) {
    return _pendingState.allowsSelectionDuringEditing;
  } else {
    return self.view.allowsSelectionDuringEditing;
  }
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelection = allowsMultipleSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
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

- (void)setAllowsMultipleSelectionDuringEditing:(BOOL)allowsMultipleSelectionDuringEditing
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing;
  }
}

- (BOOL)allowsMultipleSelectionDuringEditing
{
  if ([self pendingState]) {
    return _pendingState.allowsMultipleSelectionDuringEditing;
  } else {
    return self.view.allowsMultipleSelectionDuringEditing;
  }
}

- (void)setBatchFetchingDelegate:(id<ASBatchFetchingDelegate>)batchFetchingDelegate
{
  _batchFetchingDelegate = batchFetchingDelegate;
}

- (id<ASBatchFetchingDelegate>)batchFetchingDelegate
{
  return _batchFetchingDelegate;
}

#pragma mark ASRangeControllerUpdateRangeProtocol

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode
{
  if ([self pendingState]) {
    _pendingState.rangeMode = rangeMode;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    [self.rangeController updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark ASEnvironment

ASLayoutElementCollectionTableSetTraitCollection(_environmentStateLock)

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

- (void)selectRowAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
  } else {
    NSLog(@"Failed to select row at index path %@ because the row never reached the view.", indexPath);
  }

}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [tableView deselectRowAtIndexPath:indexPath animated:animated];
  } else {
    NSLog(@"Failed to deselect row at index path %@ because the row never reached the view.", indexPath);
  }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  } else {
    NSLog(@"Failed to scroll to row at index path %@ because the row never reached the view.", indexPath);
  }
}

#pragma mark - Querying Data

- (void)reloadDataInitiallyIfNeeded
{
  ASDisplayNodeAssertMainThread();
  if (!self.dataController.initialReloadDataHasBeenCalled) {
    // Note: Just calling reloadData isn't enough here – we need to
    // ensure that _nodesConstrainedWidth is updated first.
    [self.view layoutIfNeeded];
  }
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap numberOfItemsInSection:section];
}

- (NSInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap numberOfSections];
}

- (NSArray<__kindof ASCellNode *> *)visibleNodes
{
  ASDisplayNodeAssertMainThread();
  return self.isNodeLoaded ? [self.view visibleNodes] : @[];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self.dataController.pendingMap indexPathForElement:cellNode.collectionElement];
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap elementForItemAtIndexPath:indexPath].node;
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  return [tableView rectForRowAtIndexPath:indexPath];
}

- (nullable __kindof UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath == nil) {
    return nil;
  }
  return [tableView cellForRowAtIndexPath:indexPath];
}

- (nullable NSIndexPath *)indexPathForSelectedRow
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  NSIndexPath *indexPath = tableView.indexPathForSelectedRow;
  if (indexPath != nil) {
    return [tableView convertIndexPathToTableNode:indexPath];
  }
  return indexPath;
}

- (NSArray<NSIndexPath *> *)indexPathsForSelectedRows
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  return [tableView convertIndexPathsToTableNode:tableView.indexPathsForSelectedRows];
}

- (nullable NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:point];
  if (indexPath != nil) {
    return [tableView convertIndexPathToTableNode:indexPath];
  }
  return indexPath;
}

- (nullable NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;
  return [tableView convertIndexPathsToTableNode:[tableView indexPathsForRowsInRect:rect]];
}

- (NSArray<NSIndexPath *> *)indexPathsForVisibleRows
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

#pragma mark - Editing

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadDataWithCompletion:completion];
  } else {
    if (completion) {
      completion();
    }
  }
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)relayoutItems
{
  [self.view relayoutItems];
}

- (void)performBatchAnimated:(BOOL)animated updates:(NS_NOESCAPE void (^)())updates completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    ASTableView *tableView = self.view;
    [tableView beginUpdates];
    if (updates) {
      updates();
    }
    [tableView endUpdatesAnimated:animated completion:completion];
  } else {
    if (updates) {
      updates();
    }
  }
}

- (void)performBatchUpdates:(NS_NOESCAPE void (^)())updates completion:(void (^)(BOOL))completion
{
  [self performBatchAnimated:YES updates:updates completion:completion];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertSections:sections withRowAnimation:animation];
  }
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteSections:sections withRowAnimation:animation];
  }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadSections:sections withRowAnimation:animation];
  }
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveSection:section toSection:newSection];
  }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
  }
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

#pragma mark - Debugging (Private)

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [super propertiesForDebugDescription];
  [result addObject:@{ @"dataSource" : ASObjectDescriptionMakeTiny(self.dataSource) }];
  [result addObject:@{ @"delegate" : ASObjectDescriptionMakeTiny(self.delegate) }];
  return result;
}

@end

#endif
