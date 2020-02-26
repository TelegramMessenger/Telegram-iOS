//
//  ASLayoutElement.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

#import <atomic>
#include <pthread.h>

using AS::MutexLocker;

#if YOGA
  #import YOGA_HEADER_PATH
  #import <AsyncDisplayKit/ASYogaUtilities.h>
#endif

#pragma mark - ASLayoutElementContext

@implementation ASLayoutElementContext

- (instancetype)init
{
  if (self = [super init]) {
    _transitionID = ASLayoutElementContextDefaultTransitionID;
  }
  return self;
}

@end

CGFloat const ASLayoutElementParentDimensionUndefined = NAN;
CGSize const ASLayoutElementParentSizeUndefined = {ASLayoutElementParentDimensionUndefined, ASLayoutElementParentDimensionUndefined};

int32_t const ASLayoutElementContextInvalidTransitionID = 0;
int32_t const ASLayoutElementContextDefaultTransitionID = ASLayoutElementContextInvalidTransitionID + 1;

#if AS_TLS_AVAILABLE

static _Thread_local __unsafe_unretained ASLayoutElementContext *tls_context;

void ASLayoutElementPushContext(ASLayoutElementContext *context)
{
  // NOTE: It would be easy to support nested contexts – just use an NSMutableArray here.
  ASDisplayNodeCAssertNil(tls_context, @"Nested ASLayoutElementContexts aren't supported.");
  
  tls_context = (__bridge ASLayoutElementContext *)(__bridge_retained CFTypeRef)context;
}

ASLayoutElementContext *ASLayoutElementGetCurrentContext()
{
  // Don't retain here. Caller will retain if it wants to!
  return tls_context;
}

void ASLayoutElementPopContext()
{
  ASDisplayNodeCAssertNotNil(tls_context, @"Attempt to pop context when there wasn't a context!");
  CFRelease((__bridge CFTypeRef)tls_context);
  tls_context = nil;
}

#else

static pthread_key_t ASLayoutElementContextKey() {
  static pthread_key_t k;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pthread_key_create(&k, NULL);
  });
  return k;
}
void ASLayoutElementPushContext(ASLayoutElementContext *context)
{
  // NOTE: It would be easy to support nested contexts – just use an NSMutableArray here.
  ASDisplayNodeCAssertNil(pthread_getspecific(ASLayoutElementContextKey()), @"Nested ASLayoutElementContexts aren't supported.");
  
  const auto cfCtx = (__bridge_retained CFTypeRef)context;
  pthread_setspecific(ASLayoutElementContextKey(), cfCtx);
}

ASLayoutElementContext *ASLayoutElementGetCurrentContext()
{
  // Don't retain here. Caller will retain if it wants to!
  const auto ctxPtr = pthread_getspecific(ASLayoutElementContextKey());
  return (__bridge ASLayoutElementContext *)ctxPtr;
}

void ASLayoutElementPopContext()
{
  const auto ctx = (CFTypeRef)pthread_getspecific(ASLayoutElementContextKey());
  ASDisplayNodeCAssertNotNil(ctx, @"Attempt to pop context when there wasn't a context!");
  CFRelease(ctx);
  pthread_setspecific(ASLayoutElementContextKey(), NULL);
}

#endif // AS_TLS_AVAILABLE

#pragma mark - ASLayoutElementStyle

NSString * const ASLayoutElementStyleWidthProperty = @"ASLayoutElementStyleWidthProperty";
NSString * const ASLayoutElementStyleMinWidthProperty = @"ASLayoutElementStyleMinWidthProperty";
NSString * const ASLayoutElementStyleMaxWidthProperty = @"ASLayoutElementStyleMaxWidthProperty";

NSString * const ASLayoutElementStyleHeightProperty = @"ASLayoutElementStyleHeightProperty";
NSString * const ASLayoutElementStyleMinHeightProperty = @"ASLayoutElementStyleMinHeightProperty";
NSString * const ASLayoutElementStyleMaxHeightProperty = @"ASLayoutElementStyleMaxHeightProperty";

