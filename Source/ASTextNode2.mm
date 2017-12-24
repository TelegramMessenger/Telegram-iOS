//
//  ASTextNode2.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextNode2.h>
#import <AsyncDisplayKit/ASTextNode.h>  // Definition of ASTextNodeDelegate

#import <tgmath.h>
#import <deque>

#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASHighlightOverlayLayer.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>

#import <AsyncDisplayKit/ASTextKitRenderer+Positioning.h>
#import <AsyncDisplayKit/ASTextKitShadower.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>

#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASTextLayout.h>

@interface ASTextCacheValue : NSObject {
  @package
  ASDN::Mutex _m;
  std::deque<std::tuple<CGSize, ASTextLayout *>> _layouts;
}
@end
@implementation ASTextCacheValue
@end

/**
 * If set, we will record all values set to attributedText into an array
 * and once we get 2000, we'll write them all out into a plist file.
 *
 * This is useful for gathering realistic text data sets from apps for performance
 * testing.
 */
#define AS_TEXTNODE2_RECORD_ATTRIBUTED_STRINGS 0

#define AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE() { \
  static dispatch_once_t onceToken; \
  dispatch_once(&onceToken, ^{ \
    NSLog(@"[Texture] Warning: Feature %@ is unimplemented in the experimental text node.", NSStringFromSelector(_cmd)); \
  });\
}

static const CGFloat ASTextNodeHighlightLightOpacity = 0.11;
static const CGFloat ASTextNodeHighlightDarkOpacity = 0.22;
static NSString *ASTextNodeTruncationTokenAttributeName = @"ASTextNodeTruncationAttribute";

@interface ASTextNode2 () <UIGestureRecognizerDelegate>

@end

@implementation ASTextNode2 {
  ASTextContainer *_textContainer;
  
  CGSize _shadowOffset;
  CGColorRef _shadowColor;
  CGFloat _shadowOpacity;
  CGFloat _shadowRadius;
  
  NSAttributedString *_attributedText;
  NSAttributedString *_composedTruncationText;
  NSArray<NSNumber *> *_pointSizeScaleFactors;
  
  NSString *_highlightedLinkAttributeName;
  id _highlightedLinkAttributeValue;
  ASTextNodeHighlightStyle _highlightStyle;
  NSRange _highlightRange;
  ASHighlightOverlayLayer *_activeHighlightLayer;
  
  UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@dynamic placeholderEnabled;

static NSArray *DefaultLinkAttributeNames = @[ NSLinkAttributeName ];

- (instancetype)init
{
  if (self = [super init]) {
    _textContainer = [[ASTextContainer alloc] init];
    // Load default values from superclass.
    _shadowOffset = [super shadowOffset];
    _shadowColor = CGColorRetain([super shadowColor]);
    _shadowOpacity = [super shadowOpacity];
    _shadowRadius = [super shadowRadius];
    
    // Disable user interaction for text node by default.
    self.userInteractionEnabled = NO;
    self.needsDisplayOnBoundsChange = YES;
    
    _textContainer.truncationType = ASTextTruncationTypeEnd;
    
    // The common case is for a text node to be non-opaque and blended over some background.
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    
    self.linkAttributeNames = DefaultLinkAttributeNames;
    
    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    
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
    plainString = [[plainString substringToIndex:50] stringByAppendingString:@"…"];
  }
  return plainString;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray *result = [super propertiesForDescription];
  NSString *plainString = [self _plainStringForDescription];
  if (plainString.length > 0) {
    [result insertObject:@{ @"text" : ASStringWithQuotesIfMultiword(plainString) } atIndex:0];
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

#pragma mark - Layout and Sizing

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
  BOOL needsUpdate = !UIEdgeInsetsEqualToEdgeInsets(_textContainer.insets, textContainerInset);
  _textContainer.insets = textContainerInset;
  
  if (needsUpdate) {
    [self setNeedsLayout];
  }
}

- (UIEdgeInsets)textContainerInset
{
  return _textContainer.insets;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDisplayNodeAssert(constrainedSize.width >= 0, @"Constrained width for text (%f) is too  narrow", constrainedSize.width);
  ASDisplayNodeAssert(constrainedSize.height >= 0, @"Constrained height for text (%f) is too short", constrainedSize.height);
  
  ASTextContainer *container = [_textContainer copy];
  NSAttributedString *attributedText = self.attributedText;
  container.size = constrainedSize;
  [self _ensureTruncationText];
  
  NSMutableAttributedString *mutableText = [attributedText mutableCopy];
  [self prepareAttributedStringForDrawing:mutableText];
  ASTextLayout *layout = [ASTextNode2 compatibleLayoutWithContainer:container text:mutableText];
  
  [self setNeedsDisplay];
  
  return layout.textBoundingSize;
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
  ASDN::MutexLocker l(__instanceLock__);
  return _attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  
  if (attributedText == nil) {
    attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:nil];
  }
  
  // Don't hold textLock for too long.
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (ASObjectIsEqual(attributedText, _attributedText)) {
      return;
    }
    
    _attributedText = attributedText;
#if AS_TEXTNODE2_RECORD_ATTRIBUTED_STRINGS
    [ASTextNode _registerAttributedText:_attributedText];
#endif
  }
  
  // Since truncation text matches style of attributedText, invalidate it now.
  [self _invalidateTruncationText];
  
  NSUInteger length = attributedText.length;
  if (length > 0) {
    self.style.ascender = [[self class] ascenderWithAttributedString:attributedText];
    self.style.descender = [[attributedText attribute:NSFontAttributeName atIndex:attributedText.length - 1 effectiveRange:NULL] descender];
  }
  
  // Tell the display node superclasses that the cached layout is incorrect now
  [self setNeedsLayout];
  
  // Force display to create renderer with new size and redisplay with new string
  [self setNeedsDisplay];
  
  
  // Accessiblity
  self.accessibilityLabel = attributedText.string;
  self.isAccessibilityElement = (length != 0); // We're an accessibility element by default if there is a string.
}

