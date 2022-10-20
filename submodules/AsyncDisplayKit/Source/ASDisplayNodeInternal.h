//
//  ASDisplayNodeInternal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#import <atomic>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#import "ASLayoutTransition.h"
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/_ASTransitionContext.h>
#import <AsyncDisplayKit/ASWeakSet.h>

NS_ASSUME_NONNULL_BEGIN

@protocol _ASDisplayLayerDelegate;
@class _ASDisplayLayer;
@class _ASPendingState;
@class ASNodeController;
struct ASDisplayNodeFlags;

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector);
BOOL ASDisplayNodeNeedsSpecialPropertiesHandling(BOOL isSynchronous, BOOL isLayerBacked);

/// Get the pending view state for the node, creating one if needed.
_ASPendingState * ASDisplayNodeGetPendingState(ASDisplayNode * node);

typedef NS_OPTIONS(NSUInteger, ASDisplayNodeMethodOverrides)
{
  ASDisplayNodeMethodOverrideNone                   = 0,
  ASDisplayNodeMethodOverrideTouchesBegan           = 1 << 0,
  ASDisplayNodeMethodOverrideTouchesCancelled       = 1 << 1,
  ASDisplayNodeMethodOverrideTouchesEnded           = 1 << 2,
  ASDisplayNodeMethodOverrideTouchesMoved           = 1 << 3,
  ASDisplayNodeMethodOverrideLayoutSpecThatFits     = 1 << 4,
  ASDisplayNodeMethodOverrideCalcLayoutThatFits     = 1 << 5,
  ASDisplayNodeMethodOverrideCalcSizeThatFits       = 1 << 6,
  ASDisplayNodeMethodOverrideCanBecomeFirstResponder= 1 << 7,
  ASDisplayNodeMethodOverrideBecomeFirstResponder   = 1 << 8,
  ASDisplayNodeMethodOverrideCanResignFirstResponder= 1 << 9,
  ASDisplayNodeMethodOverrideResignFirstResponder   = 1 << 10,
  ASDisplayNodeMethodOverrideIsFirstResponder       = 1 << 11,
};

typedef NS_OPTIONS(uint_least32_t, ASDisplayNodeAtomicFlags)
{
  Synchronous = 1 << 0,
  YogaLayoutInProgress = 1 << 1,
};

// Can be called without the node's lock. Client is responsible for thread safety.
#define _loaded(node) (node->_layer != nil)

#define checkFlag(flag) ((_atomicFlags.load() & flag) != 0)
// Returns the old value of the flag as a BOOL.
#define setFlag(flag, x) (((x ? _atomicFlags.fetch_or(flag) \
                              : _atomicFlags.fetch_and(~flag)) & flag) != 0)

AS_EXTERN NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification;
AS_EXTERN NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp;

// Allow 2^n increments of begin disabling hierarchy notifications
#define VISIBILITY_NOTIFICATIONS_DISABLED_BITS 4

#define TIME_DISPLAYNODE_OPS 0 // If you're using this information frequently, try: (DEBUG || PROFILE)

#define NUM_CLIP_CORNER_LAYERS 4

@interface ASDisplayNode () <_ASTransitionContextCompletionDelegate>
{
@package
  AS::RecursiveMutex __instanceLock__;

  _ASPendingState *_pendingViewState;
  ASInterfaceState _pendingInterfaceState;
  ASInterfaceState _preExitingInterfaceState;
  
  UIView *_view;
  CALayer *_layer;

  std::atomic<ASDisplayNodeAtomicFlags> _atomicFlags;

  struct ASDisplayNodeFlags {
    // public properties
    unsigned viewEverHadAGestureRecognizerAttached:1;
    unsigned layerBacked:1;
    unsigned displaysAsynchronously:1;
    unsigned rasterizesSubtree:1;
    unsigned shouldBypassEnsureDisplay:1;
    unsigned displaySuspended:1;
    unsigned shouldAnimateSizeChanges:1;
    
    // Wrapped view handling
    
