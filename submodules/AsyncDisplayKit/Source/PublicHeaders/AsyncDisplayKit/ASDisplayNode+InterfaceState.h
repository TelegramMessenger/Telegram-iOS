//
//  ASDisplayNode+InterfaceState.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * Interface state is available on ASDisplayNode and ASViewController, and
 * allows checking whether a node is in an interface situation where it is prudent to trigger certain
 * actions: measurement, data loading, display, and visibility (the latter for animations or other onscreen-only effects).
 *
 * The defualt state, ASInterfaceStateNone, means that the element is not predicted to be onscreen soon and
 * preloading should not be performed. Swift: use [] for the default behavior.
 */
typedef NS_OPTIONS(NSUInteger, ASInterfaceState)
{
    /** The element is not predicted to be onscreen soon and preloading should not be performed */
    ASInterfaceStateNone          = 0,
    /** The element may be added to a view soon that could become visible.  Measure the layout, including size calculation. */
    ASInterfaceStateMeasureLayout = 1 << 0,
    /** The element is likely enough to come onscreen that disk and/or network data required for display should be fetched. */
    ASInterfaceStatePreload       = 1 << 1,
    /** The element is very likely to become visible, and concurrent rendering should be executed for any -setNeedsDisplay. */
    ASInterfaceStateDisplay       = 1 << 2,
    /** The element is physically onscreen by at least 1 pixel.
     In practice, all other bit fields should also be set when this flag is set. */
    ASInterfaceStateVisible       = 1 << 3,
    
    /**
     * The node is not contained in a cell but it is in a window.
     *
     * Currently we only set `interfaceState` to other values for
     * nodes contained in table views or collection views.
     */
    ASInterfaceStateInHierarchy   = ASInterfaceStateMeasureLayout | ASInterfaceStatePreload | ASInterfaceStateDisplay | ASInterfaceStateVisible,
};

@protocol ASInterfaceStateDelegate <NSObject>

/**
 * @abstract Called whenever any bit in the ASInterfaceState bitfield is changed.
 * @discussion Subclasses may use this to monitor when they become visible, should free cached data, and much more.
 * @see ASInterfaceState
 */
- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState;

/**
 * @abstract Called whenever the node becomes visible.
 * @discussion Subclasses may use this to monitor when they become visible.
 * @note This method is guaranteed to be called on main.
 */
- (void)didEnterVisibleState;

/**
 * @abstract Called whenever the node is no longer visible.
 * @discussion Subclasses may use this to monitor when they are no longer visible.
 * @note This method is guaranteed to be called on main.
 */
- (void)didExitVisibleState;

/**
 * @abstract Called whenever the the node has entered the display state.
 * @discussion Subclasses may use this to monitor when a node should be rendering its content.
 * @note This method is guaranteed to be called on main.
 */
- (void)didEnterDisplayState;

/**
 * @abstract Called whenever the the node has exited the display state.
 * @discussion Subclasses may use this to monitor when a node should no longer be rendering its content.
 * @note This method is guaranteed to be called on main.
 */
- (void)didExitDisplayState;

/**
 * @abstract Called whenever the the node has entered the preload state.
 * @discussion Subclasses may use this to monitor data for a node should be preloaded, either from a local or remote source.
 * @note This method is guaranteed to be called on main.
 */
- (void)didEnterPreloadState;

/**
 * @abstract Called whenever the the node has exited the preload state.
 * @discussion Subclasses may use this to monitor whether preloading data for a node should be canceled.
 * @note This method is guaranteed to be called on main.
 */
- (void)didExitPreloadState;

/**
 * @abstract Called when the node has completed applying the layout.
 * @discussion Can be used for operations that are performed after layout has completed.
 * @note This method is guaranteed to be called on main.
 */
- (void)nodeDidLayout;

/**
 * @abstract Called when the node loads.
 * @discussion Can be used for operations that are performed after the node's view is available.
 * @note This method is guaranteed to be called on main.
 */
- (void)nodeDidLoad;

/**
 * @abstract Indicates that the receiver and all subnodes have finished displaying.
 * @discussion May be called more than once, for example if the receiver has a network image node.
 * This is called after the first display pass even if network image nodes have not downloaded anything
 * (text would be done, and other nodes that are ready to do their final display). Each render of
 * every progressive jpeg network node would cause this to be called, so this hook could be called up to
 * 1 + (pJPEGcount * pJPEGrenderCount) times. The render count depends on how many times the downloader calls
 * the progressImage block.
 * @note This method is guaranteed to be called on main.
 */
- (void)hierarchyDisplayDidFinish;

@optional
/**
 * @abstract Called when the node is about to calculate layout. This is only called before
 * Yoga-driven layouts.
 * @discussion Can be used for operations that are performed after the node's view is available.
 * @note This method is guaranteed to be called on main, but implementations should be careful not
 * to attempt to ascend the node tree when handling this, as the root node is locked when this is
 * called.
 */
- (void)nodeWillCalculateLayout:(ASSizeRange)constrainedSize;

@end
