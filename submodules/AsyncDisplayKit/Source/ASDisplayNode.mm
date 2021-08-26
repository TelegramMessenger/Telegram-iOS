//
//  ASDisplayNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASDisplayNodeInternal.h"

#import <AsyncDisplayKit/ASDisplayNode+Ancestry.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+LayoutSpec.h>
#import "ASLayoutSpec+Subclasses.h"

#import <objc/runtime.h>
#include <string>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import "_ASAsyncTransactionContainer+Private.h"
#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/_ASDisplayView.h>
#import "_ASPendingState.h"
#import "_ASScopeTimer.h"
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+InterfaceState.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import "ASLayoutElementStylePrivate.h"
#import <AsyncDisplayKit/ASLayoutSpec.h>
#import "ASLayoutSpecPrivate.h"
#import <AsyncDisplayKit/ASMainThreadDeallocation.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>
#import "ASSignpost.h"
#import <AsyncDisplayKit/ASTraitCollection.h>
#import "ASWeakProxy.h"
#import "ASResponderChainEnumerator.h"

// Conditionally time these scopes to our debug ivars (only exist in debug/profile builds)
#if TIME_DISPLAYNODE_OPS
  #define TIME_SCOPED(outVar) AS::ScopeTimer t(outVar)
#else
  #define TIME_SCOPED(outVar)
#endif
// This is trying to merge non-rangeManaged with rangeManaged, so both range-managed and standalone nodes wait before firing their exit-visibility handlers, as UIViewController transitions now do rehosting at both start & end of animation.
// Enable this will mitigate interface updating state when coalescing disabled.
// TODO(wsdwsd0829): Rework enabling code to ensure that interface state behavior is not altered when ASCATransactionQueue is disabled.
#define ENABLE_NEW_EXIT_HIERARCHY_BEHAVIOR 0

using AS::MutexLocker;

static ASDisplayNodeNonFatalErrorBlock _nonFatalErrorBlock = nil;

// Forward declare CALayerDelegate protocol as the iOS 10 SDK moves CALayerDelegate from an informal delegate to a protocol.
// We have to forward declare the protocol as this place otherwise it will not compile compiling with an Base SDK < iOS 10
@protocol CALayerDelegate;

@interface ASDisplayNode () <UIGestureRecognizerDelegate, CALayerDelegate, _ASDisplayLayerDelegate, ASCATransactionQueueObserving>
/**
 * See ASDisplayNodeInternal.h for ivars
 */

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation ASDisplayNode

@dynamic layoutElementType;

@synthesize threadSafeBounds = _threadSafeBounds;

static std::atomic_bool suppressesInvalidCollectionUpdateExceptions = ATOMIC_VAR_INIT(NO);
static std::atomic_bool storesUnflattenedLayouts = ATOMIC_VAR_INIT(NO);

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector)
{
  return ASSubclassOverridesSelector([ASDisplayNode class], subclass, selector);
}

// For classes like ASTableNode, ASCollectionNode, ASScrollNode and similar - we have to be sure to set certain properties
// like setFrame: and setBackgroundColor: directly to the UIView and not apply it to the layer only.
BOOL ASDisplayNodeNeedsSpecialPropertiesHandling(BOOL isSynchronous, BOOL isLayerBacked)
{
  return isSynchronous && !isLayerBacked;
}

_ASPendingState *ASDisplayNodeGetPendingState(ASDisplayNode *node)
{
  ASLockScope(node);
  _ASPendingState *result = node->_pendingViewState;
  if (result == nil) {
    result = [[_ASPendingState alloc] init];
    node->_pendingViewState = result;
  }
  return result;
}

void StubImplementationWithNoArgs(id receiver) {}
void StubImplementationWithSizeRange(id receiver, ASSizeRange sr) {}
void StubImplementationWithTwoInterfaceStates(id receiver, ASInterfaceState s0, ASInterfaceState s1) {}

/**
 *  Returns ASDisplayNodeFlags for the given class/instance. instance MAY BE NIL.
 *
 *  @param c        the class, required
 *  @param instance the instance, which may be nil. (If so, the class is inspected instead)
 *  @remarks        The instance value is used only if we suspect the class may be dynamic (because it overloads 
 *                  +respondsToSelector: or -respondsToSelector.) In that case we use our "slow path", calling this 
 *                  method on each -init and passing the instance value. While this may seem like an unlikely scenario,
 *                  it turns our our own internal tests use a dynamic class, so it's worth capturing this edge case.
 *
 *  @return ASDisplayNode flags.
 */
static struct ASDisplayNodeFlags GetASDisplayNodeFlags(Class c, ASDisplayNode *instance)
{
  ASDisplayNodeCAssertNotNil(c, @"class is required");

  struct ASDisplayNodeFlags flags = {0};

  flags.isInHierarchy = NO;
  flags.displaysAsynchronously = YES;
  flags.shouldAnimateSizeChanges = YES;
  flags.implementsDrawRect = ([c respondsToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] ? 1 : 0);
  flags.implementsImageDisplay = ([c respondsToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  if (instance) {
    flags.implementsDrawParameters = ([instance respondsToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
  } else {
    flags.implementsDrawParameters = ([c instancesRespondToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
  }
  
  
  return flags;
}

/**
 *  Returns ASDisplayNodeMethodOverrides for the given class
 *
 *  @param c the class, required.
 *
 *  @return ASDisplayNodeMethodOverrides.
 */
static ASDisplayNodeMethodOverrides GetASDisplayNodeMethodOverrides(Class c)
{
  ASDisplayNodeCAssertNotNil(c, @"class is required");
  
  ASDisplayNodeMethodOverrides overrides = ASDisplayNodeMethodOverrideNone;
  
  // Handling touches
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesBegan:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesBegan;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesMoved:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesMoved;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesCancelled:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesCancelled;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesEnded:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesEnded;
  }
  
  // Responder chain
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(canBecomeFirstResponder))) {
    overrides |= ASDisplayNodeMethodOverrideCanBecomeFirstResponder;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(becomeFirstResponder))) {
    overrides |= ASDisplayNodeMethodOverrideBecomeFirstResponder;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(canResignFirstResponder))) {
    overrides |= ASDisplayNodeMethodOverrideCanResignFirstResponder;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(resignFirstResponder))) {
    overrides |= ASDisplayNodeMethodOverrideResignFirstResponder;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(isFirstResponder))) {
    overrides |= ASDisplayNodeMethodOverrideIsFirstResponder;
  }
  
  // Layout related methods
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(layoutSpecThatFits:))) {
    overrides |= ASDisplayNodeMethodOverrideLayoutSpecThatFits;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(calculateLayoutThatFits:)) ||
      ASDisplayNodeSubclassOverridesSelector(c, @selector(calculateLayoutThatFits:
                                                          restrictedToSize:
                                                          relativeToParentSize:))) {
    overrides |= ASDisplayNodeMethodOverrideCalcLayoutThatFits;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(calculateSizeThatFits:))) {
    overrides |= ASDisplayNodeMethodOverrideCalcSizeThatFits;
  }

  return overrides;
}

+ (void)initialize
{
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  if (self != [ASDisplayNode class]) {
    
    // Subclasses should never override these. Use unused to prevent warnings
    __unused NSString *classString = NSStringFromClass(self);
    
    //ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:)), @"Subclass %@ must not override layoutThatFits: method. Instead override calculateLayoutThatFits:.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:parentSize:)), @"Subclass %@ must not override layoutThatFits:parentSize method. Instead override calculateLayoutThatFits:.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearContents)), @"Subclass %@ must not override recursivelyClearContents method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearPreloadedData)), @"Subclass %@ must not override recursivelyClearFetchedData method.", classString);
  } else {
    // Check if subnodes where modified during the creation of the layout
	  __block IMP originalLayoutSpecThatFitsIMP = ASReplaceMethodWithBlock(self, @selector(_locked_layoutElementThatFits:), ^(ASDisplayNode *_self, ASSizeRange sizeRange) {
		  NSArray *oldSubnodes = _self.subnodes;
		  ASLayoutSpec *layoutElement = ((ASLayoutSpec *( *)(id, SEL, ASSizeRange))originalLayoutSpecThatFitsIMP)(_self, @selector(_locked_layoutElementThatFits:), sizeRange);
		  NSArray *subnodes = _self.subnodes;
		  ASDisplayNodeAssert(oldSubnodes.count == subnodes.count, @"Adding or removing nodes in layoutSpecBlock or layoutSpecThatFits: is not allowed and can cause unexpected behavior.");
		  for (NSInteger i = 0; i < oldSubnodes.count; i++) {
			  ASDisplayNodeAssert(oldSubnodes[i] == subnodes[i], @"Adding or removing nodes in layoutSpecBlock or layoutSpecThatFits: is not allowed and can cause unexpected behavior.");
		  }
		  return layoutElement;
	  });
  }
#endif

  // Below we are pre-calculating values per-class and dynamically adding a method (_staticInitialize) to populate these values
  // when each instance is constructed. These values don't change for each class, so there is significant performance benefit
  // in doing it here. +initialize is guaranteed to be called before any instance method so it is safe to add this method here.
  // Note that we take care to detect if the class overrides +respondsToSelector: or -respondsToSelector and take the slow path
  // (recalculating for each instance) to make sure we are always correct.

  BOOL classOverridesRespondsToSelector = ASSubclassOverridesClassSelector([NSObject class], self, @selector(respondsToSelector:));
  BOOL instancesOverrideRespondsToSelector = ASSubclassOverridesSelector([NSObject class], self, @selector(respondsToSelector:));
  struct ASDisplayNodeFlags flags = GetASDisplayNodeFlags(self, nil);
  ASDisplayNodeMethodOverrides methodOverrides = GetASDisplayNodeMethodOverrides(self);
  
  __unused Class initializeSelf = self;

  IMP staticInitialize = imp_implementationWithBlock(^(ASDisplayNode *node) {
    ASDisplayNodeAssert(node.class == initializeSelf, @"Node class %@ does not have a matching _staticInitialize method; check to ensure [super initialize] is called within any custom +initialize implementations!  Overridden methods will not be called unless they are also implemented by superclass %@", node.class, initializeSelf);
    node->_flags = (classOverridesRespondsToSelector || instancesOverrideRespondsToSelector) ? GetASDisplayNodeFlags(node.class, node) : flags;
    node->_methodOverrides = (classOverridesRespondsToSelector) ? GetASDisplayNodeMethodOverrides(node.class) : methodOverrides;
  });

  class_replaceMethod(self, @selector(_staticInitialize), staticInitialize, "v:@");
  
  // Add stub implementations for global methods that the client didn't
  // implement in a category. We do this instead of hard-coding empty
  // implementations to avoid a linker warning when it merges categories.
  // Note: addMethod will not do anything if a method already exists.
  if (self == ASDisplayNode.class) {
    IMP noArgsImp = (IMP)StubImplementationWithNoArgs;
    class_addMethod(self, @selector(baseDidInit), noArgsImp, "v@:");
    class_addMethod(self, @selector(baseWillDealloc), noArgsImp, "v@:");
    class_addMethod(self, @selector(didLoad), noArgsImp, "v@:");
    class_addMethod(self, @selector(layoutDidFinish), noArgsImp, "v@:");
    class_addMethod(self, @selector(didEnterPreloadState), noArgsImp, "v@:");
    class_addMethod(self, @selector(didExitPreloadState), noArgsImp, "v@:");
    class_addMethod(self, @selector(didEnterDisplayState), noArgsImp, "v@:");
    class_addMethod(self, @selector(didExitDisplayState), noArgsImp, "v@:");
    class_addMethod(self, @selector(didEnterVisibleState), noArgsImp, "v@:");
    class_addMethod(self, @selector(didExitVisibleState), noArgsImp, "v@:");
    class_addMethod(self, @selector(hierarchyDisplayDidFinish), noArgsImp, "v@:");
    class_addMethod(self, @selector(asyncTraitCollectionDidChange), noArgsImp, "v@:");
    class_addMethod(self, @selector(calculatedLayoutDidChange), noArgsImp, "v@:");
    
    auto type0 = "v@:" + std::string(@encode(ASSizeRange));
    class_addMethod(self, @selector(willCalculateLayout:), (IMP)StubImplementationWithSizeRange, type0.c_str());
    
    auto interfaceStateType = std::string(@encode(ASInterfaceState));
    auto type1 = "v@:" + interfaceStateType + interfaceStateType;
    class_addMethod(self, @selector(interfaceStateDidChange:fromState:), (IMP)StubImplementationWithTwoInterfaceStates, type1.c_str());
  }
}

#if !AS_INITIALIZE_FRAMEWORK_MANUALLY
+ (void)load
{
  ASInitializeFrameworkMainThread();
}
#endif

+ (Class)viewClass
{
  return [_ASDisplayView class];
}

+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark - Lifecycle

- (void)_staticInitialize
{
  ASDisplayNodeAssert(NO, @"_staticInitialize must be overridden");
}

- (void)_initializeInstance
{
  [self _staticInitialize];

#if ASEVENTLOG_ENABLE
  _eventLog = [[ASEventLog alloc] initWithObject:self];
#endif
  
  _viewClass = [self.class viewClass];
  _layerClass = [self.class layerClass];
  BOOL isSynchronous = ![_viewClass isSubclassOfClass:[_ASDisplayView class]]
                        || ![_layerClass isSubclassOfClass:[_ASDisplayLayer class]];
  setFlag(Synchronous, isSynchronous);
  

  _contentsScaleForDisplay = ASScreenScale();
  _drawingPriority = ASDefaultTransactionPriority;
  
  _primitiveTraitCollection = ASPrimitiveTraitCollectionMakeDefault();
  
  _layoutVersion = 1;
  
  _defaultLayoutTransitionDuration = 0.2;
  _defaultLayoutTransitionDelay = 0.0;
  _defaultLayoutTransitionOptions = UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone;
  
  _flags.canClearContentsOfLayer = YES;
  _flags.canCallSetNeedsDisplayOfLayer = YES;

  _fallbackSafeAreaInsets = UIEdgeInsetsZero;
  _fallbackInsetsLayoutMarginsFromSafeArea = YES;
  _isViewControllerRoot = NO;

  _automaticallyRelayoutOnSafeAreaChanges = NO;
  _automaticallyRelayoutOnLayoutMarginsChanges = NO;

  [self baseDidInit];
  ASDisplayNodeLogEvent(self, @"init");
}

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  [self _initializeInstance];

  return self;
}

- (instancetype)initWithViewClass:(Class)viewClass
{
  if (!(self = [self init]))
    return nil;

  ASDisplayNodeAssert([viewClass isSubclassOfClass:[UIView class]], @"should initialize with a subclass of UIView");

  _viewClass = viewClass;
  setFlag(Synchronous, ![viewClass isSubclassOfClass:[_ASDisplayView class]]);

  return self;
}

