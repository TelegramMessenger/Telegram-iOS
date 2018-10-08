//
//  ASTraitCollection.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASLayoutElement.h>

#pragma mark - ASPrimitiveContentSizeCategory

// UIContentSizeCategoryUnspecified is available only in iOS 10.0 and later.
// This is used for compatibility with older iOS versions.
ASDISPLAYNODE_INLINE UIContentSizeCategory AS_UIContentSizeCategoryUnspecified() {
  if (AS_AVAILABLE_IOS(10)) {
    return UIContentSizeCategoryUnspecified;
  } else {
    return @"_UICTContentSizeCategoryUnspecified";
  }
}

ASDISPLAYNODE_INLINE UIContentSizeCategory _Nonnull AS_safeContentSizeCategory(UIContentSizeCategory _Nullable sizeCategory) {
  return sizeCategory ? sizeCategory : AS_UIContentSizeCategoryUnspecified();
}

ASPrimitiveContentSizeCategory ASPrimitiveContentSizeCategoryMake(UIContentSizeCategory sizeCategory) {
  if ([sizeCategory isEqualToString:UIContentSizeCategoryExtraSmall]) {
    return UIContentSizeCategoryExtraSmall;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategorySmall]) {
    return UIContentSizeCategorySmall;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryMedium]) {
    return UIContentSizeCategoryMedium;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryLarge]) {
    return UIContentSizeCategoryLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryExtraLarge]) {
    return UIContentSizeCategoryExtraLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryExtraExtraLarge]) {
    return UIContentSizeCategoryExtraExtraLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]) {
    return UIContentSizeCategoryExtraExtraExtraLarge;
  }

  if ([sizeCategory isEqualToString:UIContentSizeCategoryAccessibilityMedium]) {
    return UIContentSizeCategoryAccessibilityMedium;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryAccessibilityLarge]) {
    return UIContentSizeCategoryAccessibilityLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryAccessibilityExtraLarge]) {
    return UIContentSizeCategoryAccessibilityExtraLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraLarge]) {
    return UIContentSizeCategoryAccessibilityExtraExtraLarge;
  }
  if ([sizeCategory isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
    return UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
  }

  return AS_UIContentSizeCategoryUnspecified();
}

#pragma mark - ASPrimitiveTraitCollection

void ASTraitCollectionPropagateDown(id<ASLayoutElement> element, ASPrimitiveTraitCollection traitCollection) {
  if (element) {
    element.primitiveTraitCollection = traitCollection;
  }
  
  for (id<ASLayoutElement> subelement in element.sublayoutElements) {
    ASTraitCollectionPropagateDown(subelement, traitCollection);
  }
}

ASPrimitiveTraitCollection ASPrimitiveTraitCollectionMakeDefault() {
  return (ASPrimitiveTraitCollection) {
    // Default values can be defined in here
    .displayGamut = UIDisplayGamutUnspecified,
    .userInterfaceIdiom = UIUserInterfaceIdiomUnspecified,
    .layoutDirection = UITraitEnvironmentLayoutDirectionUnspecified,
    .preferredContentSizeCategory = ASPrimitiveContentSizeCategoryMake(AS_UIContentSizeCategoryUnspecified()),
    .containerSize = CGSizeZero,
  };
}

ASPrimitiveTraitCollection ASPrimitiveTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection) {
  ASPrimitiveTraitCollection environmentTraitCollection = ASPrimitiveTraitCollectionMakeDefault();
  environmentTraitCollection.horizontalSizeClass = traitCollection.horizontalSizeClass;
  environmentTraitCollection.verticalSizeClass = traitCollection.verticalSizeClass;
  environmentTraitCollection.displayScale = traitCollection.displayScale;
  environmentTraitCollection.userInterfaceIdiom = traitCollection.userInterfaceIdiom;
  environmentTraitCollection.forceTouchCapability = traitCollection.forceTouchCapability;
  if (AS_AVAILABLE_IOS(10)) {
    environmentTraitCollection.displayGamut = traitCollection.displayGamut;
    environmentTraitCollection.layoutDirection = traitCollection.layoutDirection;

    // preferredContentSizeCategory is also available on older iOS versions, but only via UIApplication class.
    // It should be noted that [UIApplication sharedApplication] is unavailable because Texture is built with only extension-safe API.
    environmentTraitCollection.preferredContentSizeCategory = ASPrimitiveContentSizeCategoryMake(traitCollection.preferredContentSizeCategory);

    #if TARGET_OS_TV
      environmentTraitCollection.userInterfaceStyle = traitCollection.userInterfaceStyle;
    #endif
  } else {
    environmentTraitCollection.displayGamut = UIDisplayGamutSRGB; // We're on iOS 9 or lower, so this is not a P3 device.
  }
  return environmentTraitCollection;
}

