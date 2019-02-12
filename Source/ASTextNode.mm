//
//  ASTextNode.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextNode.h>

#if AS_ENABLE_TEXTNODE

#import <AsyncDisplayKit/ASTextNode2.h>

#import <AsyncDisplayKit/ASTextNode+Beta.h>

#import <mutex>
#import <tgmath.h>

#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASHighlightOverlayLayer.h>
#import <AsyncDisplayKit/ASGraphicsContext.h>

#import <AsyncDisplayKit/ASTextKitCoreTextAdditions.h>
#import <AsyncDisplayKit/ASTextKitRenderer+Positioning.h>
#import <AsyncDisplayKit/ASTextKitShadower.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayout.h>

#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/ASHashing.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

/**
 * If set, we will record all values set to attributedText into an array
 * and once we get 2000, we'll write them all out into a plist file.
 *
 * This is useful for gathering realistic text data sets from apps for performance
 * testing.
 */
#define AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS 0

static const NSTimeInterval ASTextNodeHighlightFadeOutDuration = 0.15;
static const NSTimeInterval ASTextNodeHighlightFadeInDuration = 0.1;
static const CGFloat ASTextNodeHighlightLightOpacity = 0.11;
static const CGFloat ASTextNodeHighlightDarkOpacity = 0.22;
static NSString *ASTextNodeTruncationTokenAttributeName = @"ASTextNodeTruncationAttribute";

#pragma mark - ASTextKitRenderer

@interface ASTextNodeRendererKey : NSObject
@property (nonatomic) ASTextKitAttributes attributes;
@property (nonatomic) CGSize constrainedSize;
@end

@implementation ASTextNodeRendererKey {
  std::mutex _m;
}

- (NSUInteger)hash
{
  std::lock_guard<std::mutex> _l(_m);
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wpadded"
  struct {
    size_t attributesHash;
    CGSize constrainedSize;
#pragma clang diagnostic pop
  } data = {
    _attributes.hash(),
    _constrainedSize
  };
  return ASHashBytes(&data, sizeof(data));
}

- (BOOL)isEqual:(ASTextNodeRendererKey *)object
{
  if (self == object) {
    return YES;
  }
  
  // NOTE: Skip the class check for this specialized, internal Key object.

  // Lock both objects, avoiding deadlock.
  std::lock(_m, object->_m);
  std::lock_guard<std::mutex> lk1(_m, std::adopt_lock);
  std::lock_guard<std::mutex> lk2(object->_m, std::adopt_lock);
  
  return _attributes == object->_attributes && CGSizeEqualToSize(_constrainedSize, object->_constrainedSize);
}

@end

static NSCache *sharedRendererCache()
{ 
 static dispatch_once_t onceToken;
 static NSCache *__rendererCache = nil;
 dispatch_once(&onceToken, ^{
   __rendererCache = [[NSCache alloc] init];
   __rendererCache.countLimit = 500; // 500 renders cache
 });
 return __rendererCache;
}

/**
 The concept here is that neither the node nor layout should ever have a strong reference to the renderer object.
 This is to reduce memory load when loading thousands and thousands of text nodes into memory at once. Instead
 we maintain a LRU renderer cache that is queried via a unique key based on text kit attributes and constrained size. 
 */

static ASTextKitRenderer *rendererForAttributes(ASTextKitAttributes attributes, CGSize constrainedSize)
{
  NSCache *cache = sharedRendererCache();
  
  ASTextNodeRendererKey *key = [[ASTextNodeRendererKey alloc] init];
  key.attributes = attributes;
  key.constrainedSize = constrainedSize;

  ASTextKitRenderer *renderer = [cache objectForKey:key];
  if (renderer == nil) {
    renderer = [[ASTextKitRenderer alloc] initWithTextKitAttributes:attributes constrainedSize:constrainedSize];
    [cache setObject:renderer forKey:key];
  }
  
  return renderer;
}

#pragma mark - ASTextNodeDrawParameter

@interface ASTextNodeDrawParameter : NSObject {
@package
  ASTextKitAttributes _rendererAttributes;
  UIColor *_backgroundColor;
  UIEdgeInsets _textContainerInsets;
}
@end

@implementation ASTextNodeDrawParameter

- (instancetype)initWithRendererAttributes:(ASTextKitAttributes)rendererAttributes
                           backgroundColor:(/*nullable*/ UIColor *)backgroundColor
                       textContainerInsets:(UIEdgeInsets)textContainerInsets
{
  self = [super init];
  if (self != nil) {
    _rendererAttributes = rendererAttributes;
    _backgroundColor = backgroundColor;
    _textContainerInsets = textContainerInsets;
  }
  return self;
}

- (ASTextKitRenderer *)rendererForBounds:(CGRect)bounds
{
  CGRect rect = UIEdgeInsetsInsetRect(bounds, _textContainerInsets);
  return rendererForAttributes(_rendererAttributes, rect.size);
}

@end


#pragma mark - ASTextNode

@interface ASTextNode () <UIGestureRecognizerDelegate>

@end

@implementation ASTextNode {
  CGSize _shadowOffset;
  CGColorRef _shadowColor;
  UIColor *_cachedShadowUIColor;
  UIColor *_placeholderColor;
  CGFloat _shadowOpacity;
  CGFloat _shadowRadius;
  
  UIEdgeInsets _textContainerInset;

  NSArray *_exclusionPaths;

  NSAttributedString *_attributedText;
  NSAttributedString *_truncationAttributedText;
  NSAttributedString *_additionalTruncationMessage;
  NSAttributedString *_composedTruncationText;
  NSArray<NSNumber *> *_pointSizeScaleFactors;
  NSLineBreakMode _truncationMode;
  
  NSUInteger _maximumNumberOfLines;

  NSString *_highlightedLinkAttributeName;
  id _highlightedLinkAttributeValue;
  ASTextNodeHighlightStyle _highlightStyle;
  NSRange _highlightRange;
  ASHighlightOverlayLayer *_activeHighlightLayer;

  UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@dynamic placeholderEnabled;

static NSArray *DefaultLinkAttributeNames() {
  static NSArray *names;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    names = @[ NSLinkAttributeName ];
  });
  return names;
}

