//
//  ASTraitCollection.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASHashing.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASLayoutElement.h>

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
  ASPrimitiveTraitCollection tc = {};
  tc.userInterfaceIdiom = UIUserInterfaceIdiomUnspecified;
  tc.forceTouchCapability = UIForceTouchCapabilityUnknown;
  tc.displayScale = 0.0;
  tc.horizontalSizeClass = UIUserInterfaceSizeClassUnspecified;
  tc.verticalSizeClass = UIUserInterfaceSizeClassUnspecified;
  tc.containerSize = CGSizeZero;
  if (AS_AVAILABLE_IOS(10)) {
    tc.displayGamut = UIDisplayGamutUnspecified;
    tc.preferredContentSizeCategory = UIContentSizeCategoryUnspecified;
    tc.layoutDirection = UITraitEnvironmentLayoutDirectionUnspecified;
  }
#if AS_BUILD_UIUSERINTERFACESTYLE
  if (AS_AVAILABLE_IOS_TVOS(12, 10)) {
    tc.userInterfaceStyle = UIUserInterfaceStyleUnspecified;
  }
#endif
  return tc;
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

    ASDisplayNodeCAssertPermanent(traitCollection.preferredContentSizeCategory);
    environmentTraitCollection.preferredContentSizeCategory = traitCollection.preferredContentSizeCategory;
  }
#if AS_BUILD_UIUSERINTERFACESTYLE
  if (AS_AVAILABLE_IOS_TVOS(12, 10)) {
    environmentTraitCollection.userInterfaceStyle = traitCollection.userInterfaceStyle;
  }
#endif
  return environmentTraitCollection;
}

BOOL ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(ASPrimitiveTraitCollection lhs, ASPrimitiveTraitCollection rhs) {
  return !memcmp(&lhs, &rhs, sizeof(ASPrimitiveTraitCollection));
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
API_AVAILABLE(ios(10))
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
API_AVAILABLE(ios(10))
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

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
#if AS_BUILD_UIUSERINTERFACESTYLE
API_AVAILABLE(tvos(10.0), ios(12.0))
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
  [props addObject:@{ @"userInterfaceIdiom": AS_NSStringFromUIUserInterfaceIdiom(traits.userInterfaceIdiom) }];
  [props addObject:@{ @"forceTouchCapability": AS_NSStringFromUIForceTouchCapability(traits.forceTouchCapability) }];
#if AS_BUILD_UIUSERINTERFACESTYLE
  if (AS_AVAILABLE_IOS_TVOS(12, 10)) {
    [props addObject:@{ @"userInterfaceStyle": AS_NSStringFromUIUserInterfaceStyle(traits.userInterfaceStyle) }];
  }
#endif
  if (AS_AVAILABLE_IOS(10)) {
    [props addObject:@{ @"layoutDirection": AS_NSStringFromUITraitEnvironmentLayoutDirection(traits.layoutDirection) }];
    [props addObject:@{ @"preferredContentSizeCategory": traits.preferredContentSizeCategory }];
    [props addObject:@{ @"displayGamut": AS_NSStringFromUIDisplayGamut(traits.displayGamut) }];
  }
  [props addObject:@{ @"containerSize": NSStringFromCGSize(traits.containerSize) }];
  return ASObjectDescriptionMakeWithoutObject(props);
}

#pragma mark - ASTraitCollection

@implementation ASTraitCollection {
  ASPrimitiveTraitCollection _prim;
}

+ (ASTraitCollection *)traitCollectionWithASPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traits NS_RETURNS_RETAINED {
  ASTraitCollection *tc = [[ASTraitCollection alloc] init];
  if (AS_AVAILABLE_IOS(10)) {
    ASDisplayNodeCAssertPermanent(traits.preferredContentSizeCategory);
  }
  tc->_prim = traits;
  return tc;
}

- (ASPrimitiveTraitCollection)primitiveTraitCollection {
  return _prim;
}
- (UIUserInterfaceSizeClass)horizontalSizeClass
{
  return _prim.horizontalSizeClass;
}
-(UIUserInterfaceSizeClass)verticalSizeClass
{
  return _prim.verticalSizeClass;
}
- (CGFloat)displayScale
{
  return _prim.displayScale;
}
- (UIDisplayGamut)displayGamut
{
  return _prim.displayGamut;
}
- (UIForceTouchCapability)forceTouchCapability
{
  return _prim.forceTouchCapability;
}
- (UITraitEnvironmentLayoutDirection)layoutDirection
{
  return _prim.layoutDirection;
}
- (CGSize)containerSize
{
  return _prim.containerSize;
}
#if AS_BUILD_UIUSERINTERFACESTYLE
- (UIUserInterfaceStyle)userInterfaceStyle
{
  return _prim.userInterfaceStyle;
}
#endif
- (UIContentSizeCategory)preferredContentSizeCategory
{
  return _prim.preferredContentSizeCategory;
}
- (NSUInteger)hash {
  return ASHashBytes(&_prim, sizeof(ASPrimitiveTraitCollection));
}

- (BOOL)isEqual:(id)object {
  if (!object || ![object isKindOfClass:ASTraitCollection.class]) {
    return NO;
  }
  return [self isEqualToTraitCollection:object];
}

- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection
{
  if (traitCollection == nil) {
    return NO;
  }

  if (self == traitCollection) {
    return YES;
  }
  return ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(_prim, traitCollection->_prim);
}

@end
