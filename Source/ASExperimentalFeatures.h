//
//  ASExperimentalFeatures.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A bit mask of features. Make sure to update configuration.json when you add entries.
 */
typedef NS_OPTIONS(NSUInteger, ASExperimentalFeatures) {
  ASExperimentalGraphicsContexts = 1 << 0,                  // exp_graphics_contexts
#if AS_ENABLE_TEXTNODE
  ASExperimentalTextNode = 1 << 1,                          // exp_text_node
#endif
  ASExperimentalInterfaceStateCoalescing = 1 << 2,          // exp_interface_state_coalesce
  ASExperimentalUnfairLock = 1 << 3,                        // exp_unfair_lock
  ASExperimentalLayerDefaults = 1 << 4,                     // exp_infer_layer_defaults
  ASExperimentalNetworkImageQueue = 1 << 5,                 // exp_network_image_queue
  ASExperimentalCollectionTeardown = 1 << 6,                // exp_collection_teardown
  ASExperimentalFramesetterCache = 1 << 7,                  // exp_framesetter_cache
  ASExperimentalSkipClearData = 1 << 8,                     // exp_skip_clear_data
  ASExperimentalDidEnterPreloadSkipASMLayout = 1 << 9,      // exp_did_enter_preload_skip_asm_layout
  ASExperimentalDisableAccessibilityCache = 1 << 10,        // exp_disable_a11y_cache
  ASExperimentalSkipAccessibilityWait = 1 << 11,            // exp_skip_a11y_wait
  ASExperimentalNewDefaultCellLayoutMode = 1 << 12,         // exp_new_default_cell_layout_mode
  ASExperimentalFeatureAll = 0xFFFFFFFF
};

/// Convert flags -> name array.
AS_EXTERN NSArray<NSString *> *ASExperimentalFeaturesGetNames(ASExperimentalFeatures flags);

/// Convert name array -> flags.
AS_EXTERN ASExperimentalFeatures ASExperimentalFeaturesFromArray(NSArray<NSString *> *array);

NS_ASSUME_NONNULL_END