- (instancetype)initWithLayerClass:(Class)layerClass
{
  if (!(self = [self init])) {
    return nil;
  }

  ASDisplayNodeAssert([layerClass isSubclassOfClass:[CALayer class]], @"should initialize with a subclass of CALayer");

  _layerClass = layerClass;
  _flags.layerBacked = YES;
  setFlag(Synchronous, ![layerClass isSubclassOfClass:[_ASDisplayLayer class]]);

  return self;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  return [self initWithViewBlock:viewBlock didLoadBlock:nil];
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
  if (!(self = [self init])) {
    return nil;
  }
#pragma clang diagnostic pop

  [self setViewBlock:viewBlock];
  if (didLoadBlock != nil) {
    [self onDidLoad:didLoadBlock];
  }
  
  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  return [self initWithLayerBlock:layerBlock didLoadBlock:nil];
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
  if (!(self = [self init])) {
    return nil;
  }
#pragma clang diagnostic pop
  
  [self setLayerBlock:layerBlock];
  if (didLoadBlock != nil) {
    [self onDidLoad:didLoadBlock];
  }
  
  return self;
}

ASSynthesizeLockingMethodsWithMutex(__instanceLock__);

- (void)setViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  ASDisplayNodeAssertFalse(self.nodeLoaded);
  ASDisplayNodeAssertNotNil(viewBlock, @"should initialize with a valid block that returns a UIView");

  _viewBlock = viewBlock;
  setFlag(Synchronous, YES);
}

- (void)setLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  ASDisplayNodeAssertFalse(self.nodeLoaded);
  ASDisplayNodeAssertNotNil(layerBlock, @"should initialize with a valid block that returns a CALayer");

  _layerBlock = layerBlock;
  _flags.layerBacked = YES;
  setFlag(Synchronous, YES);
}

- (ASDisplayNodeMethodOverrides)methodOverrides
{
  return _methodOverrides;
}

- (void)onDidLoad:(ASDisplayNodeDidLoadBlock)body
{
  AS::UniqueLock l(__instanceLock__);

  if ([self _locked_isNodeLoaded]) {
    ASDisplayNodeAssertThreadAffinity(self);
    l.unlock();
    body(self);
    return;
  } else if (_onDidLoadBlocks == nil) {
    _onDidLoadBlocks = [NSMutableArray arrayWithObject:body];
  } else {
    [_onDidLoadBlocks addObject:body];
  }
}

- (void)dealloc
{
  _flags.isDeallocating = YES;
  [self baseWillDealloc];

  // Synchronous nodes may not be able to call the hierarchy notifications, so only enforce for regular nodes.
  //ASDisplayNodeAssert(checkFlag(Synchronous) || !ASInterfaceStateIncludesVisible(_interfaceState), @"Node should always be marked invisible before deallocating. Node: %@", self);
  
  self.asyncLayer.asyncDelegate = nil;
  _view.asyncdisplaykit_node = nil;
  _layer.asyncdisplaykit_node = nil;

  // Remove any subnodes so they lose their connection to the now deallocated parent.  This can happen
  // because subnodes do not retain their supernode, but subnodes can legitimately remain alive if another
  // thing outside the view hierarchy system (e.g. async display, controller code, etc). keeps a retained
  // reference to subnodes.

  for (ASDisplayNode *subnode in _subnodes)
    [subnode _setSupernode:nil];

  [self scheduleIvarsForMainThreadDeallocation];

  // TODO: Remove this? If supernode isn't already nil, this method isn't dealloc-safe anyway.
  [self _setSupernode:nil];
}

#pragma mark - Loading

- (BOOL)_locked_shouldLoadViewOrLayer
{
  ASAssertLocked(__instanceLock__);
  return !_flags.isDeallocating && !(_hierarchyState & ASHierarchyStateRasterized);
}

- (UIView *)_locked_viewToLoad
{
  ASAssertLocked(__instanceLock__);
  
  UIView *view = nil;
  bool initializedWithCustomView = false;
  if (_viewBlock) {
    initializedWithCustomView = true;
    view = _viewBlock();
    ASDisplayNodeAssertNotNil(view, @"View block returned nil");
    ASDisplayNodeAssert(![view isKindOfClass:[_ASDisplayView class]], @"View block should return a synchronously displayed view");
    _viewBlock = nil;
    _viewClass = [view class];
  } else {
    view = [[_viewClass alloc] init];
  }
  
  // Special handling of wrapping UIKit components
  if (checkFlag(Synchronous)) {
    [self checkResponderCompatibility];
    
    // UIImageView layers. More details on the flags
    if ([_viewClass isSubclassOfClass:[UIImageView class]]) {
      _flags.canClearContentsOfLayer = NO;
      _flags.canCallSetNeedsDisplayOfLayer = NO;
    }
      
    if (initializedWithCustomView) {
        static dispatch_once_t onceToken;
        static IMP defaultMethod = NULL;
        dispatch_once(&onceToken, ^{
             defaultMethod = [[UIView class] instanceMethodForSelector:@selector(drawRect:)];
        });
        if ([[view class] instanceMethodForSelector:@selector(drawRect:)] != defaultMethod) {
        } else {
          _flags.canClearContentsOfLayer = NO;
          _flags.canCallSetNeedsDisplayOfLayer = NO;
        }
    }
      
    // UIActivityIndicator
    if ([_viewClass isSubclassOfClass:[UIActivityIndicatorView class]]
        || [_viewClass isSubclassOfClass:[UIVisualEffectView class]]) {
      self.opaque = NO;
    }
      
    // CAEAGLLayer
    if([[view.layer class] isSubclassOfClass:[CAEAGLLayer class]]){
      _flags.canClearContentsOfLayer = NO;
    }
  }

  return view;
}

- (CALayer *)_locked_layerToLoad
{
  ASAssertLocked(__instanceLock__);
  ASDisplayNodeAssert(_flags.layerBacked, @"_layerToLoad is only for layer-backed nodes");

  CALayer *layer = nil;
  if (_layerBlock) {
    layer = _layerBlock();
    ASDisplayNodeAssertNotNil(layer, @"Layer block returned nil");
    ASDisplayNodeAssert(![layer isKindOfClass:[_ASDisplayLayer class]], @"Layer block should return a synchronously displayed layer");
    _layerBlock = nil;
    _layerClass = [layer class];
  } else {
    layer = [[_layerClass alloc] init];
  }

  return layer;
}

- (void)_locked_loadViewOrLayer
{
  ASAssertLocked(__instanceLock__);
  
  if (_flags.layerBacked) {
    TIME_SCOPED(_debugTimeToCreateView);
    _layer = [self _locked_layerToLoad];
    static int ASLayerDelegateAssociationKey;
    
    /**
     * CALayer's .delegate property is documented to be weak, but the implementation is actually assign.
     * Because our layer may survive longer than the node (e.g. if someone else retains it, or if the node
     * begins deallocation on a background thread and it waiting for the -dealloc call to reach main), the only
     * way to avoid a dangling pointer is to use a weak proxy.
     */
    ASWeakProxy *instance = [ASWeakProxy weakProxyWithTarget:self];
    _layer.delegate = (id<CALayerDelegate>)instance;
    objc_setAssociatedObject(_layer, &ASLayerDelegateAssociationKey, instance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  } else {
    TIME_SCOPED(_debugTimeToCreateView);
    _view = [self _locked_viewToLoad];
    _view.asyncdisplaykit_node = self;
    _layer = _view.layer;
  }
  _layer.asyncdisplaykit_node = self;
  
  self._locked_asyncLayer.asyncDelegate = self;
}

- (void)_didLoad
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  ASDisplayNodeLogEvent(self, @"didLoad");
  TIME_SCOPED(_debugTimeForDidLoad);
  
  [self didLoad];
  
  __instanceLock__.lock();
  const auto onDidLoadBlocks = ASTransferStrong(_onDidLoadBlocks);
  __instanceLock__.unlock();
  
  for (ASDisplayNodeDidLoadBlock block in onDidLoadBlocks) {
    block(self);
  }
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del nodeDidLoad];
  }];
}

- (BOOL)isNodeLoaded
{
  if (ASDisplayNodeThreadIsMain()) {
    // Because the view and layer can only be created and destroyed on Main, that is also the only thread
    // where the state of this property can change. As an optimization, we can avoid locking.
    return _loaded(self);
  } else {
    MutexLocker l(__instanceLock__);
    return [self _locked_isNodeLoaded];
  }
}

- (BOOL)_locked_isNodeLoaded
{
  ASAssertLocked(__instanceLock__);
  return _loaded(self);
}

#pragma mark - Misc Setter / Getter

- (UIView *)view
{
  AS::UniqueLock l(__instanceLock__);

  ASDisplayNodeAssert(!_flags.layerBacked, @"Call to -view undefined on layer-backed nodes");
  BOOL isLayerBacked = _flags.layerBacked;
  if (isLayerBacked) {
    return nil;
  }

  if (_view != nil) {
    return _view;
  }

  if (![self _locked_shouldLoadViewOrLayer]) {
    return nil;
  }
  
  // Loading a view needs to happen on the main thread
  ASDisplayNodeAssertMainThread();
  [self _locked_loadViewOrLayer];
  
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    l.unlock();
    [self __setNeedsLayout];
    l.lock();
  }
  
  [self _locked_applyPendingStateToViewOrLayer];
  
  // The following methods should not be called with a lock
  l.unlock();

  // No need for the lock as accessing the subviews or layers are always happening on main
  [self _addSubnodeViewsAndLayers];
  
  // A subclass hook should never be called with a lock
  [self _didLoad];

  return _view;
}

- (CALayer *)layer
{
  AS::UniqueLock l(__instanceLock__);
  if (_layer != nil) {
    return _layer;
  }
  
  if (![self _locked_shouldLoadViewOrLayer]) {
    return nil;
  }
  
  // Loading a layer needs to happen on the main thread
  ASDisplayNodeAssertMainThread();
  [self _locked_loadViewOrLayer];
  CALayer *layer = _layer;
  
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    l.unlock();
    [self __setNeedsLayout];
    l.lock();
  }
  
  [self _locked_applyPendingStateToViewOrLayer];
  
  // The following methods should not be called with a lock
  l.unlock();

  // No need for the lock as accessing the subviews or layers are always happening on main
  [self _addSubnodeViewsAndLayers];
  
  // A subclass hook should never be called with a lock
  [self _didLoad];

  return layer;
}

// Returns nil if the layer is not an _ASDisplayLayer; will not create the layer if nil.
- (_ASDisplayLayer *)asyncLayer
{
  MutexLocker l(__instanceLock__);
  return [self _locked_asyncLayer];
}

- (_ASDisplayLayer *)_locked_asyncLayer
{
  ASAssertLocked(__instanceLock__);
  return [_layer isKindOfClass:[_ASDisplayLayer class]] ? (_ASDisplayLayer *)_layer : nil;
}

- (BOOL)isSynchronous
{
  return checkFlag(Synchronous);
}

- (void)setLayerBacked:(BOOL)isLayerBacked
{
  // Only call this if assertions are enabled – it could be expensive.
  ASDisplayNodeAssert(!isLayerBacked || self.supportsLayerBacking, @"Node %@ does not support layer backing.", self);

  MutexLocker l(__instanceLock__);
  if (_flags.layerBacked == isLayerBacked) {
    return;
  }
  
  if ([self _locked_isNodeLoaded]) {
    ASDisplayNodeFailAssert(@"Cannot change layerBacked after view/layer has loaded.");
    return;
  }

  _flags.layerBacked = isLayerBacked;
}

- (BOOL)isLayerBacked
{
  MutexLocker l(__instanceLock__);
  return _flags.layerBacked;
}

- (BOOL)supportsLayerBacking
{
  MutexLocker l(__instanceLock__);
  return !checkFlag(Synchronous) && !_flags.viewEverHadAGestureRecognizerAttached && _viewClass == [_ASDisplayView class] && _layerClass == [_ASDisplayLayer class];
}

- (BOOL)shouldAnimateSizeChanges
{
  MutexLocker l(__instanceLock__);
  return _flags.shouldAnimateSizeChanges;
}

- (void)setShouldAnimateSizeChanges:(BOOL)shouldAnimateSizeChanges
{
  MutexLocker l(__instanceLock__);
  _flags.shouldAnimateSizeChanges = shouldAnimateSizeChanges;
}

- (CGRect)threadSafeBounds
{
  MutexLocker l(__instanceLock__);
  return [self _locked_threadSafeBounds];
}

- (CGRect)_locked_threadSafeBounds
{
  ASAssertLocked(__instanceLock__);
  return _threadSafeBounds;
}

- (void)setThreadSafeBounds:(CGRect)newBounds
{
  MutexLocker l(__instanceLock__);
  _threadSafeBounds = newBounds;
}

- (void)nodeViewDidAddGestureRecognizer
{
  MutexLocker l(__instanceLock__);
  _flags.viewEverHadAGestureRecognizerAttached = YES;
}

- (UIEdgeInsets)fallbackSafeAreaInsets
{
  MutexLocker l(__instanceLock__);
  return _fallbackSafeAreaInsets;
}

- (void)setFallbackSafeAreaInsets:(UIEdgeInsets)insets
{
  BOOL needsManualUpdate;
  BOOL updatesLayoutMargins;

  {
    MutexLocker l(__instanceLock__);
    ASDisplayNodeAssertThreadAffinity(self);

    if (UIEdgeInsetsEqualToEdgeInsets(insets, _fallbackSafeAreaInsets)) {
      return;
    }

    _fallbackSafeAreaInsets = insets;
    needsManualUpdate = !AS_AT_LEAST_IOS11 || _flags.layerBacked;
    updatesLayoutMargins = needsManualUpdate && [self _locked_insetsLayoutMarginsFromSafeArea];
  }

  if (needsManualUpdate) {
    [self safeAreaInsetsDidChange];
  }

  if (updatesLayoutMargins) {
    [self layoutMarginsDidChange];
  }
}

- (void)_fallbackUpdateSafeAreaOnChildren
{
  ASDisplayNodeAssertThreadAffinity(self);

  UIEdgeInsets insets = self.safeAreaInsets;
  CGRect bounds = self.bounds;

  for (ASDisplayNode *child in self.subnodes) {
    if (AS_AT_LEAST_IOS11 && !child.layerBacked) {
      // In iOS 11 view-backed nodes already know what their safe area is.
      continue;
    }

    if (child.viewControllerRoot) {
      // Its safe area is controlled by a view controller. Don't override it.
      continue;
    }

    CGRect childFrame = child.frame;
    UIEdgeInsets childInsets = UIEdgeInsetsMake(MAX(insets.top    - (CGRectGetMinY(childFrame) - CGRectGetMinY(bounds)), 0),
                                                MAX(insets.left   - (CGRectGetMinX(childFrame) - CGRectGetMinX(bounds)), 0),
                                                MAX(insets.bottom - (CGRectGetMaxY(bounds) - CGRectGetMaxY(childFrame)), 0),
                                                MAX(insets.right  - (CGRectGetMaxX(bounds) - CGRectGetMaxX(childFrame)), 0));

    child.fallbackSafeAreaInsets = childInsets;
  }
}

- (BOOL)isViewControllerRoot
{
  MutexLocker l(__instanceLock__);
  return _isViewControllerRoot;
}

- (void)setViewControllerRoot:(BOOL)flag
{
  MutexLocker l(__instanceLock__);
  _isViewControllerRoot = flag;
}

- (BOOL)automaticallyRelayoutOnSafeAreaChanges
{
  MutexLocker l(__instanceLock__);
  return _automaticallyRelayoutOnSafeAreaChanges;
}

- (void)setAutomaticallyRelayoutOnSafeAreaChanges:(BOOL)flag
{
  MutexLocker l(__instanceLock__);
  _automaticallyRelayoutOnSafeAreaChanges = flag;
}

