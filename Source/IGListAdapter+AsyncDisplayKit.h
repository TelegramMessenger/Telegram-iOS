//
//  IGListAdapter+AsyncDisplayKit.h
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

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_IG_LIST_KIT

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionNode;

@interface IGListAdapter (AsyncDisplayKit)

/**
 * Connect this list adapter to the given collection node.
 *
 * @param collectionNode The collection node to drive with this list adapter.
 *
 * @note This method may only be called once per list adapter, 
 *   and it must be called on the main thread. -[UIViewController init]
 *   is a good place to call it. This method does not retain the collection node.
 */
- (void)setASDKCollectionNode:(ASCollectionNode *)collectionNode;

@end

NS_ASSUME_NONNULL_END

#endif // AS_IG_LIST_KIT
