//
//  _ASPendingState.mm
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

#import <AsyncDisplayKit/_ASPendingState.h>

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

#define __shouldSetNeedsDisplay(layer) (flags.needsDisplay \
  || (flags.setOpaque && opaque != (layer).opaque)\
  || (flags.setBackgroundColor && !CGColorEqualToColor(backgroundColor, (layer).backgroundColor)))

typedef struct {
  // Properties
  int needsDisplay:1;
  int needsLayout:1;
  int layoutIfNeeded:1;
  
  // Flags indicating that a given property should be applied to the view at creation
  int setClipsToBounds:1;
  int setOpaque:1;
  int setNeedsDisplayOnBoundsChange:1;
  int setAutoresizesSubviews:1;
  int setAutoresizingMask:1;
  int setFrame:1;
  int setBounds:1;
  int setBackgroundColor:1;
  int setTintColor:1;
  int setHidden:1;
  int setAlpha:1;
  int setCornerRadius:1;
  int setContentMode:1;
  int setNeedsDisplay:1;
  int setAnchorPoint:1;
  int setPosition:1;
  int setZPosition:1;
  int setTransform:1;
  int setSublayerTransform:1;
  int setContents:1;
  int setContentsGravity:1;
  int setContentsRect:1;
  int setContentsCenter:1;
  int setContentsScale:1;
  int setRasterizationScale:1;
  int setUserInteractionEnabled:1;
  int setExclusiveTouch:1;
  int setShadowColor:1;
  int setShadowOpacity:1;
  int setShadowOffset:1;
  int setShadowRadius:1;
  int setBorderWidth:1;
  int setBorderColor:1;
  int setAsyncTransactionContainer:1;
  int setAllowsGroupOpacity:1;
  int setAllowsEdgeAntialiasing:1;
  int setEdgeAntialiasingMask:1;
  int setIsAccessibilityElement:1;
  int setAccessibilityLabel:1;
  int setAccessibilityAttributedLabel:1;
  int setAccessibilityHint:1;
  int setAccessibilityAttributedHint:1;
  int setAccessibilityValue:1;
  int setAccessibilityAttributedValue:1;
  int setAccessibilityTraits:1;
  int setAccessibilityFrame:1;
  int setAccessibilityLanguage:1;
  int setAccessibilityElementsHidden:1;
  int setAccessibilityViewIsModal:1;
  int setShouldGroupAccessibilityChildren:1;
  int setAccessibilityIdentifier:1;
  int setAccessibilityNavigationStyle:1;
  int setAccessibilityHeaderElements:1;
  int setAccessibilityActivationPoint:1;
  int setAccessibilityPath:1;
  int setSemanticContentAttribute:1;
  int setLayoutMargins:1;
  int setPreservesSuperviewLayoutMargins:1;
  int setInsetsLayoutMarginsFromSafeArea:1;
} ASPendingStateFlags;

@implementation _ASPendingState
{
  @package //Expose all ivars for ASDisplayNode to bypass getters for efficiency

  UIViewAutoresizing autoresizingMask;
  unsigned int edgeAntialiasingMask;
  CGRect frame;   // Frame is only to be used for synchronous views wrapped by nodes (see setFrame:)
  CGRect bounds;
  CGColorRef backgroundColor;
  CGFloat alpha;
  CGFloat cornerRadius;
  UIViewContentMode contentMode;
  CGPoint anchorPoint;
  CGPoint position;
  CGFloat zPosition;
  CATransform3D transform;
  CATransform3D sublayerTransform;
  id contents;
  NSString *contentsGravity;
  CGRect contentsRect;
  CGRect contentsCenter;
  CGFloat contentsScale;
  CGFloat rasterizationScale;
  CGColorRef shadowColor;
  CGFloat shadowOpacity;
  CGSize shadowOffset;
  CGFloat shadowRadius;
  CGFloat borderWidth;
  CGColorRef borderColor;
  BOOL asyncTransactionContainer;
  UIEdgeInsets layoutMargins;
  BOOL preservesSuperviewLayoutMargins;
  BOOL insetsLayoutMarginsFromSafeArea;
  BOOL isAccessibilityElement;
  NSString *accessibilityLabel;
  NSAttributedString *accessibilityAttributedLabel;
  NSString *accessibilityHint;
  NSAttributedString *accessibilityAttributedHint;
  NSString *accessibilityValue;
  NSAttributedString *accessibilityAttributedValue;
  UIAccessibilityTraits accessibilityTraits;
  CGRect accessibilityFrame;
  NSString *accessibilityLanguage;
  BOOL accessibilityElementsHidden;
  BOOL accessibilityViewIsModal;
  BOOL shouldGroupAccessibilityChildren;
  NSString *accessibilityIdentifier;
  UIAccessibilityNavigationStyle accessibilityNavigationStyle;
  NSArray *accessibilityHeaderElements;
  CGPoint accessibilityActivationPoint;
  UIBezierPath *accessibilityPath;
  UISemanticContentAttribute semanticContentAttribute API_AVAILABLE(ios(9.0), tvos(9.0));

  ASPendingStateFlags _flags;
}

/**
 * Apply the state's frame, bounds, and position to layer. This will not
 * be called on synchronous view-backed nodes which require we directly
 * call [view setFrame:].
 *
 * FIXME: How should we reconcile order-of-operations between setting frame, bounds, position?
 * Note we can't read bounds and position in the background, so we have to keep the frame
 * value intact until application time (now).
 */
ASDISPLAYNODE_INLINE void ASPendingStateApplyMetricsToLayer(_ASPendingState *state, CALayer *layer) {
  ASPendingStateFlags flags = state->_flags;
  if (flags.setFrame) {
    CGRect _bounds = CGRectZero;
    CGPoint _position = CGPointZero;
    ASBoundsAndPositionForFrame(state->frame, layer.bounds.origin, layer.anchorPoint, &_bounds, &_position);
    layer.bounds = _bounds;
    layer.position = _position;
  } else {
    if (flags.setBounds)
      layer.bounds = state->bounds;
    if (flags.setPosition)
      layer.position = state->position;
  }
}

