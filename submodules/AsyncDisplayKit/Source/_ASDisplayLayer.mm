//
//  _ASDisplayLayer.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/_ASDisplayLayer.h>

#import <objc/runtime.h>

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@implementation _ASDisplayLayer
{
  BOOL _attemptedDisplayWhileZeroSized;

  struct {
    BOOL delegateDidChangeBounds:1;
  } _delegateFlags;
}

@dynamic displaysAsynchronously;

#ifdef DEBUG
- (void)dealloc {
  if (![NSThread isMainThread]) {
    assert(true);
  }
}
#endif

#pragma mark - Properties

- (void)setDelegate:(id)delegate
{
  [super setDelegate:delegate];
  _delegateFlags.delegateDidChangeBounds = [delegate respondsToSelector:@selector(layer:didChangeBoundsWithOldValue:newValue:)];
}

- (void)setDisplaySuspended:(BOOL)displaySuspended
{
  ASDisplayNodeAssertMainThread();
  if (_displaySuspended != displaySuspended) {
    _displaySuspended = displaySuspended;
    if (!displaySuspended) {
      // If resuming display, trigger a display now.
      [self setNeedsDisplay];
    } else {
      // If suspending display, cancel any current async display so that we don't have contents set on us when it's finished.
      [self cancelAsyncDisplay];
    }
  }
}

- (void)setBounds:(CGRect)bounds
{
  BOOL valid = ASDisplayNodeAssertNonFatal(ASIsCGRectValidForLayout(bounds), @"Caught attempt to set invalid bounds %@ on %@.", NSStringFromCGRect(bounds), self);
  if (!valid) {
    return;
  }
  if (_delegateFlags.delegateDidChangeBounds) {
    CGRect oldBounds = self.bounds;
    [super setBounds:bounds];
    self.asyncdisplaykit_node.threadSafeBounds = bounds;
    [(id<ASCALayerExtendedDelegate>)self.delegate layer:self didChangeBoundsWithOldValue:oldBounds newValue:bounds];
    
  } else {
    [super setBounds:bounds];
    self.asyncdisplaykit_node.threadSafeBounds = bounds;
  }

  if (_attemptedDisplayWhileZeroSized && CGRectIsEmpty(bounds) == NO && self.needsDisplayOnBoundsChange == NO) {
    _attemptedDisplayWhileZeroSized = NO;
    [self setNeedsDisplay];
  }
}

#if DEBUG // These override is strictly to help detect application-level threading errors.  Avoid method overhead in release.
- (void)setContents:(id)contents
{
  ASDisplayNodeAssertMainThread();
  [super setContents:contents];
}

- (void)setNeedsLayout
{
  ASDisplayNodeAssertMainThread();
  [super setNeedsLayout];
}
#endif

- (void)layoutSublayers
{
  ASDisplayNodeAssertMainThread();
  [super layoutSublayers];

  [self.asyncdisplaykit_node __layout];
}

- (void)setNeedsDisplay
{
  ASDisplayNodeAssertMainThread();
  
  // FIXME: Reconsider whether we should cancel a display in progress.
  // We should definitely cancel a display that is scheduled, but unstarted display.
  [self cancelAsyncDisplay];

  // Short circuit if display is suspended. When resumed, we will setNeedsDisplay at that time.
  if (!_displaySuspended) {
    [super setNeedsDisplay];
  }
}

#pragma mark -

+ (dispatch_queue_t)displayQueue
{
  static dispatch_queue_t displayQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    displayQueue = dispatch_queue_create("org.AsyncDisplayKit.ASDisplayLayer.displayQueue", DISPATCH_QUEUE_CONCURRENT);
    // we use the highpri queue to prioritize UI rendering over other async operations
    dispatch_set_target_queue(displayQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  });

  return displayQueue;
}

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"displaysAsynchronously"]) {
    return @YES;
  } else if ([key isEqualToString:@"opaque"]) {
    return @YES;
  } else {
    return [super defaultValueForKey:key];
  }
}

#pragma mark - Display

- (void)displayImmediately
{
  // This method is a low-level bypass that avoids touching CA, including any reset of the
  // needsDisplay flag, until the .contents property is set with the result.
  // It is designed to be able to block the thread of any caller and fully execute the display.

  ASDisplayNodeAssertMainThread();
  [self display:NO];
}

- (void)_hackResetNeedsDisplay
{
  ASDisplayNodeAssertMainThread();
  // Don't listen to our subclasses crazy ideas about setContents by going through super
  super.contents = super.contents;
}

- (void)display
{
  ASDisplayNodeAssertMainThread();
  [self _hackResetNeedsDisplay];

  if (self.displaySuspended) {
    return;
  }

  [self display:self.displaysAsynchronously];
}

- (void)display:(BOOL)asynchronously
{
  if (CGRectIsEmpty(self.bounds)) {
    _attemptedDisplayWhileZeroSized = YES;
  }
  
  [self.asyncDelegate displayAsyncLayer:self asynchronously:asynchronously];
}

- (void)cancelAsyncDisplay
{
  ASDisplayNodeAssertMainThread();

  [self.asyncDelegate cancelDisplayAsyncLayer:self];
}

// e.g. <MYTextNodeLayer: 0xFFFFFF; node = <MYTextNode: 0xFFFFFFE; name = "Username node for user 179">>
- (NSString *)description
{
  NSMutableString *description = [[super description] mutableCopy];
  ASDisplayNode *node = self.asyncdisplaykit_node;
  if (node != nil) {
    NSString *classString = [NSString stringWithFormat:@"%s-", object_getClassName(node)];
    [description replaceOccurrencesOfString:@"_ASDisplay" withString:classString options:kNilOptions range:NSMakeRange(0, description.length)];
    NSUInteger insertionIndex = [description rangeOfString:@">"].location;
    if (insertionIndex != NSNotFound) {
      NSString *nodeString = [NSString stringWithFormat:@"; node = %@", node];
      [description insertString:nodeString atIndex:insertionIndex];
    }
  }
  return description;
}

@end