NSString * const ASLayoutElementStyleSpacingBeforeProperty = @"ASLayoutElementStyleSpacingBeforeProperty";
NSString * const ASLayoutElementStyleSpacingAfterProperty = @"ASLayoutElementStyleSpacingAfterProperty";
NSString * const ASLayoutElementStyleFlexGrowProperty = @"ASLayoutElementStyleFlexGrowProperty";
NSString * const ASLayoutElementStyleFlexShrinkProperty = @"ASLayoutElementStyleFlexShrinkProperty";
NSString * const ASLayoutElementStyleFlexBasisProperty = @"ASLayoutElementStyleFlexBasisProperty";
NSString * const ASLayoutElementStyleAlignSelfProperty = @"ASLayoutElementStyleAlignSelfProperty";
NSString * const ASLayoutElementStyleAscenderProperty = @"ASLayoutElementStyleAscenderProperty";
NSString * const ASLayoutElementStyleDescenderProperty = @"ASLayoutElementStyleDescenderProperty";

NSString * const ASLayoutElementStyleLayoutPositionProperty = @"ASLayoutElementStyleLayoutPositionProperty";

#if YOGA
NSString * const ASYogaFlexWrapProperty = @"ASLayoutElementStyleLayoutFlexWrapProperty";
NSString * const ASYogaFlexDirectionProperty = @"ASYogaFlexDirectionProperty";
NSString * const ASYogaDirectionProperty = @"ASYogaDirectionProperty";
NSString * const ASYogaSpacingProperty = @"ASYogaSpacingProperty";
NSString * const ASYogaJustifyContentProperty = @"ASYogaJustifyContentProperty";
NSString * const ASYogaAlignItemsProperty = @"ASYogaAlignItemsProperty";
NSString * const ASYogaPositionTypeProperty = @"ASYogaPositionTypeProperty";
NSString * const ASYogaPositionProperty = @"ASYogaPositionProperty";
NSString * const ASYogaMarginProperty = @"ASYogaMarginProperty";
NSString * const ASYogaPaddingProperty = @"ASYogaPaddingProperty";
NSString * const ASYogaBorderProperty = @"ASYogaBorderProperty";
NSString * const ASYogaAspectRatioProperty = @"ASYogaAspectRatioProperty";
#endif

#define ASLayoutElementStyleSetSizeWithScope(x) \
  __instanceLock__.lock(); \
  ASLayoutElementSize newSize = _size.load(); \
  { x } \
  _size.store(newSize); \
  __instanceLock__.unlock();

#define ASLayoutElementStyleCallDelegate(propertyName)\
do {\
  [self propertyDidChange:propertyName];\
  [_delegate style:self propertyDidChange:propertyName];\
} while(0)

@implementation ASLayoutElementStyle {
  AS::RecursiveMutex __instanceLock__;
  ASLayoutElementStyleExtensions _extensions;

  std::atomic<ASLayoutElementSize> _size;
  std::atomic<CGFloat> _spacingBefore;
  std::atomic<CGFloat> _spacingAfter;
  std::atomic<CGFloat> _flexGrow;
  std::atomic<CGFloat> _flexShrink;
  std::atomic<ASDimension> _flexBasis;
  std::atomic<ASStackLayoutAlignSelf> _alignSelf;
  std::atomic<CGFloat> _ascender;
  std::atomic<CGFloat> _descender;
  std::atomic<CGPoint> _layoutPosition;

#if YOGA
  YGNodeRef _yogaNode;
  std::atomic<YGWrap> _flexWrap;
  std::atomic<ASStackLayoutDirection> _flexDirection;
  std::atomic<YGDirection> _direction;
  std::atomic<ASStackLayoutJustifyContent> _justifyContent;
  std::atomic<ASStackLayoutAlignItems> _alignItems;
  std::atomic<YGPositionType> _positionType;
  std::atomic<ASEdgeInsets> _position;
  std::atomic<ASEdgeInsets> _margin;
  std::atomic<ASEdgeInsets> _padding;
  std::atomic<ASEdgeInsets> _border;
  std::atomic<CGFloat> _aspectRatio;
  ASStackLayoutAlignItems _parentAlignStyle;
#endif
}