#pragma mark - Text Layout

- (void)setExclusionPaths:(NSArray *)exclusionPaths
{
  _textContainer.exclusionPaths = exclusionPaths;
  
  [self setNeedsLayout];
  [self setNeedsDisplay];
}

- (NSArray *)exclusionPaths
{
  return _textContainer.exclusionPaths;
}

- (void)prepareAttributedStringForDrawing:(NSMutableAttributedString *)attributedString
{
  ASDN::MutexLocker lock(__instanceLock__);
 
  // Apply paragraph style if needed
  [attributedString enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, attributedString.length) options:kNilOptions usingBlock:^(NSParagraphStyle *style, NSRange range, BOOL * _Nonnull stop) {
    if (style == nil || style.lineBreakMode == _truncationMode) {
      return;
    }
    
    NSMutableParagraphStyle *paragraphStyle = [style mutableCopy] ?: [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = _truncationMode;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
  }];
  
  // Apply background color if needed
  UIColor *backgroundColor = self.backgroundColor;
  if (CGColorGetAlpha(backgroundColor.CGColor) > 0) {
    [attributedString addAttribute:NSBackgroundColorAttributeName value:backgroundColor range:NSMakeRange(0, attributedString.length)];
  }
  
  // Apply shadow if needed
  if (_shadowOpacity > 0 && (_shadowRadius != 0 || !CGSizeEqualToSize(_shadowOffset, CGSizeZero)) && CGColorGetAlpha(_shadowColor) > 0) {
    NSShadow *shadow = [[NSShadow alloc] init];
    if (_shadowOpacity != 1) {
      shadow.shadowColor = [UIColor colorWithCGColor:CGColorCreateCopyWithAlpha(_shadowColor, _shadowOpacity * CGColorGetAlpha(_shadowColor))];
    } else {
      shadow.shadowColor = [UIColor colorWithCGColor:_shadowColor];
    }
    shadow.shadowOffset = _shadowOffset;
    shadow.shadowBlurRadius = _shadowRadius;
    [attributedString addAttribute:NSShadowAttributeName value:shadow range:NSMakeRange(0, attributedString.length)];
  }
}

