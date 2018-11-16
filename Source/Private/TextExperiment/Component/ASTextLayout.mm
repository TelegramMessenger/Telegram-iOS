//
//  ASTextLayout.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextLayout.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASTextUtilities.h>
#import <AsyncDisplayKit/ASTextAttribute.h>
#import <AsyncDisplayKit/NSAttributedString+ASText.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

#import <pthread.h>

const CGSize ASTextContainerMaxSize = (CGSize){0x100000, 0x100000};

typedef struct {
  CGFloat head;
  CGFloat foot;
} ASRowEdge;

static inline CGSize ASTextClipCGSize(CGSize size) {
  if (size.width > ASTextContainerMaxSize.width) size.width = ASTextContainerMaxSize.width;
  if (size.height > ASTextContainerMaxSize.height) size.height = ASTextContainerMaxSize.height;
  return size;
}

static inline UIEdgeInsets UIEdgeInsetRotateVertical(UIEdgeInsets insets) {
  UIEdgeInsets one;
  one.top = insets.left;
  one.left = insets.bottom;
  one.bottom = insets.right;
  one.right = insets.top;
  return one;
}

/**
 Sometimes CoreText may convert CGColor to UIColor for `kCTForegroundColorAttributeName`
 attribute in iOS7. This should be a bug of CoreText, and may cause crash. Here's a workaround.
 */
static CGColorRef ASTextGetCGColor(CGColorRef color) {
  static UIColor *defaultColor;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultColor = [UIColor blackColor];
  });
  if (!color) return defaultColor.CGColor;
  if ([((__bridge NSObject *)color) respondsToSelector:@selector(CGColor)]) {
    return ((__bridge UIColor *)color).CGColor;
  }
  return color;
}

@implementation ASTextLinePositionSimpleModifier
- (void)modifyLines:(NSArray *)lines fromText:(NSAttributedString *)text inContainer:(ASTextContainer *)container {
  if (container.verticalForm) {
    for (NSUInteger i = 0, max = lines.count; i < max; i++) {
      ASTextLine *line = lines[i];
      CGPoint pos = line.position;
      pos.x = container.size.width - container.insets.right - line.row * _fixedLineHeight - _fixedLineHeight * 0.9;
      line.position = pos;
    }
  } else {
    for (NSUInteger i = 0, max = lines.count; i < max; i++) {
      ASTextLine *line = lines[i];
      CGPoint pos = line.position;
      pos.y = line.row * _fixedLineHeight + _fixedLineHeight * 0.9 + container.insets.top;
      line.position = pos;
    }
  }
}

- (id)copyWithZone:(NSZone *)zone {
  ASTextLinePositionSimpleModifier *one = [self.class new];
  one.fixedLineHeight = _fixedLineHeight;
  return one;
}
@end


@implementation ASTextContainer {
  @package
  BOOL _readonly; ///< used only in ASTextLayout.implementation
  dispatch_semaphore_t _lock;
  
  CGSize _size;
  UIEdgeInsets _insets;
  UIBezierPath *_path;
  NSArray *_exclusionPaths;
  BOOL _pathFillEvenOdd;
  CGFloat _pathLineWidth;
  BOOL _verticalForm;
  NSUInteger _maximumNumberOfRows;
  ASTextTruncationType _truncationType;
  NSAttributedString *_truncationToken;
  id<ASTextLinePositionModifier> _linePositionModifier;
}

- (NSString *)description
{
  return [NSString
          stringWithFormat:@"immutable: %@, insets: %@, size: %@", self->_readonly ? @"YES" : @"NO",
                           NSStringFromUIEdgeInsets(self->_insets), NSStringFromCGSize(self->_size)];
}

+ (instancetype)containerWithSize:(CGSize)size NS_RETURNS_RETAINED {
  return [self containerWithSize:size insets:UIEdgeInsetsZero];
}

+ (instancetype)containerWithSize:(CGSize)size insets:(UIEdgeInsets)insets NS_RETURNS_RETAINED {
  ASTextContainer *one = [self new];
  one.size = ASTextClipCGSize(size);
  one.insets = insets;
  return one;
}

+ (instancetype)containerWithPath:(UIBezierPath *)path NS_RETURNS_RETAINED {
  ASTextContainer *one = [self new];
  one.path = path;
  return one;
}

- (instancetype)init {
  self = [super init];
  if (!self) return nil;
  _lock = dispatch_semaphore_create(1);
  _pathFillEvenOdd = YES;
  return self;
}

- (id)copyForced:(BOOL)forceCopy
{
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
  if (_readonly && !forceCopy) {
    dispatch_semaphore_signal(_lock);
    return self;
  }

  ASTextContainer *one = [self.class new];
  one->_size = _size;
  one->_insets = _insets;
  one->_path = _path;
  one->_exclusionPaths = [_exclusionPaths copy];
  one->_pathFillEvenOdd = _pathFillEvenOdd;
  one->_pathLineWidth = _pathLineWidth;
  one->_verticalForm = _verticalForm;
  one->_maximumNumberOfRows = _maximumNumberOfRows;
  one->_truncationType = _truncationType;
  one->_truncationToken = [_truncationToken copy];
  one->_linePositionModifier = [(NSObject *)_linePositionModifier copy];
  dispatch_semaphore_signal(_lock);
  return one;
}

- (id)copyWithZone:(NSZone *)zone {
  return [self copyForced:NO];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return [self copyForced:YES];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:[NSValue valueWithCGSize:_size] forKey:@"size"];
  [aCoder encodeObject:[NSValue valueWithUIEdgeInsets:_insets] forKey:@"insets"];
  [aCoder encodeObject:_path forKey:@"path"];
  [aCoder encodeObject:_exclusionPaths forKey:@"exclusionPaths"];
  [aCoder encodeBool:_pathFillEvenOdd forKey:@"pathFillEvenOdd"];
  [aCoder encodeDouble:_pathLineWidth forKey:@"pathLineWidth"];
  [aCoder encodeBool:_verticalForm forKey:@"verticalForm"];
  [aCoder encodeInteger:_maximumNumberOfRows forKey:@"maximumNumberOfRows"];
  [aCoder encodeInteger:_truncationType forKey:@"truncationType"];
  [aCoder encodeObject:_truncationToken forKey:@"truncationToken"];
  if ([_linePositionModifier respondsToSelector:@selector(encodeWithCoder:)] &&
      [_linePositionModifier respondsToSelector:@selector(initWithCoder:)]) {
    [aCoder encodeObject:_linePositionModifier forKey:@"linePositionModifier"];
  }
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [self init];
  _size = ((NSValue *)[aDecoder decodeObjectForKey:@"size"]).CGSizeValue;
  _insets = ((NSValue *)[aDecoder decodeObjectForKey:@"insets"]).UIEdgeInsetsValue;
  _path = [aDecoder decodeObjectForKey:@"path"];
  _exclusionPaths = [aDecoder decodeObjectForKey:@"exclusionPaths"];
  _pathFillEvenOdd = [aDecoder decodeBoolForKey:@"pathFillEvenOdd"];
  _pathLineWidth = [aDecoder decodeDoubleForKey:@"pathLineWidth"];
  _verticalForm = [aDecoder decodeBoolForKey:@"verticalForm"];
  _maximumNumberOfRows = [aDecoder decodeIntegerForKey:@"maximumNumberOfRows"];
  _truncationType = (ASTextTruncationType)[aDecoder decodeIntegerForKey:@"truncationType"];
  _truncationToken = [aDecoder decodeObjectForKey:@"truncationToken"];
  _linePositionModifier = [aDecoder decodeObjectForKey:@"linePositionModifier"];
  return self;
}

- (void)makeImmutable
{
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
  _readonly = YES;
  dispatch_semaphore_signal(_lock);
}

#define Getter(...) \
dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); \
__VA_ARGS__; \
dispatch_semaphore_signal(_lock);

#define Setter(...) \
dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); \
if (__builtin_expect(_readonly, NO)) { \
  ASDisplayNodeFailAssert(@"Attempt to modify immutable text container."); \
  dispatch_semaphore_signal(_lock); \
  return; \
} \
__VA_ARGS__; \
dispatch_semaphore_signal(_lock);

- (CGSize)size {
  Getter(CGSize size = _size) return size;
}

- (void)setSize:(CGSize)size {
  Setter(if(!_path) _size = ASTextClipCGSize(size));
}

- (UIEdgeInsets)insets {
  Getter(UIEdgeInsets insets = _insets) return insets;
}

- (void)setInsets:(UIEdgeInsets)insets {
  Setter(if(!_path){
    if (insets.top < 0) insets.top = 0;
    if (insets.left < 0) insets.left = 0;
    if (insets.bottom < 0) insets.bottom = 0;
    if (insets.right < 0) insets.right = 0;
    _insets = insets;
  });
}

- (UIBezierPath *)path {
  Getter(UIBezierPath *path = _path) return path;
}

- (void)setPath:(UIBezierPath *)path {
  Setter(
         _path = path.copy;
         if (_path) {
           CGRect bounds = _path.bounds;
           CGSize size = bounds.size;
           UIEdgeInsets insets = UIEdgeInsetsZero;
           if (bounds.origin.x < 0) size.width += bounds.origin.x;
           if (bounds.origin.x > 0) insets.left = bounds.origin.x;
           if (bounds.origin.y < 0) size.height += bounds.origin.y;
           if (bounds.origin.y > 0) insets.top = bounds.origin.y;
           _size = size;
           _insets = insets;
         }
         );
}

- (NSArray *)exclusionPaths {
  Getter(NSArray *paths = _exclusionPaths) return paths;
}

- (void)setExclusionPaths:(NSArray *)exclusionPaths {
  Setter(_exclusionPaths = exclusionPaths.copy);
}

- (BOOL)isPathFillEvenOdd {
  Getter(BOOL is = _pathFillEvenOdd) return is;
}

- (void)setPathFillEvenOdd:(BOOL)pathFillEvenOdd {
  Setter(_pathFillEvenOdd = pathFillEvenOdd);
}

- (CGFloat)pathLineWidth {
  Getter(CGFloat width = _pathLineWidth) return width;
}

- (void)setPathLineWidth:(CGFloat)pathLineWidth {
  Setter(_pathLineWidth = pathLineWidth);
}

- (BOOL)isVerticalForm {
  Getter(BOOL v = _verticalForm) return v;
}

- (void)setVerticalForm:(BOOL)verticalForm {
  Setter(_verticalForm = verticalForm);
}

- (NSUInteger)maximumNumberOfRows {
  Getter(NSUInteger num = _maximumNumberOfRows) return num;
}

- (void)setMaximumNumberOfRows:(NSUInteger)maximumNumberOfRows {
  Setter(_maximumNumberOfRows = maximumNumberOfRows);
}

- (ASTextTruncationType)truncationType {
  Getter(ASTextTruncationType type = _truncationType) return type;
}

- (void)setTruncationType:(ASTextTruncationType)truncationType {
  Setter(_truncationType = truncationType);
}

- (NSAttributedString *)truncationToken {
  Getter(NSAttributedString *token = _truncationToken) return token;
}

- (void)setTruncationToken:(NSAttributedString *)truncationToken {
  Setter(_truncationToken = truncationToken.copy);
}

- (void)setLinePositionModifier:(id<ASTextLinePositionModifier>)linePositionModifier {
  Setter(_linePositionModifier = [(NSObject *)linePositionModifier copy]);
}

- (id<ASTextLinePositionModifier>)linePositionModifier {
  Getter(id<ASTextLinePositionModifier> m = _linePositionModifier) return m;
}

#undef Getter
#undef Setter
@end




@interface ASTextLayout ()

@property (nonatomic) ASTextContainer *container;
@property (nonatomic) NSAttributedString *text;
@property (nonatomic) NSRange range;

@property (nonatomic) CTFrameRef frame;
@property (nonatomic) NSArray *lines;
@property (nonatomic) ASTextLine *truncatedLine;
@property (nonatomic) NSArray *attachments;
@property (nonatomic) NSArray *attachmentRanges;
@property (nonatomic) NSArray *attachmentRects;
@property (nonatomic) NSSet *attachmentContentsSet;
@property (nonatomic) NSUInteger rowCount;
@property (nonatomic) NSRange visibleRange;
@property (nonatomic) CGRect textBoundingRect;
@property (nonatomic) CGSize textBoundingSize;

@property (nonatomic) BOOL containsHighlight;
@property (nonatomic) BOOL needDrawBlockBorder;
@property (nonatomic) BOOL needDrawBackgroundBorder;
@property (nonatomic) BOOL needDrawShadow;
@property (nonatomic) BOOL needDrawUnderline;
@property (nonatomic) BOOL needDrawText;
@property (nonatomic) BOOL needDrawAttachment;
@property (nonatomic) BOOL needDrawInnerShadow;
@property (nonatomic) BOOL needDrawStrikethrough;
@property (nonatomic) BOOL needDrawBorder;

@property (nonatomic) NSUInteger *lineRowsIndex;
@property (nonatomic) ASRowEdge *lineRowsEdge; ///< top-left origin

@end



@implementation ASTextLayout

#pragma mark - Layout

- (instancetype)_init {
  self = [super init];
  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"lines: %ld, visibleRange:%@, textBoundingRect:%@",
                                    [self.lines count],
                                    NSStringFromRange(self.visibleRange),
                                    NSStringFromCGRect(self.textBoundingRect)];
}

+ (ASTextLayout *)layoutWithContainerSize:(CGSize)size text:(NSAttributedString *)text {
  ASTextContainer *container = [ASTextContainer containerWithSize:size];
  return [self layoutWithContainer:container text:text];
}

+ (ASTextLayout *)layoutWithContainer:(ASTextContainer *)container text:(NSAttributedString *)text {
  return [self layoutWithContainer:container text:text range:NSMakeRange(0, text.length)];
}