@dynamic width, height, minWidth, maxWidth, minHeight, maxHeight;
@dynamic preferredSize, minSize, maxSize, preferredLayoutSize, minLayoutSize, maxLayoutSize;

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(id<ASLayoutElementStyleDelegate>)delegate
{
  self = [self init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _size = ASLayoutElementSizeMake();
#if YOGA
    _parentAlignStyle = ASStackLayoutAlignItemsNotSet;
#endif
  }
  return self;
}

ASSynthesizeLockingMethodsWithMutex(__instanceLock__)

#pragma mark - ASLayoutElementStyleSize

- (ASLayoutElementSize)size
{
  return _size.load();
}

- (void)setSize:(ASLayoutElementSize)size
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize = size;
  });
  // No CallDelegate method as ASLayoutElementSize is currently internal.
}

#pragma mark - ASLayoutElementStyleSizeForwarding

- (ASDimension)width
{
  return _size.load().width;
}

- (void)setWidth:(ASDimension)width
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.width = width;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
}

- (ASDimension)height
{
  return _size.load().height;
}

- (void)setHeight:(ASDimension)height
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.height = height;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (ASDimension)minWidth
{
  return _size.load().minWidth;
}

- (void)setMinWidth:(ASDimension)minWidth
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.minWidth = minWidth;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
}

- (ASDimension)maxWidth
{
  return _size.load().maxWidth;
}

- (void)setMaxWidth:(ASDimension)maxWidth
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.maxWidth = maxWidth;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
}

- (ASDimension)minHeight
{
  return _size.load().minHeight;
}

- (void)setMinHeight:(ASDimension)minHeight
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.minHeight = minHeight;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (ASDimension)maxHeight
{
  return _size.load().maxHeight;
}

- (void)setMaxHeight:(ASDimension)maxHeight
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.maxHeight = maxHeight;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}


#pragma mark - ASLayoutElementStyleSizeHelpers

- (void)setPreferredSize:(CGSize)preferredSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.width = ASDimensionMakeWithPoints(preferredSize.width);
    newSize.height = ASDimensionMakeWithPoints(preferredSize.height);
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (CGSize)preferredSize
{
  ASLayoutElementSize size = _size.load();
  if (size.width.unit == ASDimensionUnitFraction) {
    NSCAssert(NO, @"Cannot get preferredSize of element with fractional width. Width: %@.", NSStringFromASDimension(size.width));
    return CGSizeZero;
  }
  
  if (size.height.unit == ASDimensionUnitFraction) {
    NSCAssert(NO, @"Cannot get preferredSize of element with fractional height. Height: %@.", NSStringFromASDimension(size.height));
    return CGSizeZero;
  }
  
  return CGSizeMake(size.width.value, size.height.value);
}

- (void)setMinSize:(CGSize)minSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.minWidth = ASDimensionMakeWithPoints(minSize.width);
    newSize.minHeight = ASDimensionMakeWithPoints(minSize.height);
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (void)setMaxSize:(CGSize)maxSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.maxWidth = ASDimensionMakeWithPoints(maxSize.width);
    newSize.maxHeight = ASDimensionMakeWithPoints(maxSize.height);
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}

- (ASLayoutSize)preferredLayoutSize
{
  ASLayoutElementSize size = _size.load();
  return ASLayoutSizeMake(size.width, size.height);
}