#pragma mark - Drawing

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  [self _ensureTruncationText];
  ASTextContainer *copiedContainer = [_textContainer copy];
  copiedContainer.size = self.bounds.size;
  NSMutableAttributedString *mutableText = [self.attributedText mutableCopy] ?: [[NSMutableAttributedString alloc] init];
  [self prepareAttributedStringForDrawing:mutableText];
  return @{
           @"container": copiedContainer,
           @"text": mutableText
           };
}

/**
 * If it can't find a compatible layout, this method creates one.
 */
+ (ASTextLayout *)compatibleLayoutWithContainer:(ASTextContainer *)container
                                           text:(NSAttributedString *)text

{
  // Allocate layoutCacheLock on the heap to prevent destruction at app exit (https://github.com/TextureGroup/Texture/issues/136)
  static ASDN::StaticMutex& layoutCacheLock = *new ASDN::StaticMutex;
  static NSCache<NSAttributedString *, ASTextCacheValue *> *textLayoutCache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    textLayoutCache = [[NSCache alloc] init];
  });
  
  ASTextCacheValue *cacheValue = ({
    ASDN::StaticMutexLocker lock(layoutCacheLock);
    cacheValue = [textLayoutCache objectForKey:text];
    if (cacheValue == nil) {
      cacheValue = [[ASTextCacheValue alloc] init];
      [textLayoutCache setObject:cacheValue forKey:text];
    }
    cacheValue;
  });
  
  CGRect containerBounds = (CGRect){ .size = container.size };
  {
    ASDN::MutexLocker lock(cacheValue->_m);
    for (auto &t : cacheValue->_layouts) {
      CGSize constrainedSize = std::get<0>(t);
      ASTextLayout *layout = std::get<1>(t);
      
      CGSize layoutSize = layout.textBoundingSize;
      // 1. CoreText can return frames that are narrower than the constrained width, for obvious reasons.
      // 2. CoreText can return frames that are slightly wider than the constrained width, for some reason.
      //    We have to trust that somehow it's OK to try and draw within our size constraint, despite the return value.
      // 3. Thus, those two values (constrained width & returned width) form a range, where
      //    intermediate values in that range will be snapped. Thus, we can use a given layout as long as our
      //    width is in that range, between the min and max of those two values.
      CGRect minRect = CGRectMake(0, 0, MIN(layoutSize.width, constrainedSize.width), MIN(layoutSize.height, constrainedSize.height));
      if (!CGRectContainsRect(containerBounds, minRect)) {
        continue;
      }
      CGRect maxRect = CGRectMake(0, 0, MAX(layoutSize.width, constrainedSize.width), MAX(layoutSize.height, constrainedSize.height));
      if (!CGRectContainsRect(maxRect, containerBounds)) {
        continue;
      }
      
      // Now check container params.
      ASTextContainer *otherContainer = layout.container;
      if (!UIEdgeInsetsEqualToEdgeInsets(container.insets, otherContainer.insets)) {
        continue;
      }
      if (!ASObjectIsEqual(container.exclusionPaths, otherContainer.exclusionPaths)) {
        continue;
      }
      if (container.maximumNumberOfRows != otherContainer.maximumNumberOfRows) {
        continue;
      }
      if (container.truncationType != otherContainer.truncationType) {
        continue;
      }
      if (!ASObjectIsEqual(container.truncationToken, otherContainer.truncationToken)) {
        continue;
      }
      // TODO: When we get a cache hit, move this entry to the front (LRU).
      return layout;
    }
  }
  
  // Cache Miss.
  
  // Compute the text layout.
  ASTextLayout *layout = [ASTextLayout layoutWithContainer:container text:text];
  
  // Store the result in the cache.
  {
    ASDN::MutexLocker lock(cacheValue->_m);
    cacheValue->_layouts.push_front(std::make_tuple(container.size, layout));
    if (cacheValue->_layouts.size() > 3) {
      cacheValue->_layouts.pop_back();
    }
  }
  
  return layout;
}