+ (ASTextLayout *)layoutWithContainer:(ASTextContainer *)container text:(NSAttributedString *)text range:(NSRange)range {
  ASTextLayout *layout = NULL;
  CGPathRef cgPath = nil;
  CGRect cgPathBox = {0};
  BOOL isVerticalForm = NO;
  BOOL rowMaySeparated = NO;
  NSMutableDictionary *frameAttrs = nil;
  CTFramesetterRef ctSetter = NULL;
  CTFrameRef ctFrame = NULL;
  CFArrayRef ctLines = nil;
  CGPoint *lineOrigins = NULL;
  NSUInteger lineCount = 0;
  NSMutableArray *lines = nil;
  NSMutableArray *attachments = nil;
  NSMutableArray *attachmentRanges = nil;
  NSMutableArray *attachmentRects = nil;
  NSMutableSet *attachmentContentsSet = nil;
  BOOL needTruncation = NO;
  NSAttributedString *truncationToken = nil;
  ASTextLine *truncatedLine = nil;
  ASRowEdge *lineRowsEdge = NULL;
  NSUInteger *lineRowsIndex = NULL;
  NSRange visibleRange;
  NSUInteger maximumNumberOfRows = 0;
  BOOL constraintSizeIsExtended = NO;
  CGRect constraintRectBeforeExtended = {0};
#define FAIL_AND_RETURN {\
  if (cgPath) CFRelease(cgPath); \
  if (ctSetter) CFRelease(ctSetter); \
  if (ctFrame) CFRelease(ctFrame); \
  if (lineOrigins) free(lineOrigins); \
  if (lineRowsEdge) free(lineRowsEdge); \
  if (lineRowsIndex) free(lineRowsIndex); \
  return nil; }
  
  container = [container copy];
  if (!text || !container) return nil;
  if (range.location + range.length > text.length) return nil;
  [container makeImmutable];
  maximumNumberOfRows = container.maximumNumberOfRows;
  
  // It may use larger constraint size when create CTFrame with
  // CTFramesetterCreateFrame in iOS 10.
  BOOL needFixLayoutSizeBug = AS_AT_LEAST_IOS10;

  layout = [[ASTextLayout alloc] _init];
  layout.text = text;
  layout.container = container;
  layout.range = range;
  isVerticalForm = container.verticalForm;
  
  // set cgPath and cgPathBox
  if (container.path == nil && container.exclusionPaths.count == 0) {
    if (container.size.width <= 0 || container.size.height <= 0) FAIL_AND_RETURN
    CGRect rect = (CGRect) {CGPointZero, container.size };
    if (needFixLayoutSizeBug) {
      constraintSizeIsExtended = YES;
      constraintRectBeforeExtended = UIEdgeInsetsInsetRect(rect, container.insets);
      constraintRectBeforeExtended = CGRectStandardize(constraintRectBeforeExtended);
      if (container.isVerticalForm) {
        rect.size.width = ASTextContainerMaxSize.width;
      } else {
        rect.size.height = ASTextContainerMaxSize.height;
      }
    }
    rect = UIEdgeInsetsInsetRect(rect, container.insets);
    rect = CGRectStandardize(rect);
    cgPathBox = rect;
    rect = CGRectApplyAffineTransform(rect, CGAffineTransformMakeScale(1, -1));
    cgPath = CGPathCreateWithRect(rect, NULL); // let CGPathIsRect() returns true
  } else if (container.path && CGPathIsRect(container.path.CGPath, &cgPathBox) && container.exclusionPaths.count == 0) {
    CGRect rect = CGRectApplyAffineTransform(cgPathBox, CGAffineTransformMakeScale(1, -1));
    cgPath = CGPathCreateWithRect(rect, NULL); // let CGPathIsRect() returns true
  } else {
    rowMaySeparated = YES;
    CGMutablePathRef path = NULL;
    if (container.path) {
      path = CGPathCreateMutableCopy(container.path.CGPath);
    } else {
      CGRect rect = (CGRect) {CGPointZero, container.size };
      rect = UIEdgeInsetsInsetRect(rect, container.insets);
      CGPathRef rectPath = CGPathCreateWithRect(rect, NULL);
      if (rectPath) {
        path = CGPathCreateMutableCopy(rectPath);
        CGPathRelease(rectPath);
      }
    }
    if (path) {
      [layout.container.exclusionPaths enumerateObjectsUsingBlock: ^(UIBezierPath *onePath, NSUInteger idx, BOOL *stop) {
        CGPathAddPath(path, NULL, onePath.CGPath);
      }];
      
      cgPathBox = CGPathGetPathBoundingBox(path);
      CGAffineTransform trans = CGAffineTransformMakeScale(1, -1);
      CGMutablePathRef transPath = CGPathCreateMutableCopyByTransformingPath(path, &trans);
      CGPathRelease(path);
      path = transPath;
    }
    cgPath = path;
  }
  if (!cgPath) FAIL_AND_RETURN
  
  // frame setter config
  frameAttrs = [[NSMutableDictionary alloc] init];
  if (container.isPathFillEvenOdd == NO) {
    frameAttrs[(id)kCTFramePathFillRuleAttributeName] = @(kCTFramePathFillWindingNumber);
  }
  if (container.pathLineWidth > 0) {
    frameAttrs[(id)kCTFramePathWidthAttributeName] = @(container.pathLineWidth);
  }
  if (container.isVerticalForm == YES) {
    frameAttrs[(id)kCTFrameProgressionAttributeName] = @(kCTFrameProgressionRightToLeft);
  }
  
  /*
   * Framesetter cache.
   * Framesetters can only be used by one thread at a time.
   * Create a CFSet with no callbacks (raw pointers) to keep track of which
   * framesetters are in use on other threads. If the one for our string is already in use,
   * just create a new one. This should be pretty rare.
   */
  static pthread_mutex_t busyFramesettersLock = PTHREAD_MUTEX_INITIALIZER;
  static NSCache<NSAttributedString *, id> *framesetterCache;
  static CFMutableSetRef busyFramesetters;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (ASActivateExperimentalFeature(ASExperimentalFramesetterCache)) {
      framesetterCache = [[NSCache alloc] init];
      framesetterCache.name = @"org.TextureGroup.Texture.framesetterCache";
      busyFramesetters = CFSetCreateMutable(NULL, 0, NULL);
    }
  });

  BOOL haveCached = NO, useCached = NO;
  if (framesetterCache) {
    // Check if there's one in the cache.
    ctSetter = (__bridge_retained CTFramesetterRef)[framesetterCache objectForKey:text];

    if (ctSetter) {
      haveCached = YES;

      // Check-and-set busy on the cached one.
      pthread_mutex_lock(&busyFramesettersLock);
      BOOL busy = CFSetContainsValue(busyFramesetters, ctSetter);
      if (!busy) {
        CFSetAddValue(busyFramesetters, ctSetter);
        useCached = YES;
      }
      pthread_mutex_unlock(&busyFramesettersLock);

      // Release if it was busy.
      if (busy) {
        CFRelease(ctSetter);
        ctSetter = NULL;
      }
    }
  }

  // Create a framesetter if needed.
  if (!ctSetter) {
    ctSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)text);
  }

  if (!ctSetter) FAIL_AND_RETURN
  ctFrame = CTFramesetterCreateFrame(ctSetter, ASTextCFRangeFromNSRange(range), cgPath, (CFDictionaryRef)frameAttrs);

  // Return to cache.
  if (framesetterCache) {
    if (useCached) {
      // If reused: mark available.
      pthread_mutex_lock(&busyFramesettersLock);
      CFSetRemoveValue(busyFramesetters, ctSetter);
      pthread_mutex_unlock(&busyFramesettersLock);
    } else if (!haveCached) {
      // If first framesetter, add to cache.
      [framesetterCache setObject:(__bridge id)ctSetter forKey:text];
    }
  }

  if (!ctFrame) FAIL_AND_RETURN
  lines = [NSMutableArray new];
  ctLines = CTFrameGetLines(ctFrame);
  lineCount = CFArrayGetCount(ctLines);
  if (lineCount > 0) {
    lineOrigins = (CGPoint *)malloc(lineCount * sizeof(CGPoint));
    if (lineOrigins == NULL) FAIL_AND_RETURN
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, lineCount), lineOrigins);
  }
  
  CGRect textBoundingRect = CGRectZero;
  CGSize textBoundingSize = CGSizeZero;
  NSInteger rowIdx = -1;
  NSUInteger rowCount = 0;
  CGRect lastRect = CGRectMake(0, -FLT_MAX, 0, 0);
  CGPoint lastPosition = CGPointMake(0, -FLT_MAX);
  if (isVerticalForm) {
    lastRect = CGRectMake(FLT_MAX, 0, 0, 0);
    lastPosition = CGPointMake(FLT_MAX, 0);
  }
  
  // calculate line frame
  NSUInteger lineCurrentIdx = 0;
  BOOL measuringBeyondConstraints = NO;
  for (NSUInteger i = 0; i < lineCount; i++) {
    CTLineRef ctLine = (CTLineRef)CFArrayGetValueAtIndex(ctLines, i);
    CFArrayRef ctRuns = CTLineGetGlyphRuns(ctLine);
    if (!ctRuns || CFArrayGetCount(ctRuns) == 0) continue;
    
    // CoreText coordinate system
    CGPoint ctLineOrigin = lineOrigins[i];
    
    // UIKit coordinate system
    CGPoint position;
    position.x = cgPathBox.origin.x + ctLineOrigin.x;
    position.y = cgPathBox.size.height + cgPathBox.origin.y - ctLineOrigin.y;
    
    ASTextLine *line = [ASTextLine lineWithCTLine:ctLine position:position vertical:isVerticalForm];
    
    [lines addObject:line];
  }
  
  // Give user a chance to modify the line's position.
  [container.linePositionModifier modifyLines:lines fromText:text inContainer:container];
  
  BOOL first = YES;
  for (ASTextLine *line in lines) {
    CGPoint position = line.position;
    CGRect rect = line.bounds;
    if (constraintSizeIsExtended) {
      if (isVerticalForm) {
        if (rect.origin.x + rect.size.width >
            constraintRectBeforeExtended.origin.x +
                constraintRectBeforeExtended.size.width) {
          measuringBeyondConstraints = YES;
        }
      } else {
        if (rect.origin.y + rect.size.height >
            constraintRectBeforeExtended.origin.y +
                constraintRectBeforeExtended.size.height) {
          measuringBeyondConstraints = YES;
        }
      }
    }

    BOOL newRow = !measuringBeyondConstraints;
    if (newRow && rowMaySeparated && position.x != lastPosition.x) {
      if (isVerticalForm) {
        if (rect.size.width > lastRect.size.width) {
          if (rect.origin.x > lastPosition.x && lastPosition.x > rect.origin.x - rect.size.width) newRow = NO;
        } else {
          if (lastRect.origin.x > position.x && position.x > lastRect.origin.x - lastRect.size.width) newRow = NO;
        }
      } else {
        if (rect.size.height > lastRect.size.height) {
          if (rect.origin.y < lastPosition.y && lastPosition.y < rect.origin.y + rect.size.height) newRow = NO;
        } else {
          if (lastRect.origin.y < position.y && position.y < lastRect.origin.y + lastRect.size.height) newRow = NO;
        }
      }
    }
    
    if (newRow) rowIdx++;
    lastRect = rect;
    lastPosition = position;
    
    line.index = lineCurrentIdx;
    line.row = rowIdx;

    rowCount = rowIdx + 1;
    lineCurrentIdx ++;

    if (first) {
      first = NO;
      textBoundingRect = rect;
    } else if (!measuringBeyondConstraints) {
      if (maximumNumberOfRows == 0 || rowIdx < maximumNumberOfRows) {
        textBoundingRect = CGRectUnion(textBoundingRect, rect);
      }
    }
  }

  {
    NSMutableArray<ASTextLine *> *removedLines = [NSMutableArray new];
    if (rowCount > 0) {
      if (maximumNumberOfRows > 0) {
        if (rowCount > maximumNumberOfRows) {
          needTruncation = YES;
          rowCount = maximumNumberOfRows;
          do {
            ASTextLine *line = lines.lastObject;
            if (!line) break;
            if (line.row < rowCount) break; // we have removed down to an allowed # of lines now
            [lines removeLastObject];
            [removedLines addObject:line];
          } while (1);
        }
      }
      ASTextLine *lastLine = rowCount < lines.count ? lines[rowCount - 1] : lines.lastObject;
      if (!needTruncation && lastLine.range.location + lastLine.range.length < text.length) {
        needTruncation = YES;
        while (lines.count > rowCount) {
          ASTextLine *line = lines.lastObject;
          [lines removeLastObject];
          [removedLines addObject:line];
        }
      }

      lineRowsEdge = (ASRowEdge *) calloc(rowCount, sizeof(ASRowEdge));
      if (lineRowsEdge == NULL) FAIL_AND_RETURN
      lineRowsIndex = (NSUInteger *) calloc(rowCount, sizeof(NSUInteger));
      if (lineRowsIndex == NULL) FAIL_AND_RETURN
      NSInteger lastRowIdx = -1;
      CGFloat lastHead = 0;
      CGFloat lastFoot = 0;
      for (NSUInteger i = 0, max = lines.count; i < max; i++) {
        ASTextLine *line = lines[i];
        CGRect rect = line.bounds;
        if ((NSInteger) line.row != lastRowIdx) {
          if (lastRowIdx >= 0) {
            lineRowsEdge[lastRowIdx] = (ASRowEdge) {.head = lastHead, .foot = lastFoot};
          }
          lastRowIdx = line.row;
          lineRowsIndex[lastRowIdx] = i;
          if (isVerticalForm) {
            lastHead = rect.origin.x + rect.size.width;
            lastFoot = lastHead - rect.size.width;
          } else {
            lastHead = rect.origin.y;
            lastFoot = lastHead + rect.size.height;
          }
        } else {
          if (isVerticalForm) {
            lastHead = MAX(lastHead, rect.origin.x + rect.size.width);
            lastFoot = MIN(lastFoot, rect.origin.x);
          } else {
            lastHead = MIN(lastHead, rect.origin.y);
            lastFoot = MAX(lastFoot, rect.origin.y + rect.size.height);
          }
        }
      }
      lineRowsEdge[lastRowIdx] = (ASRowEdge) {.head = lastHead, .foot = lastFoot};

      for (NSUInteger i = 1; i < rowCount; i++) {
        ASRowEdge v0 = lineRowsEdge[i - 1];
        ASRowEdge v1 = lineRowsEdge[i];
        lineRowsEdge[i - 1].foot = lineRowsEdge[i].head = (v0.foot + v1.head) * 0.5;
      }
    }

    { // calculate bounding size
      CGRect rect = textBoundingRect;
      if (container.path) {
        if (container.pathLineWidth > 0) {
          CGFloat inset = container.pathLineWidth / 2;
          rect = CGRectInset(rect, -inset, -inset);
        }
      } else {
        rect = UIEdgeInsetsInsetRect(rect, ASTextUIEdgeInsetsInvert(container.insets));
      }
      rect = CGRectStandardize(rect);
      CGSize size = rect.size;
      if (container.verticalForm) {
        size.width += container.size.width - (rect.origin.x + rect.size.width);
      } else {
        size.width += rect.origin.x;
      }
      size.height += rect.origin.y;
      if (size.width < 0) size.width = 0;
      if (size.height < 0) size.height = 0;
      size.width = ceil(size.width);
      size.height = ceil(size.height);
      textBoundingSize = size;
    }

    visibleRange = ASTextNSRangeFromCFRange(CTFrameGetVisibleStringRange(ctFrame));
    if (needTruncation) {
      ASTextLine *lastLine = lines.lastObject;
      NSRange lastRange = lastLine.range;
      visibleRange.length = lastRange.location + lastRange.length - visibleRange.location;

      // create truncated line
      if (container.truncationType != ASTextTruncationTypeNone) {
        CTLineRef truncationTokenLine = NULL;
        if (container.truncationToken) {
          truncationToken = container.truncationToken;
          truncationTokenLine = CTLineCreateWithAttributedString((CFAttributedStringRef) truncationToken);
        } else {
          CFArrayRef runs = CTLineGetGlyphRuns(lastLine.CTLine);
          NSUInteger runCount = CFArrayGetCount(runs);
          NSMutableDictionary *attrs = nil;
          if (runCount > 0) {
            CTRunRef run = (CTRunRef) CFArrayGetValueAtIndex(runs, runCount - 1);
            attrs = (id) CTRunGetAttributes(run);
            attrs = attrs ? attrs.mutableCopy : [NSMutableArray new];
            [attrs removeObjectsForKeys:[NSMutableAttributedString as_allDiscontinuousAttributeKeys]];
            CTFontRef font = (__bridge CTFontRef) attrs[(id) kCTFontAttributeName];
            CGFloat fontSize = font ? CTFontGetSize(font) : 12.0;
            UIFont *uiFont = [UIFont systemFontOfSize:fontSize * 0.9];
            if (uiFont) {
              font = CTFontCreateWithName((__bridge CFStringRef) uiFont.fontName, uiFont.pointSize, NULL);
            } else {
              font = NULL;
            }
            if (font) {
              attrs[(id) kCTFontAttributeName] = (__bridge id) (font);
              uiFont = nil;
              CFRelease(font);
            }
            CGColorRef color = (__bridge CGColorRef) (attrs[(id) kCTForegroundColorAttributeName]);
            if (color && CFGetTypeID(color) == CGColorGetTypeID() && CGColorGetAlpha(color) == 0) {
              // ignore clear color
              [attrs removeObjectForKey:(id) kCTForegroundColorAttributeName];
            }
            if (!attrs) attrs = [NSMutableDictionary new];
          }
          truncationToken = [[NSAttributedString alloc] initWithString:ASTextTruncationToken attributes:attrs];
          truncationTokenLine = CTLineCreateWithAttributedString((CFAttributedStringRef) truncationToken);
        }
        if (truncationTokenLine) {
          CTLineTruncationType type = kCTLineTruncationEnd;
          if (container.truncationType == ASTextTruncationTypeStart) {
            type = kCTLineTruncationStart;
          } else if (container.truncationType == ASTextTruncationTypeMiddle) {
            type = kCTLineTruncationMiddle;
          }
          NSMutableAttributedString *lastLineText = [text attributedSubstringFromRange:lastLine.range].mutableCopy;
          CGFloat truncatedWidth = lastLine.width;
          CGFloat atLeastOneLine = lastLine.width;
          CGRect cgPathRect = CGRectZero;
          if (CGPathIsRect(cgPath, &cgPathRect)) {
            if (isVerticalForm) {
              truncatedWidth = cgPathRect.size.height;
             } else {
              truncatedWidth = cgPathRect.size.width;
            }
          }
          int i = 0;
          if (type != kCTLineTruncationStart) { // Middle or End/Tail wants text preceding truncated content.
            i = (int)removedLines.count - 1;
            while (atLeastOneLine < truncatedWidth && i >= 0) {
              if (lastLineText.length > 0 && [lastLineText.string characterAtIndex:lastLineText.string.length - 1] == '\n') { // Explicit newlines are always "long enough".
                [lastLineText deleteCharactersInRange:NSMakeRange(lastLineText.string.length - 1, 1)];
                break;
              }
              [lastLineText appendAttributedString:[text attributedSubstringFromRange:removedLines[i].range]];
              atLeastOneLine += removedLines[i--].width;
            }
            [lastLineText appendAttributedString:truncationToken];
          }
          if (type != kCTLineTruncationEnd && removedLines.count > 0) { // Middle or Start/Head wants text following truncated content.
            i = 0;
            atLeastOneLine = removedLines[i].width;
            while (atLeastOneLine < truncatedWidth && i < removedLines.count) {
              atLeastOneLine += removedLines[i++].width;
            }
            for (i--; i >= 0; i--) {
              NSAttributedString *nextLine = [text attributedSubstringFromRange:removedLines[i].range];
              if ([nextLine.string characterAtIndex:nextLine.string.length - 1] == '\n') { // Explicit newlines are always "long enough".
                lastLineText = [NSMutableAttributedString new];
              } else {
                [lastLineText appendAttributedString:nextLine];
              }
            }
            [lastLineText insertAttributedString:truncationToken atIndex:0];
          }

          CTLineRef ctLastLineExtend = CTLineCreateWithAttributedString((CFAttributedStringRef) lastLineText);
          if (ctLastLineExtend) {
            CTLineRef ctTruncatedLine = CTLineCreateTruncatedLine(ctLastLineExtend, truncatedWidth, type, truncationTokenLine);
            CFRelease(ctLastLineExtend);
            if (ctTruncatedLine) {
              truncatedLine = [ASTextLine lineWithCTLine:ctTruncatedLine position:lastLine.position vertical:isVerticalForm];
              truncatedLine.index = lastLine.index;
              truncatedLine.row = lastLine.row;
              CFRelease(ctTruncatedLine);
            }
          }
          CFRelease(truncationTokenLine);
        }
      }
    }
  }
  
  if (isVerticalForm) {
    NSCharacterSet *rotateCharset = ASTextVerticalFormRotateCharacterSet();
    NSCharacterSet *rotateMoveCharset = ASTextVerticalFormRotateAndMoveCharacterSet();

    void (^lineBlock)(ASTextLine *) = ^(ASTextLine *line){
      CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
      if (!runs) return;
      NSUInteger runCount = CFArrayGetCount(runs);
      if (runCount == 0) return;
      NSMutableArray *lineRunRanges = [NSMutableArray new];
      line.verticalRotateRange = lineRunRanges;
      for (NSUInteger r = 0; r < runCount; r++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
        NSMutableArray *runRanges = [NSMutableArray new];
        [lineRunRanges addObject:runRanges];
        NSUInteger glyphCount = CTRunGetGlyphCount(run);
        if (glyphCount == 0) continue;
        
        CFIndex runStrIdx[glyphCount + 1];
        CTRunGetStringIndices(run, CFRangeMake(0, 0), runStrIdx);
        CFRange runStrRange = CTRunGetStringRange(run);
        runStrIdx[glyphCount] = runStrRange.location + runStrRange.length;
        CFDictionaryRef runAttrs = CTRunGetAttributes(run);
        CTFontRef font = (CTFontRef)CFDictionaryGetValue(runAttrs, kCTFontAttributeName);
        BOOL isColorGlyph = ASTextCTFontContainsColorBitmapGlyphs(font);
        
        NSUInteger prevIdx = 0;
        ASTextRunGlyphDrawMode prevMode = ASTextRunGlyphDrawModeHorizontal;
        NSString *layoutStr = layout.text.string;
        for (NSUInteger g = 0; g < glyphCount; g++) {
          BOOL glyphRotate = 0, glyphRotateMove = NO;
          CFIndex runStrLen = runStrIdx[g + 1] - runStrIdx[g];
          if (isColorGlyph) {
            glyphRotate = YES;
          } else if (runStrLen == 1) {
            unichar c = [layoutStr characterAtIndex:runStrIdx[g]];
            glyphRotate = [rotateCharset characterIsMember:c];
            if (glyphRotate) glyphRotateMove = [rotateMoveCharset characterIsMember:c];
          } else if (runStrLen > 1){
            NSString *glyphStr = [layoutStr substringWithRange:NSMakeRange(runStrIdx[g], runStrLen)];
            BOOL glyphRotate = [glyphStr rangeOfCharacterFromSet:rotateCharset].location != NSNotFound;
            if (glyphRotate) glyphRotateMove = [glyphStr rangeOfCharacterFromSet:rotateMoveCharset].location != NSNotFound;
          }
          
          ASTextRunGlyphDrawMode mode = glyphRotateMove ? ASTextRunGlyphDrawModeVerticalRotateMove : (glyphRotate ? ASTextRunGlyphDrawModeVerticalRotate : ASTextRunGlyphDrawModeHorizontal);
          if (g == 0) {
            prevMode = mode;
          } else if (mode != prevMode) {
            ASTextRunGlyphRange *aRange = [ASTextRunGlyphRange rangeWithRange:NSMakeRange(prevIdx, g - prevIdx) drawMode:prevMode];
            [runRanges addObject:aRange];
            prevIdx = g;
            prevMode = mode;
          }
        }
        if (prevIdx < glyphCount) {
          ASTextRunGlyphRange *aRange = [ASTextRunGlyphRange rangeWithRange:NSMakeRange(prevIdx, glyphCount - prevIdx) drawMode:prevMode];
          [runRanges addObject:aRange];
        }
        
      }
    };
    for (ASTextLine *line in lines) {
      lineBlock(line);
    }
    if (truncatedLine) lineBlock(truncatedLine);
  }
  
  if (visibleRange.length > 0) {
    layout.needDrawText = YES;
    
    void (^block)(NSDictionary *attrs, NSRange range, BOOL *stop) = ^(NSDictionary *attrs, NSRange range, BOOL *stop) {
      if (attrs[ASTextHighlightAttributeName]) layout.containsHighlight = YES;
      if (attrs[ASTextBlockBorderAttributeName]) layout.needDrawBlockBorder = YES;
      if (attrs[ASTextBackgroundBorderAttributeName]) layout.needDrawBackgroundBorder = YES;
      if (attrs[ASTextShadowAttributeName] || attrs[NSShadowAttributeName]) layout.needDrawShadow = YES;
      if (attrs[ASTextUnderlineAttributeName]) layout.needDrawUnderline = YES;
      if (attrs[ASTextAttachmentAttributeName]) layout.needDrawAttachment = YES;
      if (attrs[ASTextInnerShadowAttributeName]) layout.needDrawInnerShadow = YES;
      if (attrs[ASTextStrikethroughAttributeName]) layout.needDrawStrikethrough = YES;
      if (attrs[ASTextBorderAttributeName]) layout.needDrawBorder = YES;
    };
    
    [layout.text enumerateAttributesInRange:visibleRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:block];
    if (truncatedLine) {
      [truncationToken enumerateAttributesInRange:NSMakeRange(0, truncationToken.length) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:block];
    }
  }
  
  attachments = [NSMutableArray new];
  attachmentRanges = [NSMutableArray new];
  attachmentRects = [NSMutableArray new];
  attachmentContentsSet = [NSMutableSet new];
  for (NSUInteger i = 0, max = lines.count; i < max; i++) {
    ASTextLine *line = lines[i];
    if (truncatedLine && line.index == truncatedLine.index) line = truncatedLine;
    if (line.attachments.count > 0) {
      [attachments addObjectsFromArray:line.attachments];
      [attachmentRanges addObjectsFromArray:line.attachmentRanges];
      [attachmentRects addObjectsFromArray:line.attachmentRects];
      for (ASTextAttachment *attachment in line.attachments) {
        if (attachment.content) {
          [attachmentContentsSet addObject:attachment.content];
        }
      }
    }
  }
  if (attachments.count == 0) {
    attachments = attachmentRanges = attachmentRects = nil;
  }

  layout.frame = ctFrame;
  layout.lines = lines;
  layout.truncatedLine = truncatedLine;
  layout.attachments = attachments;
  layout.attachmentRanges = attachmentRanges;
  layout.attachmentRects = attachmentRects;
  layout.attachmentContentsSet = attachmentContentsSet;
  layout.rowCount = rowCount;
  layout.visibleRange = visibleRange;
  layout.textBoundingRect = textBoundingRect;
  layout.textBoundingSize = textBoundingSize;
  layout.lineRowsEdge = lineRowsEdge;
  layout.lineRowsIndex = lineRowsIndex;
  CFRelease(cgPath);
  CFRelease(ctSetter);
  CFRelease(ctFrame);
  if (lineOrigins) free(lineOrigins);
  return layout;
}