- (void)setPreferredLayoutSize:(ASLayoutSize)preferredLayoutSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.width = preferredLayoutSize.width;
    newSize.height = preferredLayoutSize.height;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (ASLayoutSize)minLayoutSize
{
  ASLayoutElementSize size = _size.load();
  return ASLayoutSizeMake(size.minWidth, size.minHeight);
}

- (void)setMinLayoutSize:(ASLayoutSize)minLayoutSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.minWidth = minLayoutSize.width;
    newSize.minHeight = minLayoutSize.height;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (ASLayoutSize)maxLayoutSize
{
  ASLayoutElementSize size = _size.load();
  return ASLayoutSizeMake(size.maxWidth, size.maxHeight);
}

- (void)setMaxLayoutSize:(ASLayoutSize)maxLayoutSize
{
  ASLayoutElementStyleSetSizeWithScope({
    newSize.maxWidth = maxLayoutSize.width;
    newSize.maxHeight = maxLayoutSize.height;
  });
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}

#pragma mark - ASStackLayoutElement

- (void)setSpacingBefore:(CGFloat)spacingBefore
{
  _spacingBefore.store(spacingBefore);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingBeforeProperty);
}

- (CGFloat)spacingBefore
{
  return _spacingBefore.load();
}

- (void)setSpacingAfter:(CGFloat)spacingAfter
{
  _spacingAfter.store(spacingAfter);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingAfterProperty);
}

- (CGFloat)spacingAfter
{
  return _spacingAfter.load();
}

- (void)setFlexGrow:(CGFloat)flexGrow
{
  _flexGrow.store(flexGrow);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexGrowProperty);
}

- (CGFloat)flexGrow
{
  return _flexGrow.load();
}

- (void)setFlexShrink:(CGFloat)flexShrink
{
  _flexShrink.store(flexShrink);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexShrinkProperty);
}

- (CGFloat)flexShrink
{
  return _flexShrink.load();
}

- (void)setFlexBasis:(ASDimension)flexBasis
{
  _flexBasis.store(flexBasis);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexBasisProperty);
}

- (ASDimension)flexBasis
{
  return _flexBasis.load();
}

- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf
{
  _alignSelf.store(alignSelf);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAlignSelfProperty);
}

- (ASStackLayoutAlignSelf)alignSelf
{
  return _alignSelf.load();
}

- (void)setAscender:(CGFloat)ascender
{
  _ascender.store(ascender);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAscenderProperty);
}

- (CGFloat)ascender
{
  return _ascender.load();
}

- (void)setDescender:(CGFloat)descender
{
  _descender.store(descender);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleDescenderProperty);
}

- (CGFloat)descender
{
  return _descender.load();
}

#pragma mark - ASAbsoluteLayoutElement

- (void)setLayoutPosition:(CGPoint)layoutPosition
{
  _layoutPosition.store(layoutPosition);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleLayoutPositionProperty);
}

- (CGPoint)layoutPosition
{
  return _layoutPosition.load();
}

#pragma mark - Extensions

- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementBoolExtensions, @"Setting index outside of max bool extensions space");
  
  MutexLocker l(__instanceLock__);
  _extensions.boolExtensions[idx] = value;
}

- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx\
{
  NSCAssert(idx < kMaxLayoutElementBoolExtensions, @"Accessing index outside of max bool extensions space");
  
  MutexLocker l(__instanceLock__);
  return _extensions.boolExtensions[idx];
}

- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateIntegerExtensions, @"Setting index outside of max integer extensions space");
  
  MutexLocker l(__instanceLock__);
  _extensions.integerExtensions[idx] = value;
}

- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateIntegerExtensions, @"Accessing index outside of max integer extensions space");
  
  MutexLocker l(__instanceLock__);
  return _extensions.integerExtensions[idx];
}

- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateEdgeInsetExtensions, @"Setting index outside of max edge insets extensions space");
  
  MutexLocker l(__instanceLock__);
  _extensions.edgeInsetsExtensions[idx] = value;
}

- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateEdgeInsetExtensions, @"Accessing index outside of max edge insets extensions space");
  
  MutexLocker l(__instanceLock__);
  return _extensions.edgeInsetsExtensions[idx];
}

#pragma mark - Debugging

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  
  if ((self.minLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.minLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"minLayoutSize" : NSStringFromASLayoutSize(self.minLayoutSize) }];
  }
  
  if ((self.preferredLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.preferredLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"preferredSize" : NSStringFromASLayoutSize(self.preferredLayoutSize) }];
  }
  
  if ((self.maxLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.maxLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"maxLayoutSize" : NSStringFromASLayoutSize(self.maxLayoutSize) }];
  }
  
  if (self.alignSelf != ASStackLayoutAlignSelfAuto) {
    [result addObject:@{ @"alignSelf" : [@[@"ASStackLayoutAlignSelfAuto",
                                          @"ASStackLayoutAlignSelfStart",
                                          @"ASStackLayoutAlignSelfEnd",
                                          @"ASStackLayoutAlignSelfCenter",
                                          @"ASStackLayoutAlignSelfStretch"] objectAtIndex:self.alignSelf] }];
  }
  
  if (self.ascender != 0) {
    [result addObject:@{ @"ascender" : @(self.ascender) }];
  }
  
  if (self.descender != 0) {
    [result addObject:@{ @"descender" : @(self.descender) }];
  }
  
  if (ASDimensionEqualToDimension(self.flexBasis, ASDimensionAuto) == NO) {
    [result addObject:@{ @"flexBasis" : NSStringFromASDimension(self.flexBasis) }];
  }
  
  if (self.flexGrow != 0) {
    [result addObject:@{ @"flexGrow" : @(self.flexGrow) }];
  }
  
  if (self.flexShrink != 0) {
    [result addObject:@{ @"flexShrink" : @(self.flexShrink) }];
  }
  
  if (self.spacingAfter != 0) {
    [result addObject:@{ @"spacingAfter" : @(self.spacingAfter) }];
  }
  
  if (self.spacingBefore != 0) {
    [result addObject:@{ @"spacingBefore" : @(self.spacingBefore) }];
  }
  
  if (CGPointEqualToPoint(self.layoutPosition, CGPointZero) == NO) {
    [result addObject:@{ @"layoutPosition" : [NSValue valueWithCGPoint:self.layoutPosition] }];
  }

  return result;
}

