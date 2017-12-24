//
//  ASLayoutElementPrivate.h
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

#import <AsyncDisplayKit/ASDimension.h>
#import <UIKit/UIGeometry.h>

@protocol ASLayoutElement;
@class ASLayoutElementStyle;

#pragma mark - ASLayoutElementContext

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASLayoutElementContext : NSObject
@property (nonatomic) int32_t transitionID;
@end

extern int32_t const ASLayoutElementContextInvalidTransitionID;

extern int32_t const ASLayoutElementContextDefaultTransitionID;

// Does not currently support nesting – there must be no current context.
extern void ASLayoutElementPushContext(ASLayoutElementContext * context);

extern ASLayoutElementContext * _Nullable ASLayoutElementGetCurrentContext(void);

extern void ASLayoutElementPopContext(void);

NS_ASSUME_NONNULL_END

#pragma mark - ASLayoutElementLayoutDefaults

#define ASLayoutElementLayoutCalculationDefaults \
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize\
{\
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];\
}\
\
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize\
{\
  return [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize];\
}\
\
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize\
                     restrictedToSize:(ASLayoutElementSize)size\
                 relativeToParentSize:(CGSize)parentSize\
{\
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutElementSizeResolve(self.style.size, parentSize));\
  return [self calculateLayoutThatFits:resolvedRange];\
}\


#pragma mark - ASLayoutElementExtensibility

// Provides extension points for elments that comply to ASLayoutElement like ASLayoutSpec to add additional
// properties besides the default one provided in ASLayoutElementStyle

static const int kMaxLayoutElementBoolExtensions = 1;
static const int kMaxLayoutElementStateIntegerExtensions = 4;
static const int kMaxLayoutElementStateEdgeInsetExtensions = 1;

typedef struct ASLayoutElementStyleExtensions {
  // Values to store extensions
  BOOL boolExtensions[kMaxLayoutElementBoolExtensions];
  NSInteger integerExtensions[kMaxLayoutElementStateIntegerExtensions];
  UIEdgeInsets edgeInsetsExtensions[kMaxLayoutElementStateEdgeInsetExtensions];
} ASLayoutElementStyleExtensions;

#define ASLayoutElementStyleExtensibilityForwarding \
- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx\
{\
  [self.style setLayoutOptionExtensionBool:value atIndex:idx];\
}\
\
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx\
{\
  return [self.style layoutOptionExtensionBoolAtIndex:idx];\
}\
\
- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx\
{\
  [self.style setLayoutOptionExtensionInteger:value atIndex:idx];\
}\
\
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx\
{\
  return [self.style layoutOptionExtensionIntegerAtIndex:idx];\
}\
\
- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx\
{\
  [self.style setLayoutOptionExtensionEdgeInsets:value atIndex:idx];\
}\
\
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx\
{\
  return [self.style layoutOptionExtensionEdgeInsetsAtIndex:idx];\
}\