+ (NSArray *)layoutWithContainers:(NSArray *)containers text:(NSAttributedString *)text {
  return [self layoutWithContainers:containers text:text range:NSMakeRange(0, text.length)];
}

+ (NSArray *)layoutWithContainers:(NSArray *)containers text:(NSAttributedString *)text range:(NSRange)range {
  if (!containers || !text) return nil;
  if (range.location + range.length > text.length) return nil;
  NSMutableArray *layouts = [[NSMutableArray alloc] init];
  for (NSUInteger i = 0, max = containers.count; i < max; i++) {
    ASTextContainer *container = containers[i];
    ASTextLayout *layout = [self layoutWithContainer:container text:text range:range];
    if (!layout) return nil;
    NSInteger length = (NSInteger)range.length - (NSInteger)layout.visibleRange.length;
    if (length <= 0) {
      range.length = 0;
      range.location = text.length;
    } else {
      range.length = length;
      range.location += layout.visibleRange.length;
    }
  }
  return layouts;
}

- (void)setFrame:(CTFrameRef)frame {
  if (_frame != frame) {
    if (frame) CFRetain(frame);
    if (_frame) CFRelease(_frame);
    _frame = frame;
  }
}

- (void)dealloc {
  if (_frame) CFRelease(_frame);
  if (_lineRowsIndex) free(_lineRowsIndex);
  if (_lineRowsEdge) free(_lineRowsEdge);
}

#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone {
  return self; // readonly object
}


#pragma mark - Query

/**
 Get the row index with 'edge' distance.
 
 @param edge  The distance from edge to the point.
 If vertical form, the edge is left edge, otherwise the edge is top edge.
 
 @return Returns NSNotFound if there's no row at the point.
 */
- (NSUInteger)_rowIndexForEdge:(CGFloat)edge {
  if (_rowCount == 0) return NSNotFound;
  BOOL isVertical = _container.verticalForm;
  NSUInteger lo = 0, hi = _rowCount - 1, mid = 0;
  NSUInteger rowIdx = NSNotFound;
  while (lo <= hi) {
    mid = (lo + hi) / 2;
    ASRowEdge oneEdge = _lineRowsEdge[mid];
    if (isVertical ?
        (oneEdge.foot <= edge && edge <= oneEdge.head) :
        (oneEdge.head <= edge && edge <= oneEdge.foot)) {
      rowIdx = mid;
      break;
    }
    if ((isVertical ? (edge > oneEdge.head) : (edge < oneEdge.head))) {
      if (mid == 0) break;
      hi = mid - 1;
    } else {
      lo = mid + 1;
    }
  }
  return rowIdx;
}

/**
 Get the closest row index with 'edge' distance.
 
 @param edge  The distance from edge to the point.
 If vertical form, the edge is left edge, otherwise the edge is top edge.
 
 @return Returns NSNotFound if there's no line.
 */
- (NSUInteger)_closestRowIndexForEdge:(CGFloat)edge {
  if (_rowCount == 0) return NSNotFound;
  NSUInteger rowIdx = [self _rowIndexForEdge:edge];
  if (rowIdx == NSNotFound) {
    if (_container.verticalForm) {
      if (edge > _lineRowsEdge[0].head) {
        rowIdx = 0;
      } else if (edge < _lineRowsEdge[_rowCount - 1].foot) {
        rowIdx = _rowCount - 1;
      }
    } else {
      if (edge < _lineRowsEdge[0].head) {
        rowIdx = 0;
      } else if (edge > _lineRowsEdge[_rowCount - 1].foot) {
        rowIdx = _rowCount - 1;
      }
    }
  }
  return rowIdx;
}

/**
 Get a CTRun from a line position.
 
 @param line     The text line.
 @param position The position in the whole text.
 
 @return Returns NULL if not found (no CTRun at the position).
 */
- (CTRunRef)_runForLine:(ASTextLine *)line position:(ASTextPosition *)position {
  if (!line || !position) return NULL;
  CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
  for (NSUInteger i = 0, max = CFArrayGetCount(runs); i < max; i++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, i);
    CFRange range = CTRunGetStringRange(run);
    if (position.affinity == ASTextAffinityBackward) {
      if (range.location < position.offset && position.offset <= range.location + range.length) {
        return run;
      }
    } else {
      if (range.location <= position.offset && position.offset < range.location + range.length) {
        return run;
      }
    }
  }
  return NULL;
}

/**
 Whether the position is inside a composed character sequence.
 
 @param line     The text line.
 @param position Text text position in whole text.
 @param block    The block to be executed before returns YES.
 left:  left X offset
 right: right X offset
 prev:  left position
 next:  right position
 */
- (BOOL)_insideComposedCharacterSequences:(ASTextLine *)line position:(NSUInteger)position block:(void (^)(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next))block {
  NSRange range = line.range;
  if (range.length == 0) return NO;
  __block BOOL inside = NO;
  __block NSUInteger _prev, _next;
  [_text.string enumerateSubstringsInRange:range options:NSStringEnumerationByComposedCharacterSequences usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
    NSUInteger prev = substringRange.location;
    NSUInteger next = substringRange.location + substringRange.length;
    if (prev == position || next == position) {
      *stop = YES;
    }
    if (prev < position && position < next) {
      inside = YES;
      _prev = prev;
      _next = next;
      *stop = YES;
    }
  }];
  if (inside && block) {
    CGFloat left = [self offsetForTextPosition:_prev lineIndex:line.index];
    CGFloat right = [self offsetForTextPosition:_next lineIndex:line.index];
    block(left, right, _prev, _next);
  }
  return inside;
}

/**
 Whether the position is inside an emoji (such as National Flag Emoji).
 
 @param line     The text line.
 @param position Text text position in whole text.
 @param block    Yhe block to be executed before returns YES.
 left:  emoji's left X offset
 right: emoji's right X offset
 prev:  emoji's left position
 next:  emoji's right position
 */
- (BOOL)_insideEmoji:(ASTextLine *)line position:(NSUInteger)position block:(void (^)(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next))block {
  if (!line) return NO;
  CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
  for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
    NSUInteger glyphCount = CTRunGetGlyphCount(run);
    if (glyphCount == 0) continue;
    CFRange range = CTRunGetStringRange(run);
    if (range.length <= 1) continue;
    if (position <= range.location || position >= range.location + range.length) continue;
    CFDictionaryRef attrs = CTRunGetAttributes(run);
    CTFontRef font = (CTFontRef)CFDictionaryGetValue(attrs, kCTFontAttributeName);
    if (!ASTextCTFontContainsColorBitmapGlyphs(font)) continue;
    
    // Here's Emoji runs (larger than 1 unichar), and position is inside the range.
    CFIndex indices[glyphCount];
    CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), indices);
    for (NSUInteger g = 0; g < glyphCount; g++) {
      CFIndex prev = indices[g];
      CFIndex next = g + 1 < glyphCount ? indices[g + 1] : range.location + range.length;
      if (position == prev) break; // Emoji edge
      if (prev < position && position < next) { // inside an emoji (such as National Flag Emoji)
        CGPoint pos = CGPointZero;
        CGSize adv = CGSizeZero;
        CTRunGetPositions(run, CFRangeMake(g, 1), &pos);
        CTRunGetAdvances(run, CFRangeMake(g, 1), &adv);
        if (block) {
          block(line.position.x + pos.x,
                line.position.x + pos.x + adv.width,
                prev, next);
        }
        return YES;
      }
    }
  }
  return NO;
}
/**
 Whether the write direction is RTL at the specified point
 
 @param line  The text line
 @param point The point in layout.
 
 @return YES if RTL.
 */
- (BOOL)_isRightToLeftInLine:(ASTextLine *)line atPoint:(CGPoint)point {
  if (!line) return NO;
  // get write direction
  BOOL RTL = NO;
  CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
  for (NSUInteger r = 0, max = CFArrayGetCount(runs); r < max; r++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
    CGPoint glyphPosition;
    CTRunGetPositions(run, CFRangeMake(0, 1), &glyphPosition);
    if (_container.verticalForm) {
      CGFloat runX = glyphPosition.x;
      runX += line.position.y;
      CGFloat runWidth = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
      if (runX <= point.y && point.y <= runX + runWidth) {
        if (CTRunGetStatus(run) & kCTRunStatusRightToLeft) RTL = YES;
        break;
      }
    } else {
      CGFloat runX = glyphPosition.x;
      runX += line.position.x;
      CGFloat runWidth = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
      if (runX <= point.x && point.x <= runX + runWidth) {
        if (CTRunGetStatus(run) & kCTRunStatusRightToLeft) RTL = YES;
        break;
      }
    }
  }
  return RTL;
}

/**
 Correct the range's edge.
 */
- (ASTextRange *)_correctedRangeWithEdge:(ASTextRange *)range {
  NSRange visibleRange = self.visibleRange;
  ASTextPosition *start = range.start;
  ASTextPosition *end = range.end;
  
  if (start.offset == visibleRange.location && start.affinity == ASTextAffinityBackward) {
    start = [ASTextPosition positionWithOffset:start.offset affinity:ASTextAffinityForward];
  }
  
  if (end.offset == visibleRange.location + visibleRange.length && start.affinity == ASTextAffinityForward) {
    end = [ASTextPosition positionWithOffset:end.offset affinity:ASTextAffinityBackward];
  }
  
  if (start != range.start || end != range.end) {
    range = [ASTextRange rangeWithStart:start end:end];
  }
  return range;
}

- (NSUInteger)lineIndexForRow:(NSUInteger)row {
  if (row >= _rowCount) return NSNotFound;
  return _lineRowsIndex[row];
}

- (NSUInteger)lineCountForRow:(NSUInteger)row {
  if (row >= _rowCount) return NSNotFound;
  if (row == _rowCount - 1) {
    return _lines.count - _lineRowsIndex[row];
  } else {
    return _lineRowsIndex[row + 1] - _lineRowsIndex[row];
  }
}

- (NSUInteger)rowIndexForLine:(NSUInteger)line {
  if (line >= _lines.count) return NSNotFound;
  return ((ASTextLine *)_lines[line]).row;
}

- (NSUInteger)lineIndexForPoint:(CGPoint)point {
  if (_lines.count == 0 || _rowCount == 0) return NSNotFound;
  NSUInteger rowIdx = [self _rowIndexForEdge:_container.verticalForm ? point.x : point.y];
  if (rowIdx == NSNotFound) return NSNotFound;
  
  NSUInteger lineIdx0 = _lineRowsIndex[rowIdx];
  NSUInteger lineIdx1 = rowIdx == _rowCount - 1 ? _lines.count - 1 : _lineRowsIndex[rowIdx + 1] - 1;
  for (NSUInteger i = lineIdx0; i <= lineIdx1; i++) {
    CGRect bounds = ((ASTextLine *)_lines[i]).bounds;
    if (CGRectContainsPoint(bounds, point)) return i;
  }
  
  return NSNotFound;
}

