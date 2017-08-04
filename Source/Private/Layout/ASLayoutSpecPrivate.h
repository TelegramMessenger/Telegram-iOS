//
//  ASLayoutSpecPrivate.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

#if DEBUG
  #define AS_DEDUPE_LAYOUT_SPEC_TREE 1
#else
  #define AS_DEDUPE_LAYOUT_SPEC_TREE 0
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ASLayoutSpec() {
  ASDN::RecursiveMutex __instanceLock__;
  std::atomic <ASPrimitiveTraitCollection> _primitiveTraitCollection;
  ASLayoutElementStyle *_style;
  NSMutableArray *_childrenArray;
}

#if AS_DEDUPE_LAYOUT_SPEC_TREE
/**
 * Recursively search the subtree for elements that occur more than once.
 */
- (nullable NSHashTable<id<ASLayoutElement>> *)findDuplicatedElementsInSubtree;
#endif

@end

NS_ASSUME_NONNULL_END
