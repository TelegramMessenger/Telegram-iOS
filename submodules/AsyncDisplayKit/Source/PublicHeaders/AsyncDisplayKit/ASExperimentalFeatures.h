//
//  ASExperimentalFeatures.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A bit mask of features. Make sure to update configuration.json when you add entries.
 */
typedef NS_OPTIONS(NSUInteger, ASExperimentalFeatures) {
  ASExperimentalGraphicsContexts = 1 << 0,                  // exp_graphics_contexts
  // If AS_ENABLE_TEXTNODE=0 or TextNode2 subspec is used this setting is a no op and ASTextNode2
  // will be used in all cases
  ASExperimentalTextNode = 1 << 1,                          // exp_text_node
  ASExperimentalInterfaceStateCoalescing = 1 << 2,          // exp_interface_state_coalesce
  ASExperimentalUnfairLock = 1 << 3,                        // exp_unfair_lock
  ASExperimentalLayerDefaults = 1 << 4,                     // exp_infer_layer_defaults
  ASExperimentalCollectionTeardown = 1 << 5,                // exp_collection_teardown
  ASExperimentalFramesetterCache = 1 << 6,                  // exp_framesetter_cache
  ASExperimentalSkipClearData = 1 << 7,                     // exp_skip_clear_data
  ASExperimentalDidEnterPreloadSkipASMLayout = 1 << 8,      // exp_did_enter_preload_skip_asm_layout
  ASExperimentalDisableAccessibilityCache = 1 << 9,         // exp_disable_a11y_cache
  ASExperimentalDispatchApply = 1 << 10,                    // exp_dispatch_apply
  ASExperimentalImageDownloaderPriority = 1 << 11,          // exp_image_downloader_priority
  ASExperimentalTextDrawing = 1 << 12,                      // exp_text_drawing
  ASExperimentalFeatureAll = 0xFFFFFFFF
};

/// Convert flags -> name array.
AS_EXTERN NSArray<NSString *> *ASExperimentalFeaturesGetNames(ASExperimentalFeatures flags);

/// Convert name array -> flags.
AS_EXTERN ASExperimentalFeatures ASExperimentalFeaturesFromArray(NSArray<NSString *> *array);

NS_ASSUME_NONNULL_END
