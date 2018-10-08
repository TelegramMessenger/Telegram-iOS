//
//  ASLayoutElementPrivate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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

AS_EXTERN int32_t const ASLayoutElementContextInvalidTransitionID;

AS_EXTERN int32_t const ASLayoutElementContextDefaultTransitionID;

// Does not currently support nesting – there must be no current context.
AS_EXTERN void ASLayoutElementPushContext(ASLayoutElementContext * context);

AS_EXTERN ASLayoutElementContext * _Nullable ASLayoutElementGetCurrentContext(void);

AS_EXTERN void ASLayoutElementPopContext(void);

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

