//
//  ASDisplayNode+AsyncDisplay.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import "ASSignpost.h"
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>

using AS::MutexLocker;

@interface ASDisplayNode () <_ASDisplayLayerDelegate>
@end

@implementation ASDisplayNode (AsyncDisplay)

#if ASDISPLAYNODE_DELAY_DISPLAY
  #define ASDN_DELAY_FOR_DISPLAY() usleep( (long)(0.1 * USEC_PER_SEC) )
#else
  #define ASDN_DELAY_FOR_DISPLAY()
#endif

#define CHECK_CANCELLED_AND_RETURN_NIL(expr)                      if (isCancelledBlock()) { \
                                                                    expr; \
                                                                    return nil; \
                                                                  } \

- (NSObject *)drawParameters
{
  __instanceLock__.lock();
  BOOL implementsDrawParameters = _flags.implementsDrawParameters;
  __instanceLock__.unlock();

  if (implementsDrawParameters) {
    return [self drawParametersForAsyncLayer:self.asyncLayer];
  } else {
    return nil;
  }
}

- (void)_recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock displayBlocks:(NSMutableArray *)displayBlocks
{
  // Skip subtrees that are hidden or zero alpha.
  if (self.isHidden || self.alpha <= 0.0) {
    return;
  }
  
  __instanceLock__.lock();
  BOOL rasterizingFromAscendent = (_hierarchyState & ASHierarchyStateRasterized);
  __instanceLock__.unlock();

  // if super node is rasterizing descendants, subnodes will not have had layout calls because they don't have layers
  if (rasterizingFromAscendent) {
    [self __layout];
  }

  // Capture these outside the display block so they are retained.
  UIColor *backgroundColor = self.backgroundColor;
  CGRect bounds = self.bounds;
  CGFloat cornerRadius = self.cornerRadius;
  BOOL clipsToBounds = self.clipsToBounds;

  CGRect frame;
  
  // If this is the root container node, use a frame with a zero origin to draw into. If not, calculate the correct frame using the node's position, transform and anchorPoint.
  if (self.rasterizesSubtree) {
    frame = CGRectMake(0.0f, 0.0f, bounds.size.width, bounds.size.height);
  } else {
    CGPoint position = self.position;
    CGPoint anchorPoint = self.anchorPoint;
    
    // Pretty hacky since full 3D transforms aren't actually supported, but attempt to compute the transformed frame of this node so that we can composite it into approximately the right spot.
    CGAffineTransform transform = CATransform3DGetAffineTransform(self.transform);
    CGSize scaledBoundsSize = CGSizeApplyAffineTransform(bounds.size, transform);
    CGPoint origin = CGPointMake(position.x - scaledBoundsSize.width * anchorPoint.x,
                                 position.y - scaledBoundsSize.height * anchorPoint.y);
    frame = CGRectMake(origin.x, origin.y, bounds.size.width, bounds.size.height);
  }

  // Get the display block for this node.
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = [self _displayBlockWithAsynchronous:NO isCancelledBlock:isCancelledBlock rasterizing:YES];

  // We'll display something if there is a display block, clipping, translation and/or a background color.
  BOOL shouldDisplay = displayBlock || backgroundColor || CGPointEqualToPoint(CGPointZero, frame.origin) == NO || clipsToBounds;

  // If we should display, then push a transform, draw the background color, and draw the contents.
  // The transform is popped in a block added after the recursion into subnodes.
  if (shouldDisplay) {
    dispatch_block_t pushAndDisplayBlock = ^{
      // Push transform relative to parent.
      CGContextRef context = UIGraphicsGetCurrentContext();
      CGContextSaveGState(context);

      CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);

      //support cornerRadius
      if (rasterizingFromAscendent && clipsToBounds) {
        if (cornerRadius) {
          [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:cornerRadius] addClip];
        } else {
          CGContextClipToRect(context, bounds);
        }
      }

      // Fill background if any.
      CGColorRef backgroundCGColor = backgroundColor.CGColor;
      if (backgroundColor && CGColorGetAlpha(backgroundCGColor) > 0.0) {
        CGContextSetFillColorWithColor(context, backgroundCGColor);
        CGContextFillRect(context, bounds);
      }

      // If there is a display block, call it to get the image, then copy the image into the current context (which is the rasterized container's backing store).
      if (displayBlock) {
        UIImage *image = (UIImage *)displayBlock();
        if (image) {
          BOOL opaque = ASImageAlphaInfoIsOpaque(CGImageGetAlphaInfo(image.CGImage));
          CGBlendMode blendMode = opaque ? kCGBlendModeCopy : kCGBlendModeNormal;
          [image drawInRect:bounds blendMode:blendMode alpha:1];
        }
      }
    };
    [displayBlocks addObject:pushAndDisplayBlock];
  }

  // Recursively capture displayBlocks for all descendants.
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];
  }

  // If we pushed a transform, pop it by adding a display block that does nothing other than that.
  if (shouldDisplay) {
    // Since this block is pure, we can store it statically.
    static dispatch_block_t popBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      popBlock = ^{
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextRestoreGState(context);
      };
    });
    [displayBlocks addObject:popBlock];
  }
}