+ (void)drawRect:(CGRect)bounds withParameters:(NSDictionary *)layoutDict isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;
{
  ASTextContainer *container = layoutDict[@"container"];
  NSAttributedString *text = layoutDict[@"text"];
  ASTextLayout *layout = [self compatibleLayoutWithContainer:container text:text];
  
  if (isCancelledBlock()) {
    return;
  }
  CGContextRef context = UIGraphicsGetCurrentContext();
  ASDisplayNodeAssert(context, @"This is no good without a context.");
  
  [layout drawInContext:context size:bounds.size point:bounds.origin view:nil layer:nil debug:[ASTextDebugOption sharedDebugOption] cancel:isCancelledBlock];
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
                   attributeName:(out NSString **)attributeNameOut
                           range:(out NSRange *)rangeOut
   inAdditionalTruncationMessage:(out BOOL *)inAdditionalTruncationMessageOut
                 forHighlighting:(BOOL)highlighting
{
  ASDN::MutexLocker l(__instanceLock__);

  // TODO: The copy and application of size shouldn't be required, but it is currently.
  // See discussion in https://github.com/TextureGroup/Texture/pull/396
  ASTextContainer *containerCopy = [_textContainer copy];
  containerCopy.size = self.calculatedSize;
  ASTextLayout *layout = [ASTextNode2 compatibleLayoutWithContainer:containerCopy text:_attributedText];
  NSRange visibleRange = layout.visibleRange;
  NSRange clampedRange = NSIntersectionRange(visibleRange, NSMakeRange(0, _attributedText.length));

  ASTextRange *range = [layout closestTextRangeAtPoint:point];

  // For now, assume that a tap inside this text, but outside the text range is a tap on the
  // truncation token.
  if (![layout textRangeAtPoint:point]) {
    *inAdditionalTruncationMessageOut = YES;
    return nil;
  }

  NSRange effectiveRange = NSMakeRange(0, 0);
  for (__strong NSString *attributeName in self.linkAttributeNames) {
    id value = [self.attributedText attribute:attributeName atIndex:range.start.offset longestEffectiveRange:&effectiveRange inRange:clampedRange];
    if (value == nil) {
      // Didn't find any links specified with this attribute.
      continue;
    }

    // If highlighting, check with delegate first. If not implemented, assume YES.
    if (highlighting
        && [_delegate respondsToSelector:@selector(textNode:shouldHighlightLinkAttribute:value:atPoint:)]
        && ![_delegate textNode:(ASTextNode *)self shouldHighlightLinkAttribute:attributeName value:value atPoint:point]) {
      value = nil;
      attributeName = nil;
    }

    if (value != nil || attributeName != nil) {
      *rangeOut = NSIntersectionRange(visibleRange, effectiveRange);

      if (attributeNameOut != NULL) {
        *attributeNameOut = attributeName;
      }

      return value;
    }
  }

  return nil;
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
    if ([_delegate respondsToSelector:@selector(textNode:shouldLongPressLinkAttribute:value:atPoint:)]) {
      return [_delegate textNode:(ASTextNode *)self
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
  ASDN::MutexLocker l(__instanceLock__);
  
  return _highlightStyle;
}

- (void)setHighlightStyle:(ASTextNodeHighlightStyle)highlightStyle
{
  ASDN::MutexLocker l(__instanceLock__);
  
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
  // Set these so that link tapping works.
  _highlightedLinkAttributeName = highlightedAttributeName;
  _highlightedLinkAttributeValue = highlightedAttributeValue;

  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  // Much of the code from original ASTextNode is probably usable here.

  return;
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

- (NSArray *)rectsForTextRange:(NSRange)textRange
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return @[];
}

- (NSArray *)highlightRectsForTextRange:(NSRange)textRange
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return @[];
}

- (CGRect)trailingRect
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return CGRectZero;
}

- (CGRect)frameForTextRange:(NSRange)textRange
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return CGRectZero;
}