- (NSUInteger)closestLineIndexForPoint:(CGPoint)point {
  BOOL isVertical = _container.verticalForm;
  if (_lines.count == 0 || _rowCount == 0) return NSNotFound;
  NSUInteger rowIdx = [self _closestRowIndexForEdge:isVertical ? point.x : point.y];
  if (rowIdx == NSNotFound) return NSNotFound;
  
  NSUInteger lineIdx0 = _lineRowsIndex[rowIdx];
  NSUInteger lineIdx1 = rowIdx == _rowCount - 1 ? _lines.count - 1 : _lineRowsIndex[rowIdx + 1] - 1;
  if (lineIdx0 == lineIdx1) return lineIdx0;
  
  CGFloat minDistance = CGFLOAT_MAX;
  NSUInteger minIndex = lineIdx0;
  for (NSUInteger i = lineIdx0; i <= lineIdx1; i++) {
    CGRect bounds = ((ASTextLine *)_lines[i]).bounds;
    if (isVertical) {
      if (bounds.origin.y <= point.y && point.y <= bounds.origin.y + bounds.size.height) return i;
      CGFloat distance;
      if (point.y < bounds.origin.y) {
        distance = bounds.origin.y - point.y;
      } else {
        distance = point.y - (bounds.origin.y + bounds.size.height);
      }
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    } else {
      if (bounds.origin.x <= point.x && point.x <= bounds.origin.x + bounds.size.width) return i;
      CGFloat distance;
      if (point.x < bounds.origin.x) {
        distance = bounds.origin.x - point.x;
      } else {
        distance = point.x - (bounds.origin.x + bounds.size.width);
      }
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    }
  }
  return minIndex;
}

- (CGFloat)offsetForTextPosition:(NSUInteger)position lineIndex:(NSUInteger)lineIndex {
  if (lineIndex >= _lines.count) return CGFLOAT_MAX;
  ASTextLine *line = _lines[lineIndex];
  CFRange range = CTLineGetStringRange(line.CTLine);
  if (position < range.location || position > range.location + range.length) return CGFLOAT_MAX;
  
  CGFloat offset = CTLineGetOffsetForStringIndex(line.CTLine, position, NULL);
  return _container.verticalForm ? (offset + line.position.y) : (offset + line.position.x);
}

- (NSUInteger)textPositionForPoint:(CGPoint)point lineIndex:(NSUInteger)lineIndex {
  if (lineIndex >= _lines.count) return NSNotFound;
  ASTextLine *line = _lines[lineIndex];
  if (_container.verticalForm) {
    point.x = point.y - line.position.y;
    point.y = 0;
  } else {
    point.x -= line.position.x;
    point.y = 0;
  }
  CFIndex idx = CTLineGetStringIndexForPosition(line.CTLine, point);
  if (idx == kCFNotFound) return NSNotFound;
  
  /*
   If the emoji contains one or more variant form (such as ☔️ "\u2614\uFE0F")
   and the font size is smaller than 379/15, then each variant form ("\uFE0F")
   will rendered as a single blank glyph behind the emoji glyph. Maybe it's a
   bug in CoreText? Seems iOS8.3 fixes this problem.
   
   If the point hit the blank glyph, the CTLineGetStringIndexForPosition()
   returns the position before the emoji glyph, but it should returns the
   position after the emoji and variant form.
   
   Here's a workaround.
   */
  CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
  for (NSUInteger r = 0, max = CFArrayGetCount(runs); r < max; r++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
    CFRange range = CTRunGetStringRange(run);
    if (range.location <= idx && idx < range.location + range.length) {
      NSUInteger glyphCount = CTRunGetGlyphCount(run);
      if (glyphCount == 0) break;
      CFDictionaryRef attrs = CTRunGetAttributes(run);
      CTFontRef font = (CTFontRef)CFDictionaryGetValue(attrs, kCTFontAttributeName);
      if (!ASTextCTFontContainsColorBitmapGlyphs(font)) break;
      
      CFIndex indices[glyphCount];
      CGPoint positions[glyphCount];
      CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), indices);
      CTRunGetPositions(run, CFRangeMake(0, glyphCount), positions);
      for (NSUInteger g = 0; g < glyphCount; g++) {
        NSUInteger gIdx = indices[g];
        if (gIdx == idx && g + 1 < glyphCount) {
          CGFloat right = positions[g + 1].x;
          if (point.x < right) break;
          NSUInteger next = indices[g + 1];
          do {
            if (next == range.location + range.length) break;
            unichar c = [_text.string characterAtIndex:next];
            if ((c == 0xFE0E || c == 0xFE0F)) { // unicode variant form for emoji style
              next++;
            } else break;
          }
          while (1);
          if (next != indices[g + 1]) idx = next;
          break;
        }
      }
      break;
    }
  }
  return idx;
}

- (ASTextPosition *)closestPositionToPoint:(CGPoint)point {
  BOOL isVertical = _container.verticalForm;
  // When call CTLineGetStringIndexForPosition() on ligature such as 'fi',
  // and the point `hit` the glyph's left edge, it may get the ligature inside offset.
  // I don't know why, maybe it's a bug of CoreText. Try to avoid it.
  if (isVertical) point.y += 0.00001234;
  else point.x += 0.00001234;
  
  NSUInteger lineIndex = [self closestLineIndexForPoint:point];
  if (lineIndex == NSNotFound) return nil;
  ASTextLine *line = _lines[lineIndex];
  __block NSUInteger position = [self textPositionForPoint:point lineIndex:lineIndex];
  if (position == NSNotFound) position = line.range.location;
  if (position <= _visibleRange.location) {
    return [ASTextPosition positionWithOffset:_visibleRange.location affinity:ASTextAffinityForward];
  } else if (position >= _visibleRange.location + _visibleRange.length) {
    return [ASTextPosition positionWithOffset:_visibleRange.location + _visibleRange.length affinity:ASTextAffinityBackward];
  }
  
  ASTextAffinity finalAffinity = ASTextAffinityForward;
  BOOL finalAffinityDetected = NO;
  
  // binding range
  NSRange bindingRange;
  ASTextBinding *binding = [_text attribute:ASTextBindingAttributeName atIndex:position longestEffectiveRange:&bindingRange inRange:NSMakeRange(0, _text.length)];
  if (binding && bindingRange.length > 0) {
    NSUInteger headLineIdx = [self lineIndexForPosition:[ASTextPosition positionWithOffset:bindingRange.location]];
    NSUInteger tailLineIdx = [self lineIndexForPosition:[ASTextPosition positionWithOffset:bindingRange.location + bindingRange.length affinity:ASTextAffinityBackward]];
    if (headLineIdx == lineIndex && lineIndex == tailLineIdx) { // all in same line
      CGFloat left = [self offsetForTextPosition:bindingRange.location lineIndex:lineIndex];
      CGFloat right = [self offsetForTextPosition:bindingRange.location + bindingRange.length lineIndex:lineIndex];
      if (left != CGFLOAT_MAX && right != CGFLOAT_MAX) {
        if (_container.isVerticalForm) {
          if (fabs(point.y - left) < fabs(point.y - right)) {
            position = bindingRange.location;
            finalAffinity = ASTextAffinityForward;
          } else {
            position = bindingRange.location + bindingRange.length;
            finalAffinity = ASTextAffinityBackward;
          }
        } else {
          if (fabs(point.x - left) < fabs(point.x - right)) {
            position = bindingRange.location;
            finalAffinity = ASTextAffinityForward;
          } else {
            position = bindingRange.location + bindingRange.length;
            finalAffinity = ASTextAffinityBackward;
          }
        }
      } else if (left != CGFLOAT_MAX) {
        position = left;
        finalAffinity = ASTextAffinityForward;
      } else if (right != CGFLOAT_MAX) {
        position = right;
        finalAffinity = ASTextAffinityBackward;
      }
      finalAffinityDetected = YES;
    } else if (headLineIdx == lineIndex) {
      CGFloat left = [self offsetForTextPosition:bindingRange.location lineIndex:lineIndex];
      if (left != CGFLOAT_MAX) {
        position = bindingRange.location;
        finalAffinity = ASTextAffinityForward;
        finalAffinityDetected = YES;
      }
    } else if (tailLineIdx == lineIndex) {
      CGFloat right = [self offsetForTextPosition:bindingRange.location + bindingRange.length lineIndex:lineIndex];
      if (right != CGFLOAT_MAX) {
        position = bindingRange.location + bindingRange.length;
        finalAffinity = ASTextAffinityBackward;
        finalAffinityDetected = YES;
      }
    } else {
      BOOL onLeft = NO, onRight = NO;
      if (headLineIdx != NSNotFound && tailLineIdx != NSNotFound) {
        if (abs((int)headLineIdx - (int)lineIndex) < abs((int)tailLineIdx - (int)lineIndex)) onLeft = YES;
        else onRight = YES;
      } else if (headLineIdx != NSNotFound) {
        onLeft = YES;
      } else if (tailLineIdx != NSNotFound) {
        onRight = YES;
      }
      
      if (onLeft) {
        CGFloat left = [self offsetForTextPosition:bindingRange.location lineIndex:headLineIdx];
        if (left != CGFLOAT_MAX) {
          lineIndex = headLineIdx;
          line = _lines[headLineIdx];
          position = bindingRange.location;
          finalAffinity = ASTextAffinityForward;
          finalAffinityDetected = YES;
        }
      } else if (onRight) {
        CGFloat right = [self offsetForTextPosition:bindingRange.location + bindingRange.length lineIndex:tailLineIdx];
        if (right != CGFLOAT_MAX) {
          lineIndex = tailLineIdx;
          line = _lines[tailLineIdx];
          position = bindingRange.location + bindingRange.length;
          finalAffinity = ASTextAffinityBackward;
          finalAffinityDetected = YES;
        }
      }
    }
  }
  
  // empty line
  if (line.range.length == 0) {
    BOOL behind = (_lines.count > 1 && lineIndex == _lines.count - 1);  //end line
    return [ASTextPosition positionWithOffset:line.range.location affinity:behind ? ASTextAffinityBackward:ASTextAffinityForward];
  }
  
  // detect weather the line is a linebreak token
  if (line.range.length <= 2) {
    NSString *str = [_text.string substringWithRange:line.range];
    if (ASTextIsLinebreakString(str)) { // an empty line ("\r", "\n", "\r\n")
      return [ASTextPosition positionWithOffset:line.range.location];
    }
  }
  
  // above whole text frame
  if (lineIndex == 0 && (isVertical ? (point.x > line.right) : (point.y < line.top))) {
    position = 0;
    finalAffinity = ASTextAffinityForward;
    finalAffinityDetected = YES;
  }
  // below whole text frame
  if (lineIndex == _lines.count - 1 && (isVertical ? (point.x < line.left) : (point.y > line.bottom))) {
    position = line.range.location + line.range.length;
    finalAffinity = ASTextAffinityBackward;
    finalAffinityDetected = YES;
  }
  
  // There must be at least one non-linebreak char,
  // ignore the linebreak characters at line end if exists.
  if (position >= line.range.location + line.range.length - 1) {
    if (position > line.range.location) {
      unichar c1 = [_text.string characterAtIndex:position - 1];
      if (ASTextIsLinebreakChar(c1)) {
        position--;
        if (position > line.range.location) {
          unichar c0 = [_text.string characterAtIndex:position - 1];
          if (ASTextIsLinebreakChar(c0)) {
            position--;
          }
        }
      }
    }
  }
  if (position == line.range.location) {
    return [ASTextPosition positionWithOffset:position];
  }
  if (position == line.range.location + line.range.length) {
    return [ASTextPosition positionWithOffset:position affinity:ASTextAffinityBackward];
  }
  
  [self _insideComposedCharacterSequences:line position:position block: ^(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next) {
    if (isVertical) {
      position = fabs(left - point.y) < fabs(right - point.y) < (right ? prev : next);
    } else {
      position = fabs(left - point.x) < fabs(right - point.x) < (right ? prev : next);
    }
  }];
  
  [self _insideEmoji:line position:position block: ^(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next) {
    if (isVertical) {
      position = fabs(left - point.y) < fabs(right - point.y) < (right ? prev : next);
    } else {
      position = fabs(left - point.x) < fabs(right - point.x) < (right ? prev : next);
    }
  }];
  
  if (position < _visibleRange.location) position = _visibleRange.location;
  else if (position > _visibleRange.location + _visibleRange.length) position = _visibleRange.location + _visibleRange.length;
  
  if (!finalAffinityDetected) {
    CGFloat ofs = [self offsetForTextPosition:position lineIndex:lineIndex];
    if (ofs != CGFLOAT_MAX) {
      BOOL RTL = [self _isRightToLeftInLine:line atPoint:point];
      if (position >= line.range.location + line.range.length) {
        finalAffinity = RTL ? ASTextAffinityForward : ASTextAffinityBackward;
      } else if (position <= line.range.location) {
        finalAffinity = RTL ? ASTextAffinityBackward : ASTextAffinityForward;
      } else {
        finalAffinity = (ofs < (isVertical ? point.y : point.x) && !RTL) ? ASTextAffinityForward : ASTextAffinityBackward;
      }
    }
  }
  
  return [ASTextPosition positionWithOffset:position affinity:finalAffinity];
}

- (ASTextPosition *)positionForPoint:(CGPoint)point
                         oldPosition:(ASTextPosition *)oldPosition
                       otherPosition:(ASTextPosition *)otherPosition {
  if (!oldPosition || !otherPosition) {
    return oldPosition;
  }
  ASTextPosition *newPos = [self closestPositionToPoint:point];
  if (!newPos) return oldPosition;
  if ([newPos compare:otherPosition] == [oldPosition compare:otherPosition] &&
      newPos.offset != otherPosition.offset) {
    return newPos;
  }
  NSUInteger lineIndex = [self lineIndexForPosition:otherPosition];
  if (lineIndex == NSNotFound) return oldPosition;
  ASTextLine *line = _lines[lineIndex];
  ASRowEdge vertical = _lineRowsEdge[line.row];
  if (_container.verticalForm) {
    point.x = (vertical.head + vertical.foot) * 0.5;
  } else {
    point.y = (vertical.head + vertical.foot) * 0.5;
  }
  newPos = [self closestPositionToPoint:point];
  if ([newPos compare:otherPosition] == [oldPosition compare:otherPosition] &&
      newPos.offset != otherPosition.offset) {
    return newPos;
  }
  
  if (_container.isVerticalForm) {
    if ([oldPosition compare:otherPosition] == NSOrderedAscending) { // search backward
      ASTextRange *range = [self textRangeByExtendingPosition:otherPosition inDirection:UITextLayoutDirectionUp offset:1];
      if (range) return range.start;
    } else { // search forward
      ASTextRange *range = [self textRangeByExtendingPosition:otherPosition inDirection:UITextLayoutDirectionDown offset:1];
      if (range) return range.end;
    }
  } else {
    if ([oldPosition compare:otherPosition] == NSOrderedAscending) { // search backward
      ASTextRange *range = [self textRangeByExtendingPosition:otherPosition inDirection:UITextLayoutDirectionLeft offset:1];
      if (range) return range.start;
    } else { // search forward
      ASTextRange *range = [self textRangeByExtendingPosition:otherPosition inDirection:UITextLayoutDirectionRight offset:1];
      if (range) return range.end;
    }
  }
  
  return oldPosition;
}

- (ASTextRange *)textRangeAtPoint:(CGPoint)point {
  NSUInteger lineIndex = [self lineIndexForPoint:point];
  if (lineIndex == NSNotFound) return nil;
  NSUInteger textPosition = [self textPositionForPoint:point lineIndex:[self lineIndexForPoint:point]];
  if (textPosition == NSNotFound) return nil;
  ASTextPosition *pos = [self closestPositionToPoint:point];
  if (!pos) return nil;
  
  // get write direction
  BOOL RTL = [self _isRightToLeftInLine:_lines[lineIndex] atPoint:point];
  CGRect rect = [self caretRectForPosition:pos];
  if (CGRectIsNull(rect)) return nil;
  
  if (_container.verticalForm) {
    ASTextRange *range = [self textRangeByExtendingPosition:pos inDirection:(rect.origin.y >= point.y && !RTL) ? UITextLayoutDirectionUp:UITextLayoutDirectionDown offset:1];
    return range;
  } else {
    ASTextRange *range = [self textRangeByExtendingPosition:pos inDirection:(rect.origin.x >= point.x && !RTL) ? UITextLayoutDirectionLeft:UITextLayoutDirectionRight offset:1];
    return range;
  }
}

- (ASTextRange *)closestTextRangeAtPoint:(CGPoint)point {
  ASTextPosition *pos = [self closestPositionToPoint:point];
  if (!pos) return nil;
  NSUInteger lineIndex = [self lineIndexForPosition:pos];
  if (lineIndex == NSNotFound) return nil;
  ASTextLine *line = _lines[lineIndex];
  BOOL RTL = [self _isRightToLeftInLine:line atPoint:point];
  CGRect rect = [self caretRectForPosition:pos];
  if (CGRectIsNull(rect)) return nil;
  
  UITextLayoutDirection direction = UITextLayoutDirectionRight;
  if (pos.offset >= line.range.location + line.range.length) {
    if (direction != RTL) {
      direction = _container.verticalForm ? UITextLayoutDirectionUp : UITextLayoutDirectionLeft;
    } else {
      direction = _container.verticalForm ? UITextLayoutDirectionDown : UITextLayoutDirectionRight;
    }
  } else if (pos.offset <= line.range.location) {
    if (direction != RTL) {
      direction = _container.verticalForm ? UITextLayoutDirectionDown : UITextLayoutDirectionRight;
    } else {
      direction = _container.verticalForm ? UITextLayoutDirectionUp : UITextLayoutDirectionLeft;
    }
  } else {
    if (_container.verticalForm) {
      direction = (rect.origin.y >= point.y && !RTL) ? UITextLayoutDirectionUp:UITextLayoutDirectionDown;
    } else {
      direction = (rect.origin.x >= point.x && !RTL) ? UITextLayoutDirectionLeft:UITextLayoutDirectionRight;
    }
  }
  
  ASTextRange *range = [self textRangeByExtendingPosition:pos inDirection:direction offset:1];
  return range;
}