    // The layer contents should not be cleared in case the node is wrapping a UIImageView.UIImageView is specifically
    // optimized for performance and does not use the usual way to provide the contents of the CALayer via the
    // CALayerDelegate method that backs the UIImageView.
    unsigned canClearContentsOfLayer:1;
    
    // Prevent calling setNeedsDisplay on a layer that backs a UIImageView. Usually calling setNeedsDisplay on a CALayer
    // triggers a recreation of the contents of layer unfortunately calling it on a CALayer that backs a UIImageView
    // it goes through the normal flow to assign the contents to a layer via the CALayerDelegate methods. Unfortunately
    // UIImageView does not do recreate the layer contents the usual way, it actually does not implement some of the
    // methods at all instead it throws away the contents of the layer and nothing will show up.
    unsigned canCallSetNeedsDisplayOfLayer:1;

    unsigned implementsDrawRect:1;
    unsigned implementsImageDisplay:1;
    unsigned implementsDrawParameters:1;

    // internal state
    unsigned isEnteringHierarchy:1;
    unsigned isExitingHierarchy:1;
    unsigned isInHierarchy:1;
    unsigned visibilityNotificationsDisabled:VISIBILITY_NOTIFICATIONS_DISABLED_BITS;
    unsigned isDeallocating:1;
  } _flags;
  
@protected
  ASDisplayNode * __weak _supernode;
  NSMutableArray<ASDisplayNode *> *_subnodes;

  ASNodeController *_strongNodeController;
  __weak ASNodeController *_weakNodeController;

  // Set this to nil whenever you modify _subnodes
  NSArray<ASDisplayNode *> *_cachedSubnodes;

  std::atomic_uint _displaySentinel;

  // This is the desired contentsScale, not the scale at which the layer's contents should be displayed
  CGFloat _contentsScaleForDisplay;
  ASDisplayNodeMethodOverrides _methodOverrides;

  UIEdgeInsets _hitTestSlop;
  
#if ASEVENTLOG_ENABLE
  ASEventLog *_eventLog;
#endif


  // Layout support
  ASLayoutElementStyle *_style;
  std::atomic<ASPrimitiveTraitCollection> _primitiveTraitCollection;

  // Layout Spec
  ASLayoutSpecBlock _layoutSpecBlock;
  NSString *_debugName;

#if YOGA
  // Only ASDisplayNodes are supported in _yogaChildren currently. This means that it is necessary to
  // create ASDisplayNodes to make a stack layout when using Yoga.
  // However, the implementation is mostly ready for id <ASLayoutElement>, with a few areas requiring updates.
  NSMutableArray<ASDisplayNode *> *_yogaChildren;
  __weak ASDisplayNode *_yogaParent;
  ASLayout *_yogaCalculatedLayout;
#endif

  // Automatically manages subnodes
  BOOL _automaticallyManagesSubnodes; // Main thread only

  // Layout Transition
  _ASTransitionContext *_pendingLayoutTransitionContext;
  NSTimeInterval _defaultLayoutTransitionDuration;
  NSTimeInterval _defaultLayoutTransitionDelay;
  UIViewAnimationOptions _defaultLayoutTransitionOptions;

  std::atomic<int32_t> _transitionID;
  std::atomic<int32_t> _pendingTransitionID;
  ASLayoutTransition *_pendingLayoutTransition;
  ASDisplayNodeLayout _calculatedDisplayNodeLayout;
  ASDisplayNodeLayout _pendingDisplayNodeLayout;
  
  /// Sentinel for layout data. Incremented when we get -setNeedsLayout / -invalidateCalculatedLayout.
  /// Starts at 1.
  std::atomic<NSUInteger> _layoutVersion;


  // Layout Spec performance measurement
  ASDisplayNodePerformanceMeasurementOptions _measurementOptions;
  NSTimeInterval _layoutSpecTotalTime;
  NSInteger _layoutSpecNumberOfPasses;
  NSTimeInterval _layoutComputationTotalTime;
  NSInteger _layoutComputationNumberOfPasses;


