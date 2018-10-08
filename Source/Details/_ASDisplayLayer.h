//
//  _ASDisplayLayer.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASBlockTypes.h>

NS_ASSUME_NONNULL_BEGIN

@class ASDisplayNode;
@protocol _ASDisplayLayerDelegate;

@interface _ASDisplayLayer : CALayer

/**
 @discussion This property overrides the CALayer category method which implements this via associated objects.
 This should result in much better performance for _ASDisplayLayers.
 */
@property (nullable, nonatomic, weak) ASDisplayNode *asyncdisplaykit_node;

/**
 @summary Set to YES to enable asynchronous display for the receiver.

 @default YES (note that this might change for subclasses)
 */
@property (nonatomic) BOOL displaysAsynchronously;

/**
 @summary Cancels any pending async display.

 @desc If the receiver has had display called and is waiting for the dispatched async display to be executed, this will
 cancel that dispatched async display.  This method is useful to call when removing the receiver from the window.
 */
- (void)cancelAsyncDisplay;

/**
 @summary The dispatch queue used for async display.

 @desc This is exposed here for tests only.
 */
+ (dispatch_queue_t)displayQueue;

/**
 @summary Delegate for asynchronous display of the layer. This should be the node (default) unless you REALLY know what you're doing.

 @desc The asyncDelegate will have the opportunity to override the methods related to async display.
 */
@property (nullable, weak) id<_ASDisplayLayerDelegate> asyncDelegate;

/**
 @summary Suspends both asynchronous and synchronous display of the receiver if YES.

 @desc This can be used to suspend all display calls while the receiver is still in the view hierarchy.  If you
 want to just cancel pending async display, use cancelAsyncDisplay instead.

 @default NO
 */
@property (nonatomic, getter=isDisplaySuspended) BOOL displaySuspended;

/**
 @summary Bypasses asynchronous rendering and performs a blocking display immediately on the current thread.

 @desc Used by ASDisplayNode to display the layer synchronously on-demand (must be called on the main thread).
 */
- (void)displayImmediately;

@end

/**
 * Optional methods that the view associated with an _ASDisplayLayer can implement. 
 * This is distinguished from _ASDisplayLayerDelegate in that it points to the _view_
 * not the node. Unfortunately this is required by ASCollectionView, since we currently
 * can't guarantee that an ASCollectionNode exists for it.
 */
@protocol ASCALayerExtendedDelegate

@optional

- (void)layer:(CALayer *)layer didChangeBoundsWithOldValue:(CGRect)oldBounds newValue:(CGRect)newBounds;

@end

/**
 Implement one of +displayAsyncLayer:parameters:isCancelled: or +drawRect:withParameters:isCancelled: to provide drawing for your node.
 Use -drawParametersForAsyncLayer: to copy any properties that are involved in drawing into an immutable object for use on the display queue.
 display/drawRect implementations MUST be thread-safe, as they can be called on the displayQueue (async) or the main thread (sync/displayImmediately)
 */
@protocol _ASDisplayLayerDelegate <NSObject>

@optional

// Called on the display queue and/or main queue (MUST BE THREAD SAFE)

/**
 @summary Delegate method to draw layer contents into a CGBitmapContext. The current UIGraphics context will be set to an appropriate context.
 @param parameters An object describing all of the properties you need to draw. Return this from -drawParametersForAsyncLayer:
 @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid unnecessary work. A return value of YES means cancel drawing and return.
 @param isRasterizing YES if the layer is being rasterized into another layer, in which case drawRect: probably wants to avoid doing things like filling its bounds with a zero-alpha color to clear the backing store.
 */
+ (void)drawRect:(CGRect)bounds
  withParameters:(nullable id)parameters
     isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock
   isRasterizing:(BOOL)isRasterizing;

/**
 @summary Delegate override to provide new layer contents as a UIImage.
 @param parameters An object describing all of the properties you need to draw. Return this from -drawParametersForAsyncLayer:
 @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid unnecessary work. A return value of YES means cancel drawing and return.
 @return A UIImage with contents that are ready to display on the main thread. Make sure that the image is already decoded before returning it here.
 */
+ (UIImage *)displayWithParameters:(nullable id<NSObject>)parameters
                       isCancelled:(AS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock;

// Called on the main thread only

/**
 @summary Delegate override for drawParameters
 */
- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer;

/**
 @summary Delegate override for willDisplay
 */
- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer asynchronously:(BOOL)asynchronously;

/**
 @summary Delegate override for didDisplay
 */
- (void)didDisplayAsyncLayer:(_ASDisplayLayer *)layer;

/**
 @summary Delegate callback to display a layer, synchronously or asynchronously.  'asyncLayer' does not necessarily need to exist (can be nil).  Typically, a delegate will display/draw its own contents and then set .contents on the layer when finished.
 */
- (void)displayAsyncLayer:(_ASDisplayLayer *)asyncLayer asynchronously:(BOOL)asynchronously;

/**
 @summary Delegate callback to handle a layer which requests its asynchronous display be cancelled.
 */
- (void)cancelDisplayAsyncLayer:(_ASDisplayLayer *)asyncLayer;

@end

NS_ASSUME_NONNULL_END
