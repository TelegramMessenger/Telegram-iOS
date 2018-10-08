//
//  ASMapNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASAvailability.h>

#if TARGET_OS_IOS && AS_USE_MAPKIT
#import <AsyncDisplayKit/ASImageNode.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
  * Map Annotation options. 
  * The default behavior is to ignore the annotations' positions, use the region or options specified instead.
  * Swift: to select the default behavior, use [].
  */
typedef NS_OPTIONS(NSUInteger, ASMapNodeShowAnnotationsOptions)
{
  /** The annotations' positions are ignored, use the region or options specified instead. */
  ASMapNodeShowAnnotationsOptionsIgnored  = 0,
  /** The annotations' positions are used to calculate the region to show in the map, equivalent to showAnnotations:animated. */
  ASMapNodeShowAnnotationsOptionsZoomed   = 1 << 0,
  /** This will only have an effect if combined with the Zoomed state with liveMap turned on.*/
  ASMapNodeShowAnnotationsOptionsAnimated = 1 << 1
};

@interface ASMapNode : ASImageNode

/**
 The current options of ASMapNode. This can be set at any time and ASMapNode will animate the change.<br><br>This property may be set from a background thread before the node is loaded, and will automatically be applied to define the behavior of the static snapshot (if .liveMap = NO) or the internal MKMapView (otherwise).<br><br> Changes to the region and camera options will only be animated when when the liveMap mode is enabled, otherwise these options will be applied statically to the new snapshot. <br><br> The options object is used to specify properties even when the liveMap mode is enabled, allowing seamless transitions between the snapshot and liveMap (as well as back to the snapshot).
 */
@property (nonatomic) MKMapSnapshotOptions *options;

/** The region is simply the sub-field on the options object.  If the objects object is reset,
    this will in effect be overwritten and become the value of the .region property on that object.
    Defaults to MKCoordinateRegionForMapRect(MKMapRectWorld).
 */
@property (nonatomic) MKCoordinateRegion region;

/**
 This is the MKMapView that is the live map part of ASMapNode. This will be nil if .liveMap = NO. Note, MKMapView is *not* thread-safe.
 */
@property (nullable, readonly) MKMapView *mapView;

/**
 Set this to YES to turn the snapshot into an interactive MKMapView and vice versa. Defaults to NO. This property may be set on a background thread before the node is loaded, and will automatically be actioned, once the node is loaded. 
 */
@property (getter=isLiveMap) BOOL liveMap;

/**
 @abstract Whether ASMapNode should automatically request a new map snapshot to correspond to the new node size.
 @default Default value is YES.
 @discussion If mapSize is set then this will be set to NO, since the size will be the same in all orientations.
 */
@property BOOL needsMapReloadOnBoundsChange;

/**
 Set the delegate of the MKMapView. This can be set even before mapView is created and will be set on the map in the case that the liveMap mode is engaged.
 
 If the live map view has been created, this may only be set on the main thread.
 */
@property (nonatomic, weak) id <MKMapViewDelegate> mapDelegate;

/**
 * @abstract The annotations to display on the map.
 */
@property (copy) NSArray<id<MKAnnotation>> *annotations;

/**
 * @abstract This property specifies how to show the annotations.
 * @default Default value is ASMapNodeShowAnnotationsIgnored
 */
@property ASMapNodeShowAnnotationsOptions showAnnotationsOptions;

/**
 * @abstract The block which should return annotation image for static map based on provided annotation.
 * @discussion This block is executed on an arbitrary serial queue. If this block is nil, standard pin is used.
 */
@property (nullable) UIImage * _Nullable (^imageForStaticMapAnnotationBlock)(id<MKAnnotation> annotation, CGPoint *centerOffset);

@end

NS_ASSUME_NONNULL_END

#endif