  // View Loading
  ASDisplayNodeViewBlock _viewBlock;
  ASDisplayNodeLayerBlock _layerBlock;
  NSMutableArray<ASDisplayNodeDidLoadBlock> *_onDidLoadBlocks;
  Class _viewClass; // nil -> _ASDisplayView
  Class _layerClass; // nil -> _ASDisplayLayer


  // Placeholder support
  UIImage *_placeholderImage;
  BOOL _placeholderEnabled;
  CALayer *_placeholderLayer;

  // keeps track of nodes/subnodes that have not finished display, used with placeholders
  ASWeakSet *_pendingDisplayNodes;


  // Corner Radius support
  CGFloat _cornerRadius;
  ASCornerRoundingType _cornerRoundingType;
  CALayer *_clipCornerLayers[NUM_CLIP_CORNER_LAYERS];

  ASDisplayNodeContextModifier _willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier _didDisplayNodeContentWithRenderingContext;


  // Accessibility support
  BOOL _isAccessibilityElement;
  NSString *_accessibilityLabel;
  NSAttributedString *_accessibilityAttributedLabel;
  NSString *_accessibilityHint;
  NSAttributedString *_accessibilityAttributedHint;
  NSString *_accessibilityValue;
  NSAttributedString *_accessibilityAttributedValue;
  UIAccessibilityTraits _accessibilityTraits;
  CGRect _accessibilityFrame;
  NSString *_accessibilityLanguage;
  BOOL _accessibilityElementsHidden;
  BOOL _accessibilityViewIsModal;
  BOOL _shouldGroupAccessibilityChildren;
  NSString *_accessibilityIdentifier;
  UIAccessibilityNavigationStyle _accessibilityNavigationStyle;
  NSArray *_accessibilityHeaderElements;
  CGPoint _accessibilityActivationPoint;
  UIBezierPath *_accessibilityPath;
  BOOL _isAccessibilityContainer;


  // Safe Area support
  // These properties are used on iOS 10 and lower, where safe area is not supported by UIKit.
  UIEdgeInsets _fallbackSafeAreaInsets;
  BOOL _fallbackInsetsLayoutMarginsFromSafeArea;

  BOOL _automaticallyRelayoutOnSafeAreaChanges;
  BOOL _automaticallyRelayoutOnLayoutMarginsChanges;

  BOOL _isViewControllerRoot;


#pragma mark - ASDisplayNode (Debugging)
  ASLayout *_unflattenedLayout;

#if TIME_DISPLAYNODE_OPS
@public
  NSTimeInterval _debugTimeToCreateView;
  NSTimeInterval _debugTimeToApplyPendingState;
  NSTimeInterval _debugTimeToAddSubnodeViews;
  NSTimeInterval _debugTimeForDidLoad;
#endif

  /// Fast path: tells whether we've ever had an interface state delegate before.
  BOOL _hasHadInterfaceStateDelegates;
  __weak id<ASInterfaceStateDelegate> _interfaceStateDelegates[AS_MAX_INTERFACE_STATE_DELEGATES];
}

+ (void)scheduleNodeForRecursiveDisplay:(ASDisplayNode *)node;

/// The _ASDisplayLayer backing the node, if any.
@property (nullable, nonatomic, readonly) _ASDisplayLayer *asyncLayer;

/// Bitmask to check which methods an object overrides.
- (ASDisplayNodeMethodOverrides)methodOverrides;

/**
 * Invoked before a call to setNeedsLayout to the underlying view
 */
- (void)__setNeedsLayout;

/**
 * Invoked after a call to setNeedsDisplay to the underlying view
 */
- (void)__setNeedsDisplay;

/**
 * Called whenever the node needs to layout its subnodes and, if it's already loaded, its subviews. Executes the layout pass for the node
 *
 * This method is thread-safe but asserts thread affinity.
 */
- (void)__layout;

/**
 * Internal method to add / replace / insert subnode and remove from supernode without checking if
 * node has automaticallyManagesSubnodes set to YES.
 */
- (void)_addSubnode:(ASDisplayNode *)subnode;
- (void)_replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode;
- (void)_insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below;
- (void)_insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above;
- (void)_insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx;
- (void)_removeFromSupernodeIfEqualTo:(ASDisplayNode *)supernode;
- (void)_removeFromSupernode;