BOOL ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(ASPrimitiveTraitCollection lhs, ASPrimitiveTraitCollection rhs) {
  UIContentSizeCategory leftSizeCategory = AS_safeContentSizeCategory(lhs.preferredContentSizeCategory);
  UIContentSizeCategory rightSizeCategory = AS_safeContentSizeCategory(rhs.preferredContentSizeCategory);

  return
    lhs.verticalSizeClass == rhs.verticalSizeClass &&
    lhs.horizontalSizeClass == rhs.horizontalSizeClass &&
    lhs.displayScale == rhs.displayScale &&
    lhs.displayGamut == rhs.displayGamut &&
    lhs.userInterfaceIdiom == rhs.userInterfaceIdiom &&
    lhs.forceTouchCapability == rhs.forceTouchCapability &&
    lhs.layoutDirection == rhs.layoutDirection &&
    #if TARGET_OS_TV
      lhs.userInterfaceStyle == rhs.userInterfaceStyle &&
    #endif

    [leftSizeCategory isEqualToString:rightSizeCategory] && // Simple pointer comparison should be sufficient here

    CGSizeEqualToSize(lhs.containerSize, rhs.containerSize);
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIUserInterfaceIdiom(UIUserInterfaceIdiom idiom) {
  switch (idiom) {
    case UIUserInterfaceIdiomTV:
      return @"TV";
    case UIUserInterfaceIdiomPad:
      return @"Pad";
    case UIUserInterfaceIdiomPhone:
      return @"Phone";
    case UIUserInterfaceIdiomCarPlay:
      return @"CarPlay";
    default:
      return @"Unspecified";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIForceTouchCapability(UIForceTouchCapability capability) {
  switch (capability) {
    case UIForceTouchCapabilityAvailable:
      return @"Available";
    case UIForceTouchCapabilityUnavailable:
      return @"Unavailable";
    default:
      return @"Unknown";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIUserInterfaceSizeClass(UIUserInterfaceSizeClass sizeClass) {
  switch (sizeClass) {
    case UIUserInterfaceSizeClassCompact:
      return @"Compact";
    case UIUserInterfaceSizeClassRegular:
      return @"Regular";
    default:
      return @"Unspecified";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIDisplayGamut(UIDisplayGamut displayGamut) {
  switch (displayGamut) {
    case UIDisplayGamutSRGB:
      return @"sRGB";
    case UIDisplayGamutP3:
      return @"P3";
    default:
      return @"Unspecified";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUITraitEnvironmentLayoutDirection(UITraitEnvironmentLayoutDirection layoutDirection) {
  switch (layoutDirection) {
    case UITraitEnvironmentLayoutDirectionLeftToRight:
      return @"LeftToRight";
    case UITraitEnvironmentLayoutDirectionRightToLeft:
      return @"RightToLeft";
    default:
      return @"Unspecified";
  }
}

#if TARGET_OS_TV
// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIUserInterfaceStyle(UIUserInterfaceStyle userInterfaceStyle) {
  switch (userInterfaceStyle) {
    case UIUserInterfaceStyleLight:
      return @"Light";
    case UIUserInterfaceStyleDark:
      return @"Dark";
    default:
      return @"Unspecified";
  }
}
#endif

NSString *NSStringFromASPrimitiveTraitCollection(ASPrimitiveTraitCollection traits) {
  NSMutableArray<NSDictionary *> *props = [NSMutableArray array];
  [props addObject:@{ @"verticalSizeClass": AS_NSStringFromUIUserInterfaceSizeClass(traits.verticalSizeClass) }];
  [props addObject:@{ @"horizontalSizeClass": AS_NSStringFromUIUserInterfaceSizeClass(traits.horizontalSizeClass) }];
  [props addObject:@{ @"displayScale": [NSString stringWithFormat: @"%.0lf", (double)traits.displayScale] }];
  [props addObject:@{ @"displayGamut": AS_NSStringFromUIDisplayGamut(traits.displayGamut) }];
  [props addObject:@{ @"userInterfaceIdiom": AS_NSStringFromUIUserInterfaceIdiom(traits.userInterfaceIdiom) }];
  [props addObject:@{ @"forceTouchCapability": AS_NSStringFromUIForceTouchCapability(traits.forceTouchCapability) }];
  [props addObject:@{ @"layoutDirection": AS_NSStringFromUITraitEnvironmentLayoutDirection(traits.layoutDirection) }];
  #if TARGET_OS_TV
    [props addObject:@{ @"userInterfaceStyle": AS_NSStringFromUIUserInterfaceStyle(traits.userInterfaceStyle) }];
  #endif
  [props addObject:@{ @"preferredContentSizeCategory": AS_safeContentSizeCategory(traits.preferredContentSizeCategory) }];
  [props addObject:@{ @"containerSize": NSStringFromCGSize(traits.containerSize) }];
  return ASObjectDescriptionMakeWithoutObject(props);
}

#pragma mark - ASTraitCollection

@implementation ASTraitCollection

#if TARGET_OS_TV

- (instancetype)initWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                          verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                               displayScale:(CGFloat)displayScale
                               displayGamut:(UIDisplayGamut)displayGamut
                         userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                       forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                            layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                         userInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle
               preferredContentSizeCategory:(UIContentSizeCategory _Nonnull)preferredContentSizeCategory
                              containerSize:(CGSize)windowSize
{
    self = [super init];
    if (self) {
      _horizontalSizeClass = horizontalSizeClass;
      _verticalSizeClass = verticalSizeClass;
      _displayScale = displayScale;
      _displayGamut = displayGamut;
      _userInterfaceIdiom = userInterfaceIdiom;
      _forceTouchCapability = forceTouchCapability;
      _layoutDirection = layoutDirection;
      _userInterfaceStyle = userInterfaceStyle;
      _preferredContentSizeCategory = AS_safeContentSizeCategory(preferredContentSizeCategory); // guard against misuse
      _containerSize = windowSize;
    }
    return self;
}

+ (instancetype)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                          displayScale:(CGFloat)displayScale
                                          displayGamut:(UIDisplayGamut)displayGamut
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                       layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                                    userInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle
                          preferredContentSizeCategory:(UIContentSizeCategory _Nonnull)preferredContentSizeCategory
                                         containerSize:(CGSize)windowSize NS_RETURNS_RETAINED
{
  return [[self alloc] initWithHorizontalSizeClass:horizontalSizeClass
                                 verticalSizeClass:verticalSizeClass
                                      displayScale:displayScale
                                      displayGamut:displayGamut
                                userInterfaceIdiom:userInterfaceIdiom
                              forceTouchCapability:forceTouchCapability
                                   layoutDirection:layoutDirection
                                userInterfaceStyle:userInterfaceStyle
                      preferredContentSizeCategory:preferredContentSizeCategory
                                     containerSize:windowSize];
}

#else

- (instancetype)initWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                          verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                               displayScale:(CGFloat)displayScale
                               displayGamut:(UIDisplayGamut)displayGamut
                         userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                       forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                            layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
               preferredContentSizeCategory:(UIContentSizeCategory _Nonnull)preferredContentSizeCategory
                              containerSize:(CGSize)windowSize
{
  self = [super init];
  if (self) {
    _horizontalSizeClass = horizontalSizeClass;
    _verticalSizeClass = verticalSizeClass;
    _displayScale = displayScale;
    _displayGamut = displayGamut;
    _userInterfaceIdiom = userInterfaceIdiom;
    _forceTouchCapability = forceTouchCapability;
    _layoutDirection = layoutDirection;
    _preferredContentSizeCategory = AS_safeContentSizeCategory(preferredContentSizeCategory); // guard against misuse
    _containerSize = windowSize;
  }
  return self;
}

+ (instancetype)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                          displayScale:(CGFloat)displayScale
                                          displayGamut:(UIDisplayGamut)displayGamut
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                       layoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection
                          preferredContentSizeCategory:(UIContentSizeCategory _Nonnull)preferredContentSizeCategory
                                         containerSize:(CGSize)windowSize NS_RETURNS_RETAINED
{
  return [[self alloc] initWithHorizontalSizeClass:horizontalSizeClass
                                 verticalSizeClass:verticalSizeClass
                                      displayScale:displayScale
                                      displayGamut:displayGamut
                                userInterfaceIdiom:userInterfaceIdiom
                              forceTouchCapability:forceTouchCapability
                                   layoutDirection:layoutDirection
                      preferredContentSizeCategory:preferredContentSizeCategory
                                     containerSize:windowSize];
}

#endif

+ (instancetype)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                       containerSize:(CGSize)windowSize NS_RETURNS_RETAINED
{
  return [self traitCollectionWithUITraitCollection:traitCollection
                                      containerSize:windowSize
                        fallbackContentSizeCategory:AS_UIContentSizeCategoryUnspecified()];
}


+ (instancetype)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                       containerSize:(CGSize)windowSize
                         fallbackContentSizeCategory:(UIContentSizeCategory _Nonnull)fallbackContentSizeCategory NS_RETURNS_RETAINED
{
  UIDisplayGamut displayGamut;
  UITraitEnvironmentLayoutDirection layoutDirection;
  UIContentSizeCategory sizeCategory;
  #if TARGET_OS_TV
    UIUserInterfaceStyle userInterfaceStyle;
  #endif
  if (AS_AVAILABLE_IOS(10)) {
    displayGamut = traitCollection.displayGamut;
    layoutDirection = traitCollection.layoutDirection;
    sizeCategory = traitCollection.preferredContentSizeCategory;
    #if TARGET_OS_TV
      userInterfaceStyle = traitCollection.userInterfaceStyle;
    #endif
  } else {
    displayGamut = UIDisplayGamutSRGB; // We're on iOS 9 or lower, so this is not a P3 device.
    layoutDirection = UITraitEnvironmentLayoutDirectionUnspecified;
    sizeCategory = fallbackContentSizeCategory;
    #if TARGET_OS_TV
      userInterfaceStyle = UIUserInterfaceStyleUnspecified;
    #endif
  }

#if TARGET_OS_TV
  return [self traitCollectionWithHorizontalSizeClass:traitCollection.horizontalSizeClass
                                    verticalSizeClass:traitCollection.verticalSizeClass
                                         displayScale:traitCollection.displayScale
                                         displayGamut:displayGamut
                                   userInterfaceIdiom:traitCollection.userInterfaceIdiom
                                 forceTouchCapability:traitCollection.forceTouchCapability
                                      layoutDirection:layoutDirection
                                   userInterfaceStyle:userInterfaceStyle
                         preferredContentSizeCategory:sizeCategory
                                        containerSize:windowSize];
#else
  return [self traitCollectionWithHorizontalSizeClass:traitCollection.horizontalSizeClass
                                    verticalSizeClass:traitCollection.verticalSizeClass
                                         displayScale:traitCollection.displayScale
                                         displayGamut:displayGamut
                                   userInterfaceIdiom:traitCollection.userInterfaceIdiom
                                 forceTouchCapability:traitCollection.forceTouchCapability
                                      layoutDirection:layoutDirection
                         preferredContentSizeCategory:sizeCategory
                                        containerSize:windowSize];
#endif
}

- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection
{
  if (traitCollection == nil) {
    return NO;
  }

  if (self == traitCollection) {
    return YES;
  }

  return
    self.horizontalSizeClass == traitCollection.horizontalSizeClass &&
    self.verticalSizeClass == traitCollection.verticalSizeClass &&
    self.displayScale == traitCollection.displayScale &&
    self.displayGamut == traitCollection.displayGamut &&
    self.userInterfaceIdiom == traitCollection.userInterfaceIdiom &&
    self.forceTouchCapability == traitCollection.forceTouchCapability &&
    self.layoutDirection == traitCollection.layoutDirection &&
    #if TARGET_OS_TV
      self.userInterfaceStyle == traitCollection.userInterfaceStyle &&
    #endif
    [self.preferredContentSizeCategory isEqualToString:traitCollection.preferredContentSizeCategory] &&
    CGSizeEqualToSize(self.containerSize, traitCollection.containerSize);
}

@end

@implementation ASTraitCollection (PrimitiveTraits)

+ (instancetype)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits NS_RETURNS_RETAINED
{
#if TARGET_OS_TV
  return [self traitCollectionWithHorizontalSizeClass:traits.horizontalSizeClass
                                    verticalSizeClass:traits.verticalSizeClass
                                         displayScale:traits.displayScale
                                         displayGamut:traits.displayGamut
                                   userInterfaceIdiom:traits.userInterfaceIdiom
                                 forceTouchCapability:traits.forceTouchCapability
                                      layoutDirection:traits.layoutDirection
                                   userInterfaceStyle:traits.userInterfaceStyle
                         preferredContentSizeCategory:AS_safeContentSizeCategory(traits.preferredContentSizeCategory)
                                        containerSize:traits.containerSize];
#else
  return [self traitCollectionWithHorizontalSizeClass:traits.horizontalSizeClass
                                    verticalSizeClass:traits.verticalSizeClass
                                         displayScale:traits.displayScale
                                         displayGamut:traits.displayGamut
                                   userInterfaceIdiom:traits.userInterfaceIdiom
                                 forceTouchCapability:traits.forceTouchCapability
                                      layoutDirection:traits.layoutDirection
                         preferredContentSizeCategory:AS_safeContentSizeCategory(traits.preferredContentSizeCategory)
                                        containerSize:traits.containerSize];
#endif
}

- (ASPrimitiveTraitCollection)primitiveTraitCollection
{
  return (ASPrimitiveTraitCollection) {
    .horizontalSizeClass = self.horizontalSizeClass,
    .verticalSizeClass = self.verticalSizeClass,
    .displayScale = self.displayScale,
    .displayGamut = self.displayGamut,
    .userInterfaceIdiom = self.userInterfaceIdiom,
    .forceTouchCapability = self.forceTouchCapability,
    .layoutDirection = self.layoutDirection,
#if TARGET_OS_TV
    .userInterfaceStyle = self.userInterfaceStyle,
#endif
    .preferredContentSizeCategory = ASPrimitiveContentSizeCategoryMake(self.preferredContentSizeCategory),
    .containerSize = self.containerSize,
  };
}

@end

@implementation ASTraitCollection (Deprecated)

- (instancetype)init
{
#if TARGET_OS_TV
  return [self initWithHorizontalSizeClass:UIUserInterfaceSizeClassUnspecified
                         verticalSizeClass:UIUserInterfaceSizeClassUnspecified
                              displayScale:0
                              displayGamut:UIDisplayGamutUnspecified
                        userInterfaceIdiom:UIUserInterfaceIdiomUnspecified
                      forceTouchCapability:UIForceTouchCapabilityUnknown
                           layoutDirection:UITraitEnvironmentLayoutDirectionUnspecified
                        userInterfaceStyle:UIUserInterfaceStyleUnspecified
              preferredContentSizeCategory:AS_UIContentSizeCategoryUnspecified()
                             containerSize:CGSizeZero];
#else
  return [self initWithHorizontalSizeClass:UIUserInterfaceSizeClassUnspecified
                         verticalSizeClass:UIUserInterfaceSizeClassUnspecified
                              displayScale:0
                              displayGamut:UIDisplayGamutUnspecified
                        userInterfaceIdiom:UIUserInterfaceIdiomUnspecified
                      forceTouchCapability:UIForceTouchCapabilityUnknown
                           layoutDirection:UITraitEnvironmentLayoutDirectionUnspecified
              preferredContentSizeCategory:AS_UIContentSizeCategoryUnspecified()
                             containerSize:CGSizeZero];
#endif
}

+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                         containerSize:(CGSize)windowSize NS_RETURNS_RETAINED
{
#if TARGET_OS_TV
  return [self traitCollectionWithHorizontalSizeClass:horizontalSizeClass
                                    verticalSizeClass:verticalSizeClass
                                         displayScale:displayScale
                                         displayGamut:UIDisplayGamutUnspecified
                                   userInterfaceIdiom:userInterfaceIdiom
                                 forceTouchCapability:forceTouchCapability
                                      layoutDirection:UITraitEnvironmentLayoutDirectionUnspecified
                                   userInterfaceStyle:UIUserInterfaceStyleUnspecified
                         preferredContentSizeCategory:AS_UIContentSizeCategoryUnspecified()
                                        containerSize:windowSize];
#else
  return [self traitCollectionWithHorizontalSizeClass:horizontalSizeClass
                                    verticalSizeClass:verticalSizeClass
                                         displayScale:displayScale
                                         displayGamut:UIDisplayGamutUnspecified
                                   userInterfaceIdiom:userInterfaceIdiom
                                 forceTouchCapability:forceTouchCapability
                                      layoutDirection:UITraitEnvironmentLayoutDirectionUnspecified
                         preferredContentSizeCategory:AS_UIContentSizeCategoryUnspecified()
                                        containerSize:windowSize];
#endif
}

@end
