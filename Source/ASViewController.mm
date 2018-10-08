//
//  ASViewController.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASViewController.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

@implementation ASViewController
{
  BOOL _ensureDisplayed;
  BOOL _automaticallyAdjustRangeModeBasedOnViewEvents;
  BOOL _parentManagesVisibilityDepth;
  NSInteger _visibilityDepth;
  BOOL _selfConformsToRangeModeProtocol;
  BOOL _nodeConformsToRangeModeProtocol;
  UIEdgeInsets _fallbackAdditionalSafeAreaInsets;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    return nil;
  }
  
  [self _initializeInstance];
  
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  if (!(self = [super initWithCoder:aDecoder])) {
    return nil;
  }
  
  [self _initializeInstance];
  
  return self;
}

#pragma clang diagnostic pop

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (!(self = [super initWithNibName:nil bundle:nil])) {
    return nil;
  }
  
  _node = node;
  [self _initializeInstance];

  return self;
}

- (void)_initializeInstance
{
  if (_node == nil) {
    return;
  }

  _node.viewControllerRoot = YES;
  
  _selfConformsToRangeModeProtocol = [self conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _nodeConformsToRangeModeProtocol = [_node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _automaticallyAdjustRangeModeBasedOnViewEvents = _selfConformsToRangeModeProtocol || _nodeConformsToRangeModeProtocol;

  _fallbackAdditionalSafeAreaInsets = UIEdgeInsetsZero;
  
  // In case the node will get loaded
  if (_node.nodeLoaded) {
    // Node already loaded the view
    [self view];
  } else {
    // If the node didn't load yet add ourselves as on did load observer to load the view in case the node gets loaded
    // before the view controller
    __weak __typeof__(self) weakSelf = self;
    [_node onDidLoad:^(__kindof ASDisplayNode * _Nonnull node) {
      if ([weakSelf isViewLoaded] == NO) {
        [weakSelf view];
      }
    }];
  }
}

- (void)dealloc
{
  ASPerformBackgroundDeallocation(&_node);
}

- (void)loadView
{
  // Apple applies a frame and autoresizing masks we need.  Allocating a view is not
  // nearly as expensive as adding and removing it from a hierarchy, and fortunately
  // we can avoid that here.  Enabling layerBacking on a single node in the hierarchy
  // will have a greater performance benefit than the impact of this transient view.
  [super loadView];
  
  if (_node == nil) {
    return;
  }
  
  ASDisplayNodeAssertTrue(!_node.layerBacked);
  
  UIView *view = self.view;
  CGRect frame = view.frame;
  UIViewAutoresizing autoresizingMask = view.autoresizingMask;
  
  // We have what we need, so now create and assign the view we actually want.
  view = _node.view;
  _node.frame = frame;
  _node.autoresizingMask = autoresizingMask;
  self.view = view;
  
  // ensure that self.node has a valid trait collection before a subclass's implementation of viewDidLoad.
  // Any subnodes added in viewDidLoad will then inherit the proper environment.
  ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
  [self propagateNewTraitCollection:traitCollection];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  // Before layout, make sure that our trait collection containerSize actually matches the size of our bounds.
  // If not, we need to update the traits and propagate them.

  CGSize boundsSize = self.view.bounds.size;
  if (CGSizeEqualToSize(self.node.primitiveTraitCollection.containerSize, boundsSize) == NO) {
    [UIView performWithoutAnimation:^{
      ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
      traitCollection.containerSize = boundsSize;
        
      // this method will call measure
      [self propagateNewTraitCollection:traitCollection];
    }];
  } else {
    // Call layoutThatFits: to let the node prepare for a layout that will happen shortly in the layout pass of the view.
    // If the node's constrained size didn't change between the last layout pass it's a no-op
    [_node layoutThatFits:[self nodeConstrainedSize]];
  }
}

- (void)viewDidLayoutSubviews
{
  if (_ensureDisplayed && self.neverShowPlaceholders) {
    _ensureDisplayed = NO;
    [_node recursivelyEnsureDisplaySynchronously:YES];
  }
  [super viewDidLayoutSubviews];

  if (!AS_AT_LEAST_IOS11) {
    [self _updateNodeFallbackSafeArea];
  }
}

- (void)_updateNodeFallbackSafeArea
{
  UIEdgeInsets safeArea = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, self.bottomLayoutGuide.length, 0);
  UIEdgeInsets additionalInsets = self.additionalSafeAreaInsets;

  safeArea = ASConcatInsets(safeArea, additionalInsets);

  _node.fallbackSafeAreaInsets = safeArea;
}

ASVisibilityDidMoveToParentViewController;

- (void)viewWillAppear:(BOOL)animated
{
  as_activity_create_for_scope("ASViewController will appear");
  as_log_debug(ASNodeLog(), "View controller %@ will appear", self);

  [super viewWillAppear:animated];

  _ensureDisplayed = YES;

  // A layout pass is forced this early to get nodes like ASCollectionNode, ASTableNode etc.
  // into the hierarchy before UIKit applies the scroll view inset adjustments, if automatic subnode management
  // is enabled. Otherwise the insets would not be applied.
  [_node.view layoutIfNeeded];
  
  if (_parentManagesVisibilityDepth == NO) {
    [self setVisibilityDepth:0];
  }
}

ASVisibilitySetVisibilityDepth;

ASVisibilityViewDidDisappearImplementation;

ASVisibilityDepthImplementation;

- (void)visibilityDepthDidChange
{
  ASLayoutRangeMode rangeMode = ASLayoutRangeModeForVisibilityDepth(self.visibilityDepth);
#if ASEnableVerboseLogging
  NSString *rangeModeString;
  switch (rangeMode) {
    case ASLayoutRangeModeMinimum:
      rangeModeString = @"Minimum";
      break;
      
    case ASLayoutRangeModeFull:
      rangeModeString = @"Full";
      break;
      
    case ASLayoutRangeModeVisibleOnly:
      rangeModeString = @"Visible Only";
      break;
      
    case ASLayoutRangeModeLowMemory:
      rangeModeString = @"Low Memory";
      break;
      
    default:
      break;
  }
  as_log_verbose(ASNodeLog(), "Updating visibility of %@ to: %@ (visibility depth: %zd)", self, rangeModeString, self.visibilityDepth);
#endif
  [self updateCurrentRangeModeWithModeIfPossible:rangeMode];
}

#pragma mark - Automatic range mode

- (BOOL)automaticallyAdjustRangeModeBasedOnViewEvents
{
  return _automaticallyAdjustRangeModeBasedOnViewEvents;
}

- (void)setAutomaticallyAdjustRangeModeBasedOnViewEvents:(BOOL)automaticallyAdjustRangeModeBasedOnViewEvents
{
  if (automaticallyAdjustRangeModeBasedOnViewEvents != _automaticallyAdjustRangeModeBasedOnViewEvents) {
    if (automaticallyAdjustRangeModeBasedOnViewEvents && _selfConformsToRangeModeProtocol == NO && _nodeConformsToRangeModeProtocol == NO) {
      NSLog(@"Warning: automaticallyAdjustRangeModeBasedOnViewEvents set to YES in %@, but range mode updating is not possible because neither view controller nor node %@ conform to ASRangeControllerUpdateRangeProtocol.", self, _node);
    }
    _automaticallyAdjustRangeModeBasedOnViewEvents = automaticallyAdjustRangeModeBasedOnViewEvents;
  }
}

- (void)updateCurrentRangeModeWithModeIfPossible:(ASLayoutRangeMode)rangeMode
{
  if (!_automaticallyAdjustRangeModeBasedOnViewEvents) {
    return;
  }
  
  if (_selfConformsToRangeModeProtocol) {
    id<ASRangeControllerUpdateRangeProtocol> rangeUpdater = (id<ASRangeControllerUpdateRangeProtocol>)self;
    [rangeUpdater updateCurrentRangeWithMode:rangeMode];
  }
  
  if (_nodeConformsToRangeModeProtocol) {
    id<ASRangeControllerUpdateRangeProtocol> rangeUpdater = (id<ASRangeControllerUpdateRangeProtocol>)_node;
    [rangeUpdater updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark - Layout Helpers

- (ASSizeRange)nodeConstrainedSize
{
  return ASSizeRangeMake(self.view.bounds.size);
}

- (ASInterfaceState)interfaceState
{
  return _node.interfaceState;
}

- (UIEdgeInsets)additionalSafeAreaInsets
{
  if (AS_AVAILABLE_IOS(11.0)) {
    return super.additionalSafeAreaInsets;
  }

  return _fallbackAdditionalSafeAreaInsets;
}

- (void)setAdditionalSafeAreaInsets:(UIEdgeInsets)additionalSafeAreaInsets
{
  if (AS_AVAILABLE_IOS(11.0)) {
    [super setAdditionalSafeAreaInsets:additionalSafeAreaInsets];
  } else {
    _fallbackAdditionalSafeAreaInsets = additionalSafeAreaInsets;
    [self _updateNodeFallbackSafeArea];
  }
}

#pragma mark - ASTraitEnvironment

- (ASPrimitiveTraitCollection)primitiveTraitCollectionForUITraitCollection:(UITraitCollection *)traitCollection
{
  if (self.overrideDisplayTraitsWithTraitCollection) {
    ASTraitCollection *asyncTraitCollection = self.overrideDisplayTraitsWithTraitCollection(traitCollection);
    return [asyncTraitCollection primitiveTraitCollection];
  }
  
  ASDisplayNodeAssertMainThread();
  ASPrimitiveTraitCollection asyncTraitCollection = ASPrimitiveTraitCollectionFromUITraitCollection(traitCollection);
  asyncTraitCollection.containerSize = self.view.frame.size;
  return asyncTraitCollection;
}

- (void)propagateNewTraitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  ASPrimitiveTraitCollection oldTraitCollection = self.node.primitiveTraitCollection;
  
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(traitCollection, oldTraitCollection) == NO) {
    as_activity_scope_verbose(as_activity_create("Propagate ASViewController trait collection", AS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT));
    as_log_debug(ASNodeLog(), "Propagating new traits for %@: %@", self, NSStringFromASPrimitiveTraitCollection(traitCollection));
    self.node.primitiveTraitCollection = traitCollection;
    
    NSArray<id<ASLayoutElement>> *children = [self.node sublayoutElements];
    for (id<ASLayoutElement> child in children) {
      ASTraitCollectionPropagateDown(child, traitCollection);
    }
    
    // Once we've propagated all the traits, layout this node.
    // Remeasure the node with the latest constrained size – old constrained size may be incorrect.
    as_activity_scope_verbose(as_activity_create("Layout ASViewController node with new traits", AS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT));
    [_node layoutThatFits:[self nodeConstrainedSize]];
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  
  ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
  traitCollection.containerSize = self.view.bounds.size;
  [self propagateNewTraitCollection:traitCollection];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
  
  ASPrimitiveTraitCollection traitCollection = _node.primitiveTraitCollection;
  traitCollection.containerSize = self.view.bounds.size;
  [self propagateNewTraitCollection:traitCollection];
}

@end

#endif
