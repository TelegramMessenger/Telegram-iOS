//
//  ASDisplayNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASDisplayNode+InterfaceState.h>
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASLocking.h>
#import <AsyncDisplayKit/ASBlockTypes.h>

NS_ASSUME_NONNULL_BEGIN

#define ASDisplayNodeLoggingEnabled 0

#ifndef AS_MAX_INTERFACE_STATE_DELEGATES
#define AS_MAX_INTERFACE_STATE_DELEGATES 4
#endif

@class ASDisplayNode;
@protocol ASContextTransitioning;

/**
 * UIView creation block. Used to create the backing view of a new display node.
 */
typedef UIView * _Nonnull(^ASDisplayNodeViewBlock)(void);

/**
 * UIView creation block. Used to create the backing view of a new display node.
 */
typedef UIViewController * _Nonnull(^ASDisplayNodeViewControllerBlock)(void);

/**
 * CALayer creation block. Used to create the backing layer of a new display node.
 */
typedef CALayer * _Nonnull(^ASDisplayNodeLayerBlock)(void);

/**
 * ASDisplayNode loaded callback block. This block is called BEFORE the -didLoad method and is always called on the main thread.
 */
typedef void (^ASDisplayNodeDidLoadBlock)(__kindof ASDisplayNode * node);

/**
 * ASDisplayNode will / did render node content in context.
 */
typedef void (^ASDisplayNodeContextModifier)(CGContextRef context, id _Nullable drawParameters);

/**
 * ASDisplayNode layout spec block. This block can be used instead of implementing layoutSpecThatFits: in subclass
 */
typedef ASLayoutSpec * _Nonnull(^ASLayoutSpecBlock)(__kindof ASDisplayNode *node, ASSizeRange constrainedSize);

/**
 * AsyncDisplayKit non-fatal error block. This block can be used for handling non-fatal errors. Useful for reporting
 * errors that happens in production.
 */
typedef void (^ASDisplayNodeNonFatalErrorBlock)(NSError *error);

typedef NS_ENUM(NSInteger, ASCornerRoundingType) {
  ASCornerRoundingTypeDefaultSlowCALayer,
  ASCornerRoundingTypePrecomposited,
  ASCornerRoundingTypeClipping
};

/**
 * Default drawing priority for display node
 */
AS_EXTERN NSInteger const ASDefaultDrawingPriority;

/**
 * An `ASDisplayNode` is an abstraction over `UIView` and `CALayer` that allows you to perform calculations about a view
 * hierarchy off the main thread, and could do rendering off the main thread as well.
 *
 * The node API is designed to be as similar as possible to `UIView`. See the README for examples.
 *
 * ## Subclassing
 *
 * `ASDisplayNode` can be subclassed to create a new UI element. The subclass header `ASDisplayNode+Subclasses` provides
 * necessary declarations and conveniences.
 *
 * Commons reasons to subclass includes making a `UIView` property available and receiving a callback after async
 * display.
 *
 */

@interface ASDisplayNode : NSObject <ASLocking> {
@public
  /**
   * The _displayNodeContext ivar is unused by Texture, but provided to enable advanced clients to make powerful extensions to base class functionality.
   * For example, _displayNodeContext can be used to implement category methods on ASDisplayNode that add functionality to all node subclass types.
   * Code demonstrating this technique can be found in the CatDealsCollectionView example.
   */
  void *_displayNodeContext;
}

+ (void)drawRect:(CGRect)bounds withParameters:(nullable id)parameters
     isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock
   isRasterizing:(BOOL)isRasterizing;
+ (nullable UIImage *)displayWithParameters:(nullable id)parameters
                                isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock;

/** @name Initializing a node object */


