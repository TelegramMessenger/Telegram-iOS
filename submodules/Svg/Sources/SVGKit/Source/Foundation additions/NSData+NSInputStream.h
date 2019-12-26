//
//  NSData+NSInputStream.h
//  Tidbits
//
//  Created by Ewan Mellor on 6/16/13.
//  Copyright (c) 2013 Tipbit, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NSInputStream)

/**
 * @param capacity May be NSUIntegerMax, in which case just an ordinary [NSMutableData data] is used.  Otherwise this is given to NSMutableData dataWithCapacity:].
 * @param error May be nil.
 * @return The data or nil on failure in which case *error will be set.
 */
+(NSData*)dataWithContentsOfStream:(NSInputStream*)input initialCapacity:(NSUInteger)capacity error:(NSError **)error;

@end