- (instancetype)init
{
  if (self = [super init]) {
    // Load default values from superclass.
    _shadowOffset = [super shadowOffset];
    _shadowColor = CGColorRetain([super shadowColor]);
    _shadowOpacity = [super shadowOpacity];
    _shadowRadius = [super shadowRadius];

    // Disable user interaction for text node by default.
    self.userInteractionEnabled = NO;
    self.needsDisplayOnBoundsChange = YES;

    _truncationMode = NSLineBreakByWordWrapping;

    // The common case is for a text node to be non-opaque and blended over some background.
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];

    self.linkAttributeNames = DefaultLinkAttributeNames();

    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = self.defaultAccessibilityTraits;

    // Placeholders
    // Disabled by default in ASDisplayNode, but add a few options for those who toggle
    // on the special placeholder behavior of ASTextNode.
    _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();
    _placeholderInsets = UIEdgeInsetsMake(1.0, 0.0, 1.0, 0.0);
  }

  return self;
}

- (void)dealloc
{
  CGColorRelease(_shadowColor);

  // TODO: This may not be necessary post-iOS-9 when most UIKit assign APIs
  // were changed to weak.
  if (_longPressGestureRecognizer) {
    _longPressGestureRecognizer.delegate = nil;
    [_longPressGestureRecognizer removeTarget:nil action:NULL];
    [self.view removeGestureRecognizer:_longPressGestureRecognizer];
  }
}

#pragma mark - Description

- (NSString *)_plainStringForDescription
{
  NSString *plainString = [[self.attributedText string] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  if (plainString.length > 50) {
    plainString = [[plainString substringToIndex:50] stringByAppendingString:@"\u2026"];
  }
  return plainString;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [super propertiesForDescription];
  NSString *plainString = [self _plainStringForDescription];
  if (plainString.length > 0) {
    [result addObject:@{ (id)kCFNull : ASStringWithQuotesIfMultiword(plainString) }];
  }
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray *result = [super propertiesForDebugDescription];
  NSString *plainString = [self _plainStringForDescription];
  if (plainString.length > 0) {
    [result insertObject:@{ @"text" : ASStringWithQuotesIfMultiword(plainString) } atIndex:0];
  }
  return result;
}

#pragma mark - ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  // If we are view-backed and the delegate cares, support the long-press callback.
  SEL longPressCallback = @selector(textNode:longPressedLinkAttribute:value:atPoint:textRange:);
  if (!self.isLayerBacked && [_delegate respondsToSelector:longPressCallback]) {
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPress:)];
    _longPressGestureRecognizer.cancelsTouchesInView = self.longPressCancelsTouches;
    _longPressGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_longPressGestureRecognizer];
  }
}

- (BOOL)supportsLayerBacking
{
  if (!super.supportsLayerBacking) {
    return NO;
  }
  
  // If the text contains any links, return NO.
  NSAttributedString *attributedText = self.attributedText;
  NSRange range = NSMakeRange(0, attributedText.length);
  for (NSString *linkAttributeName in _linkAttributeNames) {
    __block BOOL hasLink = NO;
    [attributedText enumerateAttribute:linkAttributeName inRange:range options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
      hasLink = (value != nil);
      *stop = YES;
    }];
    if (hasLink) {
      return NO;
    }
  }
  return YES;
}

#pragma mark - Renderer Management

- (ASTextKitRenderer *)_renderer
{
  ASLockScopeSelf();
  return [self _locked_renderer];
}

- (ASTextKitRenderer *)_rendererWithBounds:(CGRect)bounds
{
  ASLockScopeSelf();
  return [self _locked_rendererWithBounds:bounds];
}

- (ASTextKitRenderer *)_locked_renderer
{
  ASAssertLocked(__instanceLock__);
  return [self _locked_rendererWithBounds:[self _locked_threadSafeBounds]];
}

- (ASTextKitRenderer *)_locked_rendererWithBounds:(CGRect)bounds
{
  ASAssertLocked(__instanceLock__);
  bounds = UIEdgeInsetsInsetRect(bounds, _textContainerInset);
  return rendererForAttributes([self _locked_rendererAttributes], bounds.size);
}

- (ASTextKitAttributes)_locked_rendererAttributes
{
  ASAssertLocked(__instanceLock__);
  return {
    .attributedString = _attributedText,
    .truncationAttributedString = [self _locked_composedTruncationText],
    .lineBreakMode = _truncationMode,
    .maximumNumberOfLines = _maximumNumberOfLines,
    .exclusionPaths = _exclusionPaths,
    // use the property getter so a subclass can provide these scale factors on demand if desired
    .pointSizeScaleFactors = self.pointSizeScaleFactors,
    .shadowOffset = _shadowOffset,
    .shadowColor = _cachedShadowUIColor,
    .shadowOpacity = _shadowOpacity,
    .shadowRadius = _shadowRadius
  };
}

- (NSString *)defaultAccessibilityLabel
{
  ASLockScopeSelf();
  return _attributedText.string;
}

- (UIAccessibilityTraits)defaultAccessibilityTraits
{
  return UIAccessibilityTraitStaticText;
}

#pragma mark - Layout and Sizing

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
  if (ASLockedSelfCompareAssignCustom(_textContainerInset, textContainerInset, UIEdgeInsetsEqualToEdgeInsets)) {
    [self setNeedsLayout];
  }
}