- (asyncdisplaykit_async_transaction_operation_block_t)_displayBlockWithAsynchronous:(BOOL)asynchronous
                                                                    isCancelledBlock:(asdisplaynode_iscancelled_block_t)isCancelledBlock
                                                                         rasterizing:(BOOL)rasterizing
{
  ASDisplayNodeAssertMainThread();

  asyncdisplaykit_async_transaction_operation_block_t displayBlock = nil;
  ASDisplayNodeFlags flags;
  
  __instanceLock__.lock();

  flags = _flags;
  
  // We always create a graphics context, unless a -display method is used, OR if we are a subnode drawing into a rasterized parent.
  BOOL shouldCreateGraphicsContext = (flags.implementsImageDisplay == NO && rasterizing == NO);
  BOOL shouldBeginRasterizing = (rasterizing == NO && flags.rasterizesSubtree);
  BOOL usesImageDisplay = flags.implementsImageDisplay;
  BOOL usesDrawRect = flags.implementsDrawRect;
  
  if (usesImageDisplay == NO && usesDrawRect == NO && shouldBeginRasterizing == NO) {
    // Early exit before requesting more expensive properties like bounds and opaque from the layer.
    __instanceLock__.unlock();
    return nil;
  }
  
  BOOL opaque = self.opaque;
  CGRect bounds = self.bounds;
  UIColor *backgroundColor = self.backgroundColor;
  CGColorRef borderColor = self.borderColor;
  CGFloat borderWidth = self.borderWidth;
  CGFloat contentsScaleForDisplay = _contentsScaleForDisplay;
    
  __instanceLock__.unlock();

  // Capture drawParameters from delegate on main thread, if this node is displaying itself rather than recursively rasterizing.
  id drawParameters = (shouldBeginRasterizing == NO ? [self drawParameters] : nil);
  
  // Only the -display methods should be called if we can't size the graphics buffer to use.
  if (CGRectIsEmpty(bounds) && (shouldBeginRasterizing || shouldCreateGraphicsContext)) {
    return nil;
  }
  
  ASDisplayNodeAssert(contentsScaleForDisplay != 0.0, @"Invalid contents scale");
  ASDisplayNodeAssert(rasterizing || !(_hierarchyState & ASHierarchyStateRasterized),
                      @"Rasterized descendants should never display unless being drawn into the rasterized container.");

  if (shouldBeginRasterizing) {
    // Collect displayBlocks for all descendants.
    NSMutableArray *displayBlocks = [[NSMutableArray alloc] init];
    [self _recursivelyRasterizeSelfAndSublayersWithIsCancelledBlock:isCancelledBlock displayBlocks:displayBlocks];
    CHECK_CANCELLED_AND_RETURN_NIL();
    
    // If [UIColor clearColor] or another semitransparent background color is used, include alpha channel when rasterizing.
    // Unlike CALayer drawing, we include the backgroundColor as a base during rasterization.
    opaque = opaque && CGColorGetAlpha(backgroundColor.CGColor) == 1.0f;

    displayBlock = ^id{
      CHECK_CANCELLED_AND_RETURN_NIL();
      
        UIImage *image = ASGraphicsCreateImage(self.primitiveTraitCollection, bounds.size, opaque, contentsScaleForDisplay, nil, isCancelledBlock, ^{
            for (dispatch_block_t block in displayBlocks) {
                if (isCancelledBlock()) return;
                block();
            }
        });

      ASDN_DELAY_FOR_DISPLAY();
      return image;
    };
  } else {
    displayBlock = ^id{
      CHECK_CANCELLED_AND_RETURN_NIL();

        __block UIImage *image = nil;
        void (^workWithContext)() = ^{
            CGContextRef currentContext = UIGraphicsGetCurrentContext();
            
            if (shouldCreateGraphicsContext && !currentContext) {
                ASDisplayNodeAssert(NO, @"Failed to create a CGContext (size: %@)", NSStringFromCGSize(bounds.size));
                return;
            }
            
            // For -display methods, we don't have a context, and thus will not call the _willDisplayNodeContentWithRenderingContext or
            // _didDisplayNodeContentWithRenderingContext blocks. It's up to the implementation of -display... to do what it needs.
            [self __willDisplayNodeContentWithRenderingContext:currentContext drawParameters:drawParameters];
            
            if (usesImageDisplay) {                                   // If we are using a display method, we'll get an image back directly.
                image = [self.class displayWithParameters:drawParameters isCancelled:isCancelledBlock];
            } else if (usesDrawRect) {                                // If we're using a draw method, this will operate on the currentContext.
                [self.class drawRect:bounds withParameters:drawParameters isCancelled:isCancelledBlock isRasterizing:rasterizing];
            }
            
            [self __didDisplayNodeContentWithRenderingContext:currentContext image:&image drawParameters:drawParameters backgroundColor:backgroundColor borderWidth:borderWidth borderColor:borderColor];
            ASDN_DELAY_FOR_DISPLAY();
        };
        
        if (shouldCreateGraphicsContext) {
            return ASGraphicsCreateImage(self.primitiveTraitCollection, bounds.size, opaque, contentsScaleForDisplay, nil, isCancelledBlock, workWithContext);
        } else {
            workWithContext();
            return image;
        }
    };
  }

  /**
   If we're profiling, wrap the display block with signpost start and end.
   Color the interval red if cancelled, green otherwise.
   */
#if AS_KDEBUG_ENABLE
  __unsafe_unretained id ptrSelf = self;
  displayBlock = ^{
    ASSignpostStartCustom(ASSignpostLayerDisplay, ptrSelf, 0);
    id result = displayBlock();
    ASSignpostEndCustom(ASSignpostLayerDisplay, ptrSelf, 0, isCancelledBlock() ? ASSignpostColorRed : ASSignpostColorGreen);
    return result;
  };
#endif

  return displayBlock;
}

