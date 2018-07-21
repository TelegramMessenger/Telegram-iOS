//
//  ASExperimentalFeatures.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASExperimentalFeatures.h>

NSArray<NSString *> *ASExperimentalFeaturesGetNames(ASExperimentalFeatures flags)
{
  NSArray *allNames = ASCreateOnce((@[@"exp_graphics_contexts",
                                      @"exp_text_node",
                                      @"exp_interface_state_coalesce",
                                      @"exp_unfair_lock",
                                      @"exp_infer_layer_defaults",
                                      @"exp_network_image_queue",
                                      @"exp_dealloc_queue_v2"]));
  
  if (flags == ASExperimentalFeatureAll) {
    return allNames;
  }
  
  // Go through all names, testing each bit.
  NSUInteger i = 0;
  return ASArrayByFlatMapping(allNames, NSString *name, ({
    (flags & (1 << i++)) ? name : nil;
  }));
}

// O(N^2) but with counts this small, it's probably faster
// than hashing the strings.
ASExperimentalFeatures ASExperimentalFeaturesFromArray(NSArray<NSString *> *array)
{
  NSArray *allNames = ASExperimentalFeaturesGetNames(ASExperimentalFeatureAll);
  ASExperimentalFeatures result = 0;
  for (NSString *str in array) {
    NSUInteger i = [allNames indexOfObject:str];
    if (i != NSNotFound) {
      result |= (1 << i);
    }
  }
  return result;
}