- (UIEdgeInsets)textContainerInset
{
  return ASLockedSelf(_textContainerInset);
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASLockScopeSelf();
  
  ASDisplayNodeAssert(constrainedSize.width >= 0, @"Constrained width for text (%f) is too  narrow", constrainedSize.width);
  ASDisplayNodeAssert(constrainedSize.height >= 0, @"Constrained height for text (%f) is too short", constrainedSize.height);
  
  // Cache the original constrained size for final size calculateion
  CGSize originalConstrainedSize = constrainedSize;

  [self setNeedsDisplay];
  
  ASTextKitRenderer *renderer = [self _locked_rendererWithBounds:{.size = constrainedSize}];
  CGSize size = renderer.size;
  if (_attributedText.length > 0) {
    self.style.ascender = [[self class] ascenderWithAttributedString:_attributedText];
    self.style.descender = [[_attributedText attribute:NSFontAttributeName atIndex:_attributedText.length - 1 effectiveRange:NULL] descender];
    if (renderer.currentScaleFactor > 0 && renderer.currentScaleFactor < 1.0) {
      // while not perfect, this is a good estimate of what the ascender of the scaled font will be.
      self.style.ascender *= renderer.currentScaleFactor;
      self.style.descender *= renderer.currentScaleFactor;
    }
  }
  
  // Add the constrained size back textContainerInset
  size.width += (_textContainerInset.left + _textContainerInset.right);
  size.height += (_textContainerInset.top + _textContainerInset.bottom);
  
  return CGSizeMake(std::fmin(size.width, originalConstrainedSize.width),
                    std::fmin(size.height, originalConstrainedSize.height));
}

#pragma mark - Modifying User Text