@synthesize clipsToBounds=clipsToBounds;
@synthesize opaque=opaque;
@synthesize frame=frame;
@synthesize bounds=bounds;
@synthesize backgroundColor=backgroundColor;
@synthesize hidden=isHidden;
@synthesize needsDisplayOnBoundsChange=needsDisplayOnBoundsChange;
@synthesize allowsGroupOpacity=allowsGroupOpacity;
@synthesize allowsEdgeAntialiasing=allowsEdgeAntialiasing;
@synthesize edgeAntialiasingMask=edgeAntialiasingMask;
@synthesize autoresizesSubviews=autoresizesSubviews;
@synthesize autoresizingMask=autoresizingMask;
@synthesize tintColor=tintColor;
@synthesize alpha=alpha;
@synthesize cornerRadius=cornerRadius;
@synthesize contentMode=contentMode;
@synthesize anchorPoint=anchorPoint;
@synthesize position=position;
@synthesize zPosition=zPosition;
@synthesize transform=transform;
@synthesize sublayerTransform=sublayerTransform;
@synthesize contents=contents;
@synthesize contentsGravity=contentsGravity;
@synthesize contentsRect=contentsRect;
@synthesize contentsCenter=contentsCenter;
@synthesize contentsScale=contentsScale;
@synthesize rasterizationScale=rasterizationScale;
@synthesize userInteractionEnabled=userInteractionEnabled;
@synthesize exclusiveTouch=exclusiveTouch;
@synthesize shadowColor=shadowColor;
@synthesize shadowOpacity=shadowOpacity;
@synthesize shadowOffset=shadowOffset;
@synthesize shadowRadius=shadowRadius;
@synthesize borderWidth=borderWidth;
@synthesize borderColor=borderColor;
@synthesize asyncdisplaykit_asyncTransactionContainer=asyncTransactionContainer;
@synthesize semanticContentAttribute=semanticContentAttribute;
@synthesize layoutMargins=layoutMargins;
@synthesize preservesSuperviewLayoutMargins=preservesSuperviewLayoutMargins;
@synthesize insetsLayoutMarginsFromSafeArea=insetsLayoutMarginsFromSafeArea;

static CGColorRef blackColorRef = NULL;
static UIColor *defaultTintColor = nil;

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;


  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Default UIKit color is an RGB color
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    blackColorRef = CGColorCreate(colorSpace, (CGFloat[]){0,0,0,1} );
    CFRetain(blackColorRef);
    CGColorSpaceRelease(colorSpace);
    defaultTintColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
  });

  // Set defaults, these come from the defaults specified in CALayer and UIView
  clipsToBounds = NO;
  opaque = YES;
  frame = CGRectZero;
  bounds = CGRectZero;
  backgroundColor = nil;
  tintColor = defaultTintColor;
  isHidden = NO;
  needsDisplayOnBoundsChange = NO;
  allowsGroupOpacity = ASDefaultAllowsGroupOpacity();
  allowsEdgeAntialiasing = ASDefaultAllowsEdgeAntialiasing();
  autoresizesSubviews = YES;
  alpha = 1.0f;
  cornerRadius = 0.0f;
  contentMode = UIViewContentModeScaleToFill;
  _flags.needsDisplay = NO;
  anchorPoint = CGPointMake(0.5, 0.5);
  position = CGPointZero;
  zPosition = 0.0;
  transform = CATransform3DIdentity;
  sublayerTransform = CATransform3DIdentity;
  contents = nil;
  contentsGravity = kCAGravityResize;
  contentsRect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
  contentsCenter = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
  contentsScale = 1.0f;
  rasterizationScale = 1.0f;
  userInteractionEnabled = YES;
  shadowColor = blackColorRef;
  shadowOpacity = 0.0;
  shadowOffset = CGSizeMake(0, -3);
  shadowRadius = 3;
  borderWidth = 0;
  borderColor = blackColorRef;
  layoutMargins = UIEdgeInsetsMake(8, 8, 8, 8);
  preservesSuperviewLayoutMargins = NO;
  insetsLayoutMarginsFromSafeArea = YES;
  isAccessibilityElement = NO;
  accessibilityLabel = nil;
  accessibilityAttributedLabel = nil;
  accessibilityHint = nil;
  accessibilityAttributedHint = nil;
  accessibilityValue = nil;
  accessibilityAttributedValue = nil;
  accessibilityTraits = UIAccessibilityTraitNone;
  accessibilityFrame = CGRectZero;
  accessibilityLanguage = nil;
  accessibilityElementsHidden = NO;
  accessibilityViewIsModal = NO;
  shouldGroupAccessibilityChildren = NO;
  accessibilityIdentifier = nil;
  accessibilityNavigationStyle = UIAccessibilityNavigationStyleAutomatic;
  accessibilityHeaderElements = nil;
  accessibilityActivationPoint = CGPointZero;
  accessibilityPath = nil;
  edgeAntialiasingMask = (kCALayerLeftEdge | kCALayerRightEdge | kCALayerTopEdge | kCALayerBottomEdge);
  semanticContentAttribute = UISemanticContentAttributeUnspecified;

  return self;
}

- (void)setNeedsDisplay
{
  _flags.needsDisplay = YES;
}

- (void)setNeedsLayout
{
  _flags.needsLayout = YES;
}

- (void)layoutIfNeeded
{
  _flags.layoutIfNeeded = YES;
}

- (void)setClipsToBounds:(BOOL)flag
{
  clipsToBounds = flag;
  _flags.setClipsToBounds = YES;
}

- (void)setOpaque:(BOOL)flag
{
  opaque = flag;
  _flags.setOpaque = YES;
}

- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag
{
  needsDisplayOnBoundsChange = flag;
  _flags.setNeedsDisplayOnBoundsChange = YES;
}

