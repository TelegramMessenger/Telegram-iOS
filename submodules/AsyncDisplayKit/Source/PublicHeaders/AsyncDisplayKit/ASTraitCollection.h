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

#pragma mark - ASPrimitiveTraitCollection

/**
 * @abstract This is an internal struct-representation of ASTraitCollection.
 *
 * @discussion This struct is for internal use only. Framework users should always use ASTraitCollection.
 *
 * If you use ASPrimitiveTraitCollection, please do make sure to initialize it with ASPrimitiveTraitCollectionMakeDefault()
 * or ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection*).
 */
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wpadded"
typedef struct {
  UIUserInterfaceSizeClass horizontalSizeClass;
  UIUserInterfaceSizeClass verticalSizeClass;

  CGFloat displayScale;
  UIDisplayGamut displayGamut API_AVAILABLE(ios(10.0));

  UIUserInterfaceIdiom userInterfaceIdiom;
  UIForceTouchCapability forceTouchCapability;
  UITraitEnvironmentLayoutDirection layoutDirection API_AVAILABLE(ios(10.0));
#if AS_BUILD_UIUSERINTERFACESTYLE
  UIUserInterfaceStyle userInterfaceStyle API_AVAILABLE(tvos(10.0), ios(12.0));
#endif

  // NOTE: This must be a constant. We will assert.
  unowned UIContentSizeCategory preferredContentSizeCategory API_AVAILABLE(ios(10.0));

  CGSize containerSize;
} ASPrimitiveTraitCollection;
#pragma clang diagnostic pop

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
  AS::MutexLocker l(lock);\
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

@property (readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (readonly) UIUserInterfaceSizeClass verticalSizeClass;

@property (readonly) CGFloat displayScale;
@property (readonly) UIDisplayGamut displayGamut API_AVAILABLE(ios(10.0));

@property (readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (readonly) UIForceTouchCapability forceTouchCapability;
@property (readonly) UITraitEnvironmentLayoutDirection layoutDirection API_AVAILABLE(ios(10.0));
#if AS_BUILD_UIUSERINTERFACESTYLE
@property (readonly) UIUserInterfaceStyle userInterfaceStyle API_AVAILABLE(tvos(10.0), ios(12.0));
#endif
@property (readonly) UIContentSizeCategory preferredContentSizeCategory  API_AVAILABLE(ios(10.0));

@property (readonly) CGSize containerSize;

- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection;

@end

/**
 * These are internal helper methods. Should never be called by the framework users.
 */
@interface ASTraitCollection (PrimitiveTraits)

+ (ASTraitCollection *)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits NS_RETURNS_RETAINED;

- (ASPrimitiveTraitCollection)primitiveTraitCollection;

@end

NS_ASSUME_NONNULL_END