// Returns the ascender of the first character in attributedString by also including the line height if specified in paragraph style.
+ (CGFloat)ascenderWithAttributedString:(NSAttributedString *)attributedString 
{
  UIFont *font = [attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
  NSParagraphStyle *paragraphStyle = [attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  if (!paragraphStyle) {
    return font.ascender;
  }
  CGFloat lineHeight = MAX(font.lineHeight, paragraphStyle.minimumLineHeight);
  if (paragraphStyle.maximumLineHeight > 0) {
    lineHeight = MIN(lineHeight, paragraphStyle.maximumLineHeight);
  }
  return lineHeight + font.descender;
}

- (NSAttributedString *)attributedText
{
  ASLockScopeSelf();
  return _attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  
  if (attributedText == nil) {
    attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:nil];
  }

  {
    ASLockScopeSelf();
    if (ASObjectIsEqual(attributedText, _attributedText)) {
      return;
    }

    NSAttributedString *cleanedAttributedString = ASCleanseAttributedStringOfCoreTextAttributes(attributedText);

    // Invalidating the truncation text must be done while we still hold the lock. Because after we release it,
    // another thread may set a new truncation text that will then be cleared by this thread, other may draw
    // this soon-to-be-invalidated text.
    [self _locked_invalidateTruncationText];

    NSUInteger length = cleanedAttributedString.length;
    if (length > 0) {
      // Updating ascender and descender in one transaction while holding the lock.
      ASLayoutElementStyle *style = [self _locked_style];
      style.ascender = [[self class] ascenderWithAttributedString:cleanedAttributedString];
      style.descender = [[attributedText attribute:NSFontAttributeName atIndex:cleanedAttributedString.length - 1 effectiveRange:NULL] descender];
    }
   
    // Update attributed text with cleaned attributed string
    _attributedText = cleanedAttributedString;
  }
  
  // Tell the display node superclasses that the cached layout is incorrect now
  [self setNeedsLayout];

  // Force display to create renderer with new size and redisplay with new string
  [self setNeedsDisplay];
  
  // Accessiblity
  const auto currentAttributedText = self.attributedText; // Grab attributed string again in case it changed in the meantime
  self.accessibilityLabel = self.defaultAccessibilityLabel;
  self.isAccessibilityElement = (currentAttributedText.length != 0); // We're an accessibility element by default if there is a string.

#if AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS
  [ASTextNode _registerAttributedText:_attributedText];
#endif
}

#pragma mark - Text Layout

- (void)setExclusionPaths:(NSArray *)exclusionPaths
{
  if (ASLockedSelfCompareAssignCopy(_exclusionPaths, exclusionPaths)) {
    [self setNeedsLayout];
    [self setNeedsDisplay];
  }
}

- (NSArray *)exclusionPaths
{
  return ASLockedSelf(_exclusionPaths);
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  ASLockScopeSelf();
  
  return [[ASTextNodeDrawParameter alloc] initWithRendererAttributes:[self _locked_rendererAttributes]
                                                     backgroundColor:self.backgroundColor
                                                 textContainerInsets:_textContainerInset];
}

+ (void)drawRect:(CGRect)bounds withParameters:(id)parameters isCancelled:(NS_NOESCAPE asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing
{
  ASTextNodeDrawParameter *drawParameter = (ASTextNodeDrawParameter *)parameters;
  UIColor *backgroundColor = (isRasterizing || drawParameter == nil) ? nil : drawParameter->_backgroundColor;
  UIEdgeInsets textContainerInsets = drawParameter ? drawParameter->_textContainerInsets : UIEdgeInsetsZero;
  ASTextKitRenderer *renderer = [drawParameter rendererForBounds:bounds];
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  ASDisplayNodeAssert(context, @"This is no good without a context.");
 
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, textContainerInsets.left, textContainerInsets.top);
  
  // Fill background
  if (backgroundColor != nil) {
    [backgroundColor setFill];
    UIRectFillUsingBlendMode(CGContextGetClipBoundingBox(context), kCGBlendModeCopy);
  }
  
  // Draw text
  [renderer drawInContext:context bounds:bounds];
  CGContextRestoreGState(context);
}

#pragma mark - Attributes

- (id)linkAttributeValueAtPoint:(CGPoint)point
                  attributeName:(out NSString **)attributeNameOut
                          range:(out NSRange *)rangeOut
{
  return [self _linkAttributeValueAtPoint:point
                            attributeName:attributeNameOut
                                    range:rangeOut
            inAdditionalTruncationMessage:NULL
                          forHighlighting:NO];
}

- (id)_linkAttributeValueAtPoint:(CGPoint)point
                   attributeName:(out NSString * __autoreleasing *)attributeNameOut
                           range:(out NSRange *)rangeOut
   inAdditionalTruncationMessage:(out BOOL *)inAdditionalTruncationMessageOut
                 forHighlighting:(BOOL)highlighting
{
  ASDisplayNodeAssertMainThread();
  
  ASLockScopeSelf();
  
  ASTextKitRenderer *renderer = [self _locked_renderer];
  NSRange visibleRange = renderer.firstVisibleRange;
  NSAttributedString *attributedString = _attributedText;
  NSRange clampedRange = NSIntersectionRange(visibleRange, NSMakeRange(0, attributedString.length));

  // Check in a 9-point region around the actual touch point so we make sure
  // we get the best attribute for the touch.
  __block CGFloat minimumGlyphDistance = CGFLOAT_MAX;

  // Final output vars
  __block id linkAttributeValue = nil;
  __block BOOL inTruncationMessage = NO;

  [renderer enumerateTextIndexesAtPosition:point usingBlock:^(NSUInteger characterIndex, CGRect glyphBoundingRect, BOOL *stop) {
    CGPoint glyphLocation = CGPointMake(CGRectGetMidX(glyphBoundingRect), CGRectGetMidY(glyphBoundingRect));
    CGFloat currentDistance = std::sqrt(std::pow(point.x - glyphLocation.x, 2.f) + std::pow(point.y - glyphLocation.y, 2.f));
    if (currentDistance >= minimumGlyphDistance) {
      // If the distance computed from the touch to the glyph location is
      // not the minimum among the located link attributes, we can just skip
      // to the next location.
      return;
    }

    // Check if it's outside the visible range, if so, then we mark this touch
    // as inside the truncation message, because in at least one of the touch
    // points it was.
    if (!(NSLocationInRange(characterIndex, visibleRange))) {
      inTruncationMessage = YES;
    }

    if (inAdditionalTruncationMessageOut != NULL) {
      *inAdditionalTruncationMessageOut = inTruncationMessage;
    }

    // Short circuit here if it's just in the truncation message.  Since the
    // truncation message may be beyond the scope of the actual input string,
    // we have to make sure that we don't start asking for attributes on it.
    if (inTruncationMessage) {
      return;
    }

    for (NSString *attributeName in self->_linkAttributeNames) {
      NSRange range;
      id value = [attributedString attribute:attributeName atIndex:characterIndex longestEffectiveRange:&range inRange:clampedRange];
      NSString *name = attributeName;

      if (value == nil || name == nil) {
        // Didn't find anything
        continue;
      }

      // If highlighting, check with delegate first. If not implemented, assume YES.
      if (highlighting
          && [self->_delegate respondsToSelector:@selector(textNode:shouldHighlightLinkAttribute:value:atPoint:)]
          && ![self->_delegate textNode:self shouldHighlightLinkAttribute:name value:value atPoint:point]) {
        value = nil;
        name = nil;
      }

      if (value != nil || name != nil) {
        // We found a minimum glyph distance link attribute, so set the min
        // distance, and the out params.
        minimumGlyphDistance = currentDistance;

        if (rangeOut != NULL && value != nil) {
          *rangeOut = range;
          // Limit to only the visible range, because the attributed string will
          // return values outside the visible range.
          if (NSMaxRange(*rangeOut) > NSMaxRange(visibleRange)) {
            (*rangeOut).length = MAX(NSMaxRange(visibleRange) - (*rangeOut).location, 0);
          }
        }

        if (attributeNameOut != NULL) {
          *attributeNameOut = name;
        }

        // Set the values for the next iteration
        linkAttributeValue = value;

        break;
      }
    }
  }];

  return linkAttributeValue;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  ASDisplayNodeAssertMainThread();
  
  if (gestureRecognizer == _longPressGestureRecognizer) {
    // Don't allow long press on truncation message
    if ([self _pendingTruncationTap]) {
      return NO;
    }

    // Ask our delegate if a long-press on an attribute is relevant
    if ([self _pendingLinkTap] && [_delegate respondsToSelector:@selector(textNode:shouldLongPressLinkAttribute:value:atPoint:)]) {
      return [_delegate textNode:self
        shouldLongPressLinkAttribute:_highlightedLinkAttributeName
                               value:_highlightedLinkAttributeValue
                             atPoint:[gestureRecognizer locationInView:self.view]];
    }

    // Otherwise we are good to go.
    return YES;
  }

  if (([self _pendingLinkTap] || [self _pendingTruncationTap])
      && [gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]
      && CGRectContainsPoint(self.threadSafeBounds, [gestureRecognizer locationInView:self.view])) {
    return NO;
  }

  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

#pragma mark - Highlighting

- (ASTextNodeHighlightStyle)highlightStyle
{
  ASLockScopeSelf();
  
  return _highlightStyle;
}

- (void)setHighlightStyle:(ASTextNodeHighlightStyle)highlightStyle
{
  ASLockScopeSelf();
  
  _highlightStyle = highlightStyle;
}

- (NSRange)highlightRange
{
  ASDisplayNodeAssertMainThread();
  
  return _highlightRange;
}

- (void)setHighlightRange:(NSRange)highlightRange
{
  [self setHighlightRange:highlightRange animated:NO];
}

- (void)setHighlightRange:(NSRange)highlightRange animated:(BOOL)animated
{
  [self _setHighlightRange:highlightRange forAttributeName:nil value:nil animated:animated];
}

- (void)_setHighlightRange:(NSRange)highlightRange forAttributeName:(NSString *)highlightedAttributeName value:(id)highlightedAttributeValue animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();

  _highlightedLinkAttributeName = highlightedAttributeName;
  _highlightedLinkAttributeValue = highlightedAttributeValue;

  if (!NSEqualRanges(highlightRange, _highlightRange) && ((0 != highlightRange.length) || (0 != _highlightRange.length))) {

    _highlightRange = highlightRange;

    if (_activeHighlightLayer) {
      if (animated) {
        __weak CALayer *weakHighlightLayer = _activeHighlightLayer;
        _activeHighlightLayer = nil;

        weakHighlightLayer.opacity = 0.0;

        CFTimeInterval beginTime = CACurrentMediaTime();
        CABasicAnimation *possibleFadeIn = (CABasicAnimation *)[weakHighlightLayer animationForKey:@"opacity"];
        if (possibleFadeIn) {
          // Calculate when we should begin fading out based on the end of the fade in animation,
          // Also check to make sure that the new begin time hasn't already passed
          CGFloat newBeginTime = (possibleFadeIn.beginTime + possibleFadeIn.duration);
          if (newBeginTime > beginTime) {
            beginTime = newBeginTime;
          }
        }
        
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeOut.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fadeOut.fromValue = possibleFadeIn.toValue ? : @(((CALayer *)weakHighlightLayer.presentationLayer).opacity);
        fadeOut.toValue = @0.0;
        fadeOut.fillMode = kCAFillModeBoth;
        fadeOut.duration = ASTextNodeHighlightFadeOutDuration;
        fadeOut.beginTime = beginTime;

        dispatch_block_t prev = [CATransaction completionBlock];
        [CATransaction setCompletionBlock:^{
          [weakHighlightLayer removeFromSuperlayer];
        }];

        [weakHighlightLayer addAnimation:fadeOut forKey:fadeOut.keyPath];

        [CATransaction setCompletionBlock:prev];

      } else {
        [_activeHighlightLayer removeFromSuperlayer];
        _activeHighlightLayer = nil;
      }
    }
    if (0 != highlightRange.length) {
      // Find layer in hierarchy that allows us to draw highlighting on.
      CALayer *highlightTargetLayer = self.layer;
      while (highlightTargetLayer != nil) {
        if (highlightTargetLayer.as_allowsHighlightDrawing) {
          break;
        }
        highlightTargetLayer = highlightTargetLayer.superlayer;
      }

      if (highlightTargetLayer != nil) {
        ASLockScopeSelf();
        ASTextKitRenderer *renderer = [self _locked_renderer];

        NSArray *highlightRects = [renderer rectsForTextRange:highlightRange measureOption:ASTextKitRendererMeasureOptionBlock];
        NSMutableArray *converted = [NSMutableArray arrayWithCapacity:highlightRects.count];
        for (NSValue *rectValue in highlightRects) {
          UIEdgeInsets shadowPadding = renderer.shadower.shadowPadding;
          CGRect rendererRect = ASTextNodeAdjustRenderRectForShadowPadding(rectValue.CGRectValue, shadowPadding);

          // The rects returned from renderer don't have `textContainerInset`,
          // as well as they are using the `constrainedSize` for layout,
          // so we can simply increase the rect by insets to get the full blown layout.
          rendererRect.size.width += _textContainerInset.left + _textContainerInset.right;
          rendererRect.size.height += _textContainerInset.top + _textContainerInset.bottom;

          CGRect highlightedRect = [self.layer convertRect:rendererRect toLayer:highlightTargetLayer];

          // We set our overlay layer's frame to the bounds of the highlight target layer.
          // Offset highlight rects to avoid double-counting target layer's bounds.origin.
          highlightedRect.origin.x -= highlightTargetLayer.bounds.origin.x;
          highlightedRect.origin.y -= highlightTargetLayer.bounds.origin.y;
          [converted addObject:[NSValue valueWithCGRect:highlightedRect]];
        }

        ASHighlightOverlayLayer *overlayLayer = [[ASHighlightOverlayLayer alloc] initWithRects:converted];
        overlayLayer.highlightColor = [[self class] _highlightColorForStyle:self.highlightStyle];
        overlayLayer.frame = highlightTargetLayer.bounds;
        overlayLayer.masksToBounds = NO;
        overlayLayer.opacity = [[self class] _highlightOpacityForStyle:self.highlightStyle];
        [highlightTargetLayer addSublayer:overlayLayer];

        if (animated) {
          CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
          fadeIn.fromValue = @0.0;
          fadeIn.toValue = @(overlayLayer.opacity);
          fadeIn.duration = ASTextNodeHighlightFadeInDuration;
          fadeIn.beginTime = CACurrentMediaTime();

          [overlayLayer addAnimation:fadeIn forKey:fadeIn.keyPath];
        }

        [overlayLayer setNeedsDisplay];

        _activeHighlightLayer = overlayLayer;
      }
    }
  }
}

- (void)_clearHighlightIfNecessary
{
  ASDisplayNodeAssertMainThread();
  
  if ([self _pendingLinkTap] || [self _pendingTruncationTap]) {
    [self setHighlightRange:NSMakeRange(0, 0) animated:YES];
  }
}

+ (CGColorRef)_highlightColorForStyle:(ASTextNodeHighlightStyle)style
{
  return [UIColor colorWithWhite:(style == ASTextNodeHighlightStyleLight ? 0.0 : 1.0) alpha:1.0].CGColor;
}

+ (CGFloat)_highlightOpacityForStyle:(ASTextNodeHighlightStyle)style
{
  return (style == ASTextNodeHighlightStyleLight) ? ASTextNodeHighlightLightOpacity : ASTextNodeHighlightDarkOpacity;
}

#pragma mark - Text rects

static CGRect ASTextNodeAdjustRenderRectForShadowPadding(CGRect rendererRect, UIEdgeInsets shadowPadding) {
  rendererRect.origin.x -= shadowPadding.left;
  rendererRect.origin.y -= shadowPadding.top;
  return rendererRect;
}

- (NSArray *)rectsForTextRange:(NSRange)textRange
{
  return [self _rectsForTextRange:textRange measureOption:ASTextKitRendererMeasureOptionCapHeight];
}

- (NSArray *)highlightRectsForTextRange:(NSRange)textRange
{
  return [self _rectsForTextRange:textRange measureOption:ASTextKitRendererMeasureOptionBlock];
}

- (NSArray *)_rectsForTextRange:(NSRange)textRange measureOption:(ASTextKitRendererMeasureOption)measureOption
{
  ASLockScopeSelf();
  
  NSArray *rects = [[self _locked_renderer] rectsForTextRange:textRange measureOption:measureOption];
  const auto adjustedRects = [[NSMutableArray<NSValue *> alloc] init];

  for (NSValue *rectValue in rects) {
    CGRect rect = [rectValue CGRectValue];
    rect = ASTextNodeAdjustRenderRectForShadowPadding(rect, self.shadowPadding);

    NSValue *adjustedRectValue = [NSValue valueWithCGRect:rect];
    [adjustedRects addObject:adjustedRectValue];
  }

  return adjustedRects;
}

- (CGRect)trailingRect
{
  ASLockScopeSelf();
  
  CGRect rect = [[self _locked_renderer] trailingRect];
  return ASTextNodeAdjustRenderRectForShadowPadding(rect, self.shadowPadding);
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  ASLockScopeSelf();
  
  CGRect frame = [[self _locked_renderer] frameForTextRange:textRange];
  return ASTextNodeAdjustRenderRectForShadowPadding(frame, self.shadowPadding);
}

#pragma mark - Placeholders

- (UIColor *)placeholderColor
{
  return ASLockedSelf(_placeholderColor);
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  if (ASLockedSelfCompareAssignCopy(_placeholderColor, placeholderColor)) {
    self.placeholderEnabled = CGColorGetAlpha(placeholderColor.CGColor) > 0;
  }
}

- (UIImage *)placeholderImage
{
  // FIXME: Replace this implementation with reusable CALayers that have .backgroundColor set.
  // This would completely eliminate the memory and performance cost of the backing store.
  CGSize size = self.calculatedSize;
  if ((size.width * size.height) < CGFLOAT_EPSILON) {
    return nil;
  }
  
  ASLockScopeSelf();
  
  ASGraphicsBeginImageContextWithOptions(size, NO, 1.0);
  [self.placeholderColor setFill];

  ASTextKitRenderer *renderer = [self _locked_renderer];
  NSRange visibleRange = renderer.firstVisibleRange;

  // cap height is both faster and creates less subpixel blending
  NSArray *lineRects = [self _rectsForTextRange:visibleRange measureOption:ASTextKitRendererMeasureOptionLineHeight];

  // fill each line with the placeholder color
  for (NSValue *rectValue in lineRects) {
    CGRect lineRect = [rectValue CGRectValue];
    CGRect fillBounds = CGRectIntegral(UIEdgeInsetsInsetRect(lineRect, self.placeholderInsets));

    if (fillBounds.size.width > 0.0 && fillBounds.size.height > 0.0) {
      UIRectFill(fillBounds);
    }
  }

  UIImage *image = ASGraphicsGetImageAndEndCurrentContext();
  return image;
}

#pragma mark - Touch Handling

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  
  if (!_passthroughNonlinkTouches) {
    return [super pointInside:point withEvent:event];
  }

  NSRange range = NSMakeRange(0, 0);
  NSString *linkAttributeName = nil;
  BOOL inAdditionalTruncationMessage = NO;

  id linkAttributeValue = [self _linkAttributeValueAtPoint:point
                                             attributeName:&linkAttributeName
                                                     range:&range
                             inAdditionalTruncationMessage:&inAdditionalTruncationMessage
                                           forHighlighting:YES];

  NSUInteger lastCharIndex = NSIntegerMax;
  BOOL linkCrossesVisibleRange = (lastCharIndex > range.location) && (lastCharIndex < NSMaxRange(range) - 1);

  if (range.length > 0 && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
    return YES;
  } else {
    return NO;
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  
  [super touchesBegan:touches withEvent:event];

  CGPoint point = [[touches anyObject] locationInView:self.view];

  NSRange range = NSMakeRange(0, 0);
  NSString *linkAttributeName = nil;
  BOOL inAdditionalTruncationMessage = NO;

  id linkAttributeValue = [self _linkAttributeValueAtPoint:point
                                             attributeName:&linkAttributeName
                                                     range:&range
                             inAdditionalTruncationMessage:&inAdditionalTruncationMessage
                                           forHighlighting:YES];

  NSUInteger lastCharIndex = NSIntegerMax;
  BOOL linkCrossesVisibleRange = (lastCharIndex > range.location) && (lastCharIndex < NSMaxRange(range) - 1);

  if (inAdditionalTruncationMessage) {
    NSRange visibleRange = NSMakeRange(0, 0);
    {
      ASLockScopeSelf();
      visibleRange = [self _locked_renderer].firstVisibleRange;
    }
    NSRange truncationMessageRange = [self _additionalTruncationMessageRangeWithVisibleRange:visibleRange];
    [self _setHighlightRange:truncationMessageRange forAttributeName:ASTextNodeTruncationTokenAttributeName value:nil animated:YES];
  } else if (range.length > 0 && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
    [self _setHighlightRange:range forAttributeName:linkAttributeName value:linkAttributeValue animated:YES];
  }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesCancelled:touches withEvent:event];
  
  [self _clearHighlightIfNecessary];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesEnded:touches withEvent:event];
  
  if ([self _pendingLinkTap] && [_delegate respondsToSelector:@selector(textNode:tappedLinkAttribute:value:atPoint:textRange:)]) {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [_delegate textNode:self tappedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:point textRange:_highlightRange];
  }

  if ([self _pendingTruncationTap]) {
    if ([_delegate respondsToSelector:@selector(textNodeTappedTruncationToken:)]) {
      [_delegate textNodeTappedTruncationToken:self];
    }
  }

  [self _clearHighlightIfNecessary];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  [super touchesMoved:touches withEvent:event];

  UITouch *touch = [touches anyObject];
  CGPoint locationInView = [touch locationInView:self.view];
  // on 3D Touch enabled phones, this gets fired with changes in force, and usually will get fired immediately after touchesBegan:withEvent:
  if (CGPointEqualToPoint([touch previousLocationInView:self.view], locationInView))
    return;
  
  // If touch has moved out of the current highlight range, clear the highlight.
  if (_highlightRange.length > 0) {
    NSRange range = NSMakeRange(0, 0);
    [self _linkAttributeValueAtPoint:locationInView
                       attributeName:NULL
                               range:&range
       inAdditionalTruncationMessage:NULL
                     forHighlighting:YES];

    if (!NSEqualRanges(_highlightRange, range)) {
      [self _clearHighlightIfNecessary];
    }
  }
}

