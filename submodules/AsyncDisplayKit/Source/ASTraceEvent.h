//
//  ASTraceEvent.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
@property (nonatomic, readonly) NSString *message;
@property (nonatomic, readonly) NSTimeInterval timestamp;

@end

NS_ASSUME_NONNULL_END