- (void)setAllowsGroupOpacity:(BOOL)flag
{
  allowsGroupOpacity = flag;
  _flags.setAllowsGroupOpacity = YES;
}

- (void)setAllowsEdgeAntialiasing:(BOOL)flag
{
  allowsEdgeAntialiasing = flag;
  _flags.setAllowsEdgeAntialiasing = YES;
}

- (void)setEdgeAntialiasingMask:(unsigned int)mask
{
  edgeAntialiasingMask = mask;
  _flags.setEdgeAntialiasingMask = YES;
}

- (void)setAutoresizesSubviews:(BOOL)flag
{
  autoresizesSubviews = flag;
  _flags.setAutoresizesSubviews = YES;
}

- (void)setAutoresizingMask:(UIViewAutoresizing)mask
{
  autoresizingMask = mask;
  _flags.setAutoresizingMask = YES;
}

- (void)setFrame:(CGRect)newFrame
{
  frame = newFrame;
  _flags.setFrame = YES;
}

- (void)setBounds:(CGRect)newBounds
{
  ASDisplayNodeAssert(!isnan(newBounds.size.width) && !isnan(newBounds.size.height), @"Invalid bounds %@ provided to %@", NSStringFromCGRect(newBounds), self);
  if (isnan(newBounds.size.width))
    newBounds.size.width = 0.0;
  if (isnan(newBounds.size.height))
    newBounds.size.height = 0.0;
  bounds = newBounds;
  _flags.setBounds = YES;
}

- (CGColorRef)backgroundColor
{
  return backgroundColor;
}

- (void)setBackgroundColor:(CGColorRef)color
{
  if (color == backgroundColor) {
    return;
  }

  CGColorRelease(backgroundColor);
  backgroundColor = CGColorRetain(color);
  _flags.setBackgroundColor = YES;
}

- (void)setTintColor:(UIColor *)newTintColor
{
  tintColor = newTintColor;
  _flags.setTintColor = YES;
}

- (void)setHidden:(BOOL)flag
{
  isHidden = flag;
  _flags.setHidden = YES;
}

- (void)setAlpha:(CGFloat)newAlpha
{
  alpha = newAlpha;
  _flags.setAlpha = YES;
}

- (void)setCornerRadius:(CGFloat)newCornerRadius
{
  cornerRadius = newCornerRadius;
  _flags.setCornerRadius = YES;
}

- (void)setContentMode:(UIViewContentMode)newContentMode
{
  contentMode = newContentMode;
  _flags.setContentMode = YES;
}

- (void)setAnchorPoint:(CGPoint)newAnchorPoint
{
  anchorPoint = newAnchorPoint;
  _flags.setAnchorPoint = YES;
}

- (void)setPosition:(CGPoint)newPosition
{
  ASDisplayNodeAssert(!isnan(newPosition.x) && !isnan(newPosition.y), @"Invalid position %@ provided to %@", NSStringFromCGPoint(newPosition), self);
  if (isnan(newPosition.x))
    newPosition.x = 0.0;
  if (isnan(newPosition.y))
    newPosition.y = 0.0;
  position = newPosition;
  _flags.setPosition = YES;
}

- (void)setZPosition:(CGFloat)newPosition
{
  zPosition = newPosition;
  _flags.setZPosition = YES;
}

- (void)setTransform:(CATransform3D)newTransform
{
  transform = newTransform;
  _flags.setTransform = YES;
}

- (void)setSublayerTransform:(CATransform3D)newSublayerTransform
{
  sublayerTransform = newSublayerTransform;
  _flags.setSublayerTransform = YES;
}

- (void)setContents:(id)newContents
{
  if (contents == newContents) {
    return;
  }

  contents = newContents;
  _flags.setContents = YES;
}

- (void)setContentsGravity:(NSString *)newContentsGravity
{
  contentsGravity = newContentsGravity;
  _flags.setContentsGravity = YES;
}

- (void)setContentsRect:(CGRect)newContentsRect
{
  contentsRect = newContentsRect;
  _flags.setContentsRect = YES;
}

- (void)setContentsCenter:(CGRect)newContentsCenter
{
  contentsCenter = newContentsCenter;
  _flags.setContentsCenter = YES;
}

- (void)setContentsScale:(CGFloat)newContentsScale
{
  contentsScale = newContentsScale;
  _flags.setContentsScale = YES;
}

- (void)setRasterizationScale:(CGFloat)newRasterizationScale
{
  rasterizationScale = newRasterizationScale;
  _flags.setRasterizationScale = YES;
}

- (void)setUserInteractionEnabled:(BOOL)flag
{
  userInteractionEnabled = flag;
  _flags.setUserInteractionEnabled = YES;
}

- (void)setExclusiveTouch:(BOOL)flag
{
  exclusiveTouch = flag;
  _flags.setExclusiveTouch = YES;
}

- (void)setShadowColor:(CGColorRef)color
{
  if (shadowColor == color) {
    return;
  }

  if (shadowColor != blackColorRef) {
    CGColorRelease(shadowColor);
  }
  shadowColor = color;
  CGColorRetain(shadowColor);

  _flags.setShadowColor = YES;
}

- (void)setShadowOpacity:(CGFloat)newOpacity
{
  shadowOpacity = newOpacity;
  _flags.setShadowOpacity = YES;
}

- (void)setShadowOffset:(CGSize)newOffset
{
  shadowOffset = newOffset;
  _flags.setShadowOffset = YES;
}

- (void)setShadowRadius:(CGFloat)newRadius
{
  shadowRadius = newRadius;
  _flags.setShadowRadius = YES;
}

- (void)setBorderWidth:(CGFloat)newWidth
{
  borderWidth = newWidth;
  _flags.setBorderWidth = YES;
}

- (void)setBorderColor:(CGColorRef)color
{
  if (borderColor == color) {
    return;
  }

  if (borderColor != blackColorRef) {
    CGColorRelease(borderColor);
  }
  borderColor = color;
  CGColorRetain(borderColor);

  _flags.setBorderColor = YES;
}