/**
 * @abstract Designated initializer.
 *
 * @return An ASDisplayNode instance whose view will be a subclass that enables asynchronous rendering, and passes 
 * through -layout and touch handling methods.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;


/**
 * @abstract Alternative initializer with a block to create the backing view.
 *
 * @param viewBlock The block that will be used to create the backing view.
 *
 * @return An ASDisplayNode instance that loads its view with the given block that is guaranteed to run on the main
 * queue. The view will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock;

/**
 * @abstract Alternative initializer with a block to create the backing view.
 *
 * @param viewBlock The block that will be used to create the backing view.
 * @param didLoadBlock The block that will be called after the view created by the viewBlock is loaded
 *
 * @return An ASDisplayNode instance that loads its view with the given block that is guaranteed to run on the main
 * queue. The view will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_DESIGNATED_INITIALIZER;

/**
 * @abstract Alternative initializer with a block to create the backing layer.
 *
 * @param layerBlock The block that will be used to create the backing layer.
 *
 * @return An ASDisplayNode instance that loads its layer with the given block that is guaranteed to run on the main
 * queue. The layer will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock;

/**
 * @abstract Alternative initializer with a block to create the backing layer.
 *
 * @param layerBlock The block that will be used to create the backing layer.
 * @param didLoadBlock The block that will be called after the layer created by the layerBlock is loaded
 *
 * @return An ASDisplayNode instance that loads its layer with the given block that is guaranteed to run on the main
 * queue. The layer will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_DESIGNATED_INITIALIZER;

/**
 * @abstract Add a block of work to be performed on the main thread when the node's view or layer is loaded. Thread safe.
 * @warning Be careful not to retain self in `body`. Change the block parameter list to `^(MYCustomNode *self) {}` if you
 *   want to shadow self (e.g. if calling this during `init`).
 *
 * @param body The work to be performed when the node is loaded.
 *
 * @precondition The node is not already loaded.
 */
- (void)onDidLoad:(ASDisplayNodeDidLoadBlock)body;

/**
 * Set the block that should be used to load this node's view.
 *
 * @param viewBlock The block that creates a view for this node.
 *
 * @precondition The node is not yet loaded.
 *
 * @note You will usually NOT call this. See the limitations documented in @c initWithViewBlock:
 */
- (void)setViewBlock:(ASDisplayNodeViewBlock)viewBlock;

/**
 * Set the block that should be used to load this node's layer.
 *
 * @param layerBlock The block that creates a layer for this node.
 *
 * @precondition The node is not yet loaded.
 *
 * @note You will usually NOT call this. See the limitations documented in @c initWithLayerBlock:
 */
- (void)setLayerBlock:(ASDisplayNodeLayerBlock)layerBlock;

/** 
 * @abstract Returns whether the node is synchronous.
 *
 * @return NO if the node wraps a _ASDisplayView, YES otherwise.
 */
@property (readonly, getter=isSynchronous) BOOL synchronous;

/** @name Getting view and layer */

/** 
 * @abstract Returns a view.
 *
 * @discussion The view property is lazily initialized, similar to UIViewController. 
 * To go the other direction, use ASViewToDisplayNode() in ASDisplayNodeExtras.h.
 *
 * @warning The first access to it must be on the main thread, and should only be used on the main thread thereafter as 
 * well.
 */
@property (readonly) UIView *view;

/** 
 * @abstract Returns whether a node's backing view or layer is loaded.
 *
 * @return YES if a view is loaded, or if layerBacked is YES and layer is not nil; NO otherwise.
 */
@property (readonly, getter=isNodeLoaded) BOOL nodeLoaded;

/** 
 * @abstract Returns whether the node rely on a layer instead of a view.
 *
 * @return YES if the node rely on a layer, NO otherwise.
 */
@property (getter=isLayerBacked) BOOL layerBacked;

/** 
 * @abstract Returns a layer.
 *
 * @discussion The layer property is lazily initialized, similar to the view property.
 * To go the other direction, use ASLayerToDisplayNode() in ASDisplayNodeExtras.h.
 *
 * @warning The first access to it must be on the main thread, and should only be used on the main thread thereafter as 
 * well.
 */
@property (readonly) CALayer * layer;

/**
 * Returns YES if the node is – at least partially – visible in a window.
 *
 * @see didEnterVisibleState and didExitVisibleState
 */
@property (readonly, getter=isVisible) BOOL visible;

/**
 * Returns YES if the node is in the preloading interface state.
 *
 * @see didEnterPreloadState and didExitPreloadState
 */
@property (readonly, getter=isInPreloadState) BOOL inPreloadState;

/**
 * Returns YES if the node is in the displaying interface state.
 *
 * @see didEnterDisplayState and didExitDisplayState
 */
@property (readonly, getter=isInDisplayState) BOOL inDisplayState;

/**
 * @abstract Returns the Interface State of the node.
 *
 * @return The current ASInterfaceState of the node, indicating whether it is visible and other situational properties.
 *
 * @see ASInterfaceState
 */
@property (readonly) ASInterfaceState interfaceState;

/**
 * @abstract Adds a delegate to receive notifications on interfaceState changes.
 *
 * @warning This must be called from the main thread.
 * There is a hard limit on the number of delegates a node can have; see
 * AS_MAX_INTERFACE_STATE_DELEGATES above.
 *
 * @see ASInterfaceState
 */