- (ASTextRange *)textRangeByExtendingPosition:(ASTextPosition *)position {
  NSUInteger visibleStart = _visibleRange.location;
  NSUInteger visibleEnd = _visibleRange.location + _visibleRange.length;
  
  if (!position) return nil;
  if (position.offset < visibleStart || position.offset > visibleEnd) return nil;
  
  // head or tail, returns immediately
  if (position.offset == visibleStart) {
    return [ASTextRange rangeWithRange:NSMakeRange(position.offset, 0)];
  } else if (position.offset == visibleEnd) {
    return [ASTextRange rangeWithRange:NSMakeRange(position.offset, 0) affinity:ASTextAffinityBackward];
  }
  
  // binding range
  NSRange tRange;
  ASTextBinding *binding = [_text attribute:ASTextBindingAttributeName atIndex:position.offset longestEffectiveRange:&tRange inRange:_visibleRange];
  if (binding && tRange.length > 0 && tRange.location < position.offset) {
    return [ASTextRange rangeWithRange:tRange];
  }
  
  // inside emoji or composed character sequences
  NSUInteger lineIndex = [self lineIndexForPosition:position];
  if (lineIndex != NSNotFound) {
    __block NSUInteger _prev, _next;
    BOOL emoji = NO, seq = NO;
    
    ASTextLine *line = _lines[lineIndex];
    emoji = [self _insideEmoji:line position:position.offset block: ^(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next) {
      _prev = prev;
      _next = next;
    }];
    if (!emoji) {
      seq = [self _insideComposedCharacterSequences:line position:position.offset block: ^(CGFloat left, CGFloat right, NSUInteger prev, NSUInteger next) {
        _prev = prev;
        _next = next;
      }];
    }
    if (emoji || seq) {
      return [ASTextRange rangeWithRange:NSMakeRange(_prev, _next - _prev)];
    }
  }
  
  // inside linebreak '\r\n'
  if (position.offset > visibleStart && position.offset < visibleEnd) {
    unichar c0 = [_text.string characterAtIndex:position.offset - 1];
    if ((c0 == '\r') && position.offset < visibleEnd) {
      unichar c1 = [_text.string characterAtIndex:position.offset];
      if (c1 == '\n') {
        return [ASTextRange rangeWithStart:[ASTextPosition positionWithOffset:position.offset - 1] end:[ASTextPosition positionWithOffset:position.offset + 1]];
      }
    }
    if (ASTextIsLinebreakChar(c0) && position.affinity == ASTextAffinityBackward) {
      NSString *str = [_text.string substringToIndex:position.offset];
      NSUInteger len = ASTextLinebreakTailLength(str);
      return [ASTextRange rangeWithStart:[ASTextPosition positionWithOffset:position.offset - len] end:[ASTextPosition positionWithOffset:position.offset]];
    }
  }
  
  return [ASTextRange rangeWithRange:NSMakeRange(position.offset, 0) affinity:position.affinity];
}

- (ASTextRange *)textRangeByExtendingPosition:(ASTextPosition *)position
                                  inDirection:(UITextLayoutDirection)direction
                                       offset:(NSInteger)offset {
  NSInteger visibleStart = _visibleRange.location;
  NSInteger visibleEnd = _visibleRange.location + _visibleRange.length;
  
  if (!position) return nil;
  if (position.offset < visibleStart || position.offset > visibleEnd) return nil;
  if (offset == 0) return [self textRangeByExtendingPosition:position];
  
  BOOL isVerticalForm = _container.verticalForm;
  BOOL verticalMove, forwardMove;
  
  if (isVerticalForm) {
    verticalMove = direction == UITextLayoutDirectionLeft || direction == UITextLayoutDirectionRight;
    forwardMove = direction == UITextLayoutDirectionLeft || direction == UITextLayoutDirectionDown;
  } else {
    verticalMove = direction == UITextLayoutDirectionUp || direction == UITextLayoutDirectionDown;
    forwardMove = direction == UITextLayoutDirectionDown || direction == UITextLayoutDirectionRight;
  }
  
  if (offset < 0) {
    forwardMove = !forwardMove;
    offset = -offset;
  }
  
  // head or tail, returns immediately
  if (!forwardMove && position.offset == visibleStart) {
    return [ASTextRange rangeWithRange:NSMakeRange(_visibleRange.location, 0)];
  } else if (forwardMove && position.offset == visibleEnd) {
    return [ASTextRange rangeWithRange:NSMakeRange(position.offset, 0) affinity:ASTextAffinityBackward];
  }
  
  // extend from position
  ASTextRange *fromRange = [self textRangeByExtendingPosition:position];
  if (!fromRange) return nil;
  ASTextRange *allForward = [ASTextRange rangeWithStart:fromRange.start end:[ASTextPosition positionWithOffset:visibleEnd]];
  ASTextRange *allBackward = [ASTextRange rangeWithStart:[ASTextPosition positionWithOffset:visibleStart] end:fromRange.end];
  
  if (verticalMove) { // up/down in text layout
    NSInteger lineIndex = [self lineIndexForPosition:position];
    if (lineIndex == NSNotFound) return nil;
    
    ASTextLine *line = _lines[lineIndex];
    NSInteger moveToRowIndex = (NSInteger)line.row + (forwardMove ? offset : -offset);
    if (moveToRowIndex < 0) return allBackward;
    else if (moveToRowIndex >= (NSInteger)_rowCount) return allForward;
    
    CGFloat ofs = [self offsetForTextPosition:position.offset lineIndex:lineIndex];
    if (ofs == CGFLOAT_MAX) return nil;
    
    NSUInteger moveToLineFirstIndex = [self lineIndexForRow:moveToRowIndex];
    NSUInteger moveToLineCount = [self lineCountForRow:moveToRowIndex];
    if (moveToLineFirstIndex == NSNotFound || moveToLineCount == NSNotFound || moveToLineCount == 0) return nil;
    CGFloat mostLeft = CGFLOAT_MAX, mostRight = -CGFLOAT_MAX;
    ASTextLine *mostLeftLine = nil, *mostRightLine = nil;
    NSUInteger insideIndex = NSNotFound;
    for (NSUInteger i = 0; i < moveToLineCount; i++) {
      NSUInteger lineIndex = moveToLineFirstIndex + i;
      ASTextLine *line = _lines[lineIndex];
      if (isVerticalForm) {
        if (line.top <= ofs && ofs <= line.bottom) {
          insideIndex = line.index;
          break;
        }
        if (line.top < mostLeft) {
          mostLeft = line.top;
          mostLeftLine = line;
        }
        if (line.bottom > mostRight) {
          mostRight = line.bottom;
          mostRightLine = line;
        }
      } else {
        if (line.left <= ofs && ofs <= line.right) {
          insideIndex = line.index;
          break;
        }
        if (line.left < mostLeft) {
          mostLeft = line.left;
          mostLeftLine = line;
        }
        if (line.right > mostRight) {
          mostRight = line.right;
          mostRightLine = line;
        }
      }
    }
    BOOL afinityEdge = NO;
    if (insideIndex == NSNotFound) {
      if (ofs <= mostLeft) {
        insideIndex = mostLeftLine.index;
      } else {
        insideIndex = mostRightLine.index;
      }
      afinityEdge = YES;
    }
    ASTextLine *insideLine = _lines[insideIndex];
    NSUInteger pos;
    if (isVerticalForm) {
      pos = [self textPositionForPoint:CGPointMake(insideLine.position.x, ofs) lineIndex:insideIndex];
    } else {
      pos = [self textPositionForPoint:CGPointMake(ofs, insideLine.position.y) lineIndex:insideIndex];
    }
    if (pos == NSNotFound) return nil;
    ASTextPosition *extPos;
    if (afinityEdge) {
      if (pos == insideLine.range.location + insideLine.range.length) {
        NSString *subStr = [_text.string substringWithRange:insideLine.range];
        NSUInteger lineBreakLen = ASTextLinebreakTailLength(subStr);
        extPos = [ASTextPosition positionWithOffset:pos - lineBreakLen];
      } else {
        extPos = [ASTextPosition positionWithOffset:pos];
      }
    } else {
      extPos = [ASTextPosition positionWithOffset:pos];
    }
    ASTextRange *ext = [self textRangeByExtendingPosition:extPos];
    if (!ext) return nil;
    if (forwardMove) {
      return [ASTextRange rangeWithStart:fromRange.start end:ext.end];
    } else {
      return [ASTextRange rangeWithStart:ext.start end:fromRange.end];
    }
    
  } else { // left/right in text layout
    ASTextPosition *toPosition = [ASTextPosition positionWithOffset:position.offset + (forwardMove ? offset : -offset)];
    if (toPosition.offset <= visibleStart) return allBackward;
    else if (toPosition.offset >= visibleEnd) return allForward;
    
    ASTextRange *toRange = [self textRangeByExtendingPosition:toPosition];
    if (!toRange) return nil;
    
    NSInteger start = MIN(fromRange.start.offset, toRange.start.offset);
    NSInteger end = MAX(fromRange.end.offset, toRange.end.offset);
    return [ASTextRange rangeWithRange:NSMakeRange(start, end - start)];
  }
}