- (void)asyncdisplaykit_setAsyncTransactionContainer:(BOOL)flag
{
  asyncTransactionContainer = flag;
  _flags.setAsyncTransactionContainer = YES;
}

- (void)setLayoutMargins:(UIEdgeInsets)margins
{
  layoutMargins = margins;
  _flags.setLayoutMargins = YES;
}

- (void)setPreservesSuperviewLayoutMargins:(BOOL)flag
{
  preservesSuperviewLayoutMargins = flag;
  _flags.setPreservesSuperviewLayoutMargins = YES;
}

- (void)setInsetsLayoutMarginsFromSafeArea:(BOOL)flag
{
  insetsLayoutMarginsFromSafeArea = flag;
  _flags.setInsetsLayoutMarginsFromSafeArea = YES;
}

- (void)setSemanticContentAttribute:(UISemanticContentAttribute)attribute API_AVAILABLE(ios(9.0), tvos(9.0)) {
  semanticContentAttribute = attribute;
  _flags.setSemanticContentAttribute = YES;
}

- (BOOL)isAccessibilityElement
{
  return isAccessibilityElement;
}

- (void)setIsAccessibilityElement:(BOOL)newIsAccessibilityElement
{
  isAccessibilityElement = newIsAccessibilityElement;
  _flags.setIsAccessibilityElement = YES;
}

- (NSString *)accessibilityLabel
{
  return accessibilityLabel;
}

- (void)setAccessibilityLabel:(NSString *)newAccessibilityLabel
{
  if (! ASObjectIsEqual(accessibilityLabel, newAccessibilityLabel)) {
    _flags.setAccessibilityLabel = YES;
    _flags.setAccessibilityAttributedLabel = YES;
    accessibilityLabel = newAccessibilityLabel ? [newAccessibilityLabel copy] : nil;
    accessibilityAttributedLabel = newAccessibilityLabel ? [[NSAttributedString alloc] initWithString:newAccessibilityLabel] : nil;
  }
}

- (NSAttributedString *)accessibilityAttributedLabel
{
  return accessibilityAttributedLabel;
}

- (void)setAccessibilityAttributedLabel:(NSAttributedString *)newAccessibilityAttributedLabel
{
  if (! ASObjectIsEqual(accessibilityAttributedLabel, newAccessibilityAttributedLabel)) {
    _flags.setAccessibilityAttributedLabel = YES;
    _flags.setAccessibilityLabel = YES;
    accessibilityAttributedLabel = newAccessibilityAttributedLabel ? [newAccessibilityAttributedLabel copy] : nil;
    accessibilityLabel = newAccessibilityAttributedLabel ? [newAccessibilityAttributedLabel.string copy] : nil;
  }
}

- (NSString *)accessibilityHint
{
  return accessibilityHint;
}

- (void)setAccessibilityHint:(NSString *)newAccessibilityHint
{
  if (! ASObjectIsEqual(accessibilityHint, newAccessibilityHint)) {
    _flags.setAccessibilityHint = YES;
    _flags.setAccessibilityAttributedHint = YES;
    accessibilityHint = newAccessibilityHint ? [newAccessibilityHint copy] : nil;
    accessibilityAttributedHint = newAccessibilityHint ? [[NSAttributedString alloc] initWithString:newAccessibilityHint] : nil;
  }
}

- (NSAttributedString *)accessibilityAttributedHint
{
  return accessibilityAttributedHint;
}

- (void)setAccessibilityAttributedHint:(NSAttributedString *)newAccessibilityAttributedHint
{
  if (! ASObjectIsEqual(accessibilityAttributedHint, newAccessibilityAttributedHint)) {
    _flags.setAccessibilityAttributedHint = YES;
    _flags.setAccessibilityHint = YES;
    accessibilityAttributedHint = newAccessibilityAttributedHint ? [newAccessibilityAttributedHint copy] : nil;
    accessibilityHint = newAccessibilityAttributedHint ? [newAccessibilityAttributedHint.string copy] : nil;
  }
}

- (NSString *)accessibilityValue
{
  return accessibilityValue;
}

- (void)setAccessibilityValue:(NSString *)newAccessibilityValue
{
  if (! ASObjectIsEqual(accessibilityValue, newAccessibilityValue)) {
    _flags.setAccessibilityValue = YES;
    _flags.setAccessibilityAttributedValue = YES;
    accessibilityValue = newAccessibilityValue ? [newAccessibilityValue copy] : nil;
    accessibilityAttributedValue = newAccessibilityValue ? [[NSAttributedString alloc] initWithString:newAccessibilityValue] : nil;
  }
}

- (NSAttributedString *)accessibilityAttributedValue
{
  return accessibilityAttributedValue;
}

- (void)setAccessibilityAttributedValue:(NSAttributedString *)newAccessibilityAttributedValue
{
  if (! ASObjectIsEqual(accessibilityAttributedValue, newAccessibilityAttributedValue)) {
    _flags.setAccessibilityAttributedValue = YES;
    _flags.setAccessibilityValue = YES;
    accessibilityAttributedValue = newAccessibilityAttributedValue?  [newAccessibilityAttributedValue copy] : nil;
    accessibilityValue = newAccessibilityAttributedValue ? [newAccessibilityAttributedValue.string copy] : nil;
  }
}

- (UIAccessibilityTraits)accessibilityTraits
{
  return accessibilityTraits;
}

- (void)setAccessibilityTraits:(UIAccessibilityTraits)newAccessibilityTraits
{
  accessibilityTraits = newAccessibilityTraits;
  _flags.setAccessibilityTraits = YES;
}

- (CGRect)accessibilityFrame
{
  return accessibilityFrame;
}

- (void)setAccessibilityFrame:(CGRect)newAccessibilityFrame
{
  accessibilityFrame = newAccessibilityFrame;
  _flags.setAccessibilityFrame = YES;
}

