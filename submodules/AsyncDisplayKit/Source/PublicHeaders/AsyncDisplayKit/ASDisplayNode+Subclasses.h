//
//  ASDisplayNode+Subclasses.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNode+LayoutSpec.h>

@class ASLayoutSpec, _ASDisplayLayer;

NS_ASSUME_NONNULL_BEGIN

/**
 * The subclass header _ASDisplayNode+Subclasses_ defines the following methods that either must or can be overriden by
 * subclasses of ASDisplayNode.
 *
 * These methods should never be called directly by other classes.
 *
 * ## Drawing
 *
 * Implement one of +displayWithParameters:isCancelled: or +drawRect:withParameters:isCancelled: to provide
 * drawing for your node.
 *
 * Use -drawParametersForAsyncLayer: to copy any properties that are involved in drawing into an immutable object for
 * use on the display queue. The display and drawRect implementations *MUST* be thread-safe, as they can be called on
 * the displayQueue (asynchronously) or the main thread (synchronously/displayImmediately).
 *
 * Class methods that require passing in copies of the values are used to minimize the need for locking around instance
 * variable access, and the possibility of the asynchronous display pass grabbing an inconsistent state across multiple
 * variables.
 */

@interface ASDisplayNode (Subclassing) <ASInterfaceStateDelegate>

#pragma mark - Properties
/** @name Properties */

/**
 * @abstract Return the calculated layout.
 *
 * @discussion For node subclasses that implement manual layout (e.g., they have a custom -layout method), 
 * calculatedLayout may be accessed on subnodes to retrieved cached information about their size.  
 * This allows -layout to be very fast, saving time on the main thread.  
 * Note: .calculatedLayout will only be set for nodes that have had -layoutThatFits: called on them.
 * For manual layout, make sure you call -layoutThatFits: in your implementation of -calculateSizeThatFits:.
 *
 * For node subclasses that use automatic layout (e.g., they implement -layoutSpecThatFits:), 
 * it is typically not necessary to use .calculatedLayout at any point.  For these nodes, 
 * the ASLayoutSpec implementation will automatically call -layoutThatFits: on all of the subnodes,
 * and the ASDisplayNode base class implementation of -layout will automatically make use of .calculatedLayout on the subnodes.
 *
 * @return Layout that wraps calculated size returned by -calculateSizeThatFits: (in manual layout mode),
 * or layout already calculated from layout spec returned by -layoutSpecThatFits: (in automatic layout mode).
 *
 * @warning Subclasses must not override this; it returns the last cached layout and is never expensive.
 */
@property (nullable, readonly) ASLayout *calculatedLayout;

#pragma mark - View Lifecycle
/** @name View Lifecycle */

/**
 * @abstract Called on the main thread immediately after self.view is created.
 *
 * @discussion This is the best time to add gesture recognizers to the view.
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)didLoad ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * An empty method that you can implement in a category to add global
 * node initialization behavior. This method will be called by [ASDisplayNode init].
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)baseDidInit;

/**
 * An empty method that you can implement in a category to add global
 * node deallocation behavior. This method will be called by [ASDisplayNode dealloc].
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)baseWillDealloc;

#pragma mark - Layout
/** @name Layout */

/**
 * @abstract Called on the main thread by the view's -layoutSubviews.
 *
 * @discussion Subclasses override this method to layout all subnodes or subviews.
 */
- (void)layout ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Called on the main thread by the view's -layoutSubviews, after -layout.
 *
 * @discussion Gives a chance for subclasses to perform actions after the subclass and superclass have finished laying
 * out.
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)layoutDidFinish ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Called on a background thread if !isNodeLoaded - called on the main thread if isNodeLoaded.
 *
 * @discussion When the .calculatedLayout property is set to a new ASLayout (directly from -calculateLayoutThatFits: or
 * calculated via use of -layoutSpecThatFits:), subclasses may inspect it here.
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)calculatedLayoutDidChange ASDISPLAYNODE_REQUIRES_SUPER;


#pragma mark - Layout calculation
/** @name Layout calculation */

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion This method is called on a non-main thread. The default implementation calls either -layoutSpecThatFits: 
 * or -calculateSizeThatFits:, whichever method is overriden. Subclasses rarely need to override this method,
 * override -layoutSpecThatFits: or -calculateSizeThatFits: instead.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -layoutThatFits: or -calculatedLayout instead.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 * ASDisplayNode's implementation of -layoutThatFits:parentSize: calls this method to resolve the node's size
 * against parentSize, intersect it with constrainedSize, and call -calculateLayoutThatFits: with the result.
 *
 * In certain advanced cases, you may want to customize this logic. Overriding this method allows you to receive all
 * three parameters and do the computation yourself.
 *
 * @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize;