#pragma mark - Placeholders

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  ASDN::MutexLocker l(__instanceLock__);
  
  _placeholderColor = placeholderColor;
  
  // prevent placeholders if we don't have a color
  self.placeholderEnabled = placeholderColor != nil;
}

- (UIImage *)placeholderImage
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return nil;
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
  
  if (inAdditionalTruncationMessage) {
    return YES;
  } else if (range.length && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
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
      ASDN::MutexLocker l(__instanceLock__);
      // TODO: The copy and application of size shouldn't be required, but it is currently.
      // See discussion in https://github.com/TextureGroup/Texture/pull/396
      ASTextContainer *containerCopy = [_textContainer copy];
      containerCopy.size = self.calculatedSize;
      ASTextLayout *layout = [ASTextNode2 compatibleLayoutWithContainer:containerCopy text:_attributedText];
      visibleRange = layout.visibleRange;
    }
    NSRange truncationMessageRange = [self _additionalTruncationMessageRangeWithVisibleRange:visibleRange];
    [self _setHighlightRange:truncationMessageRange forAttributeName:ASTextNodeTruncationTokenAttributeName value:nil animated:YES];
  } else if (range.length && !linkCrossesVisibleRange && linkAttributeValue != nil && linkAttributeName != nil) {
    [self _setHighlightRange:range forAttributeName:linkAttributeName value:linkAttributeValue animated:YES];
  }

  return;
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
    [_delegate textNode:(ASTextNode *)self tappedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:point textRange:_highlightRange];
  }
  
  if ([self _pendingTruncationTap]) {
    if ([_delegate respondsToSelector:@selector(textNodeTappedTruncationToken:)]) {
      [_delegate textNodeTappedTruncationToken:(ASTextNode *)self];
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
    if ([_delegate respondsToSelector:@selector(textNode:longPressedLinkAttribute:value:atPoint:textRange:)]) {
      CGPoint touchPoint = [_longPressGestureRecognizer locationInView:self.view];
      [_delegate textNode:(ASTextNode *)self longPressedLinkAttribute:_highlightedLinkAttributeName value:_highlightedLinkAttributeValue atPoint:touchPoint textRange:_highlightRange];
    }
  }
}

- (BOOL)_pendingLinkTap
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return (_highlightedLinkAttributeValue != nil && ![self _pendingTruncationTap]) && _delegate != nil;
}

- (BOOL)_pendingTruncationTap
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return [_highlightedLinkAttributeName isEqualToString:ASTextNodeTruncationTokenAttributeName];
}

#pragma mark - Shadow Properties

/**
 * Note about shadowed text:
 *
 * Shadowed text is pretty rare, and we are a framework that targets serious developers.
 * We should probably ignore these properties and tell developers to set the shadow into their attributed text instead.
 */
- (CGColorRef)shadowColor
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowColor;
}

- (void)setShadowColor:(CGColorRef)shadowColor
{
  __instanceLock__.lock();
  
  if (_shadowColor != shadowColor && CGColorEqualToColor(shadowColor, _shadowColor) == NO) {
    CGColorRelease(_shadowColor);
    _shadowColor = CGColorRetain(shadowColor);
    __instanceLock__.unlock();
    
    [self setNeedsDisplay];
    return;
  }
  
  __instanceLock__.unlock();
}

- (CGSize)shadowOffset
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (CGSizeEqualToSize(_shadowOffset, shadowOffset)) {
      return;
    }
    _shadowOffset = shadowOffset;
  }
  
  [self setNeedsDisplay];
}

- (CGFloat)shadowOpacity
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowOpacity;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_shadowOpacity == shadowOpacity) {
      return;
    }
    
    _shadowOpacity = shadowOpacity;
  }
  
  [self setNeedsDisplay];
}

- (CGFloat)shadowRadius
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _shadowRadius;
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_shadowRadius == shadowRadius) {
      return;
    }
    
    _shadowRadius = shadowRadius;
  }
  
  [self setNeedsDisplay];
}

