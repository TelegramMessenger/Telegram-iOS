//
//  ASTraitCollection.h
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


#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASTraitCollection;
@protocol ASLayoutElement;
@protocol ASTraitEnvironment;

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

#pragma mark - ASPrimitiveContentSizeCategory

/**
 * ASPrimitiveContentSizeCategory is a UIContentSizeCategory that can be used inside a struct.
 *
 * We need an unretained pointer because ARC can't manage struct memory.
 *
 * WARNING: DO NOT cast UIContentSizeCategory values to ASPrimitiveContentSizeCategory directly.
 *   Use ASPrimitiveContentSizeCategoryMake(UIContentSizeCategory) instead.
 *   This is because we make some assumptions about the lifetime of the object it points to.
 *   Also note that cast from ASPrimitiveContentSizeCategory to UIContentSizeCategory is always safe.
 */
typedef __unsafe_unretained UIContentSizeCategory ASPrimitiveContentSizeCategory;

/**
 * Safely casts from UIContentSizeCategory to ASPrimitiveContentSizeCategory.
 *
 * The UIKit documentation doesn't specify if we can receive a copy of the UIContentSizeCategory constant. While getting
 * copies is fine with ARC, usage of unretained pointers requires us to ensure the lifetime of the object it points to.
 * Manual retain&release of the UIContentSizeCategory object is not an option because it would require us to do that
 * everywhere ASPrimitiveTraitCollection is used. This is error-prone and can lead to crashes and memory leaks. So, we
 * explicitly limit possible values of ASPrimitiveContentSizeCategory to the predetermined set of global constants with
 * known lifetime.
 *
 * @return a pointer to one of the UIContentSizeCategory constants.
 */
extern ASPrimitiveContentSizeCategory ASPrimitiveContentSizeCategoryMake(UIContentSizeCategory sizeCategory);

#pragma mark - ASPrimitiveTraitCollection

typedef struct ASPrimitiveTraitCollection {
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceSizeClass verticalSizeClass;

  CGFloat displayScale;
  UIDisplayGamut displayGamut;

  UIUserInterfaceIdiom userInterfaceIdiom;
  UIForceTouchCapability forceTouchCapability;
  UITraitEnvironmentLayoutDirection layoutDirection;
#if TARGET_OS_TV
  UIUserInterfaceStyle userInterfaceStyle;
#endif

  ASPrimitiveContentSizeCategory preferredContentSizeCategory;

  CGSize containerSize;
} ASPrimitiveTraitCollection;

/**
 * Creates ASPrimitiveTraitCollection with default values.
 */
extern ASPrimitiveTraitCollection ASPrimitiveTraitCollectionMakeDefault(void);

/**
 * Creates a ASPrimitiveTraitCollection from a given UITraitCollection.
 */
extern ASPrimitiveTraitCollection ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection);


/**
 * Compares two ASPrimitiveTraitCollection to determine if they are the same.
 */
extern BOOL ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(ASPrimitiveTraitCollection lhs, ASPrimitiveTraitCollection rhs);

/**
 * Returns a string representation of a ASPrimitiveTraitCollection.
 */
extern NSString *NSStringFromASPrimitiveTraitCollection(ASPrimitiveTraitCollection traits);

/**
 * This function will walk the layout element hierarchy and updates the layout element trait collection for every
 * layout element within the hierarchy.
 */
extern void ASTraitCollectionPropagateDown(id<ASLayoutElement> element, ASPrimitiveTraitCollection traitCollection);

ASDISPLAYNODE_EXTERN_C_END

/**
 * Abstraction on top of UITraitCollection for propagation within AsyncDisplayKit-Layout
 */
@protocol ASTraitEnvironment <NSObject>

/**
 * Returns a struct-representation of the environment's ASEnvironmentDisplayTraits. This only exists as a internal
 * convenience method. Users should access the trait collections through the NSObject based asyncTraitCollection API
 */
- (ASPrimitiveTraitCollection)primitiveTraitCollection;

/**
 * Sets a trait collection on this environment state.
 */
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection;

/**
 */
- (ASTraitCollection *)asyncTraitCollection;

@end

#define ASPrimitiveTraitCollectionDefaults \
- (ASPrimitiveTraitCollection)primitiveTraitCollection\
{\
  return _primitiveTraitCollection.load();\
}\
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection\
{\
  _primitiveTraitCollection = traitCollection;\
}\

#define ASLayoutElementCollectionTableSetTraitCollection(lock) \
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection\
{\
  ASDN::MutexLocker l(lock);\
\
  ASPrimitiveTraitCollection oldTraits = self.primitiveTraitCollection;\
  [super setPrimitiveTraitCollection:traitCollection];\
\
  /* Extra Trait Collection Handling */\
\
  /* If the node is not loaded  yet don't do anything as otherwise the access of the view will trigger a load */\
  if (! self.isNodeLoaded) { return; }\
\
  ASPrimitiveTraitCollection currentTraits = self.primitiveTraitCollection;\
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(currentTraits, oldTraits) == NO) {\
    [self.dataController environmentDidChange];\
  }\
}\

#pragma mark - ASTraitCollection

AS_SUBCLASSING_RESTRICTED
@interface ASTraitCollection : NSObject

@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, assign, readonly) UIUserInterfaceSizeClass verticalSizeClass;

@property (nonatomic, assign, readonly) CGFloat displayScale;
@property (nonatomic, assign, readonly) UIDisplayGamut displayGamut;

@property (nonatomic, assign, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, assign, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, assign, readonly) UITraitEnvironmentLayoutDirection layoutDirection;
#if TARGET_OS_TV
@property (nonatomic, assign, readonly) UIUserInterfaceStyle userInterfaceStyle;
#endif

@property (nonatomic, assign, readonly) UIContentSizeCategory preferredContentSizeCategory;

@property (nonatomic, assign, readonly) CGSize containerSize;

+ (ASTraitCollection *)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize
                                fallbackContentSizeCategory:(UIContentSizeCategory)fallbackContentSizeCategory;

#if TARGET_OS_TV
+ (ASTraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                            verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                                 displayScale:(CGFloat)displayScale
                                                 displayGamut:(UIDisplayGamut)displayGamut
                                           userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                         forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                              layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                                           userInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle
                                 preferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
                                                containerSize:(CGSize)windowSize;
#else
+ (ASTraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                            verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                                 displayScale:(CGFloat)displayScale
                                                 displayGamut:(UIDisplayGamut)displayGamut
                                           userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                         forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                              layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                                 preferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
                                                containerSize:(CGSize)windowSize;
#endif

- (ASPrimitiveTraitCollection)primitiveTraitCollection;
- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end

@interface ASTraitCollection (Deprecated)

+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                         containerSize:(CGSize)windowSize
  ASDISPLAYNODE_DEPRECATED_MSG("Use full version of this method instead.");

@end

NS_ASSUME_NONNULL_END