- (void)_handleLongPress:(UILongPressGestureRecognizer *)longPressRecognizer
{
  ASDisplayNodeAssertMainThread();
  
  // Respond to long-press when it begins, not when it ends.
  if (longPressRecognizer.state == UIGestureRecognizerStateBegan) {
    if ([self _pendingLinkTap] && [_delegate respondsToSelector:@selector(textNode:longPressedLinkAttribute:value:atPoint:textRange:)]) {
      CGPoint touchPoint = [_longPressGestureRecognizer locationInView:self.view];
      [_delegate textNode:self longPressedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:touchPoint textRange:_highlightRange];
    }
  }
}

- (BOOL)_pendingLinkTap
{
  ASLockScopeSelf();
  
  return (_highlightedLinkAttributeValue != nil && ![self _pendingTruncationTap]) && _delegate != nil;
}

- (BOOL)_pendingTruncationTap
{
  ASLockScopeSelf();
  
  return [_highlightedLinkAttributeName isEqualToString:ASTextNodeTruncationTokenAttributeName];
}

#pragma mark - Shadow Properties

- (CGColorRef)shadowColor
{
  return ASLockedSelf(_shadowColor);
}

- (void)setShadowColor:(CGColorRef)shadowColor
{
  [self lock];

  if (_shadowColor != shadowColor && CGColorEqualToColor(shadowColor, _shadowColor) == NO) {
    CGColorRelease(_shadowColor);
    _shadowColor = CGColorRetain(shadowColor);
    _cachedShadowUIColor = [UIColor colorWithCGColor:shadowColor];
    [self unlock];
    
    [self setNeedsDisplay];
    return;
  }

  [self unlock];
}