- (BOOL)automaticallyRelayoutOnLayoutMarginsChanges
{
  MutexLocker l(__instanceLock__);
  return _automaticallyRelayoutOnLayoutMarginsChanges;
}

- (void)setAutomaticallyRelayoutOnLayoutMarginsChanges:(BOOL)flag
{
  MutexLocker l(__instanceLock__);
  _automaticallyRelayoutOnLayoutMarginsChanges = flag;
}

#pragma mark - UIResponder

#define HANDLE_NODE_RESPONDER_METHOD(__sel) \
  /* All responder methods should be called on the main thread */ \
  ASDisplayNodeAssertMainThread(); \
  if (checkFlag(Synchronous)) { \
    /* If the view is not a _ASDisplayView subclass (Synchronous) just call through to the view as we
     expect it's a non _ASDisplayView subclass that will respond */ \
    return [_view __sel]; \
  } else { \
    if (ASSubclassOverridesSelector([_ASDisplayView class], _viewClass, @selector(__sel))) { \
    /* If the subclass overwrites canBecomeFirstResponder just call through
       to it as we expect it will handle it */ \
      return [_view __sel]; \
    } else { \
      /* Call through to _ASDisplayView's superclass to get it handled */ \
      return [(_ASDisplayView *)_view __##__sel]; \
    } \
  } \

- (void)checkResponderCompatibility
{
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  // There are certain cases we cannot handle and are not supported:
  // 1. If the _view class is not a subclass of _ASDisplayView
  if (checkFlag(Synchronous)) {
    // 2. At least one UIResponder methods are overwritten in the node subclass
    NSString *message =  @"Overwritting %@ and having a backing view that is not an _ASDisplayView is not supported.";
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self.class, @selector(canBecomeFirstResponder)), ([NSString stringWithFormat:message, @"canBecomeFirstResponder"]));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self.class, @selector(becomeFirstResponder)), ([NSString stringWithFormat:message, @"becomeFirstResponder"]));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self.class, @selector(canResignFirstResponder)), ([NSString stringWithFormat:message, @"canResignFirstResponder"]));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self.class, @selector(resignFirstResponder)), ([NSString stringWithFormat:message, @"resignFirstResponder"]));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self.class, @selector(isFirstResponder)), ([NSString stringWithFormat:message, @"isFirstResponder"]));
  }
#endif
}

- (BOOL)__canBecomeFirstResponder
{
  if (_view == nil) {
    // By default we return NO if not view is created yet
    return NO;
  }
  
  HANDLE_NODE_RESPONDER_METHOD(canBecomeFirstResponder);
}

- (BOOL)__becomeFirstResponder
{
  // Note: This implicitly loads the view if it hasn't been loaded yet.
  [self view];

  if (![self canBecomeFirstResponder]) {
    return NO;
  }

  HANDLE_NODE_RESPONDER_METHOD(becomeFirstResponder);
}

- (BOOL)__canResignFirstResponder
{
  if (_view == nil) {
    // By default we return YES if no view is created yet
    return YES;
  }
  
  HANDLE_NODE_RESPONDER_METHOD(canResignFirstResponder);
}

- (BOOL)__resignFirstResponder
{
  // Note: This implicitly loads the view if it hasn't been loaded yet.
  [self view];

  if (![self canResignFirstResponder]) {
    return NO;
  }
  
  HANDLE_NODE_RESPONDER_METHOD(resignFirstResponder);
}

- (BOOL)__isFirstResponder
{
  if (_view == nil) {
    // If no view is created yet we can just return NO as it's unlikely it's the first responder
    return NO;
  }
  
  HANDLE_NODE_RESPONDER_METHOD(isFirstResponder);
}

#pragma mark <ASDebugNameProvider>

- (NSString *)debugName
{
  MutexLocker l(__instanceLock__);
  return _debugName;
}

- (void)setDebugName:(NSString *)debugName
{
  MutexLocker l(__instanceLock__);
  if (!ASObjectIsEqual(_debugName, debugName)) {
    _debugName = [debugName copy];
  }
}

#pragma mark - Layout

#pragma mark <ASLayoutElementTransition>

- (BOOL)canLayoutAsynchronous
{
  return !self.isNodeLoaded;
}

#pragma mark Layout Pass

- (void)__setNeedsLayout
{
  [self invalidateCalculatedLayout];
}

- (void)invalidateCalculatedLayout
{
  MutexLocker l(__instanceLock__);
  
  _layoutVersion++;
  
  _unflattenedLayout = nil;

#if YOGA
  [self invalidateCalculatedYogaLayout];
#endif
}

- (void)__layout
{
  ASDisplayNodeAssertThreadAffinity(self);
  // ASAssertUnlocked(__instanceLock__);
  
  BOOL loaded = NO;
  {
    AS::UniqueLock l(__instanceLock__);
    loaded = [self _locked_isNodeLoaded];
    CGRect bounds = _threadSafeBounds;
    
    if (CGRectEqualToRect(bounds, CGRectZero)) {
      // Performing layout on a zero-bounds view often results in frame calculations
      // with negative sizes after applying margins, which will cause
      // layoutThatFits: on subnodes to assert.
      return;
    }
    
    // If a current layout transition is in progress there is no need to do a measurement and layout pass in here as
    // this is supposed to happen within the layout transition process
    if (_transitionID != ASLayoutElementContextInvalidTransitionID) {
      return;
    }

    // This method will confirm that the layout is up to date (and update if needed).
    // Importantly, it will also APPLY the layout to all of our subnodes if (unless parent is transitioning).
    l.unlock();
    [self _u_measureNodeWithBoundsIfNecessary:bounds];
    l.lock();
    
    [self _locked_layoutPlaceholderIfNecessary];
  }
  
  [self _layoutSublayouts];
  
  // Per API contract, `-layout` and `-layoutDidFinish` are called only if the node is loaded. 
  if (loaded) {
    ASPerformBlockOnMainThread(^{
      [self layout];
      [self _layoutClipCornersIfNeeded];
      [self _layoutDidFinish];
    });
  }

  [self _fallbackUpdateSafeAreaOnChildren];
}

- (void)_layoutDidFinish
{
  ASDisplayNodeAssertMainThread();
  // ASAssertUnlocked(__instanceLock__);
  ASDisplayNodeAssertTrue(self.isNodeLoaded);
  [self layoutDidFinish];
}

#pragma mark Calculation

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
#if AS_KDEBUG_ENABLE
  // We only want one calculateLayout signpost interval per thread.
  // Currently there is no fallback for profiling i386, since it's not useful.
  static _Thread_local NSInteger tls_callDepth;
  if (tls_callDepth++ == 0) {
    ASSignpostStart(ASSignpostCalculateLayout);
  }
#endif

  ASSizeRange styleAndParentSize = ASLayoutElementSizeResolve(self.style.size, parentSize);
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, styleAndParentSize);
  ASLayout *result = [self calculateLayoutThatFits:resolvedRange];

#if AS_KDEBUG_ENABLE
  if (--tls_callDepth == 0) {
    ASSignpostEnd(ASSignpostCalculateLayout);
  }
#endif
  
  return result;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  switch (self.layoutEngineType) {
    case ASLayoutEngineTypeLayoutSpec:
      return [self calculateLayoutLayoutSpec:constrainedSize];
#if YOGA
    case ASLayoutEngineTypeYoga:
      return [self calculateLayoutYoga:constrainedSize];
#endif
      // If YOGA is not defined but for some reason the layout type engine is Yoga
      // we explicitly fallthrough here
    default:
      break;
  }

  // If this case is reached a layout type engine was defined for a node that is currently
  // not supported.
  ASDisplayNodeAssert(NO, @"No layout type determined");
  return nil;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
  
  ASDisplayNodeLogEvent(self, @"calculateSizeThatFits: with constrainedSize: %@", NSStringFromCGSize(constrainedSize));

  return ASIsCGSizeValidForSize(constrainedSize) ? constrainedSize : CGSizeZero;
}

- (void)layout
{
  // Hook for subclasses
  ASDisplayNodeAssertMainThread();
  // ASAssertUnlocked(__instanceLock__);
  ASDisplayNodeAssertTrue(self.isNodeLoaded);
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del nodeDidLayout];
  }];
}

#pragma mark Layout Transition

- (void)_layoutTransitionMeasurementDidFinish
{
  // Hook for subclasses - No-Op in ASDisplayNode
}

#pragma mark <_ASTransitionContextCompletionDelegate>

/**
 * After completeTransition: is called on the ASContextTransitioning object in animateLayoutTransition: this
 * delegate method will be called that start the completion process of the transition
 */
- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete
{
  ASDisplayNodeAssertMainThread();

  [self didCompleteLayoutTransition:context];
  
  _pendingLayoutTransitionContext = nil;

  [self _pendingLayoutTransitionDidComplete];
}

#pragma mark - Display

NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification = @"ASRenderingEngineDidDisplayScheduledNodes";
NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp = @"ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp";

- (BOOL)displaysAsynchronously
{
  MutexLocker l(__instanceLock__);
  return [self _locked_displaysAsynchronously];
}

/**
 * Core implementation of -displaysAsynchronously.
 */
- (BOOL)_locked_displaysAsynchronously
{
  ASAssertLocked(__instanceLock__);
  return checkFlag(Synchronous) == NO && _flags.displaysAsynchronously;
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  MutexLocker l(__instanceLock__);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (checkFlag(Synchronous)) {
    return;
  }

  if (_flags.displaysAsynchronously == displaysAsynchronously) {
    return;
  }

  _flags.displaysAsynchronously = displaysAsynchronously;

  self._locked_asyncLayer.displaysAsynchronously = displaysAsynchronously;
}

- (BOOL)rasterizesSubtree
{
  MutexLocker l(__instanceLock__);
  return _flags.rasterizesSubtree;
}

- (void)enableSubtreeRasterization
{
  MutexLocker l(__instanceLock__);
  // Already rasterized from self.
  if (_flags.rasterizesSubtree) {
    return;
  }

  // If rasterized from above, bail.
  if (ASHierarchyStateIncludesRasterized(_hierarchyState)) {
    ASDisplayNodeFailAssert(@"Subnode of a rasterized node should not have redundant -enableSubtreeRasterization.");
    return;
  }

  // Ensure not loaded.
  if ([self _locked_isNodeLoaded]) {
    ASDisplayNodeFailAssert(@"Cannot call %@ on loaded node: %@", NSStringFromSelector(_cmd), self);
    return;
  }

  // Ensure no loaded subnodes
  ASDisplayNode *loadedSubnode = ASDisplayNodeFindFirstSubnode(self, ^BOOL(ASDisplayNode * _Nonnull node) {
    return node.nodeLoaded;
  });
  if (loadedSubnode != nil) {
      ASDisplayNodeFailAssert(@"Cannot call %@ on node %@ with loaded subnode %@", NSStringFromSelector(_cmd), self, loadedSubnode);
      return;
  }

  _flags.rasterizesSubtree = YES;

  // Tell subnodes that now they're in a rasterized hierarchy (while holding lock!)
  for (ASDisplayNode *subnode in _subnodes) {
    [subnode enterHierarchyState:ASHierarchyStateRasterized];
  }
}

- (CGFloat)contentsScaleForDisplay
{
  MutexLocker l(__instanceLock__);

  return _contentsScaleForDisplay;
}

- (void)setContentsScaleForDisplay:(CGFloat)contentsScaleForDisplay
{
  MutexLocker l(__instanceLock__);

  if (_contentsScaleForDisplay == contentsScaleForDisplay) {
    return;
  }

  _contentsScaleForDisplay = contentsScaleForDisplay;
}

- (void)displayImmediately
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!checkFlag(Synchronous), @"this method is designed for asynchronous mode only");

  [self.asyncLayer displayImmediately];
}

- (void)recursivelyDisplayImmediately
{
  for (ASDisplayNode *child in self.subnodes) {
    [child recursivelyDisplayImmediately];
  }
  [self displayImmediately];
}

- (void)__setNeedsDisplay
{
  BOOL shouldScheduleForDisplay = NO;
  {
    MutexLocker l(__instanceLock__);
    BOOL nowDisplay = ASInterfaceStateIncludesDisplay(_interfaceState);
    // FIXME: This should not need to recursively display, so create a non-recursive variant.
    // The semantics of setNeedsDisplay (as defined by CALayer behavior) are not recursive.
    if (_layer != nil && !checkFlag(Synchronous) && nowDisplay && [self _implementsDisplay]) {
      shouldScheduleForDisplay = YES;
    }
  }
  
  if (shouldScheduleForDisplay) {
    [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
  }
}

+ (void)scheduleNodeForRecursiveDisplay:(ASDisplayNode *)node
{
  static dispatch_once_t onceToken;
  static ASRunLoopQueue<ASDisplayNode *> *renderQueue;
  dispatch_once(&onceToken, ^{
    renderQueue = [[ASRunLoopQueue<ASDisplayNode *> alloc] initWithRunLoop:CFRunLoopGetMain()
                                                             retainObjects:NO
                                                                   handler:^(ASDisplayNode * _Nonnull dequeuedItem, BOOL isQueueDrained) {
      [dequeuedItem _recursivelyTriggerDisplayAndBlock:NO];
      if (isQueueDrained) {
        CFTimeInterval timestamp = CACurrentMediaTime();
        [[NSNotificationCenter defaultCenter] postNotificationName:ASRenderingEngineDidDisplayScheduledNodesNotification
                                                            object:nil
                                                          userInfo:@{ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp: @(timestamp)}];
      }
    }];
  });

  [renderQueue enqueue:node];
}

/// Helper method to summarize whether or not the node run through the display process
- (BOOL)_implementsDisplay
{
  MutexLocker l(__instanceLock__);
  
  return _flags.implementsDrawRect || _flags.implementsImageDisplay || _flags.rasterizesSubtree;
}

// Track that a node will be displayed as part of the current node hierarchy.
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeWillDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  // No lock needed as _pendingDisplayNodes is main thread only
  if (!_pendingDisplayNodes) {
    _pendingDisplayNodes = [[ASWeakSet alloc] init];
  }

  [_pendingDisplayNodes addObject:node];
}

// Notify that a node that was pending display finished
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeDidDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  // No lock for _pendingDisplayNodes needed as it's main thread only
  [_pendingDisplayNodes removeObject:node];

  if (_pendingDisplayNodes.isEmpty) {
    
    [self hierarchyDisplayDidFinish];
    [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> delegate) {
      [delegate hierarchyDisplayDidFinish];
    }];
      
    BOOL placeholderShouldPersist = [self placeholderShouldPersist];

    __instanceLock__.lock();
    if (_placeholderLayer.superlayer && !placeholderShouldPersist) {
      void (^cleanupBlock)() = ^{
        [_placeholderLayer removeFromSuperlayer];
      };

      if (_placeholderFadeDuration > 0.0 && ASInterfaceStateIncludesVisible(self.interfaceState)) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:cleanupBlock];
        [CATransaction setAnimationDuration:_placeholderFadeDuration];
        _placeholderLayer.opacity = 0.0;
        [CATransaction commit];
      } else {
        cleanupBlock();
      }
    }
    __instanceLock__.unlock();
  }
}

// Helper method to determine if it's safe to call setNeedsDisplay on a layer without throwing away the content.
// For details look at the comment on the canCallSetNeedsDisplayOfLayer flag
- (BOOL)_canCallSetNeedsDisplayOfLayer
{
  MutexLocker l(__instanceLock__);
  return _flags.canCallSetNeedsDisplayOfLayer;
}