/**
 * @abstract Return the calculated size.
 *
 * @param constrainedSize The maximum size the receiver should fit in.
 *
 * @discussion Subclasses that override should expect this method to be called on a non-main thread. The returned size
 * is wrapped in an ASLayout and cached for quick access during -layout. Other expensive work that needs to
 * be done before display can be performed here, and using ivars to cache any valuable intermediate results is
 * encouraged.
 *
 * @note Subclasses that override are committed to manual layout. Therefore, -layout: must be overriden to layout all subnodes or subviews.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -layoutThatFits: or layoutThatFits:parentSize: instead.
 */
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize;

/**
 * @abstract Invalidate previously measured and cached layout.
 *
 * @discussion Subclasses should call this method to invalidate the previously measured and cached layout for the display
 * node, when the contents of the node change in such a way as to require measuring it again.
 */
- (void)invalidateCalculatedLayout;

#pragma mark - Observing Node State Changes
/** @name Observing node state changes */

/**
  * Declare <ASInterfaceStateDelegate> methods as requiring super calls (this can't be required in the protocol).
  * For descriptions, see <ASInterfaceStateDelegate> definition.
  */

AS_CATEGORY_IMPLEMENTABLE
- (void)didEnterVisibleState ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)didExitVisibleState  ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)didEnterDisplayState ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)didExitDisplayState  ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)didEnterPreloadState ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)didExitPreloadState  ASDISPLAYNODE_REQUIRES_SUPER;

AS_CATEGORY_IMPLEMENTABLE
- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Called when the node's ASTraitCollection changes
 *
 * @discussion Subclasses can override this method to react to a trait collection change.
 */
AS_CATEGORY_IMPLEMENTABLE
- (void)asyncTraitCollectionDidChange;

#pragma mark - Drawing
/** @name Drawing */

/**
 * @summary Delegate method to draw layer contents into a CGBitmapContext. The current UIGraphics context will be set
 * to an appropriate context.
 *
 * @param bounds Region to draw in.
 * @param parameters An object describing all of the properties you need to draw. Return this from
 * -drawParametersForAsyncLayer:
 * @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid
 * unnecessary work. A return value of YES means cancel drawing and return.
 * @param isRasterizing YES if the layer is being rasterized into another layer, in which case drawRect: probably wants
 * to avoid doing things like filling its bounds with a zero-alpha color to clear the backing store.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
/*+ (void)drawRect:(CGRect)bounds withParameters:(nullable id)parameters
                                   isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock
                                 isRasterizing:(BOOL)isRasterizing;*/

/**
 * @summary Delegate override to provide new layer contents as a UIImage.
 *
 * @param parameters An object describing all of the properties you need to draw. Return this from
 * -drawParametersForAsyncLayer:
 * @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid
 * unnecessary work. A return value of YES means cancel drawing and return.
 *
 * @return A UIImage with contents that are ready to display on the main thread. Make sure that the image is already
 * decoded before returning it here.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
+ (nullable UIImage *)displayWithParameters:(nullable id)parameters
                                isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock;

/**
 * @abstract Delegate override for drawParameters
 *
 * @param layer The layer that will be drawn into.
 *
 * @note Called on the main thread only
 */
- (nullable id<NSObject>)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer;

/**
 * @abstract Indicates that the receiver is about to display.
 *
 * @discussion Deprecated in 2.5.
 *
 * @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) is
 * about to begin.
 *
 * @note Called on the main thread only
 */
- (void)displayWillStart ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED_MSG("Use displayWillStartAsynchronously: instead.");

/**
 * @abstract Indicates that the receiver is about to display.
 *
 * @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) is
 * about to begin.
 *
 * @note Called on the main thread only
 */
- (void)displayWillStartAsynchronously:(BOOL)asynchronously ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver has finished displaying.
 *
 * @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) has
 * completed.
 *
 * @note Called on the main thread only
 */
- (void)displayDidFinish ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Called just before the view is added to a window.
 */
- (void)willEnterHierarchy ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Called after the view is removed from the window.
 */
- (void)didExitHierarchy ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Called just after the view is added to a window.
 * Note: this may be called multiple times during view controller transitions. To overcome this: use didEnterVisibleState or its equavalents.
 */
- (void)didEnterHierarchy ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Whether the view or layer of this display node is currently in a window
 */
@property (readonly, getter=isInHierarchy) BOOL inHierarchy;

/**
 * Provides an opportunity to clear backing store and other memory-intensive intermediates, such as text layout managers
 * on the current node.
 *
 * @discussion Called by -recursivelyClearContents. Always called on main thread. Base class implements self.contents = nil, clearing any backing
 * store, for asynchronous regeneration when needed.
 */
- (void)clearContents ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver is about to display its subnodes. This method is not called if there are no
 * subnodes present.
 *
 * @param subnode The subnode of which display is about to begin.
 *
 * @discussion Subclasses may override this method to be notified when subnode display (asynchronous or synchronous) is
 * about to begin.
 */
- (void)subnodeDisplayWillStart:(ASDisplayNode *)subnode ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver is finished displaying its subnodes. This method is not called if there are
 * no subnodes present.
 *
 * @param subnode The subnode of which display is about to completed.
 *
 * @discussion Subclasses may override this method to be notified when subnode display (asynchronous or synchronous) has
 * completed.
 */
- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Marks the receiver's bounds as needing to be redrawn, with a scale value.
 *
 * @param contentsScale The scale at which the receiver should be drawn.
 *
 * @discussion Subclasses should override this if they don't want their contentsScale changed.
 *
 * @note This changes an internal property.
 * -setNeedsDisplay is also available to trigger display without changing contentsScaleForDisplay.
 * @see -setNeedsDisplay, contentsScaleForDisplay
 */
- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale;

/**
 * @abstract Recursively calls setNeedsDisplayAtScale: on subnodes.
 *
 * @param contentsScale The scale at which the receiver's subnode hierarchy should be drawn.
 *
 * @discussion Subclasses may override this if they require modifying the scale set on their child nodes.
 *
 * @note Only the node tree is walked, not the view or layer trees.
 *
 * @see setNeedsDisplayAtScale:
 * @see contentsScaleForDisplay
 */
- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale;

/**
 * @abstract The scale factor to apply to the rendering.
 *
 * @discussion Use setNeedsDisplayAtScale: to set a value and then after display, the display node will set the layer's
 * contentsScale. This is to prevent jumps when re-rasterizing at a different contentsScale.
 * Read this property if you need to know the future contentsScale of your layer, eg in drawParameters.
 *
 * @see setNeedsDisplayAtScale:
 */
@property (readonly) CGFloat contentsScaleForDisplay;


#pragma mark - Touch handling
/** @name Touch handling */

/**
 * @abstract Tells the node when touches began in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Tells the node when touches moved in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Tells the node when touches ended in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Tells the node when touches was cancelled in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesCancelled:(nullable NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;


#pragma mark - Managing Gesture Recognizers
/** @name Managing Gesture Recognizers */

/**
 * @abstract Asks the node if a gesture recognizer should continue tracking touches.
 *
 * @param gestureRecognizer A gesture recognizer trying to recognize a gesture.
 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;


#pragma mark - Hit Testing

/** @name Hit Testing */

/**
 * @abstract Returns the view that contains the point.
 *
 * @discussion Override to make this node respond differently to touches: (e.g. hide touches from subviews, send all
 * touches to certain subviews (hit area maximizing), etc.)
 *
 * @param point A point specified in the node's local coordinate system (bounds).
 * @param event The event that warranted a call to this method.
 *
 * @return Returns a UIView, not ASDisplayNode, for two reasons:
 * 1) allows sending events to plain UIViews that don't have attached nodes,
 * 2) hitTest: is never called before the views are created.
 */
- (nullable UIView *)hitTest:(CGPoint)point withEvent:(nullable UIEvent *)event;


#pragma mark - Placeholders
/** @name Placeholders */

/**
 * @abstract Optionally provide an image to serve as the placeholder for the backing store while the contents are being
 * displayed.
 *
 * @discussion
 * Subclasses may override this method and return an image to use as the placeholder. Take caution as there may be a
 * time and place where this method is called on a background thread. Note that -[UIImage imageNamed:] is not thread
 * safe when using image assets.
 *
 * To retrieve the CGSize to do any image drawing, use the node's calculatedSize property.
 *
 * Defaults to nil.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
- (nullable UIImage *)placeholderImage;


#pragma mark - Description
/** @name Description */

/**
 * @abstract Return a description of the node
 *
 * @discussion The function that gets called for each display node in -recursiveDescription
 */
- (NSString *)descriptionForRecursiveDescription;

@end


// Check that at most a layoutSpecBlock or one of the three layout methods is overridden
#define __ASDisplayNodeCheckForLayoutMethodOverrides \
    ASDisplayNodeAssert(_layoutSpecBlock != NULL || \
    ((ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateSizeThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(layoutSpecThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateLayoutThatFits:)) ? 1 : 0)) <= 1, \
    @"Subclass %@ must at least provide a layoutSpecBlock or override at most one of the three layout methods: calculateLayoutThatFits:, layoutSpecThatFits:, or calculateSizeThatFits:", NSStringFromClass(self.class))

#define ASDisplayNodeAssertThreadAffinity(viewNode)   ASDisplayNodeAssert(!viewNode || ASMainThreadAssertionsAreDisabled() || ASDisplayNodeThreadIsMain() || !(viewNode).nodeLoaded, @"Incorrect display node thread affinity - this method should not be called off the main thread after the ASDisplayNode's view or layer have been created")
#define ASDisplayNodeCAssertThreadAffinity(viewNode) ASDisplayNodeCAssert(!viewNode || ASMainThreadAssertionsAreDisabled() || ASDisplayNodeThreadIsMain() || !(viewNode).nodeLoaded, @"Incorrect display node thread affinity - this method should not be called off the main thread after the ASDisplayNode's view or layer have been created")

NS_ASSUME_NONNULL_END