- (CGSize)shadowOffset
{
  return ASLockedSelf(_shadowOffset);
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
  if (ASLockedSelfCompareAssignCustom(_shadowOffset, shadowOffset, CGSizeEqualToSize)) {
    [self setNeedsDisplay];
  }
}

- (CGFloat)shadowOpacity
{
  return ASLockedSelf(_shadowOpacity);
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
  if (ASLockedSelfCompareAssign(_shadowOpacity, shadowOpacity)) {
    [self setNeedsDisplay];
  }
}

- (CGFloat)shadowRadius
{
  return ASLockedSelf(_shadowRadius);
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
  if (ASLockedSelfCompareAssign(_shadowRadius, shadowRadius)) {
    [self setNeedsDisplay];
  }
}

- (UIEdgeInsets)shadowPadding
{
  ASLockScopeSelf();
  return [self _locked_renderer].shadower.shadowPadding;
}

#pragma mark - Truncation Message

static NSAttributedString *DefaultTruncationAttributedString()
{
  static NSAttributedString *defaultTruncationAttributedString;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultTruncationAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"\u2026", @"Default truncation string")];
  });
  return defaultTruncationAttributedString;
}

- (NSAttributedString *)truncationAttributedText
{
  return ASLockedSelf(_truncationAttributedText);
}