- (void)propertyDidChange:(NSString *)propertyName
{
#if YOGA
  /* TODO(appleguy): STYLE SETTER METHODS LEFT TO IMPLEMENT
   void YGNodeStyleSetOverflow(YGNodeRef node, YGOverflow overflow);
   void YGNodeStyleSetFlex(YGNodeRef node, float flex);
   */

  if (_yogaNode == NULL) {
    return;
  }
  // Because the NSStrings used to identify each property are const, use efficient pointer comparison.
  if (propertyName == ASLayoutElementStyleWidthProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, Width, self.width);
  }
  else if (propertyName == ASLayoutElementStyleMinWidthProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, MinWidth, self.minWidth);
  }
  else if (propertyName == ASLayoutElementStyleMaxWidthProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, MaxWidth, self.maxWidth);
  }
  else if (propertyName == ASLayoutElementStyleHeightProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, Height, self.height);
  }
  else if (propertyName == ASLayoutElementStyleMinHeightProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, MinHeight, self.minHeight);
  }
  else if (propertyName == ASLayoutElementStyleMaxHeightProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, MaxHeight, self.maxHeight);
  }
  else if (propertyName == ASLayoutElementStyleFlexGrowProperty) {
    YGNodeStyleSetFlexGrow(_yogaNode, self.flexGrow);
  }
  else if (propertyName == ASLayoutElementStyleFlexShrinkProperty) {
    YGNodeStyleSetFlexShrink(_yogaNode, self.flexShrink);
  }
  else if (propertyName == ASLayoutElementStyleFlexBasisProperty) {
    YGNODE_STYLE_SET_DIMENSION(_yogaNode, FlexBasis, self.flexBasis);
  }
  else if (propertyName == ASLayoutElementStyleAlignSelfProperty) {
    YGNodeStyleSetAlignSelf(_yogaNode, yogaAlignSelf(self.alignSelf));
  }
  else if (propertyName == ASYogaFlexWrapProperty) {
    YGNodeStyleSetFlexWrap(_yogaNode, self.flexWrap);
  }
  else if (propertyName == ASYogaFlexDirectionProperty) {
    YGNodeStyleSetFlexDirection(_yogaNode, yogaFlexDirection(self.flexDirection));
  }
  else if (propertyName == ASYogaDirectionProperty) {
    YGNodeStyleSetDirection(_yogaNode, self.direction);
  }
  else if (propertyName == ASYogaJustifyContentProperty) {
    YGNodeStyleSetJustifyContent(_yogaNode, yogaJustifyContent(self.justifyContent));
  }
  else if (propertyName == ASYogaAlignItemsProperty) {
    ASStackLayoutAlignItems alignItems = self.alignItems;
    if (alignItems != ASStackLayoutAlignItemsNotSet) {
      YGNodeStyleSetAlignItems(_yogaNode, yogaAlignItems(alignItems));
    }
  }
  else if (propertyName == ASYogaPositionTypeProperty) {
    YGNodeStyleSetPositionType(_yogaNode, self.positionType);
  }
  else if (propertyName == ASYogaPositionProperty) {
    ASEdgeInsets position = self.position;
    YGEdge edge = YGEdgeLeft;
    for (int i = 0; i < YGEdgeAll + 1; ++i) {
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(_yogaNode, Position, dimensionForEdgeWithEdgeInsets(edge, position), edge);
      edge = (YGEdge)(edge + 1);
    }
  }
  else if (propertyName == ASYogaMarginProperty) {
    ASEdgeInsets margin   = self.margin;
    YGEdge edge = YGEdgeLeft;
    for (int i = 0; i < YGEdgeAll + 1; ++i) {
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(_yogaNode, Margin, dimensionForEdgeWithEdgeInsets(edge, margin), edge);
      edge = (YGEdge)(edge + 1);
    }
  }
  else if (propertyName == ASYogaPaddingProperty) {
    ASEdgeInsets padding  = self.padding;
    YGEdge edge = YGEdgeLeft;
    for (int i = 0; i < YGEdgeAll + 1; ++i) {
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(_yogaNode, Padding, dimensionForEdgeWithEdgeInsets(edge, padding), edge);
      edge = (YGEdge)(edge + 1);
    }
  }
  else if (propertyName == ASYogaBorderProperty) {
    ASEdgeInsets border   = self.border;
    YGEdge edge = YGEdgeLeft;
    for (int i = 0; i < YGEdgeAll + 1; ++i) {
      YGNODE_STYLE_SET_FLOAT_WITH_EDGE(_yogaNode, Border, dimensionForEdgeWithEdgeInsets(edge, border), edge);
      edge = (YGEdge)(edge + 1);
    }
  }
  else if (propertyName == ASYogaAspectRatioProperty) {
    CGFloat aspectRatio = self.aspectRatio;
    if (aspectRatio > FLT_EPSILON && aspectRatio < CGFLOAT_MAX / 2.0) {
      YGNodeStyleSetAspectRatio(_yogaNode, aspectRatio);
    }
  }
#endif
}

#pragma mark - Yoga Flexbox Properties

#if YOGA

+ (void)initialize
{
  [super initialize];
  YGConfigSetPointScaleFactor(YGConfigGetDefault(), ASScreenScale());
  // Yoga recommends using Web Defaults for all new projects. This will be enabled for Texture very soon.
  //YGConfigSetUseWebDefaults(YGConfigGetDefault(), true);
}