- (void)addInterfaceStateDelegate:(id <ASInterfaceStateDelegate>)interfaceStateDelegate;

/**
 * @abstract Removes a delegate from receiving notifications on interfaceState changes.
 *
 * @warning This must be called from the main thread.
 *
 * @see ASInterfaceState
 */
- (void)removeInterfaceStateDelegate:(id <ASInterfaceStateDelegate>)interfaceStateDelegate;

/**
 * @abstract Class property that allows to set a block that can be called on non-fatal errors. This
 * property can be useful for cases when Async Display Kit can recover from an abnormal behavior, but
 * still gives the opportunity to use a reporting mechanism to catch occurrences in production. In
 * development, Async Display Kit will assert instead of calling this block.
 *
 * @warning This method is not thread-safe.
 */
@property (class, nonatomic) ASDisplayNodeNonFatalErrorBlock nonFatalErrorBlock;

/** @name Managing the nodes hierarchy */


/** 
 * @abstract Add a node as a subnode to this node.
 *
 * @param subnode The node to be added.
 *
 * @discussion The subnode's view will automatically be added to this node's view, lazily if the views are not created 
 * yet.
 */
- (void)addSubnode:(ASDisplayNode *)subnode;

/** 
 * @abstract Insert a subnode before a given subnode in the list.
 *
 * @param subnode The node to insert below another node.
 * @param below The sibling node that will be above the inserted node.
 *
 * @discussion If the views are loaded, the subnode's view will be inserted below the given node's view in the hierarchy 
 * even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below;

/** 
 * @abstract Insert a subnode after a given subnode in the list.
 *
 * @param subnode The node to insert below another node.
 * @param above The sibling node that will be behind the inserted node.
 *
 * @discussion If the views are loaded, the subnode's view will be inserted above the given node's view in the hierarchy
 * even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above;

/** 
 * @abstract Insert a subnode at a given index in subnodes.
 *
 * @param subnode The node to insert.
 * @param idx The index in the array of the subnodes property at which to insert the node. Subnodes indices start at 0
 * and cannot be greater than the number of subnodes.
 *
 * @discussion If this node's view is loaded, ASDisplayNode insert the subnode's view after the subnode at index - 1's 
 * view even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx;

/** 
 * @abstract Replace subnode with replacementSubnode.
 *
 * @param subnode A subnode of self.
 * @param replacementSubnode A node with which to replace subnode.
 *
 * @discussion Should both subnode and replacementSubnode already be subnodes of self, subnode is removed and 
 * replacementSubnode inserted in its place.
 * If subnode is not a subnode of self, this method will throw an exception.
 * If replacementSubnode is nil, this method will throw an exception
 */
- (void)replaceSubnode:(ASDisplayNode *)subnode withSubnode:(ASDisplayNode *)replacementSubnode;

/** 
 * @abstract Remove this node from its supernode.
 *
 * @discussion The node's view will be automatically removed from the supernode's view.
 */
- (void)removeFromSupernode;

/** 
 * @abstract The receiver's immediate subnodes.
 */
@property (nullable, readonly, copy) NSArray<ASDisplayNode *> *subnodes;

/** 
 * @abstract The receiver's supernode.
 */
@property (nullable, readonly, weak) ASDisplayNode *supernode;


/** @name Drawing and Updating the View */

/** 
 * @abstract Whether this node's view performs asynchronous rendering.
 *
 * @return Defaults to YES, except for synchronous views (ie, those created with -initWithViewBlock: /
 * -initWithLayerBlock:), which are always NO.
 *
 * @discussion If this flag is set, then the node will participate in the current asyncdisplaykit_async_transaction and 
 * do its rendering on the displayQueue instead of the main thread.
 *
 * Asynchronous rendering proceeds as follows:
 *
 * When the view is initially added to the hierarchy, it has -needsDisplay true.
 * After layout, Core Animation will call -display on the _ASDisplayLayer
 * -display enqueues a rendering operation on the displayQueue
 * When the render block executes, it calls the delegate display method (-drawRect:... or -display)
 * The delegate provides contents via this method and an operation is added to the asyncdisplaykit_async_transaction
 * Once all rendering is complete for the current asyncdisplaykit_async_transaction,
 * the completion for the block sets the contents on all of the layers in the same frame
 *
 * If asynchronous rendering is disabled:
 *
 * When the view is initially added to the hierarchy, it has -needsDisplay true.
 * After layout, Core Animation will call -display on the _ASDisplayLayer
 * -display calls  delegate display method (-drawRect:... or -display) immediately
 * -display sets the layer contents immediately with the result
 *
 * Note: this has nothing to do with -[CALayer drawsAsynchronously].
 */