void recursivelyTriggerDisplayForLayer(CALayer *layer, BOOL shouldBlock)
{
  // This recursion must handle layers in various states:
  // 1. Just added to hierarchy, CA hasn't yet called -display
  // 2. Previously in a hierarchy (such as a working window owned by an Intelligent Preloading class, like ASTableView / ASCollectionView / ASViewController)
  // 3. Has no content to display at all
  // Specifically for case 1), we need to explicitly trigger a -display call now.
  // Otherwise, there is no opportunity to block the main thread after CoreAnimation's transaction commit
  // (even a runloop observer at a late call order will not stop the next frame from compositing, showing placeholders).
  
  ASDisplayNode *node = [layer asyncdisplaykit_node];
  
  if (node.isSynchronous && [node _canCallSetNeedsDisplayOfLayer]) {
    // Layers for UIKit components that are wrapped within a node needs to be set to be displayed as the contents of
    // the layer get's cleared and would not be recreated otherwise.
    // We do not call this for _ASDisplayLayer as an optimization.
    [layer setNeedsDisplay];
  }
  
  if ([node _implementsDisplay]) {
    // For layers that do get displayed here, this immediately kicks off the work on the concurrent -[_ASDisplayLayer displayQueue].
    // At the same time, it creates an associated _ASAsyncTransaction, which we can use to block on display completion.  See ASDisplayNode+AsyncDisplay.mm.
    [layer displayIfNeeded];
  }
  
  // Kick off the recursion first, so that all necessary display calls are sent and the displayQueue is full of parallelizable work.
  // NOTE: The docs report that `sublayers` returns a copy but it actually doesn't.
  for (CALayer *sublayer in [layer.sublayers copy]) {
    recursivelyTriggerDisplayForLayer(sublayer, shouldBlock);
  }
  
  if (shouldBlock) {
    // As the recursion unwinds, verify each transaction is complete and block if it is not.
    // While blocking on one transaction, others may be completing concurrently, so it doesn't matter which blocks first.
    BOOL waitUntilComplete = (!node.shouldBypassEnsureDisplay);
    if (waitUntilComplete) {
      for (_ASAsyncTransaction *transaction in [layer.asyncdisplaykit_asyncLayerTransactions copy]) {
        // Even if none of the layers have had a chance to start display earlier, they will still be allowed to saturate a multicore CPU while blocking main.
        // This significantly reduces time on the main thread relative to UIKit.
        [transaction waitUntilComplete];
      }
    }
  }
}

- (void)_recursivelyTriggerDisplayAndBlock:(BOOL)shouldBlock
{
  ASDisplayNodeAssertMainThread();
  
  CALayer *layer = self.layer;
  // -layoutIfNeeded is recursive, and even walks up to superlayers to check if they need layout,
  // so we should call it outside of starting the recursion below.  If our own layer is not marked
  // as dirty, we can assume layout has run on this subtree before.
  if ([layer needsLayout]) {
    [layer layoutIfNeeded];
  }
  recursivelyTriggerDisplayForLayer(layer, shouldBlock);
}

- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously
{
  [self _recursivelyTriggerDisplayAndBlock:synchronously];
}

- (void)setShouldBypassEnsureDisplay:(BOOL)shouldBypassEnsureDisplay
{
  MutexLocker l(__instanceLock__);
  _flags.shouldBypassEnsureDisplay = shouldBypassEnsureDisplay;
}

- (BOOL)shouldBypassEnsureDisplay
{
  MutexLocker l(__instanceLock__);
  return _flags.shouldBypassEnsureDisplay;
}

- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale
{
  {
    MutexLocker l(__instanceLock__);
    if (contentsScale == _contentsScaleForDisplay) {
      return;
    }
    
    _contentsScaleForDisplay = contentsScale;
  }

  [self setNeedsDisplay];
}

- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    [node setNeedsDisplayAtScale:contentsScale];
  });
}

- (void)_layoutClipCornersIfNeeded
{
  ASDisplayNodeAssertMainThread();
  if (_clipCornerLayers[0] == nil) {
    return;
  }
  
  CGSize boundsSize = self.bounds.size;
  for (int idx = 0; idx < NUM_CLIP_CORNER_LAYERS; idx++) {
    BOOL isTop   = (idx == 0 || idx == 1);
    BOOL isRight = (idx == 1 || idx == 2);
    if (_clipCornerLayers[idx]) {
      // Note the Core Animation coordinates are reversed for y; 0 is at the bottom.
      _clipCornerLayers[idx].position = CGPointMake(isRight ? boundsSize.width : 0.0, isTop ? boundsSize.height : 0.0);
      [_layer addSublayer:_clipCornerLayers[idx]];
    }
  }
}

- (void)_updateClipCornerLayerContentsWithRadius:(CGFloat)radius backgroundColor:(UIColor *)backgroundColor
{
  ASPerformBlockOnMainThread(^{
    for (int idx = 0; idx < NUM_CLIP_CORNER_LAYERS; idx++) {
      // Layers are, in order: Top Left, Top Right, Bottom Right, Bottom Left.
      // anchorPoint is Bottom Left at 0,0 and Top Right at 1,1.
      BOOL isTop   = (idx == 0 || idx == 1);
      BOOL isRight = (idx == 1 || idx == 2);
      
      CGSize size = CGSizeMake(radius + 1, radius + 1);
      ASGraphicsBeginImageContextWithOptions(size, NO, self.contentsScaleForDisplay);
      
      CGContextRef ctx = UIGraphicsGetCurrentContext();
      if (isRight == YES) {
        CGContextTranslateCTM(ctx, -radius + 1, 0);
      }
      if (isTop == YES) {
        CGContextTranslateCTM(ctx, 0, -radius + 1);
      }
      UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, radius * 2, radius * 2) cornerRadius:radius];
      [roundedRect setUsesEvenOddFillRule:YES];
      [roundedRect appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(-1, -1, radius * 2 + 1, radius * 2 + 1)]];
      [backgroundColor setFill];
      [roundedRect fill];
      
      // No lock needed, as _clipCornerLayers is only modified on the main thread.
      CALayer *clipCornerLayer = _clipCornerLayers[idx];
      clipCornerLayer.contents = (id)(ASGraphicsGetImageAndEndCurrentContext().CGImage);
      clipCornerLayer.bounds = CGRectMake(0.0, 0.0, size.width, size.height);
      clipCornerLayer.anchorPoint = CGPointMake(isRight ? 1.0 : 0.0, isTop ? 1.0 : 0.0);
    }
    [self _layoutClipCornersIfNeeded];
  });
}

- (void)_setClipCornerLayersVisible:(BOOL)visible
{
}

- (void)updateCornerRoundingWithType:(ASCornerRoundingType)newRoundingType cornerRadius:(CGFloat)newCornerRadius
{
  __instanceLock__.lock();
    CGFloat oldCornerRadius = _cornerRadius;
    ASCornerRoundingType oldRoundingType = _cornerRoundingType;

    _cornerRadius = newCornerRadius;
    _cornerRoundingType = newRoundingType;
  __instanceLock__.unlock();
 
  ASPerformBlockOnMainThread(^{
    ASDisplayNodeAssertMainThread();
    
    if (oldRoundingType != newRoundingType || oldCornerRadius != newCornerRadius) {
      if (oldRoundingType == ASCornerRoundingTypeDefaultSlowCALayer) {
        if (newRoundingType == ASCornerRoundingTypePrecomposited) {
          self.layerCornerRadius = 0.0;
          if (oldCornerRadius > 0.0) {
            [self displayImmediately];
          } else {
            [self setNeedsDisplay]; // Async display is OK if we aren't replacing an existing .cornerRadius.
          }
        }
        else if (newRoundingType == ASCornerRoundingTypeClipping) {
          self.layerCornerRadius = 0.0;
          [self _setClipCornerLayersVisible:YES];
        } else if (newRoundingType == ASCornerRoundingTypeDefaultSlowCALayer) {
          self.layerCornerRadius = newCornerRadius;
        }
      }
      else if (oldRoundingType == ASCornerRoundingTypePrecomposited) {
        if (newRoundingType == ASCornerRoundingTypeDefaultSlowCALayer) {
          self.layerCornerRadius = newCornerRadius;
          [self setNeedsDisplay];
        }
        else if (newRoundingType == ASCornerRoundingTypePrecomposited) {
          // Corners are already precomposited, but the radius has changed.
          // Default to async re-display.  The user may force a synchronous display if desired.
          [self setNeedsDisplay];
        }
        else if (newRoundingType == ASCornerRoundingTypeClipping) {
          [self _setClipCornerLayersVisible:YES];
          [self setNeedsDisplay];
        }
      }
      else if (oldRoundingType == ASCornerRoundingTypeClipping) {
        if (newRoundingType == ASCornerRoundingTypeDefaultSlowCALayer) {
          self.layerCornerRadius = newCornerRadius;
          [self _setClipCornerLayersVisible:NO];
        }
        else if (newRoundingType == ASCornerRoundingTypePrecomposited) {
          [self _setClipCornerLayersVisible:NO];
          [self displayImmediately];
        }
        else if (newRoundingType == ASCornerRoundingTypeClipping) {
          // Clip corners already exist, but the radius has changed.
          [self _updateClipCornerLayerContentsWithRadius:newCornerRadius backgroundColor:self.backgroundColor];
        }
      }
    }
  });
}

- (void)recursivelySetDisplaySuspended:(BOOL)flag
{
  _recursivelySetDisplaySuspended(self, nil, flag);
}

// TODO: Replace this with ASDisplayNodePerformBlockOnEveryNode or a variant with a condition / test block.
static void _recursivelySetDisplaySuspended(ASDisplayNode *node, CALayer *layer, BOOL flag)
{
  // If there is no layer, but node whose its view is loaded, then we can traverse down its layer hierarchy.  Otherwise we must stick to the node hierarchy to avoid loading views prematurely.  Note that for nodes that haven't loaded their views, they can't possibly have subviews/sublayers, so we don't need to traverse the layer hierarchy for them.
  if (!layer && node && node.nodeLoaded) {
    layer = node.layer;
  }

  // If we don't know the node, but the layer is an async layer, get the node from the layer.
  if (!node && layer && [layer isKindOfClass:[_ASDisplayLayer class]]) {
    node = layer.asyncdisplaykit_node;
  }

  // Set the flag on the node.  If this is a pure layer (no node) then this has no effect (plain layers don't support preventing/cancelling display).
  node.displaySuspended = flag;

  if (layer && !node.rasterizesSubtree) {
    // If there is a layer, recurse down the layer hierarchy to set the flag on descendants.  This will cover both layer-based and node-based children.
    for (CALayer *sublayer in layer.sublayers) {
      _recursivelySetDisplaySuspended(nil, sublayer, flag);
    }
  } else {
    // If there is no layer (view not loaded yet) or this node rasterizes descendants (there won't be a layer tree to traverse), recurse down the subnode hierarchy to set the flag on descendants.  This covers only node-based children, but for a node whose view is not loaded it can't possibly have nodeless children.
    for (ASDisplayNode *subnode in node.subnodes) {
      _recursivelySetDisplaySuspended(subnode, nil, flag);
    }
  }
}

- (BOOL)displaySuspended
{
  MutexLocker l(__instanceLock__);
  return _flags.displaySuspended;
}

- (void)setDisplaySuspended:(BOOL)flag
{
  ASDisplayNodeAssertThreadAffinity(self);
  __instanceLock__.lock();

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (checkFlag(Synchronous) || _flags.displaySuspended == flag) {
    __instanceLock__.unlock();
    return;
  }

  _flags.displaySuspended = flag;

  self._locked_asyncLayer.displaySuspended = flag;
  
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();

  if ([self _implementsDisplay]) {
    // Display start and finish methods needs to happen on the main thread
    ASPerformBlockOnMainThread(^{
      if (flag) {
        [supernode subnodeDisplayDidFinish:self];
      } else {
        [supernode subnodeDisplayWillStart:self];
      }
    });
  }
}

#pragma mark <_ASDisplayLayerDelegate>

- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer asynchronously:(BOOL)asynchronously
{
  // Subclass hook.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self displayWillStart];
#pragma clang diagnostic pop

  [self displayWillStartAsynchronously:asynchronously];
}

- (void)didDisplayAsyncLayer:(_ASDisplayLayer *)layer
{
  // Subclass hook.
  [self displayDidFinish];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)displayWillStart {}
#pragma clang diagnostic pop
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  ASDisplayNodeAssertMainThread();

  ASDisplayNodeLogEvent(self, @"displayWillStart");
  // in case current node takes longer to display than it's subnodes, treat it as a dependent node
  [self _pendingNodeWillDisplay:self];
  
  __instanceLock__.lock();
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  [supernode subnodeDisplayWillStart:self];
}

- (void)displayDidFinish
{
  ASDisplayNodeAssertMainThread();
  
  ASDisplayNodeLogEvent(self, @"displayDidFinish");
  [self _pendingNodeDidDisplay:self];

  __instanceLock__.lock();
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  [supernode subnodeDisplayDidFinish:self];
}

- (void)subnodeDisplayWillStart:(ASDisplayNode *)subnode
{
  // Subclass hook
  [self _pendingNodeWillDisplay:subnode];
}

- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode
{
  // Subclass hook
  [self _pendingNodeDidDisplay:subnode];
}

#pragma mark <CALayerDelegate>

// We are only the delegate for the layer when we are layer-backed, as UIView performs this function normally
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
  if (event == kCAOnOrderIn) {
    [self __enterHierarchy];
  } else if (event == kCAOnOrderOut) {
    [self __exitHierarchy];
  }

  ASDisplayNodeAssert(_flags.layerBacked, @"We shouldn't get called back here unless we are layer-backed.");
  return (id)kCFNull;
}

#pragma mark - Error Handling

+ (void)setNonFatalErrorBlock:(ASDisplayNodeNonFatalErrorBlock)nonFatalErrorBlock
{
  if (_nonFatalErrorBlock != nonFatalErrorBlock) {
    _nonFatalErrorBlock = [nonFatalErrorBlock copy];
  }
}

+ (ASDisplayNodeNonFatalErrorBlock)nonFatalErrorBlock
{
  return _nonFatalErrorBlock;
}

#pragma mark - Converting to and from the Node's Coordinate System

- (CATransform3D)_transformToAncestor:(ASDisplayNode *)ancestor
{
  CATransform3D transform = CATransform3DIdentity;
  ASDisplayNode *currentNode = self;
  while (currentNode.supernode) {
    if (currentNode == ancestor) {
      return transform;
    }

    CGPoint anchorPoint = currentNode.anchorPoint;
    CGRect bounds = currentNode.bounds;
    CGPoint position = currentNode.position;
    CGPoint origin = CGPointMake(position.x - bounds.size.width * anchorPoint.x,
                                 position.y - bounds.size.height * anchorPoint.y);

    transform = CATransform3DTranslate(transform, origin.x, origin.y, 0);
    transform = CATransform3DTranslate(transform, -bounds.origin.x, -bounds.origin.y, 0);
    currentNode = currentNode.supernode;
  }
  return transform;
}