- (NSUInteger)lineIndexForPosition:(ASTextPosition *)position {
  if (!position) return NSNotFound;
  if (_lines.count == 0) return NSNotFound;
  NSUInteger location = position.offset;
  NSInteger lo = 0, hi = _lines.count - 1, mid = 0;
  if (position.affinity == ASTextAffinityBackward) {
    while (lo <= hi) {
      mid = (lo + hi) / 2;
      ASTextLine *line = _lines[mid];
      NSRange range = line.range;
      if (range.location < location && location <= range.location + range.length) {
        return mid;
      }
      if (location <= range.location) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
  } else {
    while (lo <= hi) {
      mid = (lo + hi) / 2;
      ASTextLine *line = _lines[mid];
      NSRange range = line.range;
      if (range.location <= location && location < range.location + range.length) {
        return mid;
      }
      if (location < range.location) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
  }
  return NSNotFound;
}

- (CGPoint)linePositionForPosition:(ASTextPosition *)position {
  NSUInteger lineIndex = [self lineIndexForPosition:position];
  if (lineIndex == NSNotFound) return CGPointZero;
  ASTextLine *line = _lines[lineIndex];
  CGFloat offset = [self offsetForTextPosition:position.offset lineIndex:lineIndex];
  if (offset == CGFLOAT_MAX) return CGPointZero;
  if (_container.verticalForm) {
    return CGPointMake(line.position.x, offset);
  } else {
    return CGPointMake(offset, line.position.y);
  }
}

- (CGRect)caretRectForPosition:(ASTextPosition *)position {
  NSUInteger lineIndex = [self lineIndexForPosition:position];
  if (lineIndex == NSNotFound) return CGRectNull;
  ASTextLine *line = _lines[lineIndex];
  CGFloat offset = [self offsetForTextPosition:position.offset lineIndex:lineIndex];
  if (offset == CGFLOAT_MAX) return CGRectNull;
  if (_container.verticalForm) {
    return CGRectMake(line.bounds.origin.x, offset, line.bounds.size.width, 0);
  } else {
    return CGRectMake(offset, line.bounds.origin.y, 0, line.bounds.size.height);
  }
}

- (CGRect)firstRectForRange:(ASTextRange *)range {
  range = [self _correctedRangeWithEdge:range];
  
  NSUInteger startLineIndex = [self lineIndexForPosition:range.start];
  NSUInteger endLineIndex = [self lineIndexForPosition:range.end];
  if (startLineIndex == NSNotFound || endLineIndex == NSNotFound) return CGRectNull;
  if (startLineIndex > endLineIndex) return CGRectNull;
  ASTextLine *startLine = _lines[startLineIndex];
  ASTextLine *endLine = _lines[endLineIndex];
  NSMutableArray *lines = [NSMutableArray new];
  for (NSUInteger i = startLineIndex; i <= startLineIndex; i++) {
    ASTextLine *line = _lines[i];
    if (line.row != startLine.row) break;
    [lines addObject:line];
  }
  if (_container.verticalForm) {
    if (lines.count == 1) {
      CGFloat top = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
      CGFloat bottom;
      if (startLine == endLine) {
        bottom = [self offsetForTextPosition:range.end.offset lineIndex:startLineIndex];
      } else {
        bottom = startLine.bottom;
      }
      if (top == CGFLOAT_MAX || bottom == CGFLOAT_MAX) return CGRectNull;
      if (top > bottom) ASTEXT_SWAP(top, bottom);
      return CGRectMake(startLine.left, top, startLine.width, bottom - top);
    } else {
      CGFloat top = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
      CGFloat bottom = startLine.bottom;
      if (top == CGFLOAT_MAX || bottom == CGFLOAT_MAX) return CGRectNull;
      if (top > bottom) ASTEXT_SWAP(top, bottom);
      CGRect rect = CGRectMake(startLine.left, top, startLine.width, bottom - top);
      for (NSUInteger i = 1; i < lines.count; i++) {
        ASTextLine *line = lines[i];
        rect = CGRectUnion(rect, line.bounds);
      }
      return rect;
    }
  } else {
    if (lines.count == 1) {
      CGFloat left = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
      CGFloat right;
      if (startLine == endLine) {
        right = [self offsetForTextPosition:range.end.offset lineIndex:startLineIndex];
      } else {
        right = startLine.right;
      }
      if (left == CGFLOAT_MAX || right == CGFLOAT_MAX) return CGRectNull;
      if (left > right) ASTEXT_SWAP(left, right);
      return CGRectMake(left, startLine.top, right - left, startLine.height);
    } else {
      CGFloat left = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
      CGFloat right = startLine.right;
      if (left == CGFLOAT_MAX || right == CGFLOAT_MAX) return CGRectNull;
      if (left > right) ASTEXT_SWAP(left, right);
      CGRect rect = CGRectMake(left, startLine.top, right - left, startLine.height);
      for (NSUInteger i = 1; i < lines.count; i++) {
        ASTextLine *line = lines[i];
        rect = CGRectUnion(rect, line.bounds);
      }
      return rect;
    }
  }
}

- (CGRect)rectForRange:(ASTextRange *)range {
  NSArray *rects = [self selectionRectsForRange:range];
  if (rects.count == 0) return CGRectNull;
  CGRect rectUnion = ((ASTextSelectionRect *)rects.firstObject).rect;
  for (NSUInteger i = 1; i < rects.count; i++) {
    ASTextSelectionRect *rect = rects[i];
    rectUnion = CGRectUnion(rectUnion, rect.rect);
  }
  return rectUnion;
}

- (NSArray *)selectionRectsForRange:(ASTextRange *)range {
  range = [self _correctedRangeWithEdge:range];
  
  BOOL isVertical = _container.verticalForm;
  NSMutableArray *rects = [[NSMutableArray<ASTextSelectionRect *> alloc] init];
  if (!range) return rects;
  
  NSUInteger startLineIndex = [self lineIndexForPosition:range.start];
  NSUInteger endLineIndex = [self lineIndexForPosition:range.end];
  if (startLineIndex == NSNotFound || endLineIndex == NSNotFound) return rects;
  if (startLineIndex > endLineIndex) ASTEXT_SWAP(startLineIndex, endLineIndex);
  ASTextLine *startLine = _lines[startLineIndex];
  ASTextLine *endLine = _lines[endLineIndex];
  CGFloat offsetStart = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
  CGFloat offsetEnd = [self offsetForTextPosition:range.end.offset lineIndex:endLineIndex];
  
  ASTextSelectionRect *start = [ASTextSelectionRect new];
  if (isVertical) {
    start.rect = CGRectMake(startLine.left, offsetStart, startLine.width, 0);
  } else {
    start.rect = CGRectMake(offsetStart, startLine.top, 0, startLine.height);
  }
  start.containsStart = YES;
  start.isVertical = isVertical;
  [rects addObject:start];
  
  ASTextSelectionRect *end = [ASTextSelectionRect new];
  if (isVertical) {
    end.rect = CGRectMake(endLine.left, offsetEnd, endLine.width, 0);
  } else {
    end.rect = CGRectMake(offsetEnd, endLine.top, 0, endLine.height);
  }
  end.containsEnd = YES;
  end.isVertical = isVertical;
  [rects addObject:end];
  
  if (startLine.row == endLine.row) { // same row
    if (offsetStart > offsetEnd) ASTEXT_SWAP(offsetStart, offsetEnd);
    ASTextSelectionRect *rect = [ASTextSelectionRect new];
    if (isVertical) {
      rect.rect = CGRectMake(startLine.bounds.origin.x, offsetStart, MAX(startLine.width, endLine.width), offsetEnd - offsetStart);
    } else {
      rect.rect = CGRectMake(offsetStart, startLine.bounds.origin.y, offsetEnd - offsetStart, MAX(startLine.height, endLine.height));
    }
    rect.isVertical = isVertical;
    [rects addObject:rect];
    
  } else { // more than one row
    
    // start line select rect
    ASTextSelectionRect *topRect = [ASTextSelectionRect new];
    topRect.isVertical = isVertical;
    CGFloat topOffset = [self offsetForTextPosition:range.start.offset lineIndex:startLineIndex];
    CTRunRef topRun = [self _runForLine:startLine position:range.start];
    if (topRun && (CTRunGetStatus(topRun) & kCTRunStatusRightToLeft)) {
      if (isVertical) {
        topRect.rect = CGRectMake(startLine.left, _container.path ? startLine.top : _container.insets.top, startLine.width, topOffset - startLine.top);
      } else {
        topRect.rect = CGRectMake(_container.path ? startLine.left : _container.insets.left, startLine.top, topOffset - startLine.left, startLine.height);
      }
      topRect.writingDirection = UITextWritingDirectionRightToLeft;
    } else {
      if (isVertical) {
        topRect.rect = CGRectMake(startLine.left, topOffset, startLine.width, (_container.path ? startLine.bottom : _container.size.height - _container.insets.bottom) - topOffset);
      } else {
        topRect.rect = CGRectMake(topOffset, startLine.top, (_container.path ? startLine.right : _container.size.width - _container.insets.right) - topOffset, startLine.height);
      }
    }
    [rects addObject:topRect];
    
    // end line select rect
    ASTextSelectionRect *bottomRect = [ASTextSelectionRect new];
    bottomRect.isVertical = isVertical;
    CGFloat bottomOffset = [self offsetForTextPosition:range.end.offset lineIndex:endLineIndex];
    CTRunRef bottomRun = [self _runForLine:endLine position:range.end];
    if (bottomRun && (CTRunGetStatus(bottomRun) & kCTRunStatusRightToLeft)) {
      if (isVertical) {
        bottomRect.rect = CGRectMake(endLine.left, bottomOffset, endLine.width, (_container.path ? endLine.bottom : _container.size.height - _container.insets.bottom) - bottomOffset);
      } else {
        bottomRect.rect = CGRectMake(bottomOffset, endLine.top, (_container.path ? endLine.right : _container.size.width - _container.insets.right) - bottomOffset, endLine.height);
      }
      bottomRect.writingDirection = UITextWritingDirectionRightToLeft;
    } else {
      if (isVertical) {
        CGFloat top = _container.path ? endLine.top : _container.insets.top;
        bottomRect.rect = CGRectMake(endLine.left, top, endLine.width, bottomOffset - top);
      } else {
        CGFloat left = _container.path ? endLine.left : _container.insets.left;
        bottomRect.rect = CGRectMake(left, endLine.top, bottomOffset - left, endLine.height);
      }
    }
    [rects addObject:bottomRect];
    
    if (endLineIndex - startLineIndex >= 2) {
      CGRect r = CGRectZero;
      BOOL startLineDetected = NO;
      for (NSUInteger l = startLineIndex + 1; l < endLineIndex; l++) {
        ASTextLine *line = _lines[l];
        if (line.row == startLine.row || line.row == endLine.row) continue;
        if (!startLineDetected) {
          r = line.bounds;
          startLineDetected = YES;
        } else {
          r = CGRectUnion(r, line.bounds);
        }
      }
      if (startLineDetected) {
        if (isVertical) {
          if (!_container.path) {
            r.origin.y = _container.insets.top;
            r.size.height = _container.size.height - _container.insets.bottom - _container.insets.top;
          }
          r.size.width =  CGRectGetMinX(topRect.rect) - CGRectGetMaxX(bottomRect.rect);
          r.origin.x = CGRectGetMaxX(bottomRect.rect);
        } else {
          if (!_container.path) {
            r.origin.x = _container.insets.left;
            r.size.width = _container.size.width - _container.insets.right - _container.insets.left;
          }
          r.origin.y = CGRectGetMaxY(topRect.rect);
          r.size.height = bottomRect.rect.origin.y - r.origin.y;
        }
        
        ASTextSelectionRect *rect = [ASTextSelectionRect new];
        rect.rect = r;
        rect.isVertical = isVertical;
        [rects addObject:rect];
      }
    } else {
      if (isVertical) {
        CGRect r0 = bottomRect.rect;
        CGRect r1 = topRect.rect;
        CGFloat mid = (CGRectGetMaxX(r0) + CGRectGetMinX(r1)) * 0.5;
        r0.size.width = mid - r0.origin.x;
        CGFloat r1ofs = r1.origin.x - mid;
        r1.origin.x -= r1ofs;
        r1.size.width += r1ofs;
        topRect.rect = r1;
        bottomRect.rect = r0;
      } else {
        CGRect r0 = topRect.rect;
        CGRect r1 = bottomRect.rect;
        CGFloat mid = (CGRectGetMaxY(r0) + CGRectGetMinY(r1)) * 0.5;
        r0.size.height = mid - r0.origin.y;
        CGFloat r1ofs = r1.origin.y - mid;
        r1.origin.y -= r1ofs;
        r1.size.height += r1ofs;
        topRect.rect = r0;
        bottomRect.rect = r1;
      }
    }
  }
  return rects;
}

- (NSArray *)selectionRectsWithoutStartAndEndForRange:(ASTextRange *)range {
  NSMutableArray *rects = [self selectionRectsForRange:range].mutableCopy;
  for (NSInteger i = 0, max = rects.count; i < max; i++) {
    ASTextSelectionRect *rect = rects[i];
    if (rect.containsStart || rect.containsEnd) {
      [rects removeObjectAtIndex:i];
      i--;
      max--;
    }
  }
  return rects;
}

- (NSArray *)selectionRectsWithOnlyStartAndEndForRange:(ASTextRange *)range {
  NSMutableArray *rects = [self selectionRectsForRange:range].mutableCopy;
  for (NSInteger i = 0, max = rects.count; i < max; i++) {
    ASTextSelectionRect *rect = rects[i];
    if (!rect.containsStart && !rect.containsEnd) {
      [rects removeObjectAtIndex:i];
      i--;
      max--;
    }
  }
  return rects;
}


#pragma mark - Draw


typedef NS_OPTIONS(NSUInteger, ASTextDecorationType) {
  ASTextDecorationTypeUnderline     = 1 << 0,
  ASTextDecorationTypeStrikethrough = 1 << 1,
};

typedef NS_OPTIONS(NSUInteger, ASTextBorderType) {
  ASTextBorderTypeBackgound = 1 << 0,
  ASTextBorderTypeNormal    = 1 << 1,
};

static CGRect ASTextMergeRectInSameLine(CGRect rect1, CGRect rect2, BOOL isVertical) {
  if (isVertical) {
    CGFloat top = MIN(rect1.origin.y, rect2.origin.y);
    CGFloat bottom = MAX(rect1.origin.y + rect1.size.height, rect2.origin.y + rect2.size.height);
    CGFloat width = MAX(rect1.size.width, rect2.size.width);
    return CGRectMake(rect1.origin.x, top, width, bottom - top);
  } else {
    CGFloat left = MIN(rect1.origin.x, rect2.origin.x);
    CGFloat right = MAX(rect1.origin.x + rect1.size.width, rect2.origin.x + rect2.size.width);
    CGFloat height = MAX(rect1.size.height, rect2.size.height);
    return CGRectMake(left, rect1.origin.y, right - left, height);
  }
}

static void ASTextGetRunsMaxMetric(CFArrayRef runs, CGFloat *xHeight, CGFloat *underlinePosition, CGFloat *lineThickness) {
  CGFloat maxXHeight = 0;
  CGFloat maxUnderlinePos = 0;
  CGFloat maxLineThickness = 0;
  for (NSUInteger i = 0, max = CFArrayGetCount(runs); i < max; i++) {
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, i);
    CFDictionaryRef attrs = CTRunGetAttributes(run);
    if (attrs) {
      CTFontRef font = (CTFontRef)CFDictionaryGetValue(attrs, kCTFontAttributeName);
      if (font) {
        CGFloat xHeight = CTFontGetXHeight(font);
        if (xHeight > maxXHeight) maxXHeight = xHeight;
        CGFloat underlinePos = CTFontGetUnderlinePosition(font);
        if (underlinePos < maxUnderlinePos) maxUnderlinePos = underlinePos;
        CGFloat lineThickness = CTFontGetUnderlineThickness(font);
        if (lineThickness > maxLineThickness) maxLineThickness = lineThickness;
      }
    }
  }
  if (xHeight) *xHeight = maxXHeight;
  if (underlinePosition) *underlinePosition = maxUnderlinePos;
  if (lineThickness) *lineThickness = maxLineThickness;
}

static void ASTextDrawRun(ASTextLine *line, CTRunRef run, CGContextRef context, CGSize size, BOOL isVertical, NSArray *runRanges, CGFloat verticalOffset) {
  CGAffineTransform runTextMatrix = CTRunGetTextMatrix(run);
  BOOL runTextMatrixIsID = CGAffineTransformIsIdentity(runTextMatrix);
  
  CFDictionaryRef runAttrs = CTRunGetAttributes(run);
  NSValue *glyphTransformValue = (NSValue *)CFDictionaryGetValue(runAttrs, (__bridge const void *)(ASTextGlyphTransformAttributeName));
  if (!isVertical && !glyphTransformValue) { // draw run
    if (!runTextMatrixIsID) {
      CGContextSaveGState(context);
      CGAffineTransform trans = CGContextGetTextMatrix(context);
      CGContextSetTextMatrix(context, CGAffineTransformConcat(trans, runTextMatrix));
    }
    CTRunDraw(run, context, CFRangeMake(0, 0));
    if (!runTextMatrixIsID) {
      CGContextRestoreGState(context);
    }
  } else { // draw glyph
    CTFontRef runFont = (CTFontRef)CFDictionaryGetValue(runAttrs, kCTFontAttributeName);
    if (!runFont) return;
    NSUInteger glyphCount = CTRunGetGlyphCount(run);
    if (glyphCount <= 0) return;
    
    CGGlyph glyphs[glyphCount];
    CGPoint glyphPositions[glyphCount];
    CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
    CTRunGetPositions(run, CFRangeMake(0, 0), glyphPositions);
    
    CGColorRef fillColor = (CGColorRef)CFDictionaryGetValue(runAttrs, kCTForegroundColorAttributeName);
    fillColor = ASTextGetCGColor(fillColor);
    NSNumber *strokeWidth = (NSNumber *)CFDictionaryGetValue(runAttrs, kCTStrokeWidthAttributeName);
    
    CGContextSaveGState(context); {
      CGContextSetFillColorWithColor(context, fillColor);
      if (!strokeWidth || strokeWidth.floatValue == 0) {
        CGContextSetTextDrawingMode(context, kCGTextFill);
      } else {
        CGColorRef strokeColor = (CGColorRef)CFDictionaryGetValue(runAttrs, kCTStrokeColorAttributeName);
        if (!strokeColor) strokeColor = fillColor;
        CGContextSetStrokeColorWithColor(context, strokeColor);
        CGContextSetLineWidth(context, CTFontGetSize(runFont) * fabs(strokeWidth.floatValue * 0.01));
        if (strokeWidth.floatValue > 0) {
          CGContextSetTextDrawingMode(context, kCGTextStroke);
        } else {
          CGContextSetTextDrawingMode(context, kCGTextFillStroke);
        }
      }
      
      if (isVertical) {
        CFIndex runStrIdx[glyphCount + 1];
        CTRunGetStringIndices(run, CFRangeMake(0, 0), runStrIdx);
        CFRange runStrRange = CTRunGetStringRange(run);
        runStrIdx[glyphCount] = runStrRange.location + runStrRange.length;
        CGSize glyphAdvances[glyphCount];
        CTRunGetAdvances(run, CFRangeMake(0, 0), glyphAdvances);
        CGFloat ascent = CTFontGetAscent(runFont);
        CGFloat descent = CTFontGetDescent(runFont);
        CGAffineTransform glyphTransform = glyphTransformValue.CGAffineTransformValue;
        CGPoint zeroPoint = CGPointZero;
        
        for (ASTextRunGlyphRange *oneRange in runRanges) {
          NSRange range = oneRange.glyphRangeInRun;
          NSUInteger rangeMax = range.location + range.length;
          ASTextRunGlyphDrawMode mode = oneRange.drawMode;
          
          for (NSUInteger g = range.location; g < rangeMax; g++) {
            CGContextSaveGState(context); {
              CGContextSetTextMatrix(context, CGAffineTransformIdentity);
              if (glyphTransformValue) {
                CGContextSetTextMatrix(context, glyphTransform);
              }
              if (mode) { // CJK glyph, need rotated
                CGFloat ofs = (ascent - descent) * 0.5;
                CGFloat w = glyphAdvances[g].width * 0.5;
                CGFloat x = x = line.position.x + verticalOffset + glyphPositions[g].y + (ofs - w);
                CGFloat y = -line.position.y + size.height - glyphPositions[g].x - (ofs + w);
                if (mode == ASTextRunGlyphDrawModeVerticalRotateMove) {
                  x += w;
                  y += w;
                }
                CGContextSetTextPosition(context, x, y);
              } else {
                CGContextRotateCTM(context, -M_PI_2);
                CGContextSetTextPosition(context,
                                         line.position.y - size.height + glyphPositions[g].x,
                                         line.position.x + verticalOffset + glyphPositions[g].y);
              }
              
              if (ASTextCTFontContainsColorBitmapGlyphs(runFont)) {
                CTFontDrawGlyphs(runFont, glyphs + g, &zeroPoint, 1, context);
              } else {
                CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
                CGContextSetFont(context, cgFont);
                CGContextSetFontSize(context, CTFontGetSize(runFont));
                CGContextShowGlyphsAtPositions(context, glyphs + g, &zeroPoint, 1);
                CGFontRelease(cgFont);
              }
            } CGContextRestoreGState(context);
          }
        }
      } else { // not vertical
        if (glyphTransformValue) {
          CFIndex runStrIdx[glyphCount + 1];
          CTRunGetStringIndices(run, CFRangeMake(0, 0), runStrIdx);
          CFRange runStrRange = CTRunGetStringRange(run);
          runStrIdx[glyphCount] = runStrRange.location + runStrRange.length;
          CGSize glyphAdvances[glyphCount];
          CTRunGetAdvances(run, CFRangeMake(0, 0), glyphAdvances);
          CGAffineTransform glyphTransform = glyphTransformValue.CGAffineTransformValue;
          CGPoint zeroPoint = CGPointZero;
          
          for (NSUInteger g = 0; g < glyphCount; g++) {
            CGContextSaveGState(context); {
              CGContextSetTextMatrix(context, CGAffineTransformIdentity);
              CGContextSetTextMatrix(context, glyphTransform);
              CGContextSetTextPosition(context,
                                       line.position.x + glyphPositions[g].x,
                                       size.height - (line.position.y + glyphPositions[g].y));
              
              if (ASTextCTFontContainsColorBitmapGlyphs(runFont)) {
                CTFontDrawGlyphs(runFont, glyphs + g, &zeroPoint, 1, context);
              } else {
                CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
                CGContextSetFont(context, cgFont);
                CGContextSetFontSize(context, CTFontGetSize(runFont));
                CGContextShowGlyphsAtPositions(context, glyphs + g, &zeroPoint, 1);
                CGFontRelease(cgFont);
              }
            } CGContextRestoreGState(context);
          }
        } else {
          if (ASTextCTFontContainsColorBitmapGlyphs(runFont)) {
            CTFontDrawGlyphs(runFont, glyphs, glyphPositions, glyphCount, context);
          } else {
            CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
            CGContextSetFont(context, cgFont);
            CGContextSetFontSize(context, CTFontGetSize(runFont));
            CGContextShowGlyphsAtPositions(context, glyphs, glyphPositions, glyphCount);
            CGFontRelease(cgFont);
          }
        }
      }
      
    } CGContextRestoreGState(context);
  }
}

static void ASTextSetLinePatternInContext(ASTextLineStyle style, CGFloat width, CGFloat phase, CGContextRef context){
  CGContextSetLineWidth(context, width);
  CGContextSetLineCap(context, kCGLineCapButt);
  CGContextSetLineJoin(context, kCGLineJoinMiter);
  
  CGFloat dash = 12, dot = 5, space = 3;
  NSUInteger pattern = style & 0xF00;
  if (pattern == ASTextLineStylePatternSolid) {
    CGContextSetLineDash(context, phase, NULL, 0);
  } else if (pattern == ASTextLineStylePatternDot) {
    CGFloat lengths[2] = {width * dot, width * space};
    CGContextSetLineDash(context, phase, lengths, 2);
  } else if (pattern == ASTextLineStylePatternDash) {
    CGFloat lengths[2] = {width * dash, width * space};
    CGContextSetLineDash(context, phase, lengths, 2);
  } else if (pattern == ASTextLineStylePatternDashDot) {
    CGFloat lengths[4] = {width * dash, width * space, width * dot, width * space};
    CGContextSetLineDash(context, phase, lengths, 4);
  } else if (pattern == ASTextLineStylePatternDashDotDot) {
    CGFloat lengths[6] = {width * dash, width * space,width * dot, width * space, width * dot, width * space};
    CGContextSetLineDash(context, phase, lengths, 6);
  } else if (pattern == ASTextLineStylePatternCircleDot) {
    CGFloat lengths[2] = {width * 0, width * 3};
    CGContextSetLineDash(context, phase, lengths, 2);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
  }
}


static void ASTextDrawBorderRects(CGContextRef context, CGSize size, ASTextBorder *border, NSArray *rects, BOOL isVertical) {
  if (rects.count == 0) return;
  
  ASTextShadow *shadow = border.shadow;
  if (shadow.color) {
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadow.offset, shadow.radius, shadow.color.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
  }
  
  NSMutableArray *paths = [NSMutableArray new];
  for (NSValue *value in rects) {
    CGRect rect = value.CGRectValue;
    if (isVertical) {
      rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(border.insets));
    } else {
      rect = UIEdgeInsetsInsetRect(rect, border.insets);
    }
    rect = ASTextCGRectPixelRound(rect);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius];
    [path closePath];
    [paths addObject:path];
  }
  
  if (border.fillColor) {
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, border.fillColor.CGColor);
    for (UIBezierPath *path in paths) {
      CGContextAddPath(context, path.CGPath);
    }
    CGContextFillPath(context);
    CGContextRestoreGState(context);
  }
  
  if (border.strokeColor && border.lineStyle > 0 && border.strokeWidth > 0) {
    
    //-------------------------- single line ------------------------------//
    CGContextSaveGState(context);
    for (UIBezierPath *path in paths) {
      CGRect bounds = CGRectUnion(path.bounds, (CGRect){CGPointZero, size});
      bounds = CGRectInset(bounds, -2 * border.strokeWidth, -2 * border.strokeWidth);
      CGContextAddRect(context, bounds);
      CGContextAddPath(context, path.CGPath);
      CGContextEOClip(context);
    }
    [border.strokeColor setStroke];
    ASTextSetLinePatternInContext(border.lineStyle, border.strokeWidth, 0, context);
    CGFloat inset = -border.strokeWidth * 0.5;
    if ((border.lineStyle & 0xFF) == ASTextLineStyleThick) {
      inset *= 2;
      CGContextSetLineWidth(context, border.strokeWidth * 2);
    }
    CGFloat radiusDelta = -inset;
    if (border.cornerRadius <= 0) {
      radiusDelta = 0;
    }
    CGContextSetLineJoin(context, border.lineJoin);
    for (NSValue *value in rects) {
      CGRect rect = value.CGRectValue;
      if (isVertical) {
        rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(border.insets));
      } else {
        rect = UIEdgeInsetsInsetRect(rect, border.insets);
      }
      rect = CGRectInset(rect, inset, inset);
      UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + radiusDelta];
      [path closePath];
      CGContextAddPath(context, path.CGPath);
    }
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    
    //------------------------- second line ------------------------------//
    if ((border.lineStyle & 0xFF) == ASTextLineStyleDouble) {
      CGContextSaveGState(context);
      CGFloat inset = -border.strokeWidth * 2;
      for (NSValue *value in rects) {
        CGRect rect = value.CGRectValue;
        rect = UIEdgeInsetsInsetRect(rect, border.insets);
        rect = CGRectInset(rect, inset, inset);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + 2 * border.strokeWidth];
        [path closePath];
        
        CGRect bounds = CGRectUnion(path.bounds, (CGRect){CGPointZero, size});
        bounds = CGRectInset(bounds, -2 * border.strokeWidth, -2 * border.strokeWidth);
        CGContextAddRect(context, bounds);
        CGContextAddPath(context, path.CGPath);
        CGContextEOClip(context);
      }
      CGContextSetStrokeColorWithColor(context, border.strokeColor.CGColor);
      ASTextSetLinePatternInContext(border.lineStyle, border.strokeWidth, 0, context);
      CGContextSetLineJoin(context, border.lineJoin);
      inset = -border.strokeWidth * 2.5;
      radiusDelta = border.strokeWidth * 2;
      if (border.cornerRadius <= 0) {
        radiusDelta = 0;
      }
      for (NSValue *value in rects) {
        CGRect rect = value.CGRectValue;
        rect = UIEdgeInsetsInsetRect(rect, border.insets);
        rect = CGRectInset(rect, inset, inset);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + radiusDelta];
        [path closePath];
        CGContextAddPath(context, path.CGPath);
      }
      CGContextStrokePath(context);
      CGContextRestoreGState(context);
    }
  }
  
  if (shadow.color) {
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
  }
}