@property BOOL displaysAsynchronously;

/** 
 * @abstract Prevent the node's layer from displaying.
 *
 * @discussion A subclass may check this flag during -display or -drawInContext: to cancel a display that is already in 
 * progress.
 *
 * Defaults to NO. Does not control display for any child or descendant nodes; for that, use 
 * -recursivelySetDisplaySuspended:.
 *
 * If a setNeedsDisplay occurs while displaySuspended is YES, and displaySuspended is set to NO, then the 
 * layer will be automatically displayed.
 */
@property BOOL displaySuspended;

/**
 * @abstract Whether size changes should be animated. Default to YES.
 */
@property BOOL shouldAnimateSizeChanges;

/** 
 * @abstract Prevent the node and its descendants' layer from displaying.
 *
 * @param flag YES if display should be prevented or cancelled; NO otherwise.
 *
 * @see displaySuspended
 */
- (void)recursivelySetDisplaySuspended:(BOOL)flag;

/**
 * @abstract Calls -clearContents on the receiver and its subnode hierarchy.
 *
 * @discussion Clears backing stores and other memory-intensive intermediates.
 * If the node is removed from a visible hierarchy and then re-added, it will automatically trigger a new asynchronous display,
 * as long as displaySuspended is not set.
 * If the node remains in the hierarchy throughout, -setNeedsDisplay is required to trigger a new asynchronous display.
 *
 * @see displaySuspended and setNeedsDisplay
 */
- (void)recursivelyClearContents;

/**
 * @abstract Toggle displaying a placeholder over the node that covers content until the node and all subnodes are
 * displayed.
 *
 * @discussion Defaults to NO.
 */
@property BOOL placeholderEnabled;

/**
 * @abstract Set the time it takes to fade out the placeholder when a node's contents are finished displaying.
 *
 * @discussion Defaults to 0 seconds.
 */
@property NSTimeInterval placeholderFadeDuration;

/**
 * @abstract Determines drawing priority of the node. Nodes with higher priority will be drawn earlier.
 *
 * @discussion Defaults to ASDefaultDrawingPriority. There may be multiple drawing threads, and some of them may
 * decide to perform operations in queued order (regardless of drawingPriority)
 */
@property NSInteger drawingPriority;

/** @name Hit Testing */


/** 
 * @abstract Bounds insets for hit testing.
 *
 * @discussion When set to a non-zero inset, increases the bounds for hit testing to make it easier to tap or perform 
 * gestures on this node.  Default is UIEdgeInsetsZero.
 *
 * This affects the default implementation of -hitTest and -pointInside, so subclasses should call super if you override 
 * it and want hitTestSlop applied.
 */
@property UIEdgeInsets hitTestSlop;

/** 
 * @abstract Returns a Boolean value indicating whether the receiver contains the specified point.
 *
 * @discussion Includes the "slop" factor specified with hitTestSlop.
 *
 * @param point A point that is in the receiver's local coordinate system (bounds).
 * @param event The event that warranted a call to this method.
 *
 * @return YES if point is inside the receiver's bounds; otherwise, NO.
 */
- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event AS_WARN_UNUSED_RESULT;


/** @name Converting Between View Coordinate Systems */


/** 
 * @abstract Converts a point from the receiver's coordinate system to that of the specified node.
 *
 * @param point A point specified in the local coordinate system (bounds) of the receiver.
 * @param node The node into whose coordinate system point is to be converted.
 *
 * @return The point converted to the coordinate system of node.
 */
- (CGPoint)convertPoint:(CGPoint)point toNode:(nullable ASDisplayNode *)node AS_WARN_UNUSED_RESULT;


/** 
 * @abstract Converts a point from the coordinate system of a given node to that of the receiver.
 *
 * @param point A point specified in the local coordinate system (bounds) of node.
 * @param node The node with point in its coordinate system.
 *
 * @return The point converted to the local coordinate system (bounds) of the receiver.
 */
- (CGPoint)convertPoint:(CGPoint)point fromNode:(nullable ASDisplayNode *)node AS_WARN_UNUSED_RESULT;


/** 
 * @abstract Converts a rectangle from the receiver's coordinate system to that of another view.
 *
 * @param rect A rectangle specified in the local coordinate system (bounds) of the receiver.
 * @param node The node that is the target of the conversion operation.
 *
 * @return The converted rectangle.
 */