static inline CATransform3D _calculateTransformFromReferenceToTarget(ASDisplayNode *referenceNode, ASDisplayNode *targetNode)
{
  ASDisplayNode *ancestor = ASDisplayNodeFindClosestCommonAncestor(referenceNode, targetNode);

  // Transform into global (away from reference coordinate space)
  CATransform3D transformToGlobal = [referenceNode _transformToAncestor:ancestor];

  // Transform into local (via inverse transform from target to ancestor)
  CATransform3D transformToLocal = CATransform3DInvert([targetNode _transformToAncestor:ancestor]);

  return CATransform3DConcat(transformToGlobal, transformToLocal);
}

- (CGPoint)convertPoint:(CGPoint)point fromNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  /**
   * When passed node=nil, all methods in this family use the UIView-style
   * behavior – that is, convert from/to window coordinates if there's a window,
   * otherwise return the point untransformed.
   */
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertPoint:point fromLayer:window.layer];
    } else {
      return point;
    }
  }
  
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(node, self);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to point
  return CGPointApplyAffineTransform(point, flattenedTransform);
}

- (CGPoint)convertPoint:(CGPoint)point toNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertPoint:point toLayer:window.layer];
    } else {
      return point;
    }
  }
  
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to point
  return CGPointApplyAffineTransform(point, flattenedTransform);
}

- (CGRect)convertRect:(CGRect)rect fromNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertRect:rect fromLayer:window.layer];
    } else {
      return rect;
    }
  }
  
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(node, self);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to rect
  return CGRectApplyAffineTransform(rect, flattenedTransform);
}

- (CGRect)convertRect:(CGRect)rect toNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertRect:rect toLayer:window.layer];
    } else {
      return rect;
    }
  }
  
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to rect
  return CGRectApplyAffineTransform(rect, flattenedTransform);
}

#pragma mark - Managing the Node Hierarchy

ASDISPLAYNODE_INLINE bool shouldDisableNotificationsForMovingBetweenParents(ASDisplayNode *from, ASDisplayNode *to) {
  if (!from || !to) return NO;
  if (from.isSynchronous) return NO;
  if (to.isSynchronous) return NO;
  if (from.isInHierarchy != to.isInHierarchy) return NO;
  return YES;
}

/// Returns incremented value of i if i is not NSNotFound
ASDISPLAYNODE_INLINE NSInteger incrementIfFound(NSInteger i) {
  return i == NSNotFound ? NSNotFound : i + 1;
}

/// Returns if a node is a member of a rasterized tree
ASDISPLAYNODE_INLINE BOOL canUseViewAPI(ASDisplayNode *node, ASDisplayNode *subnode) {
  return (subnode.isLayerBacked == NO && node.isLayerBacked == NO);
}

/// Returns if node is a member of a rasterized tree
ASDISPLAYNODE_INLINE BOOL subtreeIsRasterized(ASDisplayNode *node) {
  return (node.rasterizesSubtree || (node.hierarchyState & ASHierarchyStateRasterized));
}

// NOTE: This method must be dealloc-safe (should not retain self).
- (ASDisplayNode *)supernode
{
  MutexLocker l(__instanceLock__);
  return _supernode;
}

- (void)_setSupernode:(ASDisplayNode *)newSupernode
{
  BOOL supernodeDidChange = NO;
  ASDisplayNode *oldSupernode = nil;
  {
    MutexLocker l(__instanceLock__);
    if (_supernode != newSupernode) {
      oldSupernode = _supernode;  // Access supernode properties outside of lock to avoid remote chance of deadlock,
                                  // in case supernode implementation must access one of our properties.
      _supernode = newSupernode;
      supernodeDidChange = YES;
    }
  }
  
  if (supernodeDidChange) {
    ASDisplayNodeLogEvent(self, @"supernodeDidChange: %@, oldValue = %@", ASObjectDescriptionMakeTiny(newSupernode), ASObjectDescriptionMakeTiny(oldSupernode));
    // Hierarchy state
    ASHierarchyState stateToEnterOrExit = (newSupernode ? newSupernode.hierarchyState
                                                        : oldSupernode.hierarchyState);
    
    // Rasterized state
    BOOL parentWasOrIsRasterized        = (newSupernode ? newSupernode.rasterizesSubtree
                                                        : oldSupernode.rasterizesSubtree);
    if (parentWasOrIsRasterized) {
      stateToEnterOrExit |= ASHierarchyStateRasterized;
    }
    if (newSupernode) {
      
      // Now that we have a supernode, propagate its traits to self.
      // This should be done before possibly forcing self to load so we have traits in -didLoad
      ASTraitCollectionPropagateDown(self, newSupernode.primitiveTraitCollection);
      
      if (!parentWasOrIsRasterized && newSupernode.nodeLoaded) {
        // Trigger the subnode to load its layer, which will create its view if it needs one.
        // By doing this prior to the downward propagation of newSupernode's interface state,
        // we can guarantee that -didEnterVisibleState is only called with .isNodeLoaded = YES.
        [self layer];
      }
      
      [self enterHierarchyState:stateToEnterOrExit];
      
      // If a node was added to a supernode, the supernode could be in a layout pending state. All of the hierarchy state
      // properties related to the transition need to be copied over as well as propagated down the subtree.
      // This is especially important as with automatic subnode management, adding subnodes can happen while a transition
      // is in fly
      if (ASHierarchyStateIncludesLayoutPending(stateToEnterOrExit)) {
        int32_t pendingTransitionId = newSupernode->_pendingTransitionID;
        if (pendingTransitionId != ASLayoutElementContextInvalidTransitionID) {
          {
            _pendingTransitionID = pendingTransitionId;
            
            // Propagate down the new pending transition id
            ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
              node->_pendingTransitionID = pendingTransitionId;
            });
          }
        }
      }
    } else {
      // If a node will be removed from the supernode it should go out from the layout pending state to remove all
      // layout pending state related properties on the node
      stateToEnterOrExit |= ASHierarchyStateLayoutPending;
      
      [self exitHierarchyState:stateToEnterOrExit];

      // We only need to explicitly exit hierarchy here if we were rasterized.
      // Otherwise we will exit the hierarchy when our view/layer does so
      // which has some nice carry-over machinery to handle cases where we are removed from a hierarchy
      // and then added into it again shortly after.
      __instanceLock__.lock();
      BOOL isInHierarchy = _flags.isInHierarchy;
      __instanceLock__.unlock();
      
      if (parentWasOrIsRasterized && isInHierarchy) {
        [self __exitHierarchy];
      }
    }
  }
}

- (NSArray *)subnodes
{
  MutexLocker l(__instanceLock__);
  if (_cachedSubnodes == nil) {
    _cachedSubnodes = [_subnodes copy];
  } else {
    ASDisplayNodeAssert(ASObjectIsEqual(_cachedSubnodes, _subnodes), @"Expected _subnodes and _cachedSubnodes to have the same contents.");
  }
  return _cachedSubnodes ?: @[];
}

/*
 * Central private helper method that should eventually be called if submethods add, insert or replace subnodes
 * This method is called with thread affinity and without lock held.
 *
 * @param subnode       The subnode to insert
 * @param subnodeIndex  The index in _subnodes to insert it
 * @param viewSublayerIndex The index in layer.sublayers (not view.subviews) at which to insert the view (use if we can use the view API) otherwise pass NSNotFound
 * @param sublayerIndex The index in layer.sublayers at which to insert the layer (use if either parent or subnode is layer-backed) otherwise pass NSNotFound
 * @param oldSubnode Remove this subnode before inserting; ok to be nil if no removal is desired
 */
- (void)_insertSubnode:(ASDisplayNode *)subnode atSubnodeIndex:(NSInteger)subnodeIndex sublayerIndex:(NSInteger)sublayerIndex andRemoveSubnode:(ASDisplayNode *)oldSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  
  if (subnode == nil || subnode == self) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode or self as subnode");
    return;
  }
  
  if (subnodeIndex == NSNotFound) {
    ASDisplayNodeFailAssert(@"Try to insert node on an index that was not found");
    return;
  }
  
  if (self.layerBacked && !subnode.layerBacked) {
    ASDisplayNodeFailAssert(@"Cannot add a view-backed node as a subnode of a layer-backed node. Supernode: %@, subnode: %@", self, subnode);
    return;
  }

  BOOL isRasterized = subtreeIsRasterized(self);
  if (isRasterized && subnode.nodeLoaded) {
    ASDisplayNodeFailAssert(@"Cannot add loaded node %@ to rasterized subtree of node %@", ASObjectDescriptionMakeTiny(subnode), ASObjectDescriptionMakeTiny(self));
    return;
  }

  __instanceLock__.lock();
    NSUInteger subnodesCount = _subnodes.count;
  __instanceLock__.unlock();
  if (subnodeIndex > subnodesCount || subnodeIndex < 0) {
    ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %ld. Count is %ld", (long)subnodeIndex, (long)subnodesCount);
    return;
  }
  
  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  ASDisplayNode *oldParent = subnode.supernode;
  BOOL disableNotifications = shouldDisableNotificationsForMovingBetweenParents(oldParent, self);
  if (disableNotifications) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  
  [subnode _removeFromSupernode];
  [oldSubnode _removeFromSupernode];
  
  __instanceLock__.lock();
    if (_subnodes == nil) {
      _subnodes = [[NSMutableArray alloc] init];
    }
    [_subnodes insertObject:subnode atIndex:subnodeIndex];
    _cachedSubnodes = nil;
  __instanceLock__.unlock();

  // This call will apply our .hierarchyState to the new subnode.
  // If we are a managed hierarchy, as in ASCellNode trees, it will also apply our .interfaceState.
  [subnode _setSupernode:self];

  // If this subnode will be rasterized, enter hierarchy if needed
  // TODO: Move this into _setSupernode: ?
  if (isRasterized) {
    if (self.inHierarchy) {
      [subnode __enterHierarchy];
    }
  } else if (self.nodeLoaded) {
    // If not rasterizing, and node is loaded insert the subview/sublayer now.
    [self _insertSubnodeSubviewOrSublayer:subnode atIndex:sublayerIndex];
  } // Otherwise we will insert subview/sublayer when we get loaded

  ASDisplayNodeAssert(disableNotifications == shouldDisableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (disableNotifications) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }
}

/*
 * Inserts the view or layer of the given node at the given index
 *
 * @param subnode       The subnode to insert
 * @param idx           The index in _view.subviews or _layer.sublayers at which to insert the subnode.view or
 *                      subnode.layer of the subnode
 */
- (void)_insertSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"_insertSubnodeSubviewOrSublayer:atIndex: should never be called before our own view is created");

  ASDisplayNodeAssert(idx != NSNotFound, @"Try to insert node on an index that was not found");
  if (idx == NSNotFound) {
    return;
  }
  
  // Because the view and layer can only be created and destroyed on Main, that is also the only thread
  // where the view and layer can change. We can avoid locking.

  // If we can use view API, do. Due to an apple bug, -insertSubview:atIndex: actually wants a LAYER index,
  // which we pass in.
  if (canUseViewAPI(self, subnode)) {
    [_view insertSubview:subnode.view atIndex:idx];
  } else {
    [_layer insertSublayer:subnode.layer atIndex:(unsigned int)idx];
  }
}

- (void)addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeLogEvent(self, @"addSubnode: %@ with automaticallyManagesSubnodes: %@",
                        subnode, self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _addSubnode:subnode];
}

- (void)_addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
    
  // Don't add if it's already a subnode
  ASDisplayNode *oldParent = subnode.supernode;
  if (!subnode || subnode == self || oldParent == self) {
    return;
  }

  NSUInteger subnodesIndex;
  NSUInteger sublayersIndex;
  {
    MutexLocker l(__instanceLock__);
    subnodesIndex = _subnodes.count;
    sublayersIndex = _layer.sublayers.count;
  }
  
  [self _insertSubnode:subnode atSubnodeIndex:subnodesIndex sublayerIndex:sublayersIndex andRemoveSubnode:nil];
}

- (void)_addSubnodeViewsAndLayers
{
  ASDisplayNodeAssertMainThread();
  
  TIME_SCOPED(_debugTimeToAddSubnodeViews);
  
  for (ASDisplayNode *node in self.subnodes) {
    [self _addSubnodeSubviewOrSublayer:node];
  }
}

- (void)_addSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertMainThread();
  
  // Due to a bug in Apple's framework we have to use the layer index to insert a subview
  // so just use the count of the sublayers to add the subnode
  NSInteger idx = _layer.sublayers.count; // No locking is needed as it's main thread only
  [self _insertSubnodeSubviewOrSublayer:subnode atIndex:idx];
}

- (void)replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeLogEvent(self, @"replaceSubnode: %@ withSubnode: %@ with automaticallyManagesSubnodes: %@",
                        oldSubnode, replacementSubnode, self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _replaceSubnode:oldSubnode withSubnode:replacementSubnode];
}

- (void)_replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);

  if (replacementSubnode == nil) {
    ASDisplayNodeFailAssert(@"Invalid subnode to replace");
    return;
  }
  
  if (oldSubnode.supernode != self) {
    ASDisplayNodeFailAssert(@"Old Subnode to replace must be a subnode");
    return;
  }

  ASDisplayNodeAssert(!(self.nodeLoaded && !oldSubnode.nodeLoaded), @"We have view loaded, but child node does not.");

  NSInteger subnodeIndex;
  NSInteger sublayerIndex = NSNotFound;
  {
    MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    subnodeIndex = [_subnodes indexOfObjectIdenticalTo:oldSubnode];
    
    // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
    // hierarchy and none of this could possibly work.
    if (subtreeIsRasterized(self) == NO) {
      if (_layer) {
        sublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:oldSubnode.layer];
        ASDisplayNodeAssert(sublayerIndex != NSNotFound, @"Somehow oldSubnode's supernode is self, yet we could not find it in our layers to replace");
        if (sublayerIndex == NSNotFound) {
          return;
        }
      }
    }
  }

  [self _insertSubnode:replacementSubnode atSubnodeIndex:subnodeIndex sublayerIndex:sublayerIndex andRemoveSubnode:oldSubnode];
}

- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ belowSubnode: %@ with automaticallyManagesSubnodes: %@",
                        subnode, below, self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _insertSubnode:subnode belowSubnode:below];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (below.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert below must be a subnode");
    return;
  }

  NSInteger belowSubnodeIndex;
  NSInteger belowSublayerIndex = NSNotFound;
  {
    MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    belowSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:below];
    
    // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
    // hierarchy and none of this could possibly work.
    if (subtreeIsRasterized(self) == NO) {
      if (_layer) {
        belowSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:below.layer];
        ASDisplayNodeAssert(belowSublayerIndex != NSNotFound, @"Somehow below's supernode is self, yet we could not find it in our layers to reference");
        if (belowSublayerIndex == NSNotFound)
          return;
      }
      
      ASDisplayNodeAssert(belowSubnodeIndex != NSNotFound, @"Couldn't find above in subnodes");
      
      // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to
      // insert it will mess up our calculation
      if (subnode.supernode == self) {
        NSInteger currentIndexInSubnodes = [_subnodes indexOfObjectIdenticalTo:subnode];
        if (currentIndexInSubnodes < belowSubnodeIndex) {
          belowSubnodeIndex--;
        }
        if (_layer) {
          NSInteger currentIndexInSublayers = [_layer.sublayers indexOfObjectIdenticalTo:subnode.layer];
          if (currentIndexInSublayers < belowSublayerIndex) {
            belowSublayerIndex--;
          }
        }
      }
    }
  }

  ASDisplayNodeAssert(belowSubnodeIndex != NSNotFound, @"Couldn't find below in subnodes");

  [self _insertSubnode:subnode atSubnodeIndex:belowSubnodeIndex sublayerIndex:belowSublayerIndex andRemoveSubnode:nil];
}

- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ abodeSubnode: %@ with automaticallyManagesSubnodes: %@",
                        subnode, above, self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _insertSubnode:subnode aboveSubnode:above];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (above.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert above must be a subnode");
    return;
  }

  NSInteger aboveSubnodeIndex;
  NSInteger aboveSublayerIndex = NSNotFound;
  {
    MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    aboveSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:above];
    
    // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
    // hierarchy and none of this could possibly work.
    if (subtreeIsRasterized(self) == NO) {
      if (_layer) {
        aboveSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:above.layer];
        ASDisplayNodeAssert(aboveSublayerIndex != NSNotFound, @"Somehow above's supernode is self, yet we could not find it in our layers to replace");
        if (aboveSublayerIndex == NSNotFound)
          return;
      }
      
      ASDisplayNodeAssert(aboveSubnodeIndex != NSNotFound, @"Couldn't find above in subnodes");
      
      // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to
      // insert it will mess up our calculation
      if (subnode.supernode == self) {
        NSInteger currentIndexInSubnodes = [_subnodes indexOfObjectIdenticalTo:subnode];
        if (currentIndexInSubnodes <= aboveSubnodeIndex) {
          aboveSubnodeIndex--;
        }
        if (_layer) {
          NSInteger currentIndexInSublayers = [_layer.sublayers indexOfObjectIdenticalTo:subnode.layer];
          if (currentIndexInSublayers <= aboveSublayerIndex) {
            aboveSublayerIndex--;
          }
        }
      }
    }
  }

  [self _insertSubnode:subnode atSubnodeIndex:incrementIfFound(aboveSubnodeIndex) sublayerIndex:incrementIfFound(aboveSublayerIndex) andRemoveSubnode:nil];
}

- (void)insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ atIndex: %td with automaticallyManagesSubnodes: %@",
                        subnode, idx, self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _insertSubnode:subnode atIndex:idx];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  
  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  NSInteger sublayerIndex = NSNotFound;
  {
    MutexLocker l(__instanceLock__);
    
    if (idx > _subnodes.count || idx < 0) {
      ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %ld. Count is %ld", (long)idx, (long)_subnodes.count);
      return;
    }
    
    // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
    // hierarchy and none of this could possibly work.
    if (subtreeIsRasterized(self) == NO) {
      // Account for potentially having other subviews
      if (_layer && idx == 0) {
        sublayerIndex = 0;
      } else if (_layer) {
        ASDisplayNode *positionInRelationTo = (_subnodes.count > 0 && idx > 0) ? _subnodes[idx - 1] : nil;
        if (positionInRelationTo) {
          sublayerIndex = incrementIfFound([_layer.sublayers indexOfObjectIdenticalTo:positionInRelationTo.layer]);
        }
      }
    }
  }

  [self _insertSubnode:subnode atSubnodeIndex:idx sublayerIndex:sublayerIndex andRemoveSubnode:nil];
}

- (void)_removeSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  
  // Don't call self.supernode here because that will retain/autorelease the supernode.  This method -_removeSupernode: is often called while tearing down a node hierarchy, and the supernode in question might be in the middle of its -dealloc.  The supernode is never messaged, only compared by value, so this is safe.
  // The particular issue that triggers this edge case is when a node calls -removeFromSupernode on a subnode from within its own -dealloc method.
  if (!subnode || subnode.supernode != self) {
    return;
  }

  __instanceLock__.lock();
    [_subnodes removeObjectIdenticalTo:subnode];
    _cachedSubnodes = nil;
  __instanceLock__.unlock();

  [subnode _setSupernode:nil];
}

- (void)removeFromSupernode
{
  ASDisplayNodeLogEvent(self, @"removeFromSupernode with automaticallyManagesSubnodes: %@",
                        self.automaticallyManagesSubnodes ? @"YES" : @"NO");
  [self _removeFromSupernode];
}

- (void)_removeFromSupernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  
  __instanceLock__.lock();
    __weak ASDisplayNode *supernode = _supernode;
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
  __instanceLock__.unlock();

  [self _removeFromSupernode:supernode view:view layer:layer];
}

- (void)_removeFromSupernodeIfEqualTo:(ASDisplayNode *)supernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  // TODO: Disabled due to PR: https://github.com/TextureGroup/Texture/pull/1204
  // ASAssertUnlocked(__instanceLock__);
  
  __instanceLock__.lock();

    // Only remove if supernode is still the expected supernode
    if (!ASObjectIsEqual(_supernode, supernode)) {
      __instanceLock__.unlock();
      return;
    }
  
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
  __instanceLock__.unlock();
  
  [self _removeFromSupernode:supernode view:view layer:layer];
}

- (void)_removeFromSupernode:(ASDisplayNode *)supernode view:(UIView *)view layer:(CALayer *)layer
{
  // Note: we continue even if supernode is nil to ensure view/layer are removed from hierarchy.

  if (supernode != nil) {
  }

  // Clear supernode's reference to us before removing the view from the hierarchy, as _ASDisplayView
  // will trigger us to clear our _supernode pointer in willMoveToSuperview:nil.
  // This may result in removing the last strong reference, triggering deallocation after this method.
  [supernode _removeSubnode:self];
  
  if (view != nil) {
    [view removeFromSuperview];
  } else if (layer != nil) {
    [layer removeFromSuperlayer];
  }
}

#pragma mark - Visibility API

- (BOOL)__visibilityNotificationsDisabled
{
  // Currently, this method is only used by the testing infrastructure to verify this internal feature.
  MutexLocker l(__instanceLock__);
  return _flags.visibilityNotificationsDisabled > 0;
}

- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled
{
  MutexLocker l(__instanceLock__);
  return (_hierarchyState & ASHierarchyStateTransitioningSupernodes);
}

- (void)__incrementVisibilityNotificationsDisabled
{
  __instanceLock__.lock();
  const size_t maxVisibilityIncrement = (1ULL<<VISIBILITY_NOTIFICATIONS_DISABLED_BITS) - 1ULL;
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled < maxVisibilityIncrement, @"Oops, too many increments of the visibility notifications API");
  if (_flags.visibilityNotificationsDisabled < maxVisibilityIncrement) {
    _flags.visibilityNotificationsDisabled++;
  }
  BOOL visibilityNotificationsDisabled = (_flags.visibilityNotificationsDisabled == 1);
  __instanceLock__.unlock();

  if (visibilityNotificationsDisabled) {
    // Must have just transitioned from 0 to 1.  Notify all subnodes that we are in a disabled state.
    [self enterHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

- (void)__decrementVisibilityNotificationsDisabled
{
  __instanceLock__.lock();
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled > 0, @"Can't decrement past 0");
  if (_flags.visibilityNotificationsDisabled > 0) {
    _flags.visibilityNotificationsDisabled--;
  }
  BOOL visibilityNotificationsDisabled = (_flags.visibilityNotificationsDisabled == 0);
  __instanceLock__.unlock();

  if (visibilityNotificationsDisabled) {
    // Must have just transitioned from 1 to 0.  Notify all subnodes that we are no longer in a disabled state.
    // FIXME: This system should be revisited when refactoring and consolidating the implementation of the
    // addSubnode: and insertSubnode:... methods.  As implemented, though logically irrelevant for expected use cases,
    // multiple nodes in the subtree below may have a non-zero visibilityNotification count and still have
    // the ASHierarchyState bit cleared (the only value checked when reading this state).
    [self exitHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

#pragma mark - Placeholder

- (void)_locked_layoutPlaceholderIfNecessary
{
  ASAssertLocked(__instanceLock__);
  if ([self _locked_shouldHavePlaceholderLayer]) {
    [self _locked_setupPlaceholderLayerIfNeeded];
  }
  // Update the placeholderLayer size in case the node size has changed since the placeholder was added.
  _placeholderLayer.frame = self.threadSafeBounds;
}

- (BOOL)_locked_shouldHavePlaceholderLayer
{
  ASAssertLocked(__instanceLock__);
  return (_placeholderEnabled && [self _implementsDisplay]);
}

- (void)_locked_setupPlaceholderLayerIfNeeded
{
  ASDisplayNodeAssertMainThread();
  ASAssertLocked(__instanceLock__);

  if (!_placeholderLayer) {
    _placeholderLayer = [CALayer layer];
    // do not set to CGFLOAT_MAX in the case that something needs to be overtop the placeholder
    _placeholderLayer.zPosition = 9999.0;
  }

  if (_placeholderLayer.contents == nil) {
    if (!_placeholderImage) {
      _placeholderImage = [self placeholderImage];
    }
    if (_placeholderImage) {
      BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(_placeholderImage.capInsets, UIEdgeInsetsZero);
      if (stretchable) {
        ASDisplayNodeSetResizableContents(_placeholderLayer, _placeholderImage);
      } else {
        _placeholderLayer.contentsScale = self.contentsScale;
        _placeholderLayer.contents = (id)_placeholderImage.CGImage;
      }
    }
  }
}

- (UIImage *)placeholderImage
{
  // Subclass hook
  return nil;
}

- (BOOL)placeholderShouldPersist
{
  // Subclass hook
  return NO;
}

#pragma mark - Hierarchy State

- (BOOL)isInHierarchy
{
  MutexLocker l(__instanceLock__);
  return _flags.isInHierarchy;
}

- (void)__enterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"Should not cause recursive __enterHierarchy");
  ASDisplayNodeLogEvent(self, @"enterHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  __instanceLock__.lock();
  
  if (!_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isEnteringHierarchy = YES;
    _flags.isInHierarchy = YES;

    // Don't call -willEnterHierarchy while holding __instanceLock__.
    // This method and subsequent ones (i.e -interfaceState and didEnter(.*)State)
    // don't expect that they are called while the lock is being held.
    // More importantly, didEnter(.*)State methods are meant to be overriden by clients.
    // And so they can potentially walk up the node tree and cause deadlocks, or do expensive tasks and cause the lock to be held for too long.
    __instanceLock__.unlock();
      [self willEnterHierarchy];
      for (ASDisplayNode *subnode in self.subnodes) {
        [subnode __enterHierarchy];
      }
    __instanceLock__.lock();
    
    _flags.isEnteringHierarchy = NO;

    // If we don't have contents finished drawing by the time we are on screen, immediately add the placeholder (if it is enabled and we do have something to draw).
    if (self.contents == nil && [self _implementsDisplay]) {
      CALayer *layer = self.layer;
      [layer setNeedsDisplay];
      
      if ([self _locked_shouldHavePlaceholderLayer]) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self _locked_setupPlaceholderLayerIfNeeded];
        _placeholderLayer.opacity = 1.0;
        [CATransaction commit];
        [layer addSublayer:_placeholderLayer];
      }
    }
  }
  
  __instanceLock__.unlock();

  [self didEnterHierarchy];
}

- (void)__exitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"Should not cause recursive __exitHierarchy");
  ASDisplayNodeLogEvent(self, @"exitHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  __instanceLock__.lock();
  
  if (_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isExitingHierarchy = YES;
    _flags.isInHierarchy = NO;

    // Don't call -didExitHierarchy while holding __instanceLock__. 
    // This method and subsequent ones (i.e -interfaceState and didExit(.*)State)
    // don't expect that they are called while the lock is being held.
    // More importantly, didExit(.*)State methods are meant to be overriden by clients.
    // And so they can potentially walk up the node tree and cause deadlocks, or do expensive tasks and cause the lock to be held for too long.
    __instanceLock__.unlock();
      [self didExitHierarchy];
      for (ASDisplayNode *subnode in self.subnodes) {
        [subnode __exitHierarchy];
      }
    __instanceLock__.lock();
    
    _flags.isExitingHierarchy = NO;
  }
  
  __instanceLock__.unlock();
}

- (void)enterHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  
  ASDisplayNodePerformBlockOnEveryNode(nil, self, NO, ^(ASDisplayNode *node) {
    node.hierarchyState |= hierarchyState;
  });
}

- (void)exitHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, NO, ^(ASDisplayNode *node) {
    node.hierarchyState &= (~hierarchyState);
  });
}

- (ASHierarchyState)hierarchyState
{
  MutexLocker l(__instanceLock__);
  return _hierarchyState;
}

- (void)setHierarchyState:(ASHierarchyState)newState
{
  ASHierarchyState oldState = ASHierarchyStateNormal;
  {
    MutexLocker l(__instanceLock__);
    if (_hierarchyState == newState) {
      return;
    }
    oldState = _hierarchyState;
    _hierarchyState = newState;
  }
  
  // Entered rasterization state.
  if (newState & ASHierarchyStateRasterized) {
    ASDisplayNodeAssert(checkFlag(Synchronous) == NO, @"Node created using -initWithViewBlock:/-initWithLayerBlock: cannot be added to subtree of node with subtree rasterization enabled. Node: %@", self);
  }
  
  // Entered or exited range managed state.
  if ((newState & ASHierarchyStateRangeManaged) != (oldState & ASHierarchyStateRangeManaged)) {
    if (newState & ASHierarchyStateRangeManaged) {
      [self enterInterfaceState:self.supernode.pendingInterfaceState];
    } else {
      // The case of exiting a range-managed state should be fairly rare.  Adding or removing the node
      // to a view hierarchy will cause its interfaceState to be either fully set or unset (all fields),
      // but because we might be about to be added to a view hierarchy, exiting the interface state now
      // would cause inefficient churn.  The tradeoff is that we may not clear contents / fetched data
      // for nodes that are removed from a managed state and then retained but not used (bad idea anyway!)
    }
  }
  
  if ((newState & ASHierarchyStateLayoutPending) != (oldState & ASHierarchyStateLayoutPending)) {
    if (newState & ASHierarchyStateLayoutPending) {
      // Entering layout pending state
    } else {
      // Leaving layout pending state, reset related properties
      MutexLocker l(__instanceLock__);
      _pendingTransitionID = ASLayoutElementContextInvalidTransitionID;
      _pendingLayoutTransition = nil;
    }
  }

  ASDisplayNodeLogEvent(self, @"setHierarchyState: %@", NSStringFromASHierarchyStateChange(oldState, newState));
}

- (void)willEnterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isEnteringHierarchy, @"You should never call -willEnterHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASAssertUnlocked(__instanceLock__);
  
  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateInHierarchy;
  } else if (ASCATransactionQueueGet().enabled) {
    __instanceLock__.lock();
    ASInterfaceState state = _preExitingInterfaceState;
    _preExitingInterfaceState = ASInterfaceStateNone;
    __instanceLock__.unlock();
    // Layer thrash happened, revert to before exiting.
    if (state != ASInterfaceStateNone) {
      self.interfaceState = state;
    }
  }
}

- (void)didEnterHierarchy {
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"You should never call -didEnterHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASDisplayNodeAssert(_flags.isInHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASAssertUnlocked(__instanceLock__);
}