- (NSString *)accessibilityLanguage
{
  return accessibilityLanguage;
}

- (void)setAccessibilityLanguage:(NSString *)newAccessibilityLanguage
{
  _flags.setAccessibilityLanguage = YES;
  accessibilityLanguage = newAccessibilityLanguage;
}

- (BOOL)accessibilityElementsHidden
{
  return accessibilityElementsHidden;
}

- (void)setAccessibilityElementsHidden:(BOOL)newAccessibilityElementsHidden
{
  accessibilityElementsHidden = newAccessibilityElementsHidden;
  _flags.setAccessibilityElementsHidden = YES;
}

- (BOOL)accessibilityViewIsModal
{
  return accessibilityViewIsModal;
}

- (void)setAccessibilityViewIsModal:(BOOL)newAccessibilityViewIsModal
{
  accessibilityViewIsModal = newAccessibilityViewIsModal;
  _flags.setAccessibilityViewIsModal = YES;
}

- (BOOL)shouldGroupAccessibilityChildren
{
  return shouldGroupAccessibilityChildren;
}

- (void)setShouldGroupAccessibilityChildren:(BOOL)newShouldGroupAccessibilityChildren
{
  shouldGroupAccessibilityChildren = newShouldGroupAccessibilityChildren;
  _flags.setShouldGroupAccessibilityChildren = YES;
}

- (NSString *)accessibilityIdentifier
{
  return accessibilityIdentifier;
}

- (void)setAccessibilityIdentifier:(NSString *)newAccessibilityIdentifier
{
  _flags.setAccessibilityIdentifier = YES;
  if (accessibilityIdentifier != newAccessibilityIdentifier) {
    accessibilityIdentifier = [newAccessibilityIdentifier copy];
  }
}

- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
  return accessibilityNavigationStyle;
}

- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)newAccessibilityNavigationStyle
{
  _flags.setAccessibilityNavigationStyle = YES;
  accessibilityNavigationStyle = newAccessibilityNavigationStyle;
}

- (NSArray *)accessibilityHeaderElements
{
  return accessibilityHeaderElements;
}

- (void)setAccessibilityHeaderElements:(NSArray *)newAccessibilityHeaderElements
{
  _flags.setAccessibilityHeaderElements = YES;
  if (accessibilityHeaderElements != newAccessibilityHeaderElements) {
    accessibilityHeaderElements = [newAccessibilityHeaderElements copy];
  }
}

- (CGPoint)accessibilityActivationPoint
{
  if (_flags.setAccessibilityActivationPoint) {
    return accessibilityActivationPoint;
  }
  
  // Default == Mid-point of the accessibilityFrame
  return CGPointMake(CGRectGetMidX(accessibilityFrame), CGRectGetMidY(accessibilityFrame));
}

- (void)setAccessibilityActivationPoint:(CGPoint)newAccessibilityActivationPoint
{
  _flags.setAccessibilityActivationPoint = YES;
  accessibilityActivationPoint = newAccessibilityActivationPoint;
}

- (UIBezierPath *)accessibilityPath
{
  return accessibilityPath;
}

- (void)setAccessibilityPath:(UIBezierPath *)newAccessibilityPath
{
  _flags.setAccessibilityPath = YES;
  if (accessibilityPath != newAccessibilityPath) {
    accessibilityPath = newAccessibilityPath;
  }
}

- (void)applyToLayer:(CALayer *)layer
{
  ASPendingStateFlags flags = _flags;

  if (__shouldSetNeedsDisplay(layer)) {
    [layer setNeedsDisplay];
  }

  if (flags.setAnchorPoint)
    layer.anchorPoint = anchorPoint;

  if (flags.setZPosition)
    layer.zPosition = zPosition;

  if (flags.setTransform)
    layer.transform = transform;

  if (flags.setSublayerTransform)
    layer.sublayerTransform = sublayerTransform;

  if (flags.setContents)
    layer.contents = contents;

  if (flags.setContentsGravity)
    layer.contentsGravity = contentsGravity;

  if (flags.setContentsRect)
    layer.contentsRect = contentsRect;

  if (flags.setContentsCenter)
    layer.contentsCenter = contentsCenter;

  if (flags.setContentsScale)
    layer.contentsScale = contentsScale;

  if (flags.setRasterizationScale)
    layer.rasterizationScale = rasterizationScale;

  if (flags.setClipsToBounds)
    layer.masksToBounds = clipsToBounds;

  if (flags.setBackgroundColor)
    layer.backgroundColor = backgroundColor;

  if (flags.setOpaque)
    layer.opaque = opaque;

  if (flags.setHidden)
    layer.hidden = isHidden;

  if (flags.setAlpha)
    layer.opacity = alpha;

  if (flags.setCornerRadius)
    layer.cornerRadius = cornerRadius;

  if (flags.setContentMode)
    layer.contentsGravity = ASDisplayNodeCAContentsGravityFromUIContentMode(contentMode);

  if (flags.setShadowColor)
    layer.shadowColor = shadowColor;

  if (flags.setShadowOpacity)
    layer.shadowOpacity = shadowOpacity;

  if (flags.setShadowOffset)
    layer.shadowOffset = shadowOffset;

  if (flags.setShadowRadius)
    layer.shadowRadius = shadowRadius;

  if (flags.setBorderWidth)
    layer.borderWidth = borderWidth;

  if (flags.setBorderColor)
    layer.borderColor = borderColor;

  if (flags.setNeedsDisplayOnBoundsChange)
    layer.needsDisplayOnBoundsChange = needsDisplayOnBoundsChange;
  
  if (flags.setAllowsGroupOpacity)
    layer.allowsGroupOpacity = allowsGroupOpacity;

  if (flags.setAllowsEdgeAntialiasing)
    layer.allowsEdgeAntialiasing = allowsEdgeAntialiasing;

  if (flags.setEdgeAntialiasingMask)
    layer.edgeAntialiasingMask = edgeAntialiasingMask;

  if (flags.setAsyncTransactionContainer)
    layer.asyncdisplaykit_asyncTransactionContainer = asyncTransactionContainer;

  if (flags.setOpaque)
    ASDisplayNodeAssert(layer.opaque == opaque, @"Didn't set opaque as desired");

  ASPendingStateApplyMetricsToLayer(self, layer);
  
  if (flags.needsLayout)
    [layer setNeedsLayout];
  
  if (flags.layoutIfNeeded)
    [layer layoutIfNeeded];
}

