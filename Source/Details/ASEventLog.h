//
//  ASEventLog.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#ifndef ASEVENTLOG_CAPACITY
#define ASEVENTLOG_CAPACITY 5
#endif

#ifndef ASEVENTLOG_ENABLE
#define ASEVENTLOG_ENABLE 0
#endif

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASEventLog : NSObject

/**
 * Create a new event log.
 *
 * @param anObject The object whose events we are logging. This object is not retained.
 */
- (instancetype)initWithObject:(id)anObject;

- (void)logEventWithBacktrace:(nullable NSArray<NSString *> *)backtrace format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
