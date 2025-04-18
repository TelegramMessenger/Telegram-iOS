//
//  ASObjectDescriptionHelpers.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASDebugNameProvider <NSObject>

@required
/**
 * @abstract Name that is printed by ascii art string and displayed in description.
 */
@property (nullable, nonatomic, copy) NSString *debugName;

@end

/**
 * Your base class should conform to this and override `-debugDescription`
 * to call `[self propertiesForDebugDescription]` and use `ASObjectDescriptionMake`
 * to return a string. Subclasses of this base class just need to override
 * `propertiesForDebugDescription`, call super, and modify the result as needed.
 */
@protocol ASDebugDescriptionProvider
@required
- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription;
@end

/**
 * Your base class should conform to this and override `-description`
 * to call `[self propertiesForDescription]` and use `ASObjectDescriptionMake`
 * to return a string. Subclasses of this base class just need to override 
 * `propertiesForDescription`, call super, and modify the result as needed.
 */
@protocol ASDescriptionProvider
@required
- (NSMutableArray<NSDictionary *> *)propertiesForDescription;
@end

AS_EXTERN NSString *ASGetDescriptionValueString(id object);

/// Useful for structs etc. Returns e.g. { position = (0 0); frame = (0 0; 50 50) }
AS_EXTERN NSString *ASObjectDescriptionMakeWithoutObject(NSArray<NSDictionary *> * _Nullable propertyGroups);

/// Returns e.g. <MYObject: 0xFFFFFFFF; name = "Object Name"; frame = (0 0; 50 50)>
AS_EXTERN NSString *ASObjectDescriptionMake(__autoreleasing id object, NSArray<NSDictionary *> * _Nullable propertyGroups);

/**
 * Returns e.g. <MYObject: 0xFFFFFFFF>
 *
 * Note: `object` param is autoreleasing so that this function is dealloc-safe.
 *   No, unsafe_unretained isn't acceptable here – the optimizer may deallocate object early.
 */
AS_EXTERN NSString *ASObjectDescriptionMakeTiny(__autoreleasing id _Nullable object);

AS_EXTERN NSString * _Nullable ASStringWithQuotesIfMultiword(NSString * _Nullable string);

NS_ASSUME_NONNULL_END