- (UIEdgeInsets)shadowPadding
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return UIEdgeInsetsZero;
}

- (void)setPointSizeScaleFactors:(NSArray<NSNumber *> *)scaleFactors
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  _pointSizeScaleFactors = [scaleFactors copy];
}

- (NSArray *)pointSizeScaleFactors
{
  return _pointSizeScaleFactors;
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

- (void)_ensureTruncationText
{
  if (_textContainer.truncationToken == nil) {
    ASDN::MutexLocker l(__instanceLock__);
    _textContainer.truncationToken = [self _locked_composedTruncationText];
  }
}

- (void)setTruncationAttributedText:(NSAttributedString *)truncationAttributedText
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (ASObjectIsEqual(_truncationAttributedText, truncationAttributedText)) {
      return;
    }
    
    _truncationAttributedText = [truncationAttributedText copy];
  }
  
  [self _invalidateTruncationText];
}

- (void)setAdditionalTruncationMessage:(NSAttributedString *)additionalTruncationMessage
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (ASObjectIsEqual(_additionalTruncationMessage, additionalTruncationMessage)) {
      return;
    }
    
    _additionalTruncationMessage = [additionalTruncationMessage copy];
  }
  
  [self _invalidateTruncationText];
}

- (void)setTruncationMode:(NSLineBreakMode)truncationMode
{
  ASDN::MutexLocker lock(__instanceLock__);
  if (_truncationMode == truncationMode) {
    return;
  }
  _truncationMode = truncationMode;
  
  ASTextTruncationType truncationType;
  switch (truncationMode) {
    case NSLineBreakByTruncatingHead:
      truncationType = ASTextTruncationTypeStart;
      break;
    case NSLineBreakByTruncatingTail:
      truncationType = ASTextTruncationTypeEnd;
      break;
    case NSLineBreakByTruncatingMiddle:
      truncationType = ASTextTruncationTypeMiddle;
      break;
    default:
      truncationType = ASTextTruncationTypeNone;
  }
		
  _textContainer.truncationType = truncationType;
  
  [self setNeedsDisplay];
}

- (BOOL)isTruncated
{
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return NO;
}

- (NSUInteger)maximumNumberOfLines
{
  return _textContainer.maximumNumberOfRows;
}

- (void)setMaximumNumberOfLines:(NSUInteger)maximumNumberOfLines
{
  if (_textContainer.maximumNumberOfRows == maximumNumberOfLines) {
    return;
  }
  _textContainer.maximumNumberOfRows = maximumNumberOfLines;
  
  [self setNeedsDisplay];
}

- (NSUInteger)lineCount
{
  ASDN::MutexLocker l(__instanceLock__);
  AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE();
  return 0;
}

#pragma mark - Truncation Message

- (void)_invalidateTruncationText
{
  _textContainer.truncationToken = nil;
  [self setNeedsDisplay];
}

/**
 * @return the additional truncation message range within the as-rendered text.
 * Must be called from main thread
 */
- (NSRange)_additionalTruncationMessageRangeWithVisibleRange:(NSRange)visibleRange
{
  ASDN::MutexLocker l(__instanceLock__);
  
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
       NSMutableDictionary *futureTruncationAttributes = [NSMutableDictionary dictionaryWithDictionary:originalStringAttributes];
       [futureTruncationAttributes addEntriesFromDictionary:attributes];
       [truncationMutableString setAttributes:futureTruncationAttributes range:range];
     }];
  }
  return truncationMutableString;
}

#if AS_TEXTNODE2_RECORD_ATTRIBUTED_STRINGS
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

+ (void)enableDebugging
{
  ASTextDebugOption *debugOption = [[ASTextDebugOption alloc] init];
  debugOption.CTLineFillColor = [UIColor colorWithRed:0 green:0.3 blue:1 alpha:0.1];
  [ASTextDebugOption setSharedDebugOption:debugOption];
}

- (BOOL)usingExperiment
{
  return YES;
}

@end
