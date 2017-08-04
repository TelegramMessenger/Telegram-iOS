//
//  ASTraceEvent.h
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
#import <AsyncDisplayKit/AsyncDisplayKit.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASTraceEvent : NSObject

/**
 * This method is dealloc safe.
 */
- (instancetype)initWithBacktrace:(nullable NSArray<NSString *> *)backtrace
                           format:(NSString *)format
                        arguments:(va_list)arguments NS_FORMAT_FUNCTION(2,0);

// Will be nil unless AS_SAVE_EVENT_BACKTRACES=1 (default=0)
@property (nonatomic, nullable, readonly) NSArray<NSString *> *backtrace;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, readonly) NSTimeInterval timestamp;

@end

NS_ASSUME_NONNULL_END
