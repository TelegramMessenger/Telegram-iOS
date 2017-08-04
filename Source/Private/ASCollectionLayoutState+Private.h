//
//  ASCollectionLayoutState+Private.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
- (nullable ASPageToLayoutAttributesTable *)getAndRemoveUnmeasuredLayoutAttributesPageTableInRect:(CGRect)rect
                                                                                      contentSize:(CGSize)contentSize
                                                                                         pageSize:(CGSize)pageSize;

@end

NS_ASSUME_NONNULL_END

#endif
