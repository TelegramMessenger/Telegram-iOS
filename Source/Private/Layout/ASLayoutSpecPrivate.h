//
//  ASLayoutSpecPrivate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