- (void)applyToView:(UIView *)view withSpecialPropertiesHandling:(BOOL)specialPropertiesHandling
{
  /*
   Use our convenience setters blah here instead of layer.blah
   We were accidentally setting some properties on layer here, but view in UIViewBridgeOptimizations.

   That could easily cause bugs where it mattered whether you set something up on a bg thread on in -didLoad
   because a different setter would be called.
   */

  CALayer *layer = view.layer;

  ASPendingStateFlags flags = _flags;
  if (__shouldSetNeedsDisplay(layer)) {
    [view setNeedsDisplay];
  }

  if (flags.setAnchorPoint)
    layer.anchorPoint = anchorPoint;

  if (flags.setPosition)
    layer.position = position;

  if (flags.setZPosition)
    layer.zPosition = zPosition;

  if (flags.setBounds)
    view.bounds = bounds;

  if (flags.setTransform)
    layer.transform = transform;

  if (flags.setSublayerTransform)
    layer.sublayerTransform = sublayerTransform;

  if (flags.setContents)
    layer.contents = contents;

  if (flags.setContentsGravity)
    layer.contentsGravity = contentsGravity;

  if (flags.setContentsRect)
    layer.contentsRect = contentsRect;

  if (flags.setContentsCenter)
    layer.contentsCenter = contentsCenter;

  if (flags.setContentsScale)
    layer.contentsScale = contentsScale;

  if (flags.setRasterizationScale)
    layer.rasterizationScale = rasterizationScale;

  if (flags.setClipsToBounds)
    view.clipsToBounds = clipsToBounds;

  if (flags.setBackgroundColor) {
    // We have to make sure certain nodes get the background color call directly set
    if (specialPropertiesHandling) {
      view.backgroundColor = [UIColor colorWithCGColor:backgroundColor];
    } else {
      // Set the background color to the layer as in the UIView bridge we use this value as background color
      layer.backgroundColor = backgroundColor;
    }
  }

  if (flags.setTintColor)
    view.tintColor = self.tintColor;

  if (flags.setOpaque)
    layer.opaque = opaque;

  if (flags.setHidden)
    view.hidden = isHidden;

  if (flags.setAlpha)
    view.alpha = alpha;

  if (flags.setCornerRadius)
    layer.cornerRadius = cornerRadius;

  if (flags.setContentMode)
    view.contentMode = contentMode;

  if (flags.setUserInteractionEnabled)
    view.userInteractionEnabled = userInteractionEnabled;

  #if TARGET_OS_IOS
  if (flags.setExclusiveTouch)
    view.exclusiveTouch = exclusiveTouch;
  #endif
    
  if (flags.setShadowColor)
    layer.shadowColor = shadowColor;

  if (flags.setShadowOpacity)
    layer.shadowOpacity = shadowOpacity;

  if (flags.setShadowOffset)
    layer.shadowOffset = shadowOffset;

  if (flags.setShadowRadius)
    layer.shadowRadius = shadowRadius;

  if (flags.setBorderWidth)
    layer.borderWidth = borderWidth;

  if (flags.setBorderColor)
    layer.borderColor = borderColor;

  if (flags.setAutoresizingMask)
    view.autoresizingMask = autoresizingMask;

  if (flags.setAutoresizesSubviews)
    view.autoresizesSubviews = autoresizesSubviews;

  if (flags.setNeedsDisplayOnBoundsChange)
    layer.needsDisplayOnBoundsChange = needsDisplayOnBoundsChange;
  
  if (flags.setAllowsGroupOpacity)
    layer.allowsGroupOpacity = allowsGroupOpacity;

  if (flags.setAllowsEdgeAntialiasing)
    layer.allowsEdgeAntialiasing = allowsEdgeAntialiasing;

  if (flags.setEdgeAntialiasingMask)
    layer.edgeAntialiasingMask = edgeAntialiasingMask;

  if (flags.setAsyncTransactionContainer)
    view.asyncdisplaykit_asyncTransactionContainer = asyncTransactionContainer;

  if (flags.setOpaque)
    ASDisplayNodeAssert(layer.opaque == opaque, @"Didn't set opaque as desired");

  if (flags.setLayoutMargins)
    view.layoutMargins = layoutMargins;

  if (flags.setPreservesSuperviewLayoutMargins)
    view.preservesSuperviewLayoutMargins = preservesSuperviewLayoutMargins;

  if (AS_AVAILABLE_IOS(11.0)) {
    if (flags.setInsetsLayoutMarginsFromSafeArea) {
      view.insetsLayoutMarginsFromSafeArea = insetsLayoutMarginsFromSafeArea;
    }
  }

  if (flags.setSemanticContentAttribute) {
    view.semanticContentAttribute = semanticContentAttribute;
  }

  if (flags.setIsAccessibilityElement)
    view.isAccessibilityElement = isAccessibilityElement;

  if (flags.setAccessibilityLabel)
    view.accessibilityLabel = accessibilityLabel;

  if (AS_AT_LEAST_IOS11 && flags.setAccessibilityAttributedLabel)
    [view setValue:accessibilityAttributedLabel forKey:@"accessibilityAttributedLabel"];

  if (flags.setAccessibilityHint)
    view.accessibilityHint = accessibilityHint;

  if (AS_AT_LEAST_IOS11 && flags.setAccessibilityAttributedHint)
    [view setValue:accessibilityAttributedHint forKey:@"accessibilityAttributedHint"];

  if (flags.setAccessibilityValue)
    view.accessibilityValue = accessibilityValue;

  if (AS_AT_LEAST_IOS11 && flags.setAccessibilityAttributedValue)
    [view setValue:accessibilityAttributedValue forKey:@"accessibilityAttributedValue"];

  if (flags.setAccessibilityTraits)
    view.accessibilityTraits = accessibilityTraits;

  if (flags.setAccessibilityFrame)
    view.accessibilityFrame = accessibilityFrame;

  if (flags.setAccessibilityLanguage)
    view.accessibilityLanguage = accessibilityLanguage;

  if (flags.setAccessibilityElementsHidden)
    view.accessibilityElementsHidden = accessibilityElementsHidden;

  if (flags.setAccessibilityViewIsModal)
    view.accessibilityViewIsModal = accessibilityViewIsModal;

  if (flags.setShouldGroupAccessibilityChildren)
    view.shouldGroupAccessibilityChildren = shouldGroupAccessibilityChildren;

  if (flags.setAccessibilityIdentifier)
    view.accessibilityIdentifier = accessibilityIdentifier;
  
  if (flags.setAccessibilityNavigationStyle)
    view.accessibilityNavigationStyle = accessibilityNavigationStyle;
  
#if TARGET_OS_TV
  if (flags.setAccessibilityHeaderElements)
    view.accessibilityHeaderElements = accessibilityHeaderElements;
#endif
  
  if (flags.setAccessibilityActivationPoint)
    view.accessibilityActivationPoint = accessibilityActivationPoint;
  
  if (flags.setAccessibilityPath)
    view.accessibilityPath = accessibilityPath;

  if (flags.setFrame && specialPropertiesHandling) {
    // Frame is only defined when transform is identity because we explicitly diverge from CALayer behavior and define frame without transform
//#if DEBUG
//    // Checking if the transform is identity is expensive, so disable when unnecessary. We have assertions on in Release, so DEBUG is the only way I know of.
//    ASDisplayNodeAssert(CATransform3DIsIdentity(layer.transform), @"-[ASDisplayNode setFrame:] - self.transform must be identity in order to set the frame property.  (From Apple's UIView documentation: If the transform property is not the identity transform, the value of this property is undefined and therefore should be ignored.)");
//#endif
    view.frame = frame;
  } else {
    ASPendingStateApplyMetricsToLayer(self, layer);
  }
  
  if (flags.needsLayout)
    [view setNeedsLayout];
  
  if (flags.layoutIfNeeded)
    [view layoutIfNeeded];
}

