//
//  ASTwoDimensionalArrayUtils.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper functions for two-dimensional array, where the objects of the root array are each arrays.
 */

/**
 * Deep mutable copy of an array that contains arrays, which contain objects.  It will go one level deep into the array to copy.
 * This method is substantially faster than the generalized version, e.g. about 10x faster, so use it whenever it fits the need.
 */
AS_EXTERN NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array) AS_WARN_UNUSED_RESULT;

/**
 * Delete the elements of the mutable two-dimensional array at given index paths – sorted in descending order!
 */
AS_EXTERN void ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray<NSIndexPath *> *indexPaths);

/**
 * Return all the index paths of a two-dimensional array, in ascending order.
 */
AS_EXTERN NSArray<NSIndexPath *> *ASIndexPathsForTwoDimensionalArray(NSArray<NSArray *>* twoDimensionalArray) AS_WARN_UNUSED_RESULT;

/**
 * Return all the elements of a two-dimensional array, in ascending order.
 */
AS_EXTERN NSArray *ASElementsInTwoDimensionalArray(NSArray<NSArray *>* twoDimensionalArray) AS_WARN_UNUSED_RESULT;

/**
 * Attempt to get the object at the given index path. Returns @c nil if the index path is out of bounds.
 */
AS_EXTERN id _Nullable ASGetElementInTwoDimensionalArray(NSArray<NSArray *> *array, NSIndexPath *indexPath) AS_WARN_UNUSED_RESULT;

NS_ASSUME_NONNULL_END
