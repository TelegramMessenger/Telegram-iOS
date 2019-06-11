//
//  ASCollectionLayoutState+Private.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASPageTable.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionLayoutState (Private)

/**
 * Remove and returns layout attributes for unmeasured elements that intersect the specified rect
 *
 * @discussion This method is atomic and thread-safe
 */
- (nullable ASPageToLayoutAttributesTable *)getAndRemoveUnmeasuredLayoutAttributesPageTableInRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END

#endif