// FIXME: Make this more efficient by tracking which properties are set rather than reading everything.
+ (_ASPendingState *)pendingViewStateFromLayer:(CALayer *)layer
{
  if (!layer) {
    return nil;
  }
  _ASPendingState *pendingState = [[_ASPendingState alloc] init];
  pendingState.anchorPoint = layer.anchorPoint;
  pendingState.position = layer.position;
  pendingState.zPosition = layer.zPosition;
  pendingState.bounds = layer.bounds;
  pendingState.transform = layer.transform;
  pendingState.sublayerTransform = layer.sublayerTransform;
  pendingState.contents = layer.contents;
  pendingState.contentsGravity = layer.contentsGravity;
  pendingState.contentsRect = layer.contentsRect;
  pendingState.contentsCenter = layer.contentsCenter;
  pendingState.contentsScale = layer.contentsScale;
  pendingState.rasterizationScale = layer.rasterizationScale;
  pendingState.clipsToBounds = layer.masksToBounds;
  pendingState.backgroundColor = layer.backgroundColor;
  pendingState.opaque = layer.opaque;
  pendingState.hidden = layer.hidden;
  pendingState.alpha = layer.opacity;
  pendingState.cornerRadius = layer.cornerRadius;
  pendingState.contentMode = ASDisplayNodeUIContentModeFromCAContentsGravity(layer.contentsGravity);
  pendingState.shadowColor = layer.shadowColor;
  pendingState.shadowOpacity = layer.shadowOpacity;
  pendingState.shadowOffset = layer.shadowOffset;
  pendingState.shadowRadius = layer.shadowRadius;
  pendingState.borderWidth = layer.borderWidth;
  pendingState.borderColor = layer.borderColor;
  pendingState.needsDisplayOnBoundsChange = layer.needsDisplayOnBoundsChange;
  pendingState.allowsGroupOpacity = layer.allowsGroupOpacity;
  pendingState.allowsEdgeAntialiasing = layer.allowsEdgeAntialiasing;
  pendingState.edgeAntialiasingMask = layer.edgeAntialiasingMask;
  return pendingState;
}