- (void)setTruncationAttributedText:(NSAttributedString *)truncationAttributedText
{
  if (ASLockedSelfCompareAssignCopy(_truncationAttributedText, truncationAttributedText)) {
    [self _invalidateTruncationText];
    [self setNeedsDisplay];
  }
}

- (void)setAdditionalTruncationMessage:(NSAttributedString *)additionalTruncationMessage
{
  if (ASLockedSelfCompareAssignCopy(_additionalTruncationMessage, additionalTruncationMessage)) {
    [self _invalidateTruncationText];
    [self setNeedsDisplay];
  }
}

- (NSAttributedString *)additionalTruncationMessage
{
  return ASLockedSelf(_additionalTruncationMessage);
}

- (void)setTruncationMode:(NSLineBreakMode)truncationMode
{
  if (ASLockedSelfCompareAssign(_truncationMode, truncationMode)) {
    [self setNeedsDisplay];
  }
}

- (NSLineBreakMode)truncationMode
{
  return ASLockedSelf(_truncationMode);
}

- (BOOL)isTruncated
{
  return ASLockedSelf([[self _locked_renderer] isTruncated]);
}

- (BOOL)shouldTruncateForConstrainedSize:(ASSizeRange)constrainedSize
{
  return ASLockedSelf([[self _locked_rendererWithBounds:{.size = constrainedSize.max}] isTruncated]);
}

- (void)setPointSizeScaleFactors:(NSArray<NSNumber *> *)pointSizeScaleFactors
{
  if (ASLockedSelfCompareAssignCopy(_pointSizeScaleFactors, pointSizeScaleFactors)) {
    [self setNeedsDisplay];
  }
}

- (NSArray<NSNumber *> *)pointSizeScaleFactors
{
  return ASLockedSelf(_pointSizeScaleFactors);
}

- (void)setMaximumNumberOfLines:(NSUInteger)maximumNumberOfLines
{
  if (ASLockedSelfCompareAssign(_maximumNumberOfLines, maximumNumberOfLines)) {
    [self setNeedsDisplay];
  }
}

- (NSUInteger)maximumNumberOfLines
{
   return ASLockedSelf(_maximumNumberOfLines);
}