static void ASTextDrawLineStyle(CGContextRef context, CGFloat length, CGFloat lineWidth, ASTextLineStyle style, CGPoint position, CGColorRef color, BOOL isVertical) {
  NSUInteger styleBase = style & 0xFF;
  if (styleBase == 0) return;
  
  CGContextSaveGState(context); {
    if (isVertical) {
      CGFloat x, y1, y2, w;
      y1 = ASRoundPixelValue(position.y);
      y2 = ASRoundPixelValue(position.y + length);
      w = (styleBase == ASTextLineStyleThick ? lineWidth * 2 : lineWidth);
      
      CGFloat linePixel = ASTextCGFloatToPixel(w);
      if (fabs(linePixel - floor(linePixel)) < 0.1) {
        int iPixel = linePixel;
        if (iPixel == 0 || (iPixel % 2)) { // odd line pixel
          x = ASTextCGFloatPixelHalf(position.x);
        } else {
          x = ASFloorPixelValue(position.x);
        }
      } else {
        x = position.x;
      }
      
      CGContextSetStrokeColorWithColor(context, color);
      ASTextSetLinePatternInContext(style, lineWidth, position.y, context);
      CGContextSetLineWidth(context, w);
      if (styleBase == ASTextLineStyleSingle) {
        CGContextMoveToPoint(context, x, y1);
        CGContextAddLineToPoint(context, x, y2);
        CGContextStrokePath(context);
      } else if (styleBase == ASTextLineStyleThick) {
        CGContextMoveToPoint(context, x, y1);
        CGContextAddLineToPoint(context, x, y2);
        CGContextStrokePath(context);
      } else if (styleBase == ASTextLineStyleDouble) {
        CGContextMoveToPoint(context, x - w, y1);
        CGContextAddLineToPoint(context, x - w, y2);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, x + w, y1);
        CGContextAddLineToPoint(context, x + w, y2);
        CGContextStrokePath(context);
      }
    } else {
      CGFloat x1, x2, y, w;
      x1 = ASRoundPixelValue(position.x);
      x2 = ASRoundPixelValue(position.x + length);
      w = (styleBase == ASTextLineStyleThick ? lineWidth * 2 : lineWidth);
      
      CGFloat linePixel = ASTextCGFloatToPixel(w);
      if (fabs(linePixel - floor(linePixel)) < 0.1) {
        int iPixel = linePixel;
        if (iPixel == 0 || (iPixel % 2)) { // odd line pixel
          y = ASTextCGFloatPixelHalf(position.y);
        } else {
          y = ASFloorPixelValue(position.y);
        }
      } else {
        y = position.y;
      }
      
      CGContextSetStrokeColorWithColor(context, color);
      ASTextSetLinePatternInContext(style, lineWidth, position.x, context);
      CGContextSetLineWidth(context, w);
      if (styleBase == ASTextLineStyleSingle) {
        CGContextMoveToPoint(context, x1, y);
        CGContextAddLineToPoint(context, x2, y);
        CGContextStrokePath(context);
      } else if (styleBase == ASTextLineStyleThick) {
        CGContextMoveToPoint(context, x1, y);
        CGContextAddLineToPoint(context, x2, y);
        CGContextStrokePath(context);
      } else if (styleBase == ASTextLineStyleDouble) {
        CGContextMoveToPoint(context, x1, y - w);
        CGContextAddLineToPoint(context, x2, y - w);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, x1, y + w);
        CGContextAddLineToPoint(context, x2, y + w);
        CGContextStrokePath(context);
      }
    }
  } CGContextRestoreGState(context);
}

static void ASTextDrawText(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
  CGContextSaveGState(context); {
    
    CGContextTranslateCTM(context, point.x, point.y);
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1, -1);
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    NSArray *lines = layout.lines;
    for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
      ASTextLine *line = lines[l];
      if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
      NSArray *lineRunRanges = line.verticalRotateRange;
      CGFloat posX = line.position.x + verticalOffset;
      CGFloat posY = size.height - line.position.y;
      CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
      for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextSetTextPosition(context, posX, posY);
        ASTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
      }
      if (cancel && cancel()) break;
    }
    
    // Use this to draw frame for test/debug.
    // CGContextTranslateCTM(context, verticalOffset, size.height);
    // CTFrameDraw(layout.frame, context);
    
  } CGContextRestoreGState(context);
}

static void ASTextDrawBlockBorder(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, point.x, point.y);
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  
  NSArray *lines = layout.lines;
  for (NSInteger l = 0, lMax = lines.count; l < lMax; l++) {
    if (cancel && cancel()) break;
    
    ASTextLine *line = lines[l];
    if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
    CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
    for (NSInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
      CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
      CFIndex glyphCount = CTRunGetGlyphCount(run);
      if (glyphCount == 0) continue;
      NSDictionary *attrs = (id)CTRunGetAttributes(run);
      ASTextBorder *border = attrs[ASTextBlockBorderAttributeName];
      if (!border) continue;
      
      NSUInteger lineStartIndex = line.index;
      while (lineStartIndex > 0) {
        if (((ASTextLine *)lines[lineStartIndex - 1]).row == line.row) lineStartIndex--;
        else break;
      }
      
      CGRect unionRect = CGRectZero;
      NSUInteger lineStartRow = ((ASTextLine *)lines[lineStartIndex]).row;
      NSUInteger lineContinueIndex = lineStartIndex;
      NSUInteger lineContinueRow = lineStartRow;
      do {
        ASTextLine *one = lines[lineContinueIndex];
        if (lineContinueIndex == lineStartIndex) {
          unionRect = one.bounds;
        } else {
          unionRect = CGRectUnion(unionRect, one.bounds);
        }
        if (lineContinueIndex + 1 == lMax) break;
        ASTextLine *next = lines[lineContinueIndex + 1];
        if (next.row != lineContinueRow) {
          ASTextBorder *nextBorder = [layout.text as_attribute:ASTextBlockBorderAttributeName atIndex:next.range.location];
          if ([nextBorder isEqual:border]) {
            lineContinueRow++;
          } else {
            break;
          }
        }
        lineContinueIndex++;
      } while (true);
      
      if (isVertical) {
        UIEdgeInsets insets = layout.container.insets;
        unionRect.origin.y = insets.top;
        unionRect.size.height = layout.container.size.height -insets.top - insets.bottom;
      } else {
        UIEdgeInsets insets = layout.container.insets;
        unionRect.origin.x = insets.left;
        unionRect.size.width = layout.container.size.width -insets.left - insets.right;
      }
      unionRect.origin.x += verticalOffset;
      ASTextDrawBorderRects(context, size, border, @[[NSValue valueWithCGRect:unionRect]], isVertical);
      
      l = lineContinueIndex;
      break;
    }
  }
  
  
  CGContextRestoreGState(context);
}

static void ASTextDrawBorder(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, ASTextBorderType type, BOOL (^cancel)(void)) {
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, point.x, point.y);
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  
  NSArray *lines = layout.lines;
  NSString *borderKey = (type == ASTextBorderTypeNormal ? ASTextBorderAttributeName : ASTextBackgroundBorderAttributeName);
  
  BOOL needJumpRun = NO;
  NSUInteger jumpRunIndex = 0;
  
  for (NSInteger l = 0, lMax = lines.count; l < lMax; l++) {
    if (cancel && cancel()) break;
    
    ASTextLine *line = lines[l];
    if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
    CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
    for (NSInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
      if (needJumpRun) {
        needJumpRun = NO;
        r = jumpRunIndex + 1;
        if (r >= rMax) break;
      }
      
      CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
      CFIndex glyphCount = CTRunGetGlyphCount(run);
      if (glyphCount == 0) continue;
      
      NSDictionary *attrs = (id)CTRunGetAttributes(run);
      ASTextBorder *border = attrs[borderKey];
      if (!border) continue;
      
      CFRange runRange = CTRunGetStringRange(run);
      if (runRange.location == kCFNotFound || runRange.length == 0) continue;
      if (runRange.location + runRange.length > layout.text.length) continue;
      
      NSMutableArray *runRects = [NSMutableArray new];
      NSInteger endLineIndex = l;
      NSInteger endRunIndex = r;
      BOOL endFound = NO;
      for (NSInteger ll = l; ll < lMax; ll++) {
        if (endFound) break;
        ASTextLine *iLine = lines[ll];
        CFArrayRef iRuns = CTLineGetGlyphRuns(iLine.CTLine);
        
        CGRect extLineRect = CGRectNull;
        for (NSInteger rr = (ll == l) ? r : 0, rrMax = CFArrayGetCount(iRuns); rr < rrMax; rr++) {
          CTRunRef iRun = (CTRunRef)CFArrayGetValueAtIndex(iRuns, rr);
          NSDictionary *iAttrs = (id)CTRunGetAttributes(iRun);
          ASTextBorder *iBorder = iAttrs[borderKey];
          if (![border isEqual:iBorder]) {
            endFound = YES;
            break;
          }
          endLineIndex = ll;
          endRunIndex = rr;
          
          CGPoint iRunPosition = CGPointZero;
          CTRunGetPositions(iRun, CFRangeMake(0, 1), &iRunPosition);
          CGFloat ascent, descent;
          CGFloat iRunWidth = CTRunGetTypographicBounds(iRun, CFRangeMake(0, 0), &ascent, &descent, NULL);
          
          if (isVertical) {
            ASTEXT_SWAP(iRunPosition.x, iRunPosition.y);
            iRunPosition.y += iLine.position.y;
            CGRect iRect = CGRectMake(verticalOffset + line.position.x - descent, iRunPosition.y, ascent + descent, iRunWidth);
            if (CGRectIsNull(extLineRect)) {
              extLineRect = iRect;
            } else {
              extLineRect = CGRectUnion(extLineRect, iRect);
            }
          } else {
            iRunPosition.x += iLine.position.x;
            CGRect iRect = CGRectMake(iRunPosition.x, iLine.position.y - ascent, iRunWidth, ascent + descent);
            if (CGRectIsNull(extLineRect)) {
              extLineRect = iRect;
            } else {
              extLineRect = CGRectUnion(extLineRect, iRect);
            }
          }
        }
        
        if (!CGRectIsNull(extLineRect)) {
          [runRects addObject:[NSValue valueWithCGRect:extLineRect]];
        }
      }
      
      NSMutableArray *drawRects = [NSMutableArray new];
      CGRect curRect= ((NSValue *)[runRects firstObject]).CGRectValue;
      for (NSInteger re = 0, reMax = runRects.count; re < reMax; re++) {
        CGRect rect = ((NSValue *)runRects[re]).CGRectValue;
        if (isVertical) {
          if (fabs(rect.origin.x - curRect.origin.x) < 1) {
            curRect = ASTextMergeRectInSameLine(rect, curRect, isVertical);
          } else {
            [drawRects addObject:[NSValue valueWithCGRect:curRect]];
            curRect = rect;
          }
        } else {
          if (fabs(rect.origin.y - curRect.origin.y) < 1) {
            curRect = ASTextMergeRectInSameLine(rect, curRect, isVertical);
          } else {
            [drawRects addObject:[NSValue valueWithCGRect:curRect]];
            curRect = rect;
          }
        }
      }
      if (!CGRectEqualToRect(curRect, CGRectZero)) {
        [drawRects addObject:[NSValue valueWithCGRect:curRect]];
      }
      
      ASTextDrawBorderRects(context, size, border, drawRects, isVertical);
      
      if (l == endLineIndex) {
        r = endRunIndex;
      } else {
        l = endLineIndex - 1;
        needJumpRun = YES;
        jumpRunIndex = endRunIndex;
        break;
      }
      
    }
  }
  
  CGContextRestoreGState(context);
}

static void ASTextDrawDecoration(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, ASTextDecorationType type, BOOL (^cancel)(void)) {
  NSArray *lines = layout.lines;
  
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, point.x, point.y);
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  CGContextTranslateCTM(context, verticalOffset, 0);
  
  for (NSUInteger l = 0, lMax = layout.lines.count; l < lMax; l++) {
    if (cancel && cancel()) break;
    
    ASTextLine *line = lines[l];
    if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
    CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
    for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
      CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
      CFIndex glyphCount = CTRunGetGlyphCount(run);
      if (glyphCount == 0) continue;
      
      NSDictionary *attrs = (id)CTRunGetAttributes(run);
      ASTextDecoration *underline = attrs[ASTextUnderlineAttributeName];
      ASTextDecoration *strikethrough = attrs[ASTextStrikethroughAttributeName];
      
      BOOL needDrawUnderline = NO, needDrawStrikethrough = NO;
      if ((type & ASTextDecorationTypeUnderline) && underline.style > 0) {
        needDrawUnderline = YES;
      }
      if ((type & ASTextDecorationTypeStrikethrough) && strikethrough.style > 0) {
        needDrawStrikethrough = YES;
      }
      if (!needDrawUnderline && !needDrawStrikethrough) continue;
      
      CFRange runRange = CTRunGetStringRange(run);
      if (runRange.location == kCFNotFound || runRange.length == 0) continue;
      if (runRange.location + runRange.length > layout.text.length) continue;
      NSString *runStr = [layout.text attributedSubstringFromRange:NSMakeRange(runRange.location, runRange.length)].string;
      if (ASTextIsLinebreakString(runStr)) continue; // may need more checks...
      
      CGFloat xHeight, underlinePosition, lineThickness;
      ASTextGetRunsMaxMetric(runs, &xHeight, &underlinePosition, &lineThickness);
      
      CGPoint underlineStart, strikethroughStart;
      CGFloat length;
      
      if (isVertical) {
        underlineStart.x = line.position.x + underlinePosition;
        strikethroughStart.x = line.position.x + xHeight / 2;
        
        CGPoint runPosition = CGPointZero;
        CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
        underlineStart.y = strikethroughStart.y = runPosition.x + line.position.y;
        length = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
        
      } else {
        underlineStart.y = line.position.y - underlinePosition;
        strikethroughStart.y = line.position.y - xHeight / 2;
        
        CGPoint runPosition = CGPointZero;
        CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
        underlineStart.x = strikethroughStart.x = runPosition.x + line.position.x;
        length = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
      }
      
      if (needDrawUnderline) {
        CGColorRef color = underline.color.CGColor;
        if (!color) {
          color = (__bridge CGColorRef)(attrs[(id)kCTForegroundColorAttributeName]);
          color = ASTextGetCGColor(color);
        }
        CGFloat thickness = underline.width ? underline.width.floatValue : lineThickness;
        ASTextShadow *shadow = underline.shadow;
        while (shadow) {
          if (!shadow.color) {
            shadow = shadow.subShadow;
            continue;
          }
          CGFloat offsetAlterX = size.width + 0xFFFF;
          CGContextSaveGState(context); {
            CGSize offset = shadow.offset;
            offset.width -= offsetAlterX;
            CGContextSaveGState(context); {
              CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
              CGContextSetBlendMode(context, shadow.blendMode);
              CGContextTranslateCTM(context, offsetAlterX, 0);
              ASTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
            } CGContextRestoreGState(context);
          } CGContextRestoreGState(context);
          shadow = shadow.subShadow;
        }
        ASTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
      }
      
      if (needDrawStrikethrough) {
        CGColorRef color = strikethrough.color.CGColor;
        if (!color) {
          color = (__bridge CGColorRef)(attrs[(id)kCTForegroundColorAttributeName]);
          color = ASTextGetCGColor(color);
        }
        CGFloat thickness = strikethrough.width ? strikethrough.width.floatValue : lineThickness;
        ASTextShadow *shadow = underline.shadow;
        while (shadow) {
          if (!shadow.color) {
            shadow = shadow.subShadow;
            continue;
          }
          CGFloat offsetAlterX = size.width + 0xFFFF;
          CGContextSaveGState(context); {
            CGSize offset = shadow.offset;
            offset.width -= offsetAlterX;
            CGContextSaveGState(context); {
              CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
              CGContextSetBlendMode(context, shadow.blendMode);
              CGContextTranslateCTM(context, offsetAlterX, 0);
              ASTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
            } CGContextRestoreGState(context);
          } CGContextRestoreGState(context);
          shadow = shadow.subShadow;
        }
        ASTextDrawLineStyle(context, length, thickness, strikethrough.style, strikethroughStart, color, isVertical);
      }
    }
  }
  CGContextRestoreGState(context);
}