// Private API for helper functions / unit tests.  Use ASDisplayNodeDisableHierarchyNotifications() to control this.
- (BOOL)__visibilityNotificationsDisabled;
- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled;
- (void)__incrementVisibilityNotificationsDisabled;
- (void)__decrementVisibilityNotificationsDisabled;

// Helper methods for UIResponder forwarding
- (BOOL)__canBecomeFirstResponder;
- (BOOL)__becomeFirstResponder;
- (BOOL)__canResignFirstResponder;
- (BOOL)__resignFirstResponder;
- (BOOL)__isFirstResponder;

/// Helper method to summarize whether or not the node run through the display process
- (BOOL)_implementsDisplay;

/// Display the node's view/layer immediately on the current thread, bypassing the background thread rendering. Will be deprecated.
- (void)displayImmediately;

/// Refreshes any precomposited or drawn clip corners, setting up state as required to transition radius or rounding type.
- (void)updateCornerRoundingWithType:(ASCornerRoundingType)newRoundingType cornerRadius:(CGFloat)newCornerRadius;

/// Alternative initialiser for backing with a custom view class.  Supports asynchronous display with _ASDisplayView subclasses.
- (instancetype)initWithViewClass:(Class)viewClass;

/// Alternative initialiser for backing with a custom layer class.  Supports asynchronous display with _ASDisplayLayer subclasses.
- (instancetype)initWithLayerClass:(Class)layerClass;

@property (nonatomic) CGFloat contentsScaleForDisplay;

- (void)applyPendingViewState;

/**
 * Makes a local copy of the interface state delegates then calls the block on each.
 *
 * Lock is not held during block invocation. Method must not be called with the lock held.
 */
- (void)enumerateInterfaceStateDelegates:(void(NS_NOESCAPE ^)(id<ASInterfaceStateDelegate> delegate))block;

/**
 * // TODO: NOT YET IMPLEMENTED
 *
 * @abstract Prevents interface state changes from affecting the node, until disabled.
 *
 * @discussion Useful to avoid flashing after removing a node from the hierarchy and re-adding it.
 * Removing a node from the hierarchy will cause it to exit the Display state, clearing its contents.
 * For some animations, it's desirable to be able to remove a node without causing it to re-display.
 * Once re-enabled, the interface state will be updated to the same value it would have been.
 *
 * @see ASInterfaceState
 */
@property (nonatomic) BOOL interfaceStateSuspended;

/**
 * This method has proven helpful in a few rare scenarios, similar to a category extension on UIView,
 * but it's considered private API for now and its use should not be encouraged.
 * @param checkViewHierarchy If YES, and no supernode can be found, method will walk up from `self.view` to find a supernode.
 * If YES, this method must be called on the main thread and the node must not be layer-backed.
 */
- (nullable ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass checkViewHierarchy:(BOOL)checkViewHierarchy;

/**
 * Whether this node rasterizes its descendants. See -enableSubtreeRasterization.
 */
@property (readonly) BOOL rasterizesSubtree;

/**
 * Called if a gesture recognizer was attached to an _ASDisplayView
 */
- (void)nodeViewDidAddGestureRecognizer;

// Recalculates fallbackSafeAreaInsets for the subnodes
- (void)_fallbackUpdateSafeAreaOnChildren;

@end

@interface ASDisplayNode (InternalPropertyBridge)

@property (nonatomic) CGFloat layerCornerRadius;

- (BOOL)_locked_insetsLayoutMarginsFromSafeArea;

@end

@interface ASDisplayNode (ASLayoutElementPrivate)

/**
 * Returns the internal style object or creates a new if no exists. Need to be called with lock held.
 */
- (ASLayoutElementStyle *)_locked_style;

/**
 * Returns the current layout element. Need to be called with lock held.
 */
- (id<ASLayoutElement>)_locked_layoutElementThatFits:(ASSizeRange)constrainedSize;

@end

NS_ASSUME_NONNULL_END
