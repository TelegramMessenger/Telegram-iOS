//
//  ASCollections.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<__covariant ObjectType> (ASCollections)

/**
 * Create an immutable NSArray from a C-array of strong pointers.
 *
 * Note: The memory for the array you pass in will be zero'd (to prevent ARC from releasing
 * the references when the array goes out of scope.)
 *
 * Can be combined with vector like:
 * vector<NSString *> vec;
 * vec.push_back(@"foo");
 * vec.push_back(@"bar");
 * NSArray *arr = [NSArray arrayTransferring:vec.data() count:vec.size()]
 * ** vec is now { nil, nil } **
 *
 * Unfortunately making a convenience method to do this is currently impossible because
 * vector<NSString *> can't be converted to vector<id> by the compiler (silly).
 *
 * See the private __CFArrayCreateTransfer function.
 */
+ (NSArray<ObjectType> *)arrayByTransferring:(ObjectType _Nonnull __strong * _Nonnull)pointers
                                       count:(NSUInteger)count NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