- (YGNodeRef)yogaNode
{
  return _yogaNode;
}

- (YGNodeRef)yogaNodeCreateIfNeeded
{
  if (_yogaNode == NULL) {
    _yogaNode = YGNodeNew();
  }
  return _yogaNode;
}

- (void)destroyYogaNode
{
  if (_yogaNode != NULL) {
    // Release the __bridge_retained Context object.
    ASLayoutElementYogaUpdateMeasureFunc(_yogaNode, nil);
    YGNodeFree(_yogaNode);
    _yogaNode = NULL;
  }
}

- (void)dealloc
{
  [self destroyYogaNode];
}

- (YGWrap)flexWrap                            { return _flexWrap.load(); }
- (ASStackLayoutDirection)flexDirection       { return _flexDirection.load(); }
- (YGDirection)direction                      { return _direction.load(); }
- (ASStackLayoutJustifyContent)justifyContent { return _justifyContent.load(); }
- (ASStackLayoutAlignItems)alignItems         { return _alignItems.load(); }
- (YGPositionType)positionType                { return _positionType.load(); }
- (ASEdgeInsets)position                      { return _position.load(); }
- (ASEdgeInsets)margin                        { return _margin.load(); }
- (ASEdgeInsets)padding                       { return _padding.load(); }
- (ASEdgeInsets)border                        { return _border.load(); }
- (CGFloat)aspectRatio                        { return _aspectRatio.load(); }
// private (ASLayoutElementStylePrivate.h)
- (ASStackLayoutAlignItems)parentAlignStyle {
  return _parentAlignStyle;
}

- (void)setFlexWrap:(YGWrap)flexWrap {
  _flexWrap.store(flexWrap);
  ASLayoutElementStyleCallDelegate(ASYogaFlexWrapProperty);
}
- (void)setFlexDirection:(ASStackLayoutDirection)flexDirection {
  _flexDirection.store(flexDirection);
  ASLayoutElementStyleCallDelegate(ASYogaFlexDirectionProperty);
}
- (void)setDirection:(YGDirection)direction {
  _direction.store(direction);
  ASLayoutElementStyleCallDelegate(ASYogaDirectionProperty);
}
- (void)setJustifyContent:(ASStackLayoutJustifyContent)justify {
  _justifyContent.store(justify);
  ASLayoutElementStyleCallDelegate(ASYogaJustifyContentProperty);
}
- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems {
  _alignItems.store(alignItems);
  ASLayoutElementStyleCallDelegate(ASYogaAlignItemsProperty);
}
- (void)setPositionType:(YGPositionType)positionType {
  _positionType.store(positionType);
  ASLayoutElementStyleCallDelegate(ASYogaPositionTypeProperty);
}
- (void)setPosition:(ASEdgeInsets)position {
  _position.store(position);
  ASLayoutElementStyleCallDelegate(ASYogaPositionProperty);
}
- (void)setMargin:(ASEdgeInsets)margin {
  _margin.store(margin);
  ASLayoutElementStyleCallDelegate(ASYogaMarginProperty);
}
- (void)setPadding:(ASEdgeInsets)padding {
  _padding.store(padding);
  ASLayoutElementStyleCallDelegate(ASYogaPaddingProperty);
}
- (void)setBorder:(ASEdgeInsets)border {
  _border.store(border);
  ASLayoutElementStyleCallDelegate(ASYogaBorderProperty);
}
- (void)setAspectRatio:(CGFloat)aspectRatio {
  _aspectRatio.store(aspectRatio);
  ASLayoutElementStyleCallDelegate(ASYogaAspectRatioProperty);
}
// private (ASLayoutElementStylePrivate.h)
- (void)setParentAlignStyle:(ASStackLayoutAlignItems)style {
  _parentAlignStyle = style;
}

#endif /* YOGA */

@end