- (CGRect)convertRect:(CGRect)rect toNode:(nullable ASDisplayNode *)node AS_WARN_UNUSED_RESULT;

/** 
 * @abstract Converts a rectangle from the coordinate system of another node to that of the receiver.
 *
 * @param rect A rectangle specified in the local coordinate system (bounds) of node.
 * @param node The node with rect in its coordinate system.
 *
 * @return The converted rectangle.
 */
- (CGRect)convertRect:(CGRect)rect fromNode:(nullable ASDisplayNode *)node AS_WARN_UNUSED_RESULT;

/**
 * Whether or not the node would support having .layerBacked = YES.
 */
@property (readonly) BOOL supportsLayerBacking;

/**
 * Whether or not the node layout should be automatically updated when it receives safeAreaInsetsDidChange.
 *
 * Defaults to NO.
 */
@property BOOL automaticallyRelayoutOnSafeAreaChanges;

/**
 * Whether or not the node layout should be automatically updated when it receives layoutMarginsDidChange.
 *
 * Defaults to NO.
 */
@property BOOL automaticallyRelayoutOnLayoutMarginsChanges;

@end

/**
 * Convenience methods for debugging.
 */
@interface ASDisplayNode (Debugging) <ASDebugNameProvider>

/**
 * Whether or not ASDisplayNode instances should store their unflattened layouts.
 *
 * The layout can be accessed via `-unflattenedCalculatedLayout`.
 *
 * Flattened layouts use less memory and are faster to lookup. On the other hand, unflattened layouts are useful for debugging
 * because they preserve original information.
 *
 * Defaults to NO.
 */
@property (class) BOOL shouldStoreUnflattenedLayouts;

@property (nullable, readonly) ASLayout *unflattenedCalculatedLayout;

/**
 * @abstract Return a description of the node hierarchy.
 *
 * @discussion For debugging: (lldb) po [node displayNodeRecursiveDescription]
 */
- (NSString *)displayNodeRecursiveDescription AS_WARN_UNUSED_RESULT;

/**
 * A detailed description of this node's layout state. This is useful when debugging.
 */
@property (copy, readonly) NSString *detailedLayoutDescription;

@end

/**
 * ## UIView bridge
 *
 * ASDisplayNode provides thread-safe access to most of UIView and CALayer properties and methods, traditionally unsafe.
 *
 * Using them will not cause the actual view/layer to be created, and will be applied when it is created (when the view 
 * or layer property is accessed).
 *
 * - NOTE: After the view or layer is created, the properties pass through to the view or layer directly and must be called on the main thread.
 *
 * See UIView and CALayer for documentation on these common properties.
 */
@interface ASDisplayNode (UIViewBridge)

/**
 * Marks the view as needing display. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 */
- (void)setNeedsDisplay;

/**
 * Marks the node as needing layout. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 *
 * If the node determines its own desired layout size will change in the next layout pass, it will propagate this
 * information up the tree so its parents can have a chance to consider and apply if necessary the new size onto the node.
 *
 * Note: ASCellNode has special behavior in that calling this method will automatically notify
 * the containing ASTableView / ASCollectionView that the cell should be resized, if necessary.
 */
- (void)setNeedsLayout;

/**
 * Performs a layout pass on the node. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 */
- (void)layoutIfNeeded;

@property           CGRect frame;                             // default=CGRectZero
@property           CGRect bounds;                            // default=CGRectZero
@property           CGPoint position;                         // default=CGPointZero
@property           CGFloat alpha;                            // default=1.0f

/* @abstract Sets the corner rounding method to use on the ASDisplayNode.
 * There are three types of corner rounding provided by Texture: CALayer, Precomposited, and Clipping.
 *
 * - ASCornerRoundingTypeDefaultSlowCALayer: uses CALayer's inefficient .cornerRadius property. Use
 * this type of corner in situations in which there is both movement through and movement underneath
 * the corner (very rare). This uses only .cornerRadius.
 *
 * - ASCornerRoundingTypePrecomposited: corners are drawn using bezier paths to clip the content in a
 * CGContext / UIGraphicsContext. This requires .backgroundColor and .cornerRadius to be set. Use opaque
 * background colors when possible for optimal efficiency, but transparent colors are supported and much
 * more efficient than CALayer. The only limitation of this approach is that it cannot clip children, and
 * thus works best for ASImageNodes or containers showing a background around their children.
 *
 * - ASCornerRoundingTypeClipping: overlays 4 separate opaque corners on top of the content that needs
 * corner rounding. Requires .backgroundColor and .cornerRadius to be set. Use clip corners in situations 
 * in which is movement through the corner, with an opaque background (no movement underneath the corner).
 * Clipped corners are ideal for animating / resizing views, and still outperform CALayer.
 *
 * For more information and examples, see http://texturegroup.org/docs/corner-rounding.html
 *
 * @default ASCornerRoundingTypeDefaultSlowCALayer
 */
