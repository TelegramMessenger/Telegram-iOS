//
//  ASIntegerMap.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An objective-C wrapper for unordered_map.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASIntegerMap : NSObject <NSCopying>

/**
 * Creates a map based on the specified update to an array.
 *
 * If oldCount is 0, returns the empty map.
 * If deleted and inserted are empty, returns the identity map.
 */
+ (ASIntegerMap *)mapForUpdateWithOldCount:(NSInteger)oldCount
                                   deleted:(nullable NSIndexSet *)deleted
                                  inserted:(nullable NSIndexSet *)inserted NS_RETURNS_RETAINED;

/**
 * A singleton that maps each integer to itself. Its inverse is itself.
 *
 * Note: You cannot mutate this.
 */
@property (class, readonly) ASIntegerMap *identityMap;
+ (ASIntegerMap *)identityMap NS_RETURNS_RETAINED;

/**
 * A singleton that returns NSNotFound for all keys. Its inverse is itself.
 *
 * Note: You cannot mutate this.
 */
@property (class, readonly) ASIntegerMap *emptyMap;
+ (ASIntegerMap *)emptyMap NS_RETURNS_RETAINED;

/**
 * Retrieves the integer for a given key, or NSNotFound if the key is not found.
 *
 * @param key A key to lookup the value for.
 */
- (NSInteger)integerForKey:(NSInteger)key;

/**
 * Sets the value for a given key.
 *
 * @param value The new value.
 * @param key The key to store the value for.
 */
- (void)setInteger:(NSInteger)value forKey:(NSInteger)key;

/**
 * Create and return a map with the inverse mapping.
 */
- (ASIntegerMap *)inverseMap;

@end

NS_ASSUME_NONNULL_END
