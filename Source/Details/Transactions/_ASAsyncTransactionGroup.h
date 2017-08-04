//
//  _ASAsyncTransactionGroup.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class _ASAsyncTransaction;
@protocol ASAsyncTransactionContainer;

/// A group of transaction containers, for which the current transactions are committed together at the end of the next runloop tick.
@interface _ASAsyncTransactionGroup : NSObject
/// The main transaction group is scheduled to commit on every tick of the main runloop.
+ (_ASAsyncTransactionGroup *)mainTransactionGroup;
+ (void)commit;

/// Add a transaction container to be committed.
/// @see ASAsyncTransactionContainer
- (void)addTransactionContainer:(id<ASAsyncTransactionContainer>)container;
@end

NS_ASSUME_NONNULL_END