@property           ASCornerRoundingType cornerRoundingType;  // default=ASCornerRoundingTypeDefaultSlowCALayer .cornerRadius (offscreen rendering)

/** @abstract The radius to use when rounding corners of the ASDisplayNode.
 *
 * @discussion This property is thread-safe and should always be preferred over CALayer's cornerRadius property,
 * even if corner rounding type is ASCornerRoundingTypeDefaultSlowCALayer.
 */
@property           CGFloat cornerRadius;                     // default=0.0

@property           BOOL clipsToBounds;                       // default==NO
@property (getter=isHidden)  BOOL hidden;                     // default==NO
@property (getter=isOpaque)  BOOL opaque;                     // default==YES

@property (nullable) id contents;                             // default=nil
@property           CGRect contentsRect;                      // default={0,0,1,1}. @see CALayer.h for details.
@property           CGRect contentsCenter;                    // default={0,0,1,1}. @see CALayer.h for details.
@property           CGFloat contentsScale;                    // default=1.0f. See @contentsScaleForDisplay for details.
@property           CGFloat rasterizationScale;               // default=1.0f.

@property           CGPoint anchorPoint;                      // default={0.5, 0.5}
@property           CGFloat zPosition;                        // default=0.0
@property           CATransform3D transform;                  // default=CATransform3DIdentity
@property           CATransform3D subnodeTransform;           // default=CATransform3DIdentity

@property (getter=isUserInteractionEnabled) BOOL userInteractionEnabled; // default=YES (NO for layer-backed nodes)
#if TARGET_OS_IOS
@property (getter=isExclusiveTouch) BOOL exclusiveTouch;      // default=NO
#endif

/**
 * @abstract The node view's background color.
 *
 * @discussion In contrast to UIView, setting a transparent color will not set opaque = NO.
 * This only affects nodes that implement +drawRect like ASTextNode.
*/
@property (nullable, copy) UIColor *backgroundColor;           // default=nil

@property (null_resettable, copy) UIColor *tintColor;          // default=Blue
- (void)tintColorDidChange;                                    // Notifies the node when the tintColor has changed.

/**
 * @abstract A flag used to determine how a node lays out its content when its bounds change.
 *
 * @discussion This is like UIView's contentMode property, but better. We do our own mapping to layer.contentsGravity in 
 * _ASDisplayView. You can set needsDisplayOnBoundsChange independently. 
 * Thus, UIViewContentModeRedraw is not allowed; use needsDisplayOnBoundsChange = YES instead, and pick an appropriate 
 * contentMode for your content while it's being re-rendered.
 */
@property            UIViewContentMode contentMode;         // default=UIViewContentModeScaleToFill
@property (copy)     NSString *contentsGravity;             // Use .contentMode in preference when possible.
@property            UISemanticContentAttribute semanticContentAttribute;

@property (nullable) CGColorRef shadowColor;                // default=opaque rgb black
@property            CGFloat shadowOpacity;                 // default=0.0
@property            CGSize shadowOffset;                   // default=(0, -3)
@property            CGFloat shadowRadius;                  // default=3
@property            CGFloat borderWidth;                   // default=0
@property (nullable) CGColorRef borderColor;                // default=opaque rgb black

@property            BOOL allowsGroupOpacity;
@property            BOOL allowsEdgeAntialiasing;
@property            unsigned int edgeAntialiasingMask;     // default==all values from CAEdgeAntialiasingMask

@property            BOOL needsDisplayOnBoundsChange;       // default==NO
@property            BOOL autoresizesSubviews;              // default==YES (undefined for layer-backed nodes)
@property            UIViewAutoresizing autoresizingMask;   // default==UIViewAutoresizingNone (undefined for layer-backed nodes)

/**
 * @abstract Content margins
 *
 * @discussion This property is bridged to its UIView counterpart.
 *
 * If your layout depends on this property, you should probably enable automaticallyRelayoutOnLayoutMarginsChanges to ensure
 * that the layout gets automatically updated when the value of this property changes. Or you can override layoutMarginsDidChange
 * and make all the necessary updates manually.
 */
@property           UIEdgeInsets layoutMargins;
@property           BOOL preservesSuperviewLayoutMargins;  // default is NO - set to enable pass-through or cascading behavior of margins from this view’s parent to its children
- (void)layoutMarginsDidChange;