- (void)__willDisplayNodeContentWithRenderingContext:(CGContextRef)context drawParameters:(id _Nullable)drawParameters
{
  if (context) {
    __instanceLock__.lock();
      ASCornerRoundingType cornerRoundingType = _cornerRoundingType;
      CGFloat cornerRadius = _cornerRadius;
      ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext = _willDisplayNodeContentWithRenderingContext;
    __instanceLock__.unlock();

    if (cornerRoundingType == ASCornerRoundingTypePrecomposited && cornerRadius > 0.0) {
      ASDisplayNodeAssert(context == UIGraphicsGetCurrentContext(), @"context is expected to be pushed on UIGraphics stack %@", self);
      // TODO: This clip path should be removed if we are rasterizing.
      CGRect boundingBox = CGContextGetClipBoundingBox(context);
      [[UIBezierPath bezierPathWithRoundedRect:boundingBox cornerRadius:cornerRadius] addClip];
    }
    
    if (willDisplayNodeContentWithRenderingContext) {
      willDisplayNodeContentWithRenderingContext(context, drawParameters);
    }
  }

}
- (void)__didDisplayNodeContentWithRenderingContext:(CGContextRef)context image:(UIImage **)image drawParameters:(id _Nullable)drawParameters backgroundColor:(UIColor *)backgroundColor borderWidth:(CGFloat)borderWidth borderColor:(CGColorRef)borderColor
{
  if (context == NULL && *image == NULL) {
    return;
  }
  
  __instanceLock__.lock();
    ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext = _didDisplayNodeContentWithRenderingContext;
  __instanceLock__.unlock();
  
  if (context != NULL) {
    if (didDisplayNodeContentWithRenderingContext) {
      didDisplayNodeContentWithRenderingContext(context, drawParameters);
    }
  }
}

