//
//  ASSection.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@protocol ASSectionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * An object representing the metadata for a section of elements in a collection.
 *
 * Its sectionID is namespaced to the data controller that created the section.
 *
 * These are useful for tracking the movement & lifetime of sections, independent of
 * their contents.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASSection : NSObject

@property (readonly) NSInteger sectionID;
@property (nullable, readonly) id<ASSectionContext> context;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSectionID:(NSInteger)sectionID context:(nullable id<ASSectionContext>)context NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END

#endif