static void ASTextDrawAttachment(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, UIView *targetView, CALayer *targetLayer, BOOL (^cancel)(void)) {
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  
  for (NSUInteger i = 0, max = layout.attachments.count; i < max; i++) {
    ASTextAttachment *a = layout.attachments[i];
    if (!a.content) continue;
    
    UIImage *image = nil;
    UIView *view = nil;
    CALayer *layer = nil;
    if ([a.content isKindOfClass:[UIImage class]]) {
      image = a.content;
    } else if ([a.content isKindOfClass:[UIView class]]) {
      view = a.content;
    } else if ([a.content isKindOfClass:[CALayer class]]) {
      layer = a.content;
    }
    if (!image && !view && !layer) continue;
    if (image && !context) continue;
    if (view && !targetView) continue;
    if (layer && !targetLayer) continue;
    if (cancel && cancel()) break;
    
    CGSize asize = image ? image.size : view ? view.frame.size : layer.frame.size;
    CGRect rect = ((NSValue *)layout.attachmentRects[i]).CGRectValue;
    if (isVertical) {
      rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(a.contentInsets));
    } else {
      rect = UIEdgeInsetsInsetRect(rect, a.contentInsets);
    }
    rect = ASTextCGRectFitWithContentMode(rect, asize, a.contentMode);
    rect = ASTextCGRectPixelRound(rect);
    rect = CGRectStandardize(rect);
    rect.origin.x += point.x + verticalOffset;
    rect.origin.y += point.y;
    if (image) {
      CGImageRef ref = image.CGImage;
      if (ref) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 0, CGRectGetMaxY(rect) + CGRectGetMinY(rect));
        CGContextScaleCTM(context, 1, -1);
        CGContextDrawImage(context, rect, ref);
        CGContextRestoreGState(context);
      }
    } else if (view) {
      view.frame = rect;
      [targetView addSubview:view];
    } else if (layer) {
      layer.frame = rect;
      [targetLayer addSublayer:layer];
    }
  }
}

static void ASTextDrawShadow(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
  //move out of context. (0xFFFF is just a random large number)
  CGFloat offsetAlterX = size.width + 0xFFFF;
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  
  CGContextSaveGState(context); {
    CGContextTranslateCTM(context, point.x, point.y);
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1, -1);
    NSArray *lines = layout.lines;
    for (NSUInteger l = 0, lMax = layout.lines.count; l < lMax; l++) {
      if (cancel && cancel()) break;
      ASTextLine *line = lines[l];
      if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
      NSArray *lineRunRanges = line.verticalRotateRange;
      CGFloat linePosX = line.position.x;
      CGFloat linePosY = size.height - line.position.y;
      CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
      for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextSetTextPosition(context, linePosX, linePosY);
        NSDictionary *attrs = (id)CTRunGetAttributes(run);
        ASTextShadow *shadow = attrs[ASTextShadowAttributeName];
        ASTextShadow *nsShadow = [ASTextShadow shadowWithNSShadow:attrs[NSShadowAttributeName]]; // NSShadow compatible
        if (nsShadow) {
          nsShadow.subShadow = shadow;
          shadow = nsShadow;
        }
        while (shadow) {
          if (!shadow.color) {
            shadow = shadow.subShadow;
            continue;
          }
          CGSize offset = shadow.offset;
          offset.width -= offsetAlterX;
          CGContextSaveGState(context); {
            CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
            CGContextSetBlendMode(context, shadow.blendMode);
            CGContextTranslateCTM(context, offsetAlterX, 0);
            ASTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
          } CGContextRestoreGState(context);
          shadow = shadow.subShadow;
        }
      }
    }
  } CGContextRestoreGState(context);
}

static void ASTextDrawInnerShadow(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, point.x, point.y);
  CGContextTranslateCTM(context, 0, size.height);
  CGContextScaleCTM(context, 1, -1);
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  
  NSArray *lines = layout.lines;
  for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
    if (cancel && cancel()) break;
    
    ASTextLine *line = lines[l];
    if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
    NSArray *lineRunRanges = line.verticalRotateRange;
    CGFloat linePosX = line.position.x;
    CGFloat linePosY = size.height - line.position.y;
    CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
    for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
      CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
      if (CTRunGetGlyphCount(run) == 0) continue;
      CGContextSetTextMatrix(context, CGAffineTransformIdentity);
      CGContextSetTextPosition(context, linePosX, linePosY);
      NSDictionary *attrs = (id)CTRunGetAttributes(run);
      ASTextShadow *shadow = attrs[ASTextInnerShadowAttributeName];
      while (shadow) {
        if (!shadow.color) {
          shadow = shadow.subShadow;
          continue;
        }
        CGPoint runPosition = CGPointZero;
        CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
        CGRect runImageBounds = CTRunGetImageBounds(run, context, CFRangeMake(0, 0));
        runImageBounds.origin.x += runPosition.x;
        if (runImageBounds.size.width < 0.1 || runImageBounds.size.height < 0.1) continue;
        
        CFDictionaryRef runAttrs = CTRunGetAttributes(run);
        NSValue *glyphTransformValue = (NSValue *)CFDictionaryGetValue(runAttrs, (__bridge const void *)(ASTextGlyphTransformAttributeName));
        if (glyphTransformValue) {
          runImageBounds = CGRectMake(0, 0, size.width, size.height);
        }
        
        // text inner shadow
        CGContextSaveGState(context); {
          CGContextSetBlendMode(context, shadow.blendMode);
          CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
          CGContextSetAlpha(context, CGColorGetAlpha(shadow.color.CGColor));
          CGContextClipToRect(context, runImageBounds);
          CGContextBeginTransparencyLayer(context, NULL); {
            UIColor *opaqueShadowColor = [shadow.color colorWithAlphaComponent:1];
            CGContextSetShadowWithColor(context, shadow.offset, shadow.radius, opaqueShadowColor.CGColor);
            CGContextSetFillColorWithColor(context, opaqueShadowColor.CGColor);
            CGContextSetBlendMode(context, kCGBlendModeSourceOut);
            CGContextBeginTransparencyLayer(context, NULL); {
              CGContextFillRect(context, runImageBounds);
              CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
              CGContextBeginTransparencyLayer(context, NULL); {
                ASTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
              } CGContextEndTransparencyLayer(context);
            } CGContextEndTransparencyLayer(context);
          } CGContextEndTransparencyLayer(context);
        } CGContextRestoreGState(context);
        shadow = shadow.subShadow;
      }
    }
  }
  
  CGContextRestoreGState(context);
}

static void ASTextDrawDebug(ASTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, ASTextDebugOption *op) {
  UIGraphicsPushContext(context);
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, point.x, point.y);
  CGContextSetLineWidth(context, 1.0 / ASScreenScale());
  CGContextSetLineDash(context, 0, NULL, 0);
  CGContextSetLineJoin(context, kCGLineJoinMiter);
  CGContextSetLineCap(context, kCGLineCapButt);
  
  BOOL isVertical = layout.container.verticalForm;
  CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
  CGContextTranslateCTM(context, verticalOffset, 0);
  
  if (op.CTFrameBorderColor || op.CTFrameFillColor) {
    UIBezierPath *path = layout.container.path;
    if (!path) {
      CGRect rect = (CGRect){CGPointZero, layout.container.size};
      rect = UIEdgeInsetsInsetRect(rect, layout.container.insets);
      if (op.CTFrameBorderColor) rect = ASTextCGRectPixelHalf(rect);
      else rect = ASTextCGRectPixelRound(rect);
      path = [UIBezierPath bezierPathWithRect:rect];
    }
    [path closePath];
    
    for (UIBezierPath *ex in layout.container.exclusionPaths) {
      [path appendPath:ex];
    }
    if (op.CTFrameFillColor) {
      [op.CTFrameFillColor setFill];
      if (layout.container.pathLineWidth > 0) {
        CGContextSaveGState(context); {
          CGContextBeginTransparencyLayer(context, NULL); {
            CGContextAddPath(context, path.CGPath);
            if (layout.container.pathFillEvenOdd) {
              CGContextEOFillPath(context);
            } else {
              CGContextFillPath(context);
            }
            CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
            [[UIColor blackColor] setFill];
            CGPathRef cgPath = CGPathCreateCopyByStrokingPath(path.CGPath, NULL, layout.container.pathLineWidth, kCGLineCapButt, kCGLineJoinMiter, 0);
            if (cgPath) {
              CGContextAddPath(context, cgPath);
              CGContextFillPath(context);
            }
            CGPathRelease(cgPath);
          } CGContextEndTransparencyLayer(context);
        } CGContextRestoreGState(context);
      } else {
        CGContextAddPath(context, path.CGPath);
        if (layout.container.pathFillEvenOdd) {
          CGContextEOFillPath(context);
        } else {
          CGContextFillPath(context);
        }
      }
    }
    if (op.CTFrameBorderColor) {
      CGContextSaveGState(context); {
        if (layout.container.pathLineWidth > 0) {
          CGContextSetLineWidth(context, layout.container.pathLineWidth);
        }
        [op.CTFrameBorderColor setStroke];
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);
      } CGContextRestoreGState(context);
    }
  }
  
  NSArray *lines = layout.lines;
  for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
    ASTextLine *line = lines[l];
    if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
    CGRect lineBounds = line.bounds;
    if (op.CTLineFillColor) {
      [op.CTLineFillColor setFill];
      CGContextAddRect(context, ASTextCGRectPixelRound(lineBounds));
      CGContextFillPath(context);
    }
    if (op.CTLineBorderColor) {
      [op.CTLineBorderColor setStroke];
      CGContextAddRect(context, ASTextCGRectPixelHalf(lineBounds));
      CGContextStrokePath(context);
    }
    if (op.baselineColor) {
      [op.baselineColor setStroke];
      if (isVertical) {
        CGFloat x = ASTextCGFloatPixelHalf(line.position.x);
        CGFloat y1 = ASTextCGFloatPixelHalf(line.top);
        CGFloat y2 = ASTextCGFloatPixelHalf(line.bottom);
        CGContextMoveToPoint(context, x, y1);
        CGContextAddLineToPoint(context, x, y2);
        CGContextStrokePath(context);
      } else {
        CGFloat x1 = ASTextCGFloatPixelHalf(lineBounds.origin.x);
        CGFloat x2 = ASTextCGFloatPixelHalf(lineBounds.origin.x + lineBounds.size.width);
        CGFloat y = ASTextCGFloatPixelHalf(line.position.y);
        CGContextMoveToPoint(context, x1, y);
        CGContextAddLineToPoint(context, x2, y);
        CGContextStrokePath(context);
      }
    }
    if (op.CTLineNumberColor) {
      [op.CTLineNumberColor set];
      NSMutableAttributedString *num = [[NSMutableAttributedString alloc] initWithString:@(l).description];
      num.as_color = op.CTLineNumberColor;
      num.as_font = [UIFont systemFontOfSize:6];
      [num drawAtPoint:CGPointMake(line.position.x, line.position.y - (isVertical ? 1 : 6))];
    }
    if (op.CTRunFillColor || op.CTRunBorderColor || op.CTRunNumberColor || op.CGGlyphFillColor || op.CGGlyphBorderColor) {
      CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
      for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, r);
        CFIndex glyphCount = CTRunGetGlyphCount(run);
        if (glyphCount == 0) continue;
        
        CGPoint glyphPositions[glyphCount];
        CTRunGetPositions(run, CFRangeMake(0, glyphCount), glyphPositions);
        
        CGSize glyphAdvances[glyphCount];
        CTRunGetAdvances(run, CFRangeMake(0, glyphCount), glyphAdvances);
        
        CGPoint runPosition = glyphPositions[0];
        if (isVertical) {
          ASTEXT_SWAP(runPosition.x, runPosition.y);
          runPosition.x = line.position.x;
          runPosition.y += line.position.y;
        } else {
          runPosition.x += line.position.x;
          runPosition.y = line.position.y - runPosition.y;
        }
        
        CGFloat ascent, descent, leading;
        CGFloat width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
        CGRect runTypoBounds;
        if (isVertical) {
          runTypoBounds = CGRectMake(runPosition.x - descent, runPosition.y, ascent + descent, width);
        } else {
          runTypoBounds = CGRectMake(runPosition.x, line.position.y - ascent, width, ascent + descent);
        }
        
        if (op.CTRunFillColor) {
          [op.CTRunFillColor setFill];
          CGContextAddRect(context, ASTextCGRectPixelRound(runTypoBounds));
          CGContextFillPath(context);
        }
        if (op.CTRunBorderColor) {
          [op.CTRunBorderColor setStroke];
          CGContextAddRect(context, ASTextCGRectPixelHalf(runTypoBounds));
          CGContextStrokePath(context);
        }
        if (op.CTRunNumberColor) {
          [op.CTRunNumberColor set];
          NSMutableAttributedString *num = [[NSMutableAttributedString alloc] initWithString:@(r).description];
          num.as_color = op.CTRunNumberColor;
          num.as_font = [UIFont systemFontOfSize:6];
          [num drawAtPoint:CGPointMake(runTypoBounds.origin.x, runTypoBounds.origin.y - 1)];
        }
        if (op.CGGlyphBorderColor || op.CGGlyphFillColor) {
          for (NSUInteger g = 0; g < glyphCount; g++) {
            CGPoint pos = glyphPositions[g];
            CGSize adv = glyphAdvances[g];
            CGRect rect;
            if (isVertical) {
              ASTEXT_SWAP(pos.x, pos.y);
              pos.x = runPosition.x;
              pos.y += line.position.y;
              rect = CGRectMake(pos.x - descent, pos.y, runTypoBounds.size.width, adv.width);
            } else {
              pos.x += line.position.x;
              pos.y = runPosition.y;
              rect = CGRectMake(pos.x, pos.y - ascent, adv.width, runTypoBounds.size.height);
            }
            if (op.CGGlyphFillColor) {
              [op.CGGlyphFillColor setFill];
              CGContextAddRect(context, ASTextCGRectPixelRound(rect));
              CGContextFillPath(context);
            }
            if (op.CGGlyphBorderColor) {
              [op.CGGlyphBorderColor setStroke];
              CGContextAddRect(context, ASTextCGRectPixelHalf(rect));
              CGContextStrokePath(context);
            }
          }
        }
      }
    }
  }
  CGContextRestoreGState(context);
  UIGraphicsPopContext();
}


- (void)drawInContext:(CGContextRef)context
                 size:(CGSize)size
                point:(CGPoint)point
                 view:(UIView *)view
                layer:(CALayer *)layer
                debug:(ASTextDebugOption *)debug
               cancel:(BOOL (^)(void))cancel{
  @autoreleasepool {
    if (self.needDrawBlockBorder && context) {
      if (cancel && cancel()) return;
      ASTextDrawBlockBorder(self, context, size, point, cancel);
    }
    if (self.needDrawBackgroundBorder && context) {
      if (cancel && cancel()) return;
      ASTextDrawBorder(self, context, size, point, ASTextBorderTypeBackgound, cancel);
    }
    if (self.needDrawShadow && context) {
      if (cancel && cancel()) return;
      ASTextDrawShadow(self, context, size, point, cancel);
    }
    if (self.needDrawUnderline && context) {
      if (cancel && cancel()) return;
      ASTextDrawDecoration(self, context, size, point, ASTextDecorationTypeUnderline, cancel);
    }
    if (self.needDrawText && context) {
      if (cancel && cancel()) return;
      ASTextDrawText(self, context, size, point, cancel);
    }
    if (self.needDrawAttachment && (context || view || layer)) {
      if (cancel && cancel()) return;
      ASTextDrawAttachment(self, context, size, point, view, layer, cancel);
    }
    if (self.needDrawInnerShadow && context) {
      if (cancel && cancel()) return;
      ASTextDrawInnerShadow(self, context, size, point, cancel);
    }
    if (self.needDrawStrikethrough && context) {
      if (cancel && cancel()) return;
      ASTextDrawDecoration(self, context, size, point, ASTextDecorationTypeStrikethrough, cancel);
    }
    if (self.needDrawBorder && context) {
      if (cancel && cancel()) return;
      ASTextDrawBorder(self, context, size, point, ASTextBorderTypeNormal, cancel);
    }
    if (debug.needDrawDebug && context) {
      if (cancel && cancel()) return;
      ASTextDrawDebug(self, context, size, point, debug);
    }
  }
}

- (void)drawInContext:(CGContextRef)context
                 size:(CGSize)size
                debug:(ASTextDebugOption *)debug {
  [self drawInContext:context size:size point:CGPointZero view:nil layer:nil debug:debug cancel:nil];
}

@end