- (void)displayAsyncLayer:(_ASDisplayLayer *)asyncLayer asynchronously:(BOOL)asynchronously
{
  ASDisplayNodeAssertMainThread();
  
  __instanceLock__.lock();
  
  if (_hierarchyState & ASHierarchyStateRasterized) {
    __instanceLock__.unlock();
    return;
  }
  
  CALayer *layer = _layer;
  BOOL rasterizesSubtree = _flags.rasterizesSubtree;
  
  __instanceLock__.unlock();

  // for async display, capture the current displaySentinel value to bail early when the job is executed if another is
  // enqueued
  // for sync display, do not support cancellation
  
  // FIXME: what about the degenerate case where we are calling setNeedsDisplay faster than the jobs are dequeuing
  // from the displayQueue?  Need to not cancel early fails from displaySentinel changes.
  asdisplaynode_iscancelled_block_t isCancelledBlock = nil;
  if (asynchronously) {
    uint displaySentinelValue = ++_displaySentinel;
    __weak ASDisplayNode *weakSelf = self;
    isCancelledBlock = ^BOOL{
      __strong ASDisplayNode *self = weakSelf;
      return self == nil || (displaySentinelValue != self->_displaySentinel.load());
    };
  } else {
    isCancelledBlock = ^BOOL{
      return NO;
    };
  }

  // Set up displayBlock to call either display or draw on the delegate and return a UIImage contents
  asyncdisplaykit_async_transaction_operation_block_t displayBlock = [self _displayBlockWithAsynchronous:asynchronously isCancelledBlock:isCancelledBlock rasterizing:NO];
  
  if (!displayBlock) {
    return;
  }
  
  ASDisplayNodeAssert(layer, @"Expect _layer to be not nil");

  // This block is called back on the main thread after rendering at the completion of the current async transaction, or immediately if !asynchronously
  asyncdisplaykit_async_transaction_operation_completion_block_t completionBlock = ^(id<NSObject> value, BOOL canceled){
    ASDisplayNodeCAssertMainThread();
    if (!canceled && !isCancelledBlock()) {
      UIImage *image = (UIImage *)value;
      BOOL stretchable = (NO == UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero));
      if (stretchable) {
        ASDisplayNodeSetResizableContents(layer, image);
      } else {
        layer.contentsScale = self.contentsScale;
        layer.contents = (id)image.CGImage;
      }
      [self didDisplayAsyncLayer:self.asyncLayer];
      
      if (rasterizesSubtree) {
        ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
          [node didDisplayAsyncLayer:node.asyncLayer];
        });
      }
    }
  };

  // Call willDisplay immediately in either case
  [self willDisplayAsyncLayer:self.asyncLayer asynchronously:asynchronously];
  
  if (rasterizesSubtree) {
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
      [node willDisplayAsyncLayer:node.asyncLayer asynchronously:asynchronously];
    });
  }

  if (asynchronously) {
    // Async rendering operations are contained by a transaction, which allows them to proceed and concurrently
    // while synchronizing the final application of the results to the layer's contents property (completionBlock).
    
    // First, look to see if we are expected to join a parent's transaction container.
    CALayer *containerLayer = layer.asyncdisplaykit_parentTransactionContainer ? : layer;
    
    // In the case that a transaction does not yet exist (such as for an individual node outside of a container),
    // this call will allocate the transaction and add it to _ASAsyncTransactionGroup.
    // It will automatically commit the transaction at the end of the runloop.
    _ASAsyncTransaction *transaction = containerLayer.asyncdisplaykit_asyncTransaction;
    
    // Adding this displayBlock operation to the transaction will start it IMMEDIATELY.
    // The only function of the transaction commit is to gate the calling of the completionBlock.
    [transaction addOperationWithBlock:displayBlock priority:self.drawingPriority queue:[_ASDisplayLayer displayQueue] completion:completionBlock];
  } else {
    UIImage *contents = (UIImage *)displayBlock();
    completionBlock(contents, NO);
  }
}

- (void)cancelDisplayAsyncLayer:(_ASDisplayLayer *)asyncLayer
{
  _displaySentinel.fetch_add(1);
}

- (ASDisplayNodeContextModifier)willDisplayNodeContentWithRenderingContext
{
  MutexLocker l(__instanceLock__);
  return _willDisplayNodeContentWithRenderingContext;
}

- (ASDisplayNodeContextModifier)didDisplayNodeContentWithRenderingContext
{
  MutexLocker l(__instanceLock__);
  return _didDisplayNodeContentWithRenderingContext;
}

- (void)setWillDisplayNodeContentWithRenderingContext:(ASDisplayNodeContextModifier)contextModifier
{
  MutexLocker l(__instanceLock__);
  _willDisplayNodeContentWithRenderingContext = contextModifier;
}

- (void)setDidDisplayNodeContentWithRenderingContext:(ASDisplayNodeContextModifier)contextModifier;
{
  MutexLocker l(__instanceLock__);
  _didDisplayNodeContentWithRenderingContext = contextModifier;
}

@end
