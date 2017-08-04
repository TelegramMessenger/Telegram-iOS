//
//  ASRectTable.h
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
#import <CoreGraphics/CGGeometry.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An alias for an NSMapTable created to store rects.
 *
 * You should not call -objectForKey:, -setObject:forKey:, or -allObjects
 * on these objects.
 */
typedef NSMapTable ASRectTable;

/**
 * A category for creating & using map tables meant for storing CGRects.
 *
 * This category is private, so name collisions are not worth worrying about.
 */
@interface NSMapTable<KeyType, id> (ASRectTableMethods)

/**
 * Creates a new rect table with (NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) for keys.
 */
+ (ASRectTable *)rectTableForStrongObjectPointers;

/**
 * Creates a new rect table with (NSMapTableWeakMemory | NSMapTableObjectPointerPersonality) for keys.
 */
+ (ASRectTable *)rectTableForWeakObjectPointers;

/**
 * Retrieves the rect for a given key, or CGRectNull if the key is not found.
 *
 * @param key An object to lookup the rect for.
 */
- (CGRect)rectForKey:(KeyType)key;

/**
 * Sets the given rect for the associated key.
 *
 * @param rect The rect to store as value.
 * @param key The key to use for the rect.
 */
- (void)setRect:(CGRect)rect forKey:(KeyType)key;

/**
 * Removes the rect for the given key, if one exists.
 *
 * @param key The key to remove.
 */
- (void)removeRectForKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
