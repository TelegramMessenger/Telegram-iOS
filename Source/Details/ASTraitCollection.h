//
//  ASTraitCollection.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//


#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASTraitCollection;
@protocol ASLayoutElement;
@protocol ASTraitEnvironment;

NS_ASSUME_NONNULL_BEGIN

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
AS_EXTERN ASPrimitiveContentSizeCategory ASPrimitiveContentSizeCategoryMake(UIContentSizeCategory sizeCategory);

#pragma mark - ASPrimitiveTraitCollection

/**
 * @abstract This is an internal struct-representation of ASTraitCollection.
 *
 * @discussion This struct is for internal use only. Framework users should always use ASTraitCollection.
 *
 * If you use ASPrimitiveTraitCollection, please do make sure to initialize it with ASPrimitiveTraitCollectionMakeDefault()
 * or ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection*).
 */
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
AS_EXTERN ASPrimitiveTraitCollection ASPrimitiveTraitCollectionMakeDefault(void);

/**
 * Creates a ASPrimitiveTraitCollection from a given UITraitCollection.
 */
AS_EXTERN ASPrimitiveTraitCollection ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection);


/**
 * Compares two ASPrimitiveTraitCollection to determine if they are the same.
 */
AS_EXTERN BOOL ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(ASPrimitiveTraitCollection lhs, ASPrimitiveTraitCollection rhs);

/**
 * Returns a string representation of a ASPrimitiveTraitCollection.
 */
AS_EXTERN NSString *NSStringFromASPrimitiveTraitCollection(ASPrimitiveTraitCollection traits);

/**
 * This function will walk the layout element hierarchy and updates the layout element trait collection for every
 * layout element within the hierarchy.
 */
AS_EXTERN void ASTraitCollectionPropagateDown(id<ASLayoutElement> element, ASPrimitiveTraitCollection traitCollection);

/**
 * Abstraction on top of UITraitCollection for propagation within AsyncDisplayKit-Layout
 */
@protocol ASTraitEnvironment <NSObject>

/**
 * @abstract Returns a struct-representation of the environment's ASEnvironmentDisplayTraits.
 *
 * @discussion This only exists as an internal convenience method. Users should access the trait collections through
 * the NSObject based asyncTraitCollection API
 */
- (ASPrimitiveTraitCollection)primitiveTraitCollection;

/**
 * @abstract Sets a trait collection on this environment state.
 *
 * @discussion This only exists as an internal convenience method. Users should not override trait collection using it.
 * Use [ASViewController overrideDisplayTraitsWithTraitCollection] block instead.
 */
- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection;

/**
 * @abstract Returns the thread-safe UITraitCollection equivalent.
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

@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, readonly) UIUserInterfaceSizeClass verticalSizeClass;

@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) UIDisplayGamut displayGamut;

@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, readonly) UITraitEnvironmentLayoutDirection layoutDirection;
#if TARGET_OS_TV
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
#endif

@property (nonatomic, readonly) UIContentSizeCategory preferredContentSizeCategory;

@property (nonatomic, readonly) CGSize containerSize;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize NS_RETURNS_RETAINED;

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                              containerSize:(CGSize)windowSize
                                fallbackContentSizeCategory:(UIContentSizeCategory)fallbackContentSizeCategory NS_RETURNS_RETAINED;

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
                                                containerSize:(CGSize)windowSize NS_RETURNS_RETAINED;
#else
+ (ASTraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                            verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                                 displayScale:(CGFloat)displayScale
                                                 displayGamut:(UIDisplayGamut)displayGamut
                                           userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                         forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                              layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                                 preferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
                                                containerSize:(CGSize)windowSize NS_RETURNS_RETAINED;
#endif

- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end

/**
 * These are internal helper methods. Should never be called by the framework users.
 */
@interface ASTraitCollection (PrimitiveTraits)

+ (ASTraitCollection *)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits NS_RETURNS_RETAINED;

- (ASPrimitiveTraitCollection)primitiveTraitCollection;

@end

@interface ASTraitCollection (Deprecated)

- (instancetype)init ASDISPLAYNODE_DEPRECATED_MSG("The default constructor of this class is going to become unavailable. Use other constructors instead.");

+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                         containerSize:(CGSize)windowSize
  NS_RETURNS_RETAINED ASDISPLAYNODE_DEPRECATED_MSG("Use full version of this method instead.");

@end

NS_ASSUME_NONNULL_END
