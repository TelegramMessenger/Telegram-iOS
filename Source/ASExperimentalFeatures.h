//
//  ASExperimentalFeatures.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A bit mask of features. Make sure to update configuration.json when you add entries.
 */
typedef NS_OPTIONS(NSUInteger, ASExperimentalFeatures) {
  ASExperimentalGraphicsContexts = 1 << 0,                  // exp_graphics_contexts
  ASExperimentalTextNode = 1 << 1,                          // exp_text_node
  ASExperimentalInterfaceStateCoalescing = 1 << 2,          // exp_interface_state_coalesce
  ASExperimentalUnfairLock = 1 << 3,                        // exp_unfair_lock
  ASExperimentalLayerDefaults = 1 << 4,                     // exp_infer_layer_defaults
  ASExperimentalNetworkImageQueue = 1 << 5,                 // exp_network_image_queue
  ASExperimentalCollectionTeardown = 1 << 6,                // exp_collection_teardown
  ASExperimentalFramesetterCache = 1 << 7,                  // exp_framesetter_cache
  ASExperimentalClearDataDuringDeallocation = 1 << 8,       // exp_clear_data_during_deallocation
  ASExperimentalFeatureAll = 0xFFFFFFFF
};

/// Convert flags -> name array.
AS_EXTERN NSArray<NSString *> *ASExperimentalFeaturesGetNames(ASExperimentalFeatures flags);

/// Convert name array -> flags.
AS_EXTERN ASExperimentalFeatures ASExperimentalFeaturesFromArray(NSArray<NSString *> *array);

NS_ASSUME_NONNULL_END
