//
//  ASSectionContext.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <Foundation/Foundation.h>

@class ASCollectionView;

@protocol ASSectionContext

/**
 * Custom name of this section, for debugging only.
 */
@property (nonatomic, copy, nullable) NSString *sectionName;
@property (nonatomic, weak, nullable) ASCollectionView *collectionView;

@end

#endif
