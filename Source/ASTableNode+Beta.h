//
//  ASTableNode+Beta.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTableNode.h>

@protocol ASBatchFetchingDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface ASTableNode (Beta)

@property (nonatomic, weak) id<ASBatchFetchingDelegate> batchFetchingDelegate;

@end

NS_ASSUME_NONNULL_END