/**
 * @abstract Safe area insets
 *
 * @discussion This property is bridged to its UIVIew counterpart.
 *
 * If your layout depends on this property, you should probably enable automaticallyRelayoutOnSafeAreaChanges to ensure
 * that the layout gets automatically updated when the value of this property changes. Or you can override safeAreaInsetsDidChange
 * and make all the necessary updates manually.
 */
@property (readonly)         UIEdgeInsets safeAreaInsets;
@property           BOOL insetsLayoutMarginsFromSafeArea;  // Default: YES
- (void)safeAreaInsetsDidChange;


// UIResponder methods
// By default these fall through to the underlying view, but can be overridden.
- (BOOL)canBecomeFirstResponder;                                            // default==NO
- (BOOL)becomeFirstResponder;                                               // default==NO (no-op)
- (BOOL)canResignFirstResponder;                                            // default==YES
- (BOOL)resignFirstResponder;                                               // default==NO (no-op)
- (BOOL)isFirstResponder;
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender;

#if TARGET_OS_TV
//Focus Engine
- (void)setNeedsFocusUpdate;
- (BOOL)canBecomeFocused;
- (void)updateFocusIfNeeded;
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator;
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context;
- (nullable UIView *)preferredFocusedView;
#endif

@end

@interface ASDisplayNode (UIViewBridgeAccessibility)

// Accessibility support
@property           BOOL isAccessibilityElement;
@property (nullable, copy)   NSString *accessibilityLabel;
@property (nullable, copy)   NSAttributedString *accessibilityAttributedLabel API_AVAILABLE(ios(11.0),tvos(11.0));
@property (nullable, copy)   NSString *accessibilityHint;
@property (nullable, copy)   NSAttributedString *accessibilityAttributedHint API_AVAILABLE(ios(11.0),tvos(11.0));
@property (nullable, copy)   NSString *accessibilityValue;
@property (nullable, copy)   NSAttributedString *accessibilityAttributedValue API_AVAILABLE(ios(11.0),tvos(11.0));
@property           UIAccessibilityTraits accessibilityTraits;
@property           CGRect accessibilityFrame;
@property (nullable, copy)   UIBezierPath *accessibilityPath;
@property           CGPoint accessibilityActivationPoint;
@property (nullable, copy)   NSString *accessibilityLanguage;
@property           BOOL accessibilityElementsHidden;
@property           BOOL accessibilityViewIsModal;
@property           BOOL shouldGroupAccessibilityChildren;
@property           UIAccessibilityNavigationStyle accessibilityNavigationStyle;
#if TARGET_OS_TV
@property (nullable, copy) 	NSArray *accessibilityHeaderElements;
#endif

// Accessibility identification support
@property (nullable, copy)   NSString *accessibilityIdentifier;

@end

@interface ASDisplayNode (ASLayoutElement) <ASLayoutElement>

/**
 * @abstract Asks the node to return a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @warning Subclasses must not override this; it caches results from -calculateLayoutThatFits:.  Calling this method may
 * be expensive if result is not cached.
 *
 * @see [ASDisplayNode(Subclassing) calculateLayoutThatFits:]
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize;
- (CGSize)measure:(CGSize)constrainedSize;

@end

@interface ASDisplayNode (ASLayoutElementStylability) <ASLayoutElementStylability>

@end

typedef NS_ENUM(NSInteger, ASLayoutEngineType) {
  ASLayoutEngineTypeLayoutSpec,
  ASLayoutEngineTypeYoga
};

@interface ASDisplayNode (ASLayout)

/**
 * @abstract Returns the current layout type the node uses for layout the subtree.
 */
@property (readonly) ASLayoutEngineType layoutEngineType;

/**
 * @abstract Return the calculated size.
 *
 * @discussion Ideal for use by subclasses in -layout, having already prompted their subnodes to calculate their size by
 * calling -layoutThatFits: on them in -calculateLayoutThatFits.
 *
 * @return Size already calculated by -calculateLayoutThatFits:.
 *
 * @warning Subclasses must not override this; it returns the last cached measurement and is never expensive.
 */
@property (readonly) CGSize calculatedSize;

/** 
 * @abstract Return the constrained size range used for calculating layout.
 *
 * @return The minimum and maximum constrained sizes used by calculateLayoutThatFits:.
 */
@property (readonly) ASSizeRange constrainedSizeForCalculatedLayout;

@end