- (NSUInteger)lineCount
{
  return ASLockedSelf([[self _locked_renderer] lineCount]);
}

#pragma mark - Truncation Message

- (void)_invalidateTruncationText
{
  ASLockScopeSelf();
  [self _locked_invalidateTruncationText];
}

- (void)_locked_invalidateTruncationText
{
  _composedTruncationText = nil;
}

/**
 * @return the additional truncation message range within the as-rendered text.
 * Must be called from main thread
 */
- (NSRange)_additionalTruncationMessageRangeWithVisibleRange:(NSRange)visibleRange
{
  ASLockScopeSelf();
  
  // Check if we even have an additional truncation message.
  if (!_additionalTruncationMessage) {
    return NSMakeRange(NSNotFound, 0);
  }

  // Character location of the unicode ellipsis (the first index after the visible range)
  NSInteger truncationTokenIndex = NSMaxRange(visibleRange);

  NSUInteger additionalTruncationMessageLength = _additionalTruncationMessage.length;
  // We get the location of the truncation token, then add the length of the
  // truncation attributed string +1 for the space between.
  return NSMakeRange(truncationTokenIndex + _truncationAttributedText.length + 1, additionalTruncationMessageLength);
}

/**
 * @return the truncation message for the string.  If there are both an
 * additional truncation message and a truncation attributed string, they will
 * be properly composed.
 */
- (NSAttributedString *)_locked_composedTruncationText
{
  ASAssertLocked(__instanceLock__);
  if (_composedTruncationText == nil) {
    if (_truncationAttributedText != nil && _additionalTruncationMessage != nil) {
      NSMutableAttributedString *newComposedTruncationString = [[NSMutableAttributedString alloc] initWithAttributedString:_truncationAttributedText];
      [newComposedTruncationString.mutableString appendString:@" "];
      [newComposedTruncationString appendAttributedString:_additionalTruncationMessage];
      _composedTruncationText = newComposedTruncationString;
    } else if (_truncationAttributedText != nil) {
      _composedTruncationText = _truncationAttributedText;
    } else if (_additionalTruncationMessage != nil) {
      _composedTruncationText = _additionalTruncationMessage;
    } else {
      _composedTruncationText = DefaultTruncationAttributedString();
    }
    _composedTruncationText = [self _locked_prepareTruncationStringForDrawing:_composedTruncationText];
  }
  return _composedTruncationText;
}

/**
 * - cleanses it of core text attributes so TextKit doesn't crash
 * - Adds whole-string attributes so the truncation message matches the styling
 * of the body text
 */
- (NSAttributedString *)_locked_prepareTruncationStringForDrawing:(NSAttributedString *)truncationString
{
  ASAssertLocked(__instanceLock__);
  truncationString = ASCleanseAttributedStringOfCoreTextAttributes(truncationString);
  NSMutableAttributedString *truncationMutableString = [truncationString mutableCopy];
  // Grab the attributes from the full string
  if (_attributedText.length > 0) {
    NSAttributedString *originalString = _attributedText;
    NSInteger originalStringLength = _attributedText.length;
    // Add any of the original string's attributes to the truncation string,
    // but don't overwrite any of the truncation string's attributes
    NSDictionary *originalStringAttributes = [originalString attributesAtIndex:originalStringLength-1 effectiveRange:NULL];
    [truncationString enumerateAttributesInRange:NSMakeRange(0, truncationString.length) options:0 usingBlock:
     ^(NSDictionary *attributes, NSRange range, BOOL *stop) {
       NSMutableDictionary *futureTruncationAttributes = [originalStringAttributes mutableCopy];
       [futureTruncationAttributes addEntriesFromDictionary:attributes];
       [truncationMutableString setAttributes:futureTruncationAttributes range:range];
     }];
  }
  return truncationMutableString;
}

#if AS_TEXTNODE_RECORD_ATTRIBUTED_STRINGS
+ (void)_registerAttributedText:(NSAttributedString *)str
{
  static NSMutableArray *array;
  static NSLock *lock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    lock = [NSLock new];
    array = [NSMutableArray new];
  });
  [lock lock];
  [array addObject:str];
  if (array.count % 20 == 0) {
    NSLog(@"Got %d strings", (int)array.count);
  }
  if (array.count == 2000) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AttributedStrings.plist"];
    NSAssert([NSKeyedArchiver archiveRootObject:array toFile:path], nil);
    NSLog(@"Saved to %@", path);
  }
  [lock unlock];
}
#endif

// All direct descendants of ASTextNode get their superclass replaced by ASTextNode2.
+ (void)initialize
{
  // Texture requires that node subclasses call [super initialize]
  [super initialize];

  if (class_getSuperclass(self) == [ASTextNode class]
      && ASActivateExperimentalFeature(ASExperimentalTextNode)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    class_setSuperclass(self, [ASTextNode2 class]);
#pragma clang diagnostic pop
  }
}

// For direct allocations of ASTextNode itself, we override allocWithZone:
+ (id)allocWithZone:(struct _NSZone *)zone
{
  if (ASActivateExperimentalFeature(ASExperimentalTextNode)) {
    return (ASTextNode *)[ASTextNode2 allocWithZone:zone];
  } else {
    return [super allocWithZone:zone];
  }
}

@end

@implementation ASTextNode (Unsupported)

- (void)setTextContainerLinePositionModifier:(id)textContainerLinePositionModifier
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
}

- (id)textContainerLinePositionModifier
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return nil;
}

@end

@implementation ASTextNode (Deprecated)

- (void)setAttributedString:(NSAttributedString *)attributedString
{
  self.attributedText = attributedString;
}

- (NSAttributedString *)attributedString
{
  return self.attributedText;
}

- (void)setTruncationAttributedString:(NSAttributedString *)truncationAttributedString
{
  self.truncationAttributedText = truncationAttributedString;
}

- (NSAttributedString *)truncationAttributedString
{
  return self.truncationAttributedText;
}

@end

#endif