- (void)didExitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isExitingHierarchy, @"You should never call -didExitHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASAssertUnlocked(__instanceLock__);

  // This case is important when tearing down hierarchies.  We must deliver a visibileStateDidChange:NO callback, as part our API guarantee that this method can be used for
  // things like data analytics about user content viewing.  We cannot call the method in the dealloc as any incidental retain operations in client code would fail.
  // Additionally, it may be that a Standard UIView which is containing us is moving between hierarchies, and we should not send the call if we will be re-added in the
  // same runloop.  Strategy: strong reference (might be the last!), wait one runloop, and confirm we are still outside the hierarchy (both layer-backed and view-backed).
  // TODO: This approach could be optimized by only performing the dispatch for root elements + recursively apply the interface state change. This would require a closer
  // integration with _ASDisplayLayer to ensure that the superlayer pointer has been cleared by this stage (to check if we are root or not), or a different delegate call.

#if !ENABLE_NEW_EXIT_HIERARCHY_BEHAVIOR
  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateNone;
    return;
  }
#endif
  if (ASInterfaceStateIncludesVisible(self.pendingInterfaceState)) {
    void(^exitVisibleInterfaceState)(void) = ^{
      // This block intentionally retains self.
      __instanceLock__.lock();
      unsigned isStillInHierarchy = _flags.isInHierarchy;
      BOOL isVisible = ASInterfaceStateIncludesVisible(_pendingInterfaceState);
      ASInterfaceState newState = (_pendingInterfaceState & ~ASInterfaceStateVisible);
      // layer may be thrashed, we need to remember the state so we can reset if it enters in same runloop later.
      _preExitingInterfaceState = _pendingInterfaceState;
      __instanceLock__.unlock();
      if (!isStillInHierarchy && isVisible) {
#if ENABLE_NEW_EXIT_HIERARCHY_BEHAVIOR
        if (![self supportsRangeManagedInterfaceState]) {
          newState = ASInterfaceStateNone;
        }
#endif
        self.interfaceState = newState;
      }
    };

    if (!ASCATransactionQueueGet().enabled) {
      dispatch_async(dispatch_get_main_queue(), exitVisibleInterfaceState);
    } else {
      exitVisibleInterfaceState();
    }
  }
}

#pragma mark - Interface State

/**
 * We currently only set interface state on nodes in table/collection views. For other nodes, if they are
 * in the hierarchy we enable all ASInterfaceState types with `ASInterfaceStateInHierarchy`, otherwise `None`.
 */
- (BOOL)supportsRangeManagedInterfaceState
{
  MutexLocker l(__instanceLock__);
  return ASHierarchyStateIncludesRangeManaged(_hierarchyState);
}

- (void)enterInterfaceState:(ASInterfaceState)interfaceState
{
  if (interfaceState == ASInterfaceStateNone) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    node.interfaceState |= interfaceState;
  });
}

- (void)exitInterfaceState:(ASInterfaceState)interfaceState
{
  if (interfaceState == ASInterfaceStateNone) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodeLogEvent(self, @"%s %@", sel_getName(_cmd), NSStringFromASInterfaceState(interfaceState));
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    node.interfaceState &= (~interfaceState);
  });
}

- (void)recursivelySetInterfaceState:(ASInterfaceState)newInterfaceState
{
  // Instead of each node in the recursion assuming it needs to schedule itself for display,
  // setInterfaceState: skips this when handling range-managed nodes (our whole subtree has this set).
  // If our range manager intends for us to be displayed right now, and didn't before, get started!
  BOOL shouldScheduleDisplay = [self supportsRangeManagedInterfaceState] && [self shouldScheduleDisplayWithNewInterfaceState:newInterfaceState];
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    node.interfaceState = newInterfaceState;
  });
  if (shouldScheduleDisplay) {
    [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
  }
}

- (ASInterfaceState)interfaceState
{
  MutexLocker l(__instanceLock__);
  return _interfaceState;
}

- (void)setInterfaceState:(ASInterfaceState)newState
{
  if (!ASCATransactionQueueGet().enabled) {
    [self applyPendingInterfaceState:newState];
  } else {
    MutexLocker l(__instanceLock__);
    if (_pendingInterfaceState != newState) {
      _pendingInterfaceState = newState;
      [ASCATransactionQueueGet() enqueue:self];
    }
  }
}

- (ASInterfaceState)pendingInterfaceState
{
  MutexLocker l(__instanceLock__);
  return _pendingInterfaceState;
}

- (void)applyPendingInterfaceState:(ASInterfaceState)newPendingState
{
  //This method is currently called on the main thread. The assert has been added here because all of the
  //did(Enter|Exit)(Display|Visible|Preload)State methods currently guarantee calling on main.
  ASDisplayNodeAssertMainThread();

  // This method manages __instanceLock__ itself, to ensure the lock is not held while didEnter/Exit(.*)State methods are called, thus avoid potential deadlocks
  ASAssertUnlocked(__instanceLock__);
  
  ASInterfaceState oldState = ASInterfaceStateNone;
  ASInterfaceState newState = ASInterfaceStateNone;
  {
    MutexLocker l(__instanceLock__);
    // newPendingState will not be used when ASCATransactionQueue is enabled
    // and use _pendingInterfaceState instead for interfaceState update.
    if (!ASCATransactionQueueGet().enabled) {
      _pendingInterfaceState = newPendingState;
    }
    oldState = _interfaceState;
    newState = _pendingInterfaceState;
    if (newState == oldState) {
      return;
    }
    _interfaceState = newState;
    _preExitingInterfaceState = ASInterfaceStateNone;
  }

  // It should never be possible for a node to be visible but not be allowed / expected to display.
  ASDisplayNodeAssertFalse(ASInterfaceStateIncludesVisible(newState) && !ASInterfaceStateIncludesDisplay(newState));

  // TODO: Trigger asynchronous measurement if it is not already cached or being calculated.
  // if ((newState & ASInterfaceStateMeasureLayout) != (oldState & ASInterfaceStateMeasureLayout)) {
  // }
  
  // For the Preload and Display ranges, we don't want to call -clear* if not being managed by a range controller.
  // Otherwise we get flashing behavior from normal UIKit manipulations like navigation controller push / pop.
  // Still, the interfaceState should be updated to the current state of the node; just don't act on the transition.
  
  // Entered or exited data loading state.
  BOOL nowPreload = ASInterfaceStateIncludesPreload(newState);
  BOOL wasPreload = ASInterfaceStateIncludesPreload(oldState);
  
  if (nowPreload != wasPreload) {
    if (nowPreload) {
      [self _didEnterPreloadState];
    } else {
      // We don't want to call -didExitPreloadState on nodes that aren't being managed by a range controller.
      // Otherwise we get flashing behavior from normal UIKit manipulations like navigation controller push / pop.
      if ([self supportsRangeManagedInterfaceState]) {
        [self _didExitPreloadState];
      }
    }
  }
  
  // Entered or exited contents rendering state.
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(newState);
  BOOL wasDisplay = ASInterfaceStateIncludesDisplay(oldState);

  if (nowDisplay != wasDisplay) {
    if ([self supportsRangeManagedInterfaceState]) {
      if (nowDisplay) {
        // Once the working window is eliminated (ASRangeHandlerRender), trigger display directly here.
        [self setDisplaySuspended:NO];
      } else {
        [self setDisplaySuspended:YES];
        //schedule clear contents on next runloop
        dispatch_async(dispatch_get_main_queue(), ^{
          __instanceLock__.lock();
          ASInterfaceState interfaceState = _interfaceState;
          __instanceLock__.unlock();
          if (ASInterfaceStateIncludesDisplay(interfaceState) == NO) {
            [self clearContents];
          }
        });
      }
    } else {
      // NOTE: This case isn't currently supported as setInterfaceState: isn't exposed externally, and all
      // internal use cases are range-managed.  When a node is visible, don't mess with display - CA will start it.
      if (!ASInterfaceStateIncludesVisible(newState)) {
        // Check _implementsDisplay purely for efficiency - it's faster even than calling -asyncLayer.
        if ([self _implementsDisplay]) {
          if (nowDisplay) {
            [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
          } else {
            [[self asyncLayer] cancelAsyncDisplay];
            //schedule clear contents on next runloop
            dispatch_async(dispatch_get_main_queue(), ^{
              __instanceLock__.lock();
              ASInterfaceState interfaceState = _interfaceState;
              __instanceLock__.unlock();
              if (ASInterfaceStateIncludesDisplay(interfaceState) == NO) {
                [self clearContents];
              }
            });
          }
        }
      }
    }
    
    if (nowDisplay) {
      [self _didEnterDisplayState];
    } else {
      [self _didExitDisplayState];
    }
  }

  // Became visible or invisible.  When range-managed, this represents literal visibility - at least one pixel
  // is onscreen.  If not range-managed, we can't guarantee more than the node being present in an onscreen window.
  BOOL nowVisible = ASInterfaceStateIncludesVisible(newState);
  BOOL wasVisible = ASInterfaceStateIncludesVisible(oldState);

  if (nowVisible != wasVisible) {
    if (nowVisible) {
      [self _didEnterVisibleState];
    } else {
      [self _didExitVisibleState];
    }
  }

  // Log this change, unless it's just the node going from {} -> {Measure} because that change happens
  // for all cell nodes and it isn't currently meaningful.
  BOOL measureChangeOnly = ((oldState | newState) == ASInterfaceStateMeasureLayout);
  if (!measureChangeOnly) {
  }
  
  ASDisplayNodeLogEvent(self, @"interfaceStateDidChange: %@", NSStringFromASInterfaceStateChange(oldState, newState));
  [self _interfaceStateDidChange:newState fromState:oldState];
}

- (void)prepareForCATransactionCommit
{
  // Apply _pendingInterfaceState actual _interfaceState, note that ASInterfaceStateNone is not used.
  [self applyPendingInterfaceState:ASInterfaceStateNone];
}

- (void)_interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  ASAssertUnlocked(__instanceLock__);
  ASDisplayNodeAssertMainThread();
  [self interfaceStateDidChange:newState fromState:oldState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del interfaceStateDidChange:newState fromState:oldState];
  }];
}

- (BOOL)shouldScheduleDisplayWithNewInterfaceState:(ASInterfaceState)newInterfaceState
{
  BOOL willDisplay = ASInterfaceStateIncludesDisplay(newInterfaceState);
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(self.interfaceState);
  return willDisplay && (willDisplay != nowDisplay);
}

- (void)addInterfaceStateDelegate:(id <ASInterfaceStateDelegate>)interfaceStateDelegate
{
  MutexLocker l(__instanceLock__);
  _hasHadInterfaceStateDelegates = YES;
  for (int i = 0; i < AS_MAX_INTERFACE_STATE_DELEGATES; i++) {
    if (_interfaceStateDelegates[i] == nil) {
      _interfaceStateDelegates[i] = interfaceStateDelegate;
      return;
    }
  }
  ASDisplayNodeFailAssert(@"Exceeded interface state delegate limit: %d", AS_MAX_INTERFACE_STATE_DELEGATES);
}

- (void)removeInterfaceStateDelegate:(id <ASInterfaceStateDelegate>)interfaceStateDelegate
{
  MutexLocker l(__instanceLock__);
  for (int i = 0; i < AS_MAX_INTERFACE_STATE_DELEGATES; i++) {
    if (_interfaceStateDelegates[i] == interfaceStateDelegate) {
      _interfaceStateDelegates[i] = nil;
      break;
    }
  }
}

- (BOOL)isVisible
{
  MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesVisible(_interfaceState);
}

- (void)_didEnterVisibleState
{
  ASDisplayNodeAssertMainThread();
  
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  // Rasterized node's loading state is merged with root node of rasterized tree.
  if (!(self.hierarchyState & ASHierarchyStateRasterized)) {
    ASDisplayNodeAssert(self.isNodeLoaded, @"Node should be loaded before entering visible state.");
  }
#endif
  
  ASAssertUnlocked(__instanceLock__);
  [self didEnterVisibleState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didEnterVisibleState];
  }];
  
#if AS_ENABLE_TIPS
  [ASTipsController.shared nodeDidAppear:self];
#endif
}

- (void)_didExitVisibleState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  [self didExitVisibleState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didExitVisibleState];
  }];
}

- (BOOL)isInDisplayState
{
  MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesDisplay(_interfaceState);
}

- (void)_didEnterDisplayState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  [self didEnterDisplayState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didEnterDisplayState];
  }];
}

- (void)_didExitDisplayState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  [self didExitDisplayState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didExitDisplayState];
  }];
}

- (BOOL)isInPreloadState
{
  MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesPreload(_interfaceState);
}

- (void)setNeedsPreload
{
  if (self.isInPreloadState) {
    [self recursivelyPreload];
  }
}

- (void)recursivelyPreload
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node didEnterPreloadState];
    });
  });
}

- (void)recursivelyClearPreloadedData
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node didExitPreloadState];
    });
  });
}

- (void)_didEnterPreloadState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  [self didEnterPreloadState];
  
  // If this node has ASM enabled and is not yet visible, force a layout pass to apply its applicable pending layout, if any,
  // so that its subnodes are inserted/deleted and start preloading right away.
  //
  // - If it has an up-to-date layout (and subnodes), calling -layoutIfNeeded will be fast.
  //
  // - If it doesn't have a calculated or pending layout that fits its current bounds, a measurement pass will occur
  // (see -__layout and -_u_measureNodeWithBoundsIfNecessary:). This scenario is uncommon,
  // and running a measurement pass here is a fine trade-off because preloading any time after this point would be late.
  
  if (self.automaticallyManagesSubnodes && !ASActivateExperimentalFeature(ASExperimentalDidEnterPreloadSkipASMLayout)) {
    [self layoutIfNeeded];
  }
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didEnterPreloadState];
  }];
}

- (void)_didExitPreloadState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  [self didExitPreloadState];
  [self enumerateInterfaceStateDelegates:^(id<ASInterfaceStateDelegate> del) {
    [del didExitPreloadState];
  }];
}

- (void)clearContents
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);

  MutexLocker l(__instanceLock__);
  if (_flags.canClearContentsOfLayer) {
    // No-op if these haven't been created yet, as that guarantees they don't have contents that needs to be released.
    _layer.contents = nil;
  }
  
  _placeholderLayer.contents = nil;
  _placeholderImage = nil;
}

- (void)recursivelyClearContents
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node clearContents];
    });
  });
}

- (void)enumerateInterfaceStateDelegates:(void (NS_NOESCAPE ^)(id<ASInterfaceStateDelegate>))block
{
  ASAssertUnlocked(__instanceLock__);

  id dels[AS_MAX_INTERFACE_STATE_DELEGATES];
  int count = 0;
  {
    ASLockScopeSelf();
    // Fast path for non-delegating nodes.
    if (!_hasHadInterfaceStateDelegates) {
      return;
    }

    for (int i = 0; i < AS_MAX_INTERFACE_STATE_DELEGATES; i++) {
      if ((dels[count] = _interfaceStateDelegates[i])) {
        count++;
      }
    }
  }
  for (int i = 0; i < count; i++) {
    block(dels[i]);
  }
}

#pragma mark - Gesture Recognizing

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  // This method is only implemented on UIView on iOS 6+.
  ASDisplayNodeAssertMainThread();
  
  // No locking needed as it's main thread only
  UIView *view = _view;
  if (view == nil) {
    return YES;
  }

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = view.superview;
  return [superview gestureRecognizerShouldBegin:gestureRecognizer];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  return [_view hitTest:point withEvent:event];
}