@interface ASDisplayNode (ASLayoutTransitioning)

/**
 * @abstract The amount of time it takes to complete the default transition animation. Default is 0.2.
 */
@property NSTimeInterval defaultLayoutTransitionDuration;

/**
 * @abstract The amount of time (measured in seconds) to wait before beginning the default transition animation.
 *           Default is 0.0.
 */
@property NSTimeInterval defaultLayoutTransitionDelay;

/**
 * @abstract A mask of options indicating how you want to perform the default transition animations.
 *           For a list of valid constants, see UIViewAnimationOptions.
 */
@property UIViewAnimationOptions defaultLayoutTransitionOptions;

/**
 * @discussion A place to perform your animation. New nodes have been inserted here. You can also use this time to re-order the hierarchy.
 */
- (void)animateLayoutTransition:(nonnull id<ASContextTransitioning>)context;

/**
 * @discussion A place to clean up your nodes after the transition
 */
- (void)didCompleteLayoutTransition:(nonnull id<ASContextTransitioning>)context;

/**
 * @abstract Transitions the current layout with a new constrained size. Must be called on main thread.
 *
 * @param animated Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 * @param shouldMeasureAsync Measure the layout asynchronously.
 * @param completion Optional completion block called only if a new layout is calculated.
 * It is called on main, right after the measurement and before -animateLayoutTransition:.
 *
 * @discussion If the passed constrainedSize is the the same as the node's current constrained size, this method is noop. If passed YES to shouldMeasureAsync it's guaranteed that measurement is happening on a background thread, otherwise measaurement will happen on the thread that the method was called on. The measurementCompletion callback is always called on the main thread right after the measurement and before -animateLayoutTransition:.
 *
 * @see animateLayoutTransition:
 *
 */
- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(nullable void(^)(void))completion;


/**
 * @abstract Invalidates the layout and begins a relayout of the node with the current `constrainedSize`. Must be called on main thread.
 *
 * @discussion It is called right after the measurement and before -animateLayoutTransition:.
 *
 * @param animated Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 * @param shouldMeasureAsync Measure the layout asynchronously.
 * @param completion Optional completion block called only if a new layout is calculated.
 *
 * @see animateLayoutTransition:
 *
 */
- (void)transitionLayoutWithAnimation:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(nullable void(^)(void))completion;

/**
 * @abstract Cancels all performing layout transitions. Can be called on any thread.
 */
- (void)cancelLayoutTransition;

@end

/*
 * ASDisplayNode support for automatic subnode management.
 */
@interface ASDisplayNode (ASAutomaticSubnodeManagement)

/**
 * @abstract A boolean that shows whether the node automatically inserts and removes nodes based on the presence or
 * absence of the node and its subnodes is completely determined in its layoutSpecThatFits: method.
 *
 * @discussion If flag is YES the node no longer require addSubnode: or removeFromSupernode method calls. The presence
 * or absence of subnodes is completely determined in its layoutSpecThatFits: method.
 */
@property BOOL automaticallyManagesSubnodes;

@end

/*
 * ASDisplayNode participates in ASAsyncTransactions, so you can determine when your subnodes are done rendering.
 * See: -(void)asyncdisplaykit_asyncTransactionContainerStateDidChange in ASDisplayNodeSubclass.h
 */
@interface ASDisplayNode (ASAsyncTransactionContainer) <ASAsyncTransactionContainer>
@end

/** UIVIew(AsyncDisplayKit) defines convenience method for adding sub-ASDisplayNode to an UIView. */
@interface UIView (AsyncDisplayKit)
/**
 * Convenience method, equivalent to [view addSubview:node.view] or [view.layer addSublayer:node.layer] if layer-backed.
 *
 * @param node The node to be added.
 */
- (void)addSubnode:(ASDisplayNode *)node;
@end

/*
 * CALayer(AsyncDisplayKit) defines convenience method for adding sub-ASDisplayNode to a CALayer.
 */
@interface CALayer (AsyncDisplayKit)
/**
 * Convenience method, equivalent to [layer addSublayer:node.layer].
 *
 * @param node The node to be added.
 */
- (void)addSubnode:(ASDisplayNode *)node;

@end

#define ASScopedLockSelfOrToRoot() ASLockScopeSelf()

@interface UIView (ASDisplayNodeInternal)
@property (nullable, weak) ASDisplayNode *asyncdisplaykit_node;
@end

@interface CALayer (ASDisplayNodeInternal)
@property (nullable, weak) ASDisplayNode *asyncdisplaykit_node;
@end

NS_ASSUME_NONNULL_END