// FIXME: Make this more efficient by tracking which properties are set rather than reading everything.
+ (_ASPendingState *)pendingViewStateFromView:(UIView *)view
{
  if (!view) {
    return nil;
  }
  _ASPendingState *pendingState = [[_ASPendingState alloc] init];

  CALayer *layer = view.layer;
  pendingState.anchorPoint = layer.anchorPoint;
  pendingState.position = layer.position;
  pendingState.zPosition = layer.zPosition;
  pendingState.bounds = view.bounds;
  pendingState.transform = layer.transform;
  pendingState.sublayerTransform = layer.sublayerTransform;
  pendingState.contents = layer.contents;
  pendingState.contentsGravity = layer.contentsGravity;
  pendingState.contentsRect = layer.contentsRect;
  pendingState.contentsCenter = layer.contentsCenter;
  pendingState.contentsScale = layer.contentsScale;
  pendingState.rasterizationScale = layer.rasterizationScale;
  pendingState.clipsToBounds = view.clipsToBounds;
  pendingState.backgroundColor = layer.backgroundColor;
  pendingState.tintColor = view.tintColor;
  pendingState.opaque = layer.opaque;
  pendingState.hidden = view.hidden;
  pendingState.alpha = view.alpha;
  pendingState.cornerRadius = layer.cornerRadius;
  pendingState.contentMode = view.contentMode;
  pendingState.userInteractionEnabled = view.userInteractionEnabled;
#if TARGET_OS_IOS
  pendingState.exclusiveTouch = view.exclusiveTouch;
#endif
  pendingState.shadowColor = layer.shadowColor;
  pendingState.shadowOpacity = layer.shadowOpacity;
  pendingState.shadowOffset = layer.shadowOffset;
  pendingState.shadowRadius = layer.shadowRadius;
  pendingState.borderWidth = layer.borderWidth;
  pendingState.borderColor = layer.borderColor;
  pendingState.autoresizingMask = view.autoresizingMask;
  pendingState.autoresizesSubviews = view.autoresizesSubviews;
  pendingState.needsDisplayOnBoundsChange = layer.needsDisplayOnBoundsChange;
  pendingState.allowsGroupOpacity = layer.allowsGroupOpacity;
  pendingState.allowsEdgeAntialiasing = layer.allowsEdgeAntialiasing;
  pendingState.edgeAntialiasingMask = layer.edgeAntialiasingMask;
  pendingState.semanticContentAttribute = view.semanticContentAttribute;
  pendingState.layoutMargins = view.layoutMargins;
  pendingState.preservesSuperviewLayoutMargins = view.preservesSuperviewLayoutMargins;
  if (AS_AVAILABLE_IOS(11)) {
    pendingState.insetsLayoutMarginsFromSafeArea = view.insetsLayoutMarginsFromSafeArea;
  }
  pendingState.isAccessibilityElement = view.isAccessibilityElement;
  pendingState.accessibilityLabel = view.accessibilityLabel;
  pendingState.accessibilityHint = view.accessibilityHint;
  pendingState.accessibilityValue = view.accessibilityValue;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
  if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
    pendingState.accessibilityAttributedLabel = view.accessibilityAttributedLabel;
    pendingState.accessibilityAttributedHint = view.accessibilityAttributedHint;
    pendingState.accessibilityAttributedValue = view.accessibilityAttributedValue;
  }
#endif
  pendingState.accessibilityTraits = view.accessibilityTraits;
  pendingState.accessibilityFrame = view.accessibilityFrame;
  pendingState.accessibilityLanguage = view.accessibilityLanguage;
  pendingState.accessibilityElementsHidden = view.accessibilityElementsHidden;
  pendingState.accessibilityViewIsModal = view.accessibilityViewIsModal;
  pendingState.shouldGroupAccessibilityChildren = view.shouldGroupAccessibilityChildren;
  pendingState.accessibilityIdentifier = view.accessibilityIdentifier;
  pendingState.accessibilityNavigationStyle = view.accessibilityNavigationStyle;
#if TARGET_OS_TV
  pendingState.accessibilityHeaderElements = view.accessibilityHeaderElements;
#endif
  pendingState.accessibilityActivationPoint = view.accessibilityActivationPoint;
  pendingState.accessibilityPath = view.accessibilityPath;
  return pendingState;
}

- (void)clearChanges
{
  _flags = (ASPendingStateFlags){ 0 };
}

- (BOOL)hasSetNeedsLayout
{
  return _flags.needsLayout;
}

- (BOOL)hasSetNeedsDisplay
{
  return _flags.needsDisplay;
}

- (BOOL)hasChanges
{
  ASPendingStateFlags flags = _flags;

  return (flags.setAnchorPoint
  || flags.setPosition
  || flags.setZPosition
  || flags.setFrame
  || flags.setBounds
  || flags.setPosition
  || flags.setTransform
  || flags.setSublayerTransform
  || flags.setContents
  || flags.setContentsGravity
  || flags.setContentsRect
  || flags.setContentsCenter
  || flags.setContentsScale
  || flags.setRasterizationScale
  || flags.setClipsToBounds
  || flags.setBackgroundColor
  || flags.setTintColor
  || flags.setHidden
  || flags.setAlpha
  || flags.setCornerRadius
  || flags.setContentMode
  || flags.setUserInteractionEnabled
  || flags.setExclusiveTouch
  || flags.setShadowOpacity
  || flags.setShadowOffset
  || flags.setShadowRadius
  || flags.setShadowColor
  || flags.setBorderWidth
  || flags.setBorderColor
  || flags.setAutoresizingMask
  || flags.setAutoresizesSubviews
  || flags.setNeedsDisplayOnBoundsChange
  || flags.setAllowsGroupOpacity
  || flags.setAllowsEdgeAntialiasing
  || flags.setEdgeAntialiasingMask
  || flags.needsDisplay
  || flags.needsLayout
  || flags.setAsyncTransactionContainer
  || flags.setOpaque
  || flags.setSemanticContentAttribute
  || flags.setLayoutMargins
  || flags.setPreservesSuperviewLayoutMargins
  || flags.setInsetsLayoutMarginsFromSafeArea
  || flags.setIsAccessibilityElement
  || flags.setAccessibilityLabel
  || flags.setAccessibilityAttributedLabel
  || flags.setAccessibilityHint
  || flags.setAccessibilityAttributedHint
  || flags.setAccessibilityValue
  || flags.setAccessibilityAttributedValue
  || flags.setAccessibilityTraits
  || flags.setAccessibilityFrame
  || flags.setAccessibilityLanguage
  || flags.setAccessibilityElementsHidden
  || flags.setAccessibilityViewIsModal
  || flags.setShouldGroupAccessibilityChildren
  || flags.setAccessibilityIdentifier
  || flags.setAccessibilityNavigationStyle
  || flags.setAccessibilityHeaderElements
  || flags.setAccessibilityActivationPoint
  || flags.setAccessibilityPath);
}

- (void)dealloc
{
  CGColorRelease(backgroundColor);
  
  if (shadowColor != blackColorRef) {
    CGColorRelease(shadowColor);
  }
  
  if (borderColor != blackColorRef) {
    CGColorRelease(borderColor);
  }
}

@end