- (void)setHitTestSlop:(UIEdgeInsets)hitTestSlop
{
  MutexLocker l(__instanceLock__);
  _hitTestSlop = hitTestSlop;
}

- (UIEdgeInsets)hitTestSlop
{
  MutexLocker l(__instanceLock__);
  return _hitTestSlop;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  UIEdgeInsets slop = self.hitTestSlop;
  if (_view && UIEdgeInsetsEqualToEdgeInsets(slop, UIEdgeInsetsZero)) {
    // Safer to use UIView's -pointInside:withEvent: if we can.
    return [_view pointInside:point withEvent:event];
  } else {
    return CGRectContainsPoint(UIEdgeInsetsInsetRect(self.bounds, slop), point);
  }
}


#pragma mark - Pending View State

- (void)_locked_applyPendingStateToViewOrLayer
{
  ASDisplayNodeAssertMainThread();
  ASAssertLocked(__instanceLock__);
  ASDisplayNodeAssert(self.nodeLoaded, @"must have a view or layer");

  TIME_SCOPED(_debugTimeToApplyPendingState);
  
  // If no view/layer properties were set before the view/layer were created, _pendingViewState will be nil and the default values
  // for the view/layer are still valid.
  [self _locked_applyPendingViewState];
  
  if (_flags.displaySuspended) {
    self._locked_asyncLayer.displaySuspended = YES;
  }
  if (!_flags.displaysAsynchronously) {
    self._locked_asyncLayer.displaysAsynchronously = NO;
  }
}

- (void)applyPendingViewState
{
  ASDisplayNodeAssertMainThread();
  ASAssertUnlocked(__instanceLock__);
  
  AS::UniqueLock l(__instanceLock__);
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    l.unlock();
    [self __setNeedsLayout];
    l.lock();
  }
  
  [self _locked_applyPendingViewState];
}

- (void)_locked_applyPendingViewState
{
  ASDisplayNodeAssertMainThread();
  ASAssertLocked(__instanceLock__);
  ASDisplayNodeAssert([self _locked_isNodeLoaded], @"Expected node to be loaded before applying pending state.");

  if (_flags.layerBacked) {
    [_pendingViewState applyToLayer:_layer];
  } else {
    BOOL specialPropertiesHandling = ASDisplayNodeNeedsSpecialPropertiesHandling(checkFlag(Synchronous), _flags.layerBacked);
    [_pendingViewState applyToView:_view withSpecialPropertiesHandling:specialPropertiesHandling];
  }

  // _ASPendingState objects can add up very quickly when adding
  // many nodes. This is especially an issue in large collection views
  // and table views. This needs to be weighed against the cost of
  // reallocing a _ASPendingState. So in range managed nodes we
  // delete the pending state, otherwise we just clear it.
  if (ASHierarchyStateIncludesRangeManaged(_hierarchyState)) {
    _pendingViewState = nil;
  } else {
    [_pendingViewState clearChanges];
  }
}

// This method has proved helpful in a few rare scenarios, similar to a category extension on UIView, but assumes knowledge of _ASDisplayView.
// It's considered private API for now and its use should not be encouraged.
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass checkViewHierarchy:(BOOL)checkViewHierarchy
{
  ASDisplayNode *supernode = self.supernode;
  while (supernode) {
    if ([supernode isKindOfClass:supernodeClass])
      return supernode;
    supernode = supernode.supernode;
  }
  if (!checkViewHierarchy) {
    return nil;
  }

  UIView *view = self.view.superview;
  while (view) {
    ASDisplayNode *viewNode = ((_ASDisplayView *)view).asyncdisplaykit_node;
    if (viewNode) {
      if ([viewNode isKindOfClass:supernodeClass])
        return viewNode;
    }

    view = view.superview;
  }

  return nil;
}

#pragma mark - Performance Measurement

- (void)setMeasurementOptions:(ASDisplayNodePerformanceMeasurementOptions)measurementOptions
{
  MutexLocker l(__instanceLock__);
  _measurementOptions = measurementOptions;
}

- (ASDisplayNodePerformanceMeasurementOptions)measurementOptions
{
  MutexLocker l(__instanceLock__);
  return _measurementOptions;
}

- (ASDisplayNodePerformanceMeasurements)performanceMeasurements
{
  MutexLocker l(__instanceLock__);
  ASDisplayNodePerformanceMeasurements measurements = { .layoutSpecNumberOfPasses = -1, .layoutSpecTotalTime = NAN, .layoutComputationNumberOfPasses = -1, .layoutComputationTotalTime = NAN };
  if (_measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec) {
    measurements.layoutSpecNumberOfPasses = _layoutSpecNumberOfPasses;
    measurements.layoutSpecTotalTime = _layoutSpecTotalTime;
  }
  if (_measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutComputation) {
    measurements.layoutComputationNumberOfPasses = _layoutComputationNumberOfPasses;
    measurements.layoutComputationTotalTime = _layoutComputationTotalTime;
  }
  return measurements;
}

#pragma mark - Accessibility

- (void)setIsAccessibilityContainer:(BOOL)isAccessibilityContainer
{
  MutexLocker l(__instanceLock__);
  _isAccessibilityContainer = isAccessibilityContainer;
}

- (BOOL)isAccessibilityContainer
{
  MutexLocker l(__instanceLock__);
  return _isAccessibilityContainer;
}

- (NSString *)defaultAccessibilityLabel
{
  return nil;
}

- (NSString *)defaultAccessibilityHint
{
  return nil;
}

- (NSString *)defaultAccessibilityValue
{
  return nil;
}

- (NSString *)defaultAccessibilityIdentifier
{
  return nil;
}

- (UIAccessibilityTraits)defaultAccessibilityTraits
{
  return UIAccessibilityTraitNone;
}

#pragma mark - Debugging (Private)

#if ASEVENTLOG_ENABLE
- (ASEventLog *)eventLog
{
  return _eventLog;
}
#endif

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  ASPushMainThreadAssertionsDisabled();
  
  NSString *debugName = self.debugName;
  if (debugName.length > 0) {
    [result addObject:@{ (id)kCFNull : ASStringWithQuotesIfMultiword(debugName) }];
  }

  NSString *axId = self.accessibilityIdentifier;
  if (axId.length > 0) {
    [result addObject:@{ (id)kCFNull : ASStringWithQuotesIfMultiword(axId) }];
  }

  ASPopMainThreadAssertionsDisabled();
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  
  if (self.debugName.length > 0) {
    [result addObject:@{ @"debugName" : ASStringWithQuotesIfMultiword(self.debugName)}];
  }
  if (self.accessibilityIdentifier.length > 0) {
    [result addObject:@{ @"axId": ASStringWithQuotesIfMultiword(self.accessibilityIdentifier) }];
  }

  CGRect windowFrame = [self _frameInWindow];
  if (CGRectIsNull(windowFrame) == NO) {
    [result addObject:@{ @"frameInWindow" : [NSValue valueWithCGRect:windowFrame] }];
  }
  
  // Attempt to find view controller.
  // Note that the convenience method asdk_associatedViewController has an assertion
  // that it's run on main. Since this is a debug method, let's bypass the assertion
  // and run up the chain ourselves.
  if (_view != nil) {
    for (UIResponder *responder in [_view asdk_responderChainEnumerator]) {
      UIViewController *vc = ASDynamicCast(responder, UIViewController);
      if (vc) {
        [result addObject:@{ @"viewController" : ASObjectDescriptionMakeTiny(vc) }];
        break;
      }
    }
  }
  
  if (_view != nil) {
    [result addObject:@{ @"alpha" : @(_view.alpha) }];
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_view.frame] }];
  } else if (_layer != nil) {
    [result addObject:@{ @"alpha" : @(_layer.opacity) }];
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_layer.frame] }];
  } else if (_pendingViewState != nil) {
    [result addObject:@{ @"alpha" : @(_pendingViewState.alpha) }];
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_pendingViewState.frame] }];
  }
#ifndef MINIMAL_ASDK
  // Check supernode so that if we are a cell node we don't find self.
  ASCellNode *cellNode = [self supernodeOfClass:[ASCellNode class] includingSelf:NO];
  if (cellNode != nil) {
    [result addObject:@{ @"cellNode" : ASObjectDescriptionMakeTiny(cellNode) }];
  }
#endif
  
  [result addObject:@{ @"interfaceState" : NSStringFromASInterfaceState(self.interfaceState)} ];
  
  if (_view != nil) {
    [result addObject:@{ @"view" : ASObjectDescriptionMakeTiny(_view) }];
  } else if (_layer != nil) {
    [result addObject:@{ @"layer" : ASObjectDescriptionMakeTiny(_layer) }];
  } else if (_viewClass != nil) {
    [result addObject:@{ @"viewClass" : _viewClass }];
  } else if (_layerClass != nil) {
    [result addObject:@{ @"layerClass" : _layerClass }];
  } else if (_viewBlock != nil) {
    [result addObject:@{ @"viewBlock" : _viewBlock }];
  } else if (_layerBlock != nil) {
    [result addObject:@{ @"layerBlock" : _layerBlock }];
  }

#if TIME_DISPLAYNODE_OPS
  NSString *creationTypeString = [NSString stringWithFormat:@"cr8:%.2lfms dl:%.2lfms ap:%.2lfms ad:%.2lfms",  1000 * _debugTimeToCreateView, 1000 * _debugTimeForDidLoad, 1000 * _debugTimeToApplyPendingState, 1000 * _debugTimeToAddSubnodeViews];
  [result addObject:@{ @"creationTypeString" : creationTypeString }];
#endif
  
  return result;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)debugDescription
{
  ASPushMainThreadAssertionsDisabled();
  const auto result = ASObjectDescriptionMake(self, [self propertiesForDebugDescription]);
  ASPopMainThreadAssertionsDisabled();
  return result;
}

// This should only be called for debugging. It's not thread safe and it doesn't assert.
// NOTE: Returns CGRectNull if the node isn't in a hierarchy.
- (CGRect)_frameInWindow
{
  if (self.isNodeLoaded == NO || self.isInHierarchy == NO) {
    return CGRectNull;
  }

  if (self.layerBacked) {
    CALayer *rootLayer = _layer;
    CALayer *nextLayer = nil;
    while ((nextLayer = rootLayer.superlayer) != nil) {
      rootLayer = nextLayer;
    }

    return [_layer convertRect:self.threadSafeBounds toLayer:rootLayer];
  } else {
    return [_view convertRect:self.threadSafeBounds toView:nil];
  }
}

@end

#pragma mark - ASDisplayNode (Debugging)

@implementation ASDisplayNode (Debugging)

+ (void)setShouldStoreUnflattenedLayouts:(BOOL)shouldStore
{
  storesUnflattenedLayouts.store(shouldStore);
}

+ (BOOL)shouldStoreUnflattenedLayouts
{
  return storesUnflattenedLayouts.load();
}

- (ASLayout *)unflattenedCalculatedLayout
{
  MutexLocker l(__instanceLock__);
  return _unflattenedLayout;
}

+ (void)setSuppressesInvalidCollectionUpdateExceptions:(BOOL)suppresses
{
  suppressesInvalidCollectionUpdateExceptions.store(suppresses);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (BOOL)suppressesInvalidCollectionUpdateExceptions
{
  return suppressesInvalidCollectionUpdateExceptions.load();
}
#pragma clang diagnostic pop

- (NSString *)displayNodeRecursiveDescription
{
  return [self _recursiveDescriptionHelperWithIndent:@""];
}

- (NSString *)_recursiveDescriptionHelperWithIndent:(NSString *)indent
{
  NSMutableString *subtree = [[[indent stringByAppendingString:self.debugDescription] stringByAppendingString:@"\n"] mutableCopy];
  for (ASDisplayNode *n in self.subnodes) {
    [subtree appendString:[n _recursiveDescriptionHelperWithIndent:[indent stringByAppendingString:@" | "]]];
  }
  return subtree;
}

- (NSString *)detailedLayoutDescription
{
  ASPushMainThreadAssertionsDisabled();
  MutexLocker l(__instanceLock__);
  const auto props = [[NSMutableArray<NSDictionary *> alloc] init];

  [props addObject:@{ @"layoutVersion": @(_layoutVersion.load()) }];
  [props addObject:@{ @"bounds": [NSValue valueWithCGRect:self.bounds] }];

  if (_calculatedDisplayNodeLayout.layout) {
    [props addObject:@{ @"calculatedLayout": _calculatedDisplayNodeLayout.layout }];
    [props addObject:@{ @"calculatedVersion": @(_calculatedDisplayNodeLayout.version) }];
    [props addObject:@{ @"calculatedConstrainedSize" : NSStringFromASSizeRange(_calculatedDisplayNodeLayout.constrainedSize) }];
    if (_calculatedDisplayNodeLayout.requestedLayoutFromAbove) {
      [props addObject:@{ @"calculatedRequestedLayoutFromAbove": @"YES" }];
    }
  }
  if (_pendingDisplayNodeLayout.layout) {
    [props addObject:@{ @"pendingLayout": _pendingDisplayNodeLayout.layout }];
    [props addObject:@{ @"pendingVersion": @(_pendingDisplayNodeLayout.version) }];
    [props addObject:@{ @"pendingConstrainedSize" : NSStringFromASSizeRange(_pendingDisplayNodeLayout.constrainedSize) }];
    if (_pendingDisplayNodeLayout.requestedLayoutFromAbove) {
      [props addObject:@{ @"pendingRequestedLayoutFromAbove": (id)kCFNull }];
    }
  }

  ASPopMainThreadAssertionsDisabled();
  return ASObjectDescriptionMake(self, props);
}

@end

#pragma mark - ASDisplayNode UIKit / CA Categories

// We use associated objects as a last resort if our view is not a _ASDisplayView ie it doesn't have the _node ivar to write to

static const char *ASDisplayNodeAssociatedNodeKey = "ASAssociatedNode";

@implementation UIView (ASDisplayNodeInternal)

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  ASWeakProxy *weakProxy = [ASWeakProxy weakProxyWithTarget:node];
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, weakProxy, OBJC_ASSOCIATION_RETAIN); // Weak reference to avoid cycle, since the node retains the view.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  ASWeakProxy *weakProxy = objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
  return weakProxy.target;
}

@end

@implementation CALayer (ASDisplayNodeInternal)

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  ASWeakProxy *weakProxy = [ASWeakProxy weakProxyWithTarget:node];
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, weakProxy, OBJC_ASSOCIATION_RETAIN); // Weak reference to avoid cycle, since the node retains the layer.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  ASWeakProxy *weakProxy = objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
  return weakProxy.target;
}

@end

@implementation UIView (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)subnode
{
  if (subnode.layerBacked) {
    // Call -addSubnode: so that we use the asyncdisplaykit_node path if possible.
    [self.layer addSubnode:subnode];
  } else {
    ASDisplayNode *selfNode = self.asyncdisplaykit_node;
    if (selfNode) {
      [selfNode addSubnode:subnode];
    } else {
      if (subnode.supernode) {
        [subnode removeFromSupernode];
      }
      [self addSubview:subnode.view];
    }
  }
}

@end

@implementation CALayer (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNode *selfNode = self.asyncdisplaykit_node;
  if (selfNode) {
    [selfNode addSubnode:subnode];
  } else {
    if (subnode.supernode) {
      [subnode removeFromSupernode];
    }
    [self addSublayer:subnode.layer];
  }
}

@end

#pragma clang diagnostic pop
